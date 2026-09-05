#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusError>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>
#include <QHostAddress>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QRandomGenerator>
#include <QSocketNotifier>
#include <QUuid>

#include <fcntl.h>
#include <unistd.h>
#include <poll.h>

#include <cerrno>

using NmSettings = QMap<QString, QVariantMap>;
using VariantMapList = QList<QVariantMap>;
using ObjectPathList = QList<QDBusObjectPath>;

Q_DECLARE_METATYPE(NmSettings)
Q_DECLARE_METATYPE(VariantMapList)

QDBusArgument &operator<<(QDBusArgument &argument, const NmSettings &settings)
{
    argument.beginMap(QMetaType::fromType<QString>(), QMetaType::fromType<QVariantMap>());
    for (auto it = settings.cbegin(); it != settings.cend(); ++it) {
        argument.beginMapEntry();
        argument << it.key() << it.value();
        argument.endMapEntry();
    }
    argument.endMap();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, NmSettings &settings)
{
    argument.beginMap();
    while (!argument.atEnd()) {
        QString key;
        QVariantMap value;
        argument.beginMapEntry();
        argument >> key >> value;
        argument.endMapEntry();
        settings.insert(key, value);
    }
    argument.endMap();
    return argument;
}

QDBusArgument &operator<<(QDBusArgument &argument, const VariantMapList &list)
{
    argument.beginArray(QMetaType::fromType<QVariantMap>());
    for (const QVariantMap &value : list)
        argument << value;
    argument.endArray();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, VariantMapList &list)
{
    argument.beginArray();
    while (!argument.atEnd()) {
        QVariantMap value;
        argument >> value;
        list.append(value);
    }
    argument.endArray();
    return argument;
}

namespace {
constexpr auto kNmService = "org.freedesktop.NetworkManager";
constexpr auto kNmPath = "/org/freedesktop/NetworkManager";
constexpr auto kNmInterface = "org.freedesktop.NetworkManager";
constexpr auto kSettingsPath = "/org/freedesktop/NetworkManager/Settings";
constexpr auto kSettingsInterface = "org.freedesktop.NetworkManager.Settings";
constexpr auto kConnectionInterface = "org.freedesktop.NetworkManager.Settings.Connection";
constexpr auto kPropertiesInterface = "org.freedesktop.DBus.Properties";
constexpr int kDbusTimeoutMs = 10000;
constexpr int kWriteTimeoutMs = 5000;
constexpr qsizetype kMaxRequestBytes = 256 * 1024;

struct FramedRequest
{
    QByteArray line;
    bool oversized = false;
};

QJsonObject errorObject(const QString &code, const QString &message)
{
    return {{"code", code}, {"message", message}};
}

QVariant unwrapDbusVariant(const QVariant &value)
{
    if (value.metaType() == QMetaType::fromType<QDBusVariant>())
        return value.value<QDBusVariant>().variant();
    return value;
}

template<typename T>
T decodeDbusValue(const QVariant &value)
{
    const QVariant unwrapped = unwrapDbusVariant(value);
    if (unwrapped.canConvert<T>())
        return unwrapped.value<T>();
    if (unwrapped.metaType() == QMetaType::fromType<QDBusArgument>())
        return qdbus_cast<T>(unwrapped.value<QDBusArgument>());
    return {};
}

bool isIpv4(const QString &value)
{
    QHostAddress address;
    return address.setAddress(value) && address.protocol() == QAbstractSocket::IPv4Protocol;
}

QStringList jsonStringList(const QJsonValue &value)
{
    QStringList result;
    if (value.isArray()) {
        for (const QJsonValue &entry : value.toArray()) {
            const QString text = entry.toString().trimmed();
            if (!text.isEmpty()) result.append(text);
        }
        return result;
    }
    for (const QString &entry : value.toString().split(',', Qt::SkipEmptyParts)) {
        const QString text = entry.trimmed();
        if (!text.isEmpty()) result.append(text);
    }
    return result;
}

QString securityLabel(const QString &keyManagement)
{
    if (keyManagement == "sae") return "sae";
    if (keyManagement == "wpa-psk") return "wpa-psk";
    return keyManagement.isEmpty() ? "open" : "unsupported";
}

bool requireReplyArgument(const QDBusMessage &reply, QString *error, const char *message)
{
    if (!reply.arguments().isEmpty()) return true;
    *error = message;
    return false;
}

QList<FramedRequest> takeRequests(QByteArray *buffer, bool *discardingOversizeLine)
{
    QList<FramedRequest> requests;
    while (true) {
        if (*discardingOversizeLine) {
            const qsizetype newline = buffer->indexOf('\n');
            if (newline < 0) {
                buffer->clear();
                return requests;
            }
            buffer->remove(0, newline + 1);
            *discardingOversizeLine = false;
        }

        const qsizetype newline = buffer->indexOf('\n');
        if (newline < 0) {
            if (buffer->size() > kMaxRequestBytes) {
                buffer->clear();
                *discardingOversizeLine = true;
                requests.append({{}, true});
            }
            return requests;
        }

        const QByteArray line = buffer->left(newline);
        buffer->remove(0, newline + 1);
        if (line.size() > kMaxRequestBytes) {
            requests.append({{}, true});
            continue;
        }
        if (!line.trimmed().isEmpty()) requests.append({line.trimmed(), false});
    }
}
}

