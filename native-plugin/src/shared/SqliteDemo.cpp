#include "SqliteDemo.h"

#include <QScopeGuard>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QVariant>

QJsonObject runSqliteDemo(const QString &path, QSqlDriver *driver)
{
    if (!driver)
        return {{"error", "QSQLITE driver is unavailable"}};

    auto database = QSqlDatabase::addDatabase(driver, "poc");
    const auto cleanup = qScopeGuard([&] {
        database.close();
        database = QSqlDatabase();
        QSqlDatabase::removeDatabase("poc");
    });
    database.setDatabaseName(path);
    if (!database.open())
        return {{"error", database.lastError().text()}};

    {
        QSqlQuery query(database);
        if (!query.exec("CREATE TABLE IF NOT EXISTS demo (id INTEGER PRIMARY KEY, message TEXT)"))
            return {{"error", query.lastError().text()}};
        if (!query.exec("INSERT OR IGNORE INTO demo VALUES (1, 'Hello from Qt SQLite')"))
            return {{"error", query.lastError().text()}};
    }

    database.close();
    database.setConnectOptions("QSQLITE_OPEN_READONLY");
    if (!database.open())
        return {{"error", database.lastError().text()}};
    QSqlQuery query(database);
    if (!query.exec("SELECT message FROM demo WHERE id = 1"))
        return {{"error", query.lastError().text()}};
    if (!query.next())
        return {{"error", "Stored message not found"}};
    return {{"path", path}, {"message", query.value(0).toString()}};
}
