# Qt SQLite — Cordova proof of concept

The same screen calls the same Qt SQL demonstration on Android and iOS. It creates a SQLite database in app-private storage, writes a message, closes the database, reopens it read-only and displays the stored message.

## Follow the code

```text
                               Android: Java → JNI ──────┐
HTML → JavaScript → Cordova                              ├→ shared C++ → Qt SQL → SQLite
                               iOS:     Swift → C bridge ─┘
```

| Layer | Source | Responsibility |
| --- | --- | --- |
| Screen | [HTML](www/index.html), [JavaScript](www/js/index.js) | Run the demonstration and show the result |
| Cordova bridge | [SqlitePoc.js](native-plugin/www/SqlitePoc.js) | Send `run` to the platform plugin |
| Android | [Java](native-plugin/src/android/SqlitePoc.java), [JNI](native-plugin/src/android/SqlitePoc.cpp) | Choose the database path and call C++ |
| iOS | [Swift](native-plugin/src/ios/SqlitePoc.swift), [C bridge](native-plugin/src/ios/SqlitePocBridge.cpp) | Choose the database path and call C++ |
| Both platforms | [SqliteDemo.cpp](native-plugin/src/shared/SqliteDemo.cpp) | Create, write, close, reopen and read using Qt's QSQLITE driver |

Android loads the Qt SQLite driver as a library. On iOS, Qt and the driver are linked into the app. The bridge's C interface lets Swift call the shared C++ without exposing Qt types to Swift.

## Android on Windows

Requires Python 3.10+ (64-bit), JDK 21, Node.js/npm, Cordova CLI and Android SDK 36 with platform-tools and command-line tools. Set `JAVA_HOME` and `ANDROID_HOME`.

```powershell
./build.ps1
cordova run android --device
```

The build script prepares its Qt/C++ tools and creates a debug APK. A connected, authorized Android device is required to run it.

## iOS simulator on an Apple Silicon Mac

Use a separate Mac checkout or copy of the project, without generated Android files. Requires Xcode with an iOS 18 or newer simulator, Node 20.17+, Cordova CLI, Python 3 and Homebrew Ruby. For example, on the Mac used for this PoC, `nvm use 20` selects the installed Node version.

Run the one-time setup from the project directory:

```bash
bash setup-ios.sh
```

It puts CMake, Ninja, CocoaPods and Qt 6.12 under `~/Christian/sqlite-poc-tools`. Qt's prebuilt iOS simulator library is for Intel, so setup builds a native ARM64 simulator kit from Qt source; the first setup takes several minutes. Set `SQLITE_POC_TOOLS` before both commands to choose another tools directory.

Build or rebuild the app:

```bash
bash build-ios.sh
```

Open `platforms/ios/App.xcworkspace` in Xcode, select an iPad simulator and run the `App` scheme. Alternatively, install `platforms/ios/build/Debug-iphonesimulator/SqliteAndroidPoc.app` using `xcrun simctl`. This build targets the Apple Silicon simulator; deploying to a physical iPhone or iPad requires a device build and Xcode signing setup.