class NetworkManagerClient final : public QObject
{
    Q_OBJECT

public:
    explicit NetworkManagerClient(QObject *parent = nullptr)
        : QObject(parent), m_bus(QDBusConnection::systemBus())
    {
        m_bus.connect(kNmService, kSettingsPath, kSettingsInterface, "NewConnection",
                      this, SLOT(onConnectionAdded(QDBusObjectPath)));
        m_bus.connect(kNmService, kSettingsPath, kSettingsInterface, "ConnectionRemoved",
                      this, SLOT(onConnectionRemoved(QDBusObjectPath)));
        m_bus.connect(kNmService, QString(), kConnectionInterface, "Updated",
                      this, SLOT(onConnectionUpdated()));
        m_bus.connect(kNmService, kNmPath, kPropertiesInterface, "PropertiesChanged",
                      this, SLOT(onPropertiesChanged(QString,QVariantMap,QStringList)));
    }

    bool available() const
    {
        if (!m_bus.isConnected() || !m_bus.interface()) return false;
        return m_bus.interface()->isServiceRegistered(kNmService).value();
    }

    QJsonObject health() const
    {
        return {
            {"available", available()},
            {"backend", "NetworkManager D-Bus"},
            {"canModify", property(kSettingsPath, kSettingsInterface, "CanModify").toBool()},
            {"version", property(kNmPath, kNmInterface, "Version").toString()}
        };
    }

    QJsonArray listProfiles(QString *error) const
    {
        const QDBusMessage reply = call(kSettingsPath, kSettingsInterface, "ListConnections");
        if (!readReply(reply, error) || reply.arguments().isEmpty()) return {};

        const ObjectPathList activeConnections = decodeDbusValue<ObjectPathList>(
            property(kNmPath, kNmInterface, "ActiveConnections"));
        QSet<QString> activeProfilePaths;
        for (const QDBusObjectPath &activePath : activeConnections) {
            const QDBusObjectPath profilePath = decodeDbusValue<QDBusObjectPath>(
                property(activePath.path(), "org.freedesktop.NetworkManager.Connection.Active", "Connection"));
            if (!profilePath.path().isEmpty()) activeProfilePaths.insert(profilePath.path());
        }

        const ObjectPathList paths = decodeDbusValue<ObjectPathList>(reply.arguments().first());
        QJsonArray profiles;
        for (const QDBusObjectPath &path : paths) {
            QString settingsError;
            const NmSettings settings = getSettings(path.path(), &settingsError);
            if (!settingsError.isEmpty()) continue;
            const QVariantMap connection = settings.value("connection");
            if (connection.value("type").toString() != "802-11-wireless") continue;

            const QVariantMap wifi = settings.value("802-11-wireless");
            const QVariantMap security = settings.value("802-11-wireless-security");
            const QVariantMap ipv4 = settings.value("ipv4");
            const VariantMapList addresses = decodeDbusValue<VariantMapList>(ipv4.value("address-data"));
            const QVariantMap firstAddress = addresses.value(0);
            const QStringList dns = decodeDbusValue<QStringList>(ipv4.value("dns-data"));

            profiles.append(QJsonObject{
                {"path", path.path()},
                {"id", connection.value("id").toString()},
                {"uuid", connection.value("uuid").toString()},
                {"ssid", QString::fromUtf8(wifi.value("ssid").toByteArray())},
                {"active", activeProfilePaths.contains(path.path())},
                {"autoconnect", connection.value("autoconnect", true).toBool()},
                {"priority", connection.value("autoconnect-priority", 0).toInt()},
                {"metered", connection.value("metered", 0).toUInt() == 1},
                {"hidden", wifi.value("hidden", false).toBool()},
                {"security", securityLabel(security.value("key-mgmt").toString())},
                {"ipv4Method", ipv4.value("method", "auto").toString()},
                {"address", firstAddress.value("address").toString()},
                {"prefix", static_cast<int>(firstAddress.value("prefix", 24).toUInt())},
                {"gateway", ipv4.value("gateway").toString()},
                {"dns", QJsonArray::fromStringList(dns)},
                {"versionId", QString::number(property(path.path(), kConnectionInterface, "VersionId").toULongLong())}
            });
        }
        return profiles;
    }

