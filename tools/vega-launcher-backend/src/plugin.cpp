#include "nativeappsearchmodel.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

class VegaLauncherPlugin final : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<NativeAppSearchModel>(uri, 1, 0, "NativeAppSearchModel");
    }
};

#include "plugin.moc"
