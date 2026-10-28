#include <jni.h>
#include <QCoreApplication>
#include <QJniObject>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPluginLoader>
#include <QScopeGuard>
#include <QSqlDatabase>
#include <QSqlDriverPlugin>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>
#include <stdexcept>

static void check(bool success, const QString &error)
{
    if (!success) throw std::runtime_error(error.toStdString());
}

static QJsonObject runDemo(const QString &path, const QString &driverPath)
{
    int argc = 1;
    char name[] = "SqlitePoc";
    char *argv[] = {name, nullptr};
    QCoreApplication application(argc, argv);
    QPluginLoader loader(driverPath);
    auto *factory = qobject_cast<QSqlDriverPlugin *>(loader.instance());
    check(factory != nullptr, "Cannot load SQLite driver: " + loader.errorString());
    auto *driver = factory->create("QSQLITE");
    check(driver != nullptr, "QSQLITE driver unavailable");
    auto database = QSqlDatabase::addDatabase(driver, "poc");
    const auto cleanup = qScopeGuard([&] {
        database.close();
        database = QSqlDatabase();
        QSqlDatabase::removeDatabase("poc");
    });
    database.setDatabaseName(path);
    bool opened = database.open();
    check(opened, database.lastError().text());
    {
        QSqlQuery query(database);
        bool created = query.exec(
            "CREATE TABLE IF NOT EXISTS demo (id INTEGER PRIMARY KEY, message TEXT)");
        check(created, query.lastError().text());
        bool inserted = query.exec(
            "INSERT OR IGNORE INTO demo VALUES (1, 'Hello from Qt SQLite')");
        check(inserted, query.lastError().text());
    }
    // Destroy the query before closing; the second open cannot create a file.
    database.close();
    database.setConnectOptions("QSQLITE_OPEN_READONLY");
    opened = database.open();
    check(opened, database.lastError().text());
    QSqlQuery query(database);
    bool selected = query.exec("SELECT message FROM demo WHERE id = 1");
    check(selected, query.lastError().text());
    check(query.next(), "Saved demonstration row was not found");
    return {{"path", path}, {"message", query.value(0).toString()}};
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_sqlitepoc_SqlitePoc_nativeRun(
    JNIEnv *env, jclass, jstring path, jstring driverPath)
{
    QJsonObject result;
    try {
        result = runDemo(QJniObject(path).toString(), QJniObject(driverPath).toString());
    } catch (const std::exception &error) {
        result = {{"error", QString::fromUtf8(error.what())}};
    }
    const QString json = QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact));
    return env->NewString(reinterpret_cast<const jchar *>(json.utf16()), json.size());
}