    QJsonObject createProfile(const QJsonObject &params, QString *error)
    {
        NmSettings settings;
        if (!buildSettings(params, &settings, error, {})) return {};

        const QDBusMessage reply = call(kSettingsPath, kSettingsInterface, "AddConnection2",
            {QVariant::fromValue(settings), 1U, QVariantMap{}});
        if (!readReply(reply, error)
                || !requireReplyArgument(reply, error,
                    "NetworkManager returned no connection path for AddConnection2")) return {};
        const QDBusObjectPath path = decodeDbusValue<QDBusObjectPath>(reply.arguments().first());
        if (path.path().isEmpty()) {
            *error = "NetworkManager returned no connection path for AddConnection2";
            return {};
        }
        if (params.value("activate").toBool(true)) {
            QString activationError;
            if (!activatePath(path.path(), &activationError))
                return {{"path", path.path()}, {"saved", true}, {"activated", false}, {"activationError", activationError}};
        }
        return {{"path", path.path()}, {"saved", true}, {"activated", params.value("activate").toBool(true)}};
    }

    QJsonObject updateProfile(const QJsonObject &params, QString *error)
    {
        const QString path = findProfilePath(params, error);
        if (path.isEmpty()) return {};

        NmSettings current = getSettings(path, error);
        if (!error->isEmpty()) return {};
        NmSettings updated;
        if (!buildSettings(params, &updated, error, current)) return {};

        QVariantMap args;
        const QString expectedVersion = params.value("versionId").toString();
        if (!expectedVersion.isEmpty())
            args.insert("version-id", QVariant::fromValue(expectedVersion.toULongLong()));
        const QDBusMessage reply = call(path, kConnectionInterface, "Update2",
            {QVariant::fromValue(updated), 1U, args});
        if (!readReply(reply, error)) return {};

        bool activated = false;
        if (params.value("activate").toBool(false)) {
            QString activationError;
            activated = activatePath(path, &activationError);
            if (!activationError.isEmpty())
                return {{"path", path}, {"saved", true}, {"activated", false}, {"activationError", activationError}};
        }
        return {{"path", path}, {"saved", true}, {"activated", activated}};
    }

    QJsonObject deleteProfile(const QJsonObject &params, QString *error)
    {
        const QString path = findProfilePath(params, error);
        if (path.isEmpty()) return {};
        const QDBusMessage reply = call(path, kConnectionInterface, "Delete");
        if (!readReply(reply, error)) return {};
        return {{"deleted", true}};
    }

    QJsonObject activateProfile(const QJsonObject &params, QString *error)
    {
        const QString path = findProfilePath(params, error);
        if (path.isEmpty()) return {};
        if (!activatePath(path, error)) return {};
        return {{"activationRequested", true}};
    }

signals:
    void profilesChanged();

private slots:
    void onConnectionAdded(const QDBusObjectPath &) { emit profilesChanged(); }
    void onConnectionRemoved(const QDBusObjectPath &) { emit profilesChanged(); }
    void onConnectionUpdated() { emit profilesChanged(); }
    void onPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &)
    {
        if (interface == kNmInterface && changed.contains("ActiveConnections"))
            emit profilesChanged();
    }

