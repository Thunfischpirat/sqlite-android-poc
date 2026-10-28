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

// Workflow: Open → CREATE TABLE → INSERT → Close → Reopen read-only → SELECT → Return message → Cleanup

static QJsonObject runDemo(const QString &path, const QString &driverPath)
{
    // Initialize Qt
    int argc = 1;
    char name[] = "SqlitePoc";
    char *argv[] = {name, nullptr};
    QCoreApplication application(argc, argv);
    // Load SQLite driver
    QPluginLoader loader(driverPath);
    auto *factory = qobject_cast<QSqlDriverPlugin *>(loader.instance());
    // Create and open database
    auto *driver = factory->create("QSQLITE");
    auto database = QSqlDatabase::addDatabase(driver, "poc");
    const auto cleanup = qScopeGuard([&] {
        database.close();
        database = QSqlDatabase();
        QSqlDatabase::removeDatabase("poc");
    });
    database.setDatabaseName(path);
    bool opened = database.open();
    // Create table and write message 
    {
        QSqlQuery query(database);
        bool created = query.exec(
            "CREATE TABLE IF NOT EXISTS demo (id INTEGER PRIMARY KEY, message TEXT)");
        bool inserted = query.exec(
            "INSERT OR IGNORE INTO demo VALUES (1, 'Hello from Qt SQLite')");
    }
    // Demonstrate persistence
    database.close();
    database.setConnectOptions("QSQLITE_OPEN_READONLY");
    opened = database.open();
    QSqlQuery query(database);
    bool selected = query.exec("SELECT message FROM demo WHERE id = 1");
    query.next();
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
    const QString json = QString::fromUtf8(
        QJsonDocument(result).toJson(QJsonDocument::Compact)
    );
    const QJniObject javaString = QJniObject::fromString(json);
    return static_cast<jstring>(env->NewLocalRef(javaString.object()));
}
