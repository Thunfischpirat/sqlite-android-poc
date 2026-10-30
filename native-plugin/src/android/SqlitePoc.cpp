#include "../shared/SqliteDemo.h"

#include <jni.h>
#include <QCoreApplication>
#include <QJniObject>
#include <QJsonDocument>
#include <QPluginLoader>
#include <QSqlDriverPlugin>
#include <exception>

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_sqlitepoc_SqlitePoc_nativeRun(
    JNIEnv *env, jclass, jstring path, jstring driverPath)
{
    QJsonObject result;
    try {
        int argc = 1;
        char name[] = "SqlitePoc";
        char *argv[] = {name, nullptr};
        QCoreApplication application(argc, argv);
        QPluginLoader loader(QJniObject(driverPath).toString());
        auto *factory = qobject_cast<QSqlDriverPlugin *>(loader.instance());
        if (!factory)
            result = {{"error", loader.errorString()}};
        else
            result = runSqliteDemo(QJniObject(path).toString(), factory->create("QSQLITE"));
    } catch (const std::exception &error) {
        result = {{"error", QString::fromUtf8(error.what())}};
    }
    const QString json = QString::fromUtf8(QJsonDocument(result).toJson(QJsonDocument::Compact));
    const QJniObject javaString = QJniObject::fromString(json);
    return static_cast<jstring>(env->NewLocalRef(javaString.object()));
}