private:
    QVariant property(const QString &path, const QString &interface, const QString &name) const
    {
        const QDBusMessage reply = call(path, kPropertiesInterface, "Get", {interface, name});
        if (reply.type() == QDBusMessage::ErrorMessage || reply.arguments().isEmpty()) return {};
        return unwrapDbusVariant(reply.arguments().first());
    }

    QDBusMessage call(const QString &path, const QString &interface, const QString &method,
                      const QVariantList &arguments = {}) const
    {
        QDBusMessage message = QDBusMessage::createMethodCall(kNmService, path, interface, method);
        message.setArguments(arguments);
        return m_bus.call(message, QDBus::Block, kDbusTimeoutMs);
    }

    static bool readReply(const QDBusMessage &reply, QString *error)
    {
        if (reply.type() != QDBusMessage::ErrorMessage) return true;
        *error = reply.errorMessage().isEmpty() ? reply.errorName() : reply.errorMessage();
        return false;
    }

    NmSettings getSettings(const QString &path, QString *error) const
    {
        const QDBusMessage reply = call(path, kConnectionInterface, "GetSettings");
        if (!readReply(reply, error) || reply.arguments().isEmpty()) return {};
        return decodeDbusValue<NmSettings>(reply.arguments().first());
    }

    QString findProfilePath(const QJsonObject &params, QString *error) const
    {
        const QString directPath = params.value("path").toString();
        if (directPath.startsWith("/org/freedesktop/NetworkManager/Settings/")) return directPath;

        const QString uuid = params.value("uuid").toString();
        if (uuid.isEmpty()) {
            *error = "A saved profile path or UUID is required";
            return {};
        }
        const QDBusMessage reply = call(kSettingsPath, kSettingsInterface, "GetConnectionByUuid", {uuid});
        if (!readReply(reply, error)
                || !requireReplyArgument(reply, error,
                    "No saved profile matches the requested UUID")) return {};
        const QString resolved = decodeDbusValue<QDBusObjectPath>(reply.arguments().first()).path();
        if (resolved.isEmpty())
            *error = "No saved profile matches the requested UUID";
        return resolved;
    }

    QString wifiDevicePath(QString *error) const
    {
        const QDBusMessage reply = call(kNmPath, kNmInterface, "GetDevices");
        if (!readReply(reply, error) || reply.arguments().isEmpty()) return {};
        const ObjectPathList devices = decodeDbusValue<ObjectPathList>(reply.arguments().first());
        for (const QDBusObjectPath &device : devices) {
            if (property(device.path(), "org.freedesktop.NetworkManager.Device", "DeviceType").toUInt() == 2)
                return device.path();
        }
        *error = "No Wi-Fi device is available";
        return {};
    }

    bool activatePath(const QString &profilePath, QString *error) const
    {
        const QString devicePath = wifiDevicePath(error);
        if (devicePath.isEmpty()) return false;
        const QDBusMessage reply = call(kNmPath, kNmInterface, "ActivateConnection", {
            QVariant::fromValue(QDBusObjectPath(profilePath)),
            QVariant::fromValue(QDBusObjectPath(devicePath)),
            QVariant::fromValue(QDBusObjectPath("/"))
        });
        return readReply(reply, error);
    }

    static bool buildSettings(const QJsonObject &params, NmSettings *settings, QString *error,
                              const NmSettings &base)
    {
        const QString ssid = params.value("ssid").toString().trimmed();
        if (ssid.isEmpty() || ssid.toUtf8().size() > 32) {
            *error = "SSID must contain 1 to 32 bytes";
            return false;
        }

        const QString security = params.value("security").toString("open");
        if (security != "open" && security != "wpa-psk" && security != "sae") {
            *error = "Only open, WPA/WPA2 PSK, and SAE profiles are supported";
            return false;
        }
        const QString password = params.value("password").toString();
        if (password.size() > 64) {
            *error = "Password must not exceed 64 characters";
            return false;
        }
        if (security != "open" && password.size() < 8) {
            *error = base.contains("802-11-wireless-security")
                ? "Re-enter the password to save changes to a secured network"
                : "A password of at least 8 characters is required";
            return false;
        }

        NmSettings next = base;
        QVariantMap connection = next.value("connection");
        const QString name = params.value("name").toString().trimmed();
        connection.insert("id", name.isEmpty() ? ssid : name);
        connection.insert("uuid", connection.value("uuid").toString().isEmpty()
            ? QUuid::createUuid().toString(QUuid::WithoutBraces) : connection.value("uuid"));
        connection.insert("type", "802-11-wireless");
        connection.insert("autoconnect", params.value("autoconnect").toBool(true));
        connection.insert("autoconnect-priority", params.value("priority").toInt(0));
        connection.insert("metered", params.value("metered").toBool(false) ? 1U : 2U);
        next.insert("connection", connection);

        QVariantMap wifi = next.value("802-11-wireless");
        wifi.insert("ssid", ssid.toUtf8());
        wifi.insert("mode", "infrastructure");
        wifi.insert("hidden", params.value("hidden").toBool(false));
        next.insert("802-11-wireless", wifi);

        if (security == "open") {
            next.remove("802-11-wireless-security");
        } else {
            QVariantMap wifiSecurity = next.value("802-11-wireless-security");
            wifiSecurity.insert("key-mgmt", security);
            if (!password.isEmpty()) wifiSecurity.insert("psk", password);
            next.insert("802-11-wireless-security", wifiSecurity);
        }

        const QString ipv4Method = params.value("ipv4Method").toString("auto");
        if (ipv4Method != "auto" && ipv4Method != "manual") {
            *error = "IPv4 method must be auto or manual";
            return false;
        }
        QVariantMap ipv4 = next.value("ipv4");
        ipv4.insert("method", ipv4Method);
        ipv4.remove("address-data");
        ipv4.remove("addresses");
        ipv4.remove("gateway");
        ipv4.remove("dns-data");
        ipv4.remove("dns");
        ipv4.remove("ignore-auto-dns");
        const QStringList dns = jsonStringList(params.value("dns"));
        for (const QString &server : dns) {
            if (!isIpv4(server)) {
                *error = "DNS entries must be valid IPv4 addresses";
                return false;
            }
        }
        if (!dns.isEmpty()) {
            ipv4.insert("dns-data", dns);
            ipv4.insert("ignore-auto-dns", true);
        }
        if (ipv4Method == "manual") {
            const QString address = params.value("address").toString().trimmed();
            const QString gateway = params.value("gateway").toString().trimmed();
            const int prefix = params.value("prefix").toInt(24);
            if (!isIpv4(address) || prefix < 1 || prefix > 32 || (!gateway.isEmpty() && !isIpv4(gateway))) {
                *error = "Manual IPv4 address, prefix, or gateway is invalid";
                return false;
            }
            VariantMapList addresses;
            addresses.append({{"address", address}, {"prefix", static_cast<uint>(prefix)}});
            ipv4.insert("address-data", QVariant::fromValue(addresses));
            if (!gateway.isEmpty()) ipv4.insert("gateway", gateway);
        }
        next.insert("ipv4", ipv4);
        if (!next.contains("ipv6")) next.insert("ipv6", {{"method", "auto"}});

        *settings = next;
        return true;
    }

    QDBusConnection m_bus;
};

