#include "nativeappsearchmodel.h"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QPersistentModelIndex>
#include <QThread>

#include <functional>
#include <iostream>

namespace {

bool waitUntil(const std::function<bool()> &condition, int timeoutMs = 3000)
{
    QElapsedTimer timer;
    timer.start();
    while (!condition() && timer.elapsed() < timeoutMs) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 20);
        QThread::msleep(1);
    }
    return condition();
}

int fail(const char *message)
{
    std::cerr << message << '\n';
    return 1;
}

} // namespace

int main(int argc, char **argv)
{
    QCoreApplication application(argc, argv);
    NativeAppSearchModel model;

    int searchCompletions = 0;
    QObject::connect(&model, &NativeAppSearchModel::searchFinished,
                     [&searchCompletions] { ++searchCompletions; });
    model.search("pre-index", 1, {QVariantMap{{"key", "fallback"}, {"name", "Fallback"}}});
    if (searchCompletions != 1 || model.rowCount() != 1)
        return fail("pre-index fallback search did not signal completion");

    model.rebuildIndex({
        QVariantMap{{"id", "firefox.desktop"}, {"name", "Firefox"}, {"iconName", "firefox"}},
        QVariantMap{{"id", "firefox.desktop"}, {"name", "Firefox Duplicate"}, {"iconName", "firefox"}},
        QVariantMap{{"id", "files.desktop"}, {"name", "Files"}, {"iconName", "system-file-manager"}},
        QVariantMap{{"id", "terminal.desktop"}, {"name", "Kitty Terminal"}, {"iconName", "kitty"}},
    });
    model.search("fir", 2);
    if (!waitUntil([&model] { return model.indexReady() && !model.busy() && model.rowCount() == 1; }))
        return fail("native search did not finish");
    if (model.get(0).value("id").toString() != "firefox.desktop")
        return fail("native search returned the wrong first result");

    int resets = 0;
    int layouts = 0;
    int insertBatches = 0;
    int moves = 0;
    QObject::connect(&model, &QAbstractItemModel::modelReset, [&resets] { ++resets; });
    QObject::connect(&model, &QAbstractItemModel::layoutChanged, [&layouts] { ++layouts; });
    QObject::connect(&model, &QAbstractItemModel::rowsInserted, [&insertBatches] { ++insertBatches; });
    QObject::connect(&model, &QAbstractItemModel::rowsMoved, [&moves] { ++moves; });
    const QPersistentModelIndex firstResultSlot = model.index(0);
    model.search("fi", 3, {QVariantMap{{"key", "web-search"}, {"name", "fi"}}});
    if (!waitUntil([&model] { return !model.busy() && model.rowCount() == 2; }))
        return fail("confident application search kept a generic fallback");
    if (model.get(1).value("id").toString() != "firefox.desktop")
        return fail("native search did not deduplicate application IDs");
    if (firstResultSlot.row() != 0
        || model.data(firstResultSlot, NativeAppSearchModel::ModelDataRole).toMap().value("id") != "files.desktop")
        return fail("stable result slot was recreated while rankings changed");
    if (layouts != 0 || insertBatches != 1 || moves != 0)
        return fail("native search did not batch structural model updates");
    if (resets != 0)
        return fail("stable result model unexpectedly reset");

    model.rebuildIndex({
        QVariantMap{{"id", "heroic.desktop"}, {"name", "Heroic Games Launcher"}, {"iconName", "heroic"}},
        QVariantMap{{"id", "avahi.desktop"}, {"name", "Avahi Zeroconf Browser"}, {"iconName", "network-workgroup"}},
        QVariantMap{{"id", "bssh.desktop"}, {"name", "Avahi SSH Server Browser"}, {"iconName", "network-workgroup"}},
        QVariantMap{{"id", "bvnc.desktop"}, {"name", "Avahi VNC Server Browser"}, {"iconName", "network-workgroup"}},
    });
    const QVariantList genericActions = {
        QVariantMap{{"key", "command"}, {"name", "her"}},
        QVariantMap{{"key", "web-search"}, {"name", "her"}},
    };
    model.search("her", 7, genericActions);
    if (!waitUntil([&model] {
            return model.indexReady() && !model.busy() && model.rowCount() > 0
                && model.get(0).value("id") == "heroic.desktop";
        }))
        return fail("confident prefix search did not rank Heroic Games Launcher first");
    if (model.get(0).value("id") != "heroic.desktop")
        return fail("short prefix did not predict Heroic Games Launcher");
    for (int row = 0; row < model.rowCount(); ++row) {
        if (!model.get(row).value("nativeApp").toBool())
            return fail("confident application search kept a generic action");
    }

    model.search("games lau", 7, genericActions);
    if (!waitUntil([&model] { return !model.busy() && model.rowCount() == 1; })
        || model.get(0).value("id") != "heroic.desktop")
        return fail("multi-word prefixes did not resolve Heroic Games Launcher");

    model.search("hgl", 7, genericActions);
    if (!waitUntil([&model] { return !model.busy() && model.rowCount() == 1; })
        || model.get(0).value("id") != "heroic.desktop")
        return fail("application initials did not resolve Heroic Games Launcher");

    model.search("no-native-match", 4, {
        QVariantMap{{"key", "a"}, {"name", "A"}},
        QVariantMap{{"key", "b"}, {"name", "B"}},
        QVariantMap{{"key", "c"}, {"name", "C"}},
        QVariantMap{{"key", "d"}, {"name", "D"}},
    });
    if (!waitUntil([&model] { return !model.busy() && model.rowCount() == 4; }))
        return fail("native search did not apply the first fallback-only result set");
    const QPersistentModelIndex secondResultSlot = model.index(1);

    model.search("no-native-match", 4, {
        QVariantMap{{"key", "d"}, {"name", "D"}},
        QVariantMap{{"key", "a"}, {"name", "A"}},
        QVariantMap{{"key", "b"}, {"name", "B"}},
        QVariantMap{{"key", "e"}, {"name", "E"}},
    });
    if (!waitUntil([&model] { return !model.busy() && model.get(3).value("key") == "e"; }))
        return fail("native search did not apply the reordered fallback result set");
    if (secondResultSlot.row() != 1 || model.get(secondResultSlot.row()).value("key") != "a")
        return fail("stable result slot was recreated during mixed result changes");
    if (resets != 0)
        return fail("stable result model reset during mixed structural changes");

    model.search("", 20);
    if (!waitUntil([&model] { return !model.busy() && model.rowCount() == 4; }))
        return fail("empty query did not return the full application index");
    for (int row = 1; row < model.rowCount(); ++row) {
        const QString previous = model.get(row - 1).value("name").toString();
        const QString current = model.get(row).value("name").toString();
        if (QString::localeAwareCompare(previous, current) > 0)
            return fail("empty-query applications are not alphabetically ordered");
    }

    model.rebuildIndex({
        QVariantMap{{"id", "btop.desktop"}, {"name", "btop"}, {"iconName", "btop"}},
        QVariantMap{{"id", "brave.desktop"}, {"name", "Brave Browser"}, {"iconName", "brave"}, {"usageBonus", 19'000}},
    });
    model.search("b", 2);
    if (!waitUntil([&model] { return model.indexReady() && !model.busy() && model.rowCount() == 2; })
        || model.get(0).value("id") != "brave.desktop")
        return fail("launcher usage did not rerank equal-prefix applications");

    model.search("btop", 2);
    if (!waitUntil([&model] { return !model.busy() && model.rowCount() == 1; })
        || model.get(0).value("id") != "btop.desktop")
        return fail("launcher usage overrode an exact application match");

    return 0;
}
