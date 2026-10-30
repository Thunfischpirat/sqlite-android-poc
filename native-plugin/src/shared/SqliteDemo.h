#pragma once

#include <QJsonObject>
#include <QString>

class QSqlDriver;

// Qt takes ownership of the QSQLITE driver supplied by the platform adapter.
QJsonObject runSqliteDemo(const QString &path, QSqlDriver *driver);