class Protocol final : public QObject
{
    Q_OBJECT

public:
    explicit Protocol(QObject *parent = nullptr)
        : QObject(parent), m_notifier(STDIN_FILENO, QSocketNotifier::Read, this)
    {
        connect(&m_notifier, &QSocketNotifier::activated, this, &Protocol::readAvailable);
        connect(&m_client, &NetworkManagerClient::profilesChanged, this, [this]() {
            write({{"event", "profiles_changed"}});
        });
    }

    static bool selfTest()
    {
        const QByteArray line = R"({"id":"1","method":"health","params":{}})";
        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(line, &error);
        QString missingArgumentError;
        const bool rejectedMissingArgument = !requireReplyArgument(
            QDBusMessage(), &missingArgumentError, "missing argument");
        QByteArray oversized(kMaxRequestBytes + 1, 'x');
        bool discardingOversizeLine = false;
        const QList<FramedRequest> rejected = takeRequests(&oversized, &discardingOversizeLine);
        const bool beganDiscarding = discardingOversizeLine;
        oversized = "discarded tail\n" + line + '\n';
        const QList<FramedRequest> recovered = takeRequests(&oversized, &discardingOversizeLine);
        return error.error == QJsonParseError::NoError
            && document.object().value("method").toString() == "health"
            && kMaxRequestBytes == 262144
            && kWriteTimeoutMs == 5000
            && securityLabel("wpa-psk") == "wpa-psk"
            && securityLabel("wpa-none") == "unsupported"
            && rejectedMissingArgument
            && missingArgumentError == "missing argument"
            && rejected.size() == 1
            && rejected.first().oversized
            && beganDiscarding
            && recovered.size() == 1
            && recovered.first().line == line
            && !recovered.first().oversized
            && !discardingOversizeLine;
    }

private slots:
    void readAvailable()
    {
        char input[8192];
        const ssize_t bytesRead = ::read(STDIN_FILENO, input, sizeof(input));
        if (bytesRead == 0) {
            QCoreApplication::quit();
            return;
        }
        if (bytesRead < 0) {
            if (errno != EAGAIN && errno != EINTR) QCoreApplication::exit(1);
            return;
        }
        m_buffer.append(input, bytesRead);
        const QList<FramedRequest> requests = takeRequests(&m_buffer, &m_discardingOversizeLine);
        for (const FramedRequest &request : requests) {
            if (request.oversized) {
                write({{"ok", false}, {"error", errorObject("PAYLOAD_TOO_LARGE", "Request exceeds 256 KiB")}});
            } else {
                handleLine(request.line);
            }
            if (m_outputFailed) return;
        }
    }

private:
    void handleLine(const QByteArray &line)
    {
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(line, &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            write({{"ok", false}, {"error", errorObject("INVALID_JSON", "Request must be one JSON object")}});
            return;
        }

        const QJsonObject request = document.object();
        const QJsonValue id = request.value("id");
        const QString method = request.value("method").toString();
        const QJsonObject params = request.value("params").toObject();
        if (id.isUndefined() || method.isEmpty()) {
            write({{"id", id}, {"ok", false}, {"error", errorObject("INVALID_REQUEST", "id and method are required")}});
            return;
        }

        QString error;
        QJsonValue result;
        if (method == "health") result = m_client.health();
        else if (method == "list_profiles") result = m_client.listProfiles(&error);
        else if (method == "create_profile") result = m_client.createProfile(params, &error);
        else if (method == "update_profile") result = m_client.updateProfile(params, &error);
        else if (method == "delete_profile") result = m_client.deleteProfile(params, &error);
        else if (method == "activate_profile") result = m_client.activateProfile(params, &error);
        else {
            write({{"id", id}, {"ok", false}, {"error", errorObject("METHOD_NOT_FOUND", "Unknown method")}});
            return;
        }

        if (!error.isEmpty()) {
            write({{"id", id}, {"ok", false}, {"error", errorObject("BACKEND_ERROR", error)}});
            return;
        }
        write({{"id", id}, {"ok", true}, {"result", result}});
    }

