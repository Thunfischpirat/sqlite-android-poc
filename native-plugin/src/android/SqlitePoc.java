package com.example.sqlitepoc;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;

public class SqlitePoc extends CordovaPlugin {
    static {
        System.loadLibrary("c++_shared");
        System.loadLibrary("Qt6Core_arm64-v8a");
        System.loadLibrary("Qt6Sql_arm64-v8a");
        System.loadLibrary("SqlitePoc");
    }

    private static native String nativeRun(String path, String driverPath);

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callback) {
        if (!"run".equals(action)) return false;
        cordova.getThreadPool().execute(() -> {
            try {
                var activity = cordova.getActivity();
                String path = new File(activity.getFilesDir(), "demo.sqlite").getPath();
                String driver = new File(activity.getApplicationInfo().nativeLibraryDir,
                    "libplugins_sqldrivers_qsqlite_arm64-v8a.so").getPath();
                JSONObject result = new JSONObject(nativeRun(path, driver));
                if (result.has("error")) callback.error(result.getString("error"));
                else callback.success(result);
            } catch (Exception error) {
                callback.error(error.toString());
            }
        });
        return true;
    }
}
