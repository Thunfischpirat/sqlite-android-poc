#include "SqlitePocBridge.h"
#include "../shared/SqliteDemo.h"

#include <QCoreApplication>
#include <QJsonDocument>
#include <QPluginLoader>
#include <QSqlDriverPlugin>
#include <QtPlugin>
#include <cstdlib>
#include <cstring>
#include <exception>

Q_IMPORT_PLUGIN(QSQLiteDriverPlugin)

extern "C" char *sqlitePocRun(const char *path)
{
    QJsonObject result;
    try {
        // The iOS adapter calls on the main thread and keeps Qt alive between runs.
        static int argc = 1;
        static char name[] = "SqlitePoc";
        static char *argv[] = {name, nullptr};
        static QCoreApplication application(argc, argv);
        QSqlDriverPlugin *factory = nullptr;
        for (QObject *plugin : QPluginLoader::staticInstances()) {
            factory = qobject_cast<QSqlDriverPlugin *>(plugin);
            if (factory)
                break;
        }
        result = runSqliteDemo(QString::fromUtf8(path), factory ? factory->create("QSQLITE") : nullptr);
    } catch (const std::exception &error) {
        result = {{"error", QString::fromUtf8(error.what())}};
    } catch (...) {
        result = {{"error", "Unexpected native error"}};
    }
    const QByteArray json = QJsonDocument(result).toJson(QJsonDocument::Compact);
    auto *copy = static_cast<char *>(std::malloc(size_t(json.size()) + 1));
    if (copy)
        std::memcpy(copy, json.constData(), size_t(json.size()) + 1);
    return copy;
}

extern "C" void sqlitePocFree(char *result)
{
    std::free(result);
}