    void write(const QJsonObject &message)
    {
        if (m_outputFailed) return;
        const QByteArray data = QJsonDocument(message).toJson(QJsonDocument::Compact) + '\n';
        qsizetype written = 0;
        while (written < data.size()) {
            const ssize_t result = ::write(STDOUT_FILENO, data.constData() + written,
                                           static_cast<size_t>(data.size() - written));
            if (result > 0) {
                written += result;
                continue;
            }
            if (result < 0 && errno == EINTR) continue;
            if (result < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                pollfd descriptor{STDOUT_FILENO, POLLOUT, 0};
                int ready;
                do {
                    ready = ::poll(&descriptor, 1, kWriteTimeoutMs);
                } while (ready < 0 && errno == EINTR);
                if (ready > 0 && (descriptor.revents & POLLOUT)) continue;
            }
            m_outputFailed = true;
            QCoreApplication::exit(1);
            return;
        }
    }

    QSocketNotifier m_notifier;
    QByteArray m_buffer;
    bool m_discardingOversizeLine = false;
    bool m_outputFailed = false;
    NetworkManagerClient m_client;
};

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    qDBusRegisterMetaType<NmSettings>();
    qDBusRegisterMetaType<VariantMapList>();

    if (app.arguments().contains("--self-test"))
        return Protocol::selfTest() ? 0 : 1;

    const int stdoutFlags = ::fcntl(STDOUT_FILENO, F_GETFL, 0);
    if (stdoutFlags < 0 || ::fcntl(STDOUT_FILENO, F_SETFL, stdoutFlags | O_NONBLOCK) < 0)
        return 1;

    Protocol protocol;
    return app.exec();
}

#include "main.moc"
