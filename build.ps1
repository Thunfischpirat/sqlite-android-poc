# One command: install the fixed Qt/C++ tools, then build the debug APK.
$ErrorActionPreference = 'Stop'
$qtVersion = '6.12.0'
$ndkVersion = '27.2.12479018'
$toolPackages = @('aqtinstall==3.3.0', 'cmake==4.4.4', 'ninja==1.13.2')
$toolsRoot = Join-Path $env:LOCALAPPDATA 'sqlite-android-poc-tools'
$qtRoot = Join-Path $toolsRoot 'Qt'
$qtAndroid = Join-Path $qtRoot "$qtVersion/android_arm64_v8a"
$qtHost = Join-Path $qtRoot "$qtVersion/mingw_64"
$python = Join-Path $toolsRoot 'python/Scripts/python.exe'
$cmake = Join-Path $toolsRoot 'python/Scripts/cmake.exe'
$ninja = Join-Path $toolsRoot 'python/Scripts/ninja.exe'

function Invoke-Tool {
    param([string]$Command, [string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed (exit $LASTEXITCODE). Build stopped."
    }
}

function Require-File {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required file missing: $Path"
    }
}

Write-Host '[1/4] Check prerequisites'
foreach ($command in @('python', 'node', 'npm', 'cordova', 'java')) {
    if (!(Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Missing prerequisite: $command. Install it and reopen PowerShell."
    }
}
if (!$env:ANDROID_HOME -or !(Test-Path -LiteralPath $env:ANDROID_HOME)) {
    throw 'Set ANDROID_HOME to your installed Android SDK.'
}
$sdkManager = Join-Path $env:ANDROID_HOME 'cmdline-tools/latest/bin/sdkmanager.bat'
Require-File $sdkManager
# Python single quotes survive native argument passing in Windows PowerShell 5.1.
Invoke-Tool 'python' @('-c', "import sys,struct; assert sys.version_info >= (3,10) and struct.calcsize('P')==8, 'Use Python 3.10+ (64-bit)'")
$javaHome = if ($env:CORDOVA_JAVA_HOME) { $env:CORDOVA_JAVA_HOME } else { $env:JAVA_HOME }
if (!$javaHome) { throw 'Set JAVA_HOME (or CORDOVA_JAVA_HOME) to JDK 21.' }
Require-File (Join-Path $javaHome 'bin/javac.exe')
# PowerShell 5.1 treats redirected stderr as errors, even for Java's normal notices.
try {
    $ErrorActionPreference = 'Continue'
    $javaVersion = & (Join-Path $javaHome 'bin/javac.exe') -version 2>&1
    $javaExitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = 'Stop'
}
if ($javaExitCode -ne 0 -or "$javaVersion" -notmatch 'javac 21[. ]') {
    throw "JDK 21 is required; found: $javaVersion"
}

Push-Location $PSScriptRoot
try {
    Write-Host '[2/4] Prepare tools'
    if (!(Test-Path -LiteralPath $python)) {
        Invoke-Tool 'python' @('-m', 'venv', (Join-Path $toolsRoot 'python'))
    }
    $versionCheck = "import importlib.metadata as m,sys; installed={d.metadata['Name'].lower():d.version for d in m.distributions()}; sys.exit(any(installed.get(n)!=v for n,v in (p.split('==') for p in sys.argv[1:])))"
    & $python -c $versionCheck @toolPackages 2>$null
    if ($LASTEXITCODE -ne 0) {
        Invoke-Tool $python (@('-m', 'pip', 'install') + $toolPackages)
    }
    Invoke-Tool $cmake @('--version')
    Invoke-Tool $ninja @('--version')
    # aqt 3.3 needs this small adapter for Qt 6.12's Windows repository layout.
    # Generate it beside the managed tools, keeping the repository build in one file.
    $aqt = Join-Path $toolsRoot 'aqt-qt612.py'
    @'
from aqt.metadata import ArchiveId
from aqt.installer import Cli
from aqt.archives import QtArchives

original_to_folder = ArchiveId.to_folder

def to_folder(self, version, qt_version_no_dots, extension=None):
    if str(version) == "6.12.0" and self.host == "windows" and self.target == "desktop" and not extension:
        extension = "mingw"
    return original_to_folder(self, version, qt_version_no_dots, extension)

ArchiveId.to_folder = to_folder
original_arch_ext = QtArchives._arch_ext

def arch_ext(self):
    if str(self.version) == "6.12.0" and self.arch == "win64_mingw":
        return "_mingw"
    return original_arch_ext(self)

QtArchives._arch_ext = arch_ext

if __name__ == "__main__":
    raise SystemExit(Cli().run())
'@ | Set-Content -LiteralPath $aqt -Encoding UTF8
    $kits = @(
        @{ Path = $qtHost; Target = 'desktop'; Arch = 'win64_mingw'; Files = @('lib/cmake/Qt6/Qt6Config.cmake', 'bin/moc.exe') },
        @{ Path = $qtAndroid; Target = 'android'; Arch = 'android_arm64_v8a'; Files = @(
            'lib/cmake/Qt6/qt.toolchain.cmake', 'lib/libQt6Core_arm64-v8a.so',
            'lib/libQt6Sql_arm64-v8a.so', 'plugins/sqldrivers/libplugins_sqldrivers_qsqlite_arm64-v8a.so',
            'jar/Qt6Android.jar') }
    )
    foreach ($kit in $kits) {
        $missing = @($kit.Files | Where-Object { !(Test-Path -LiteralPath (Join-Path $kit.Path $_)) })
        if ($missing.Count -gt 0) {
            Invoke-Tool $python @($aqt, 'install-qt', 'windows', $kit.Target, $qtVersion,
                $kit.Arch, '--archives', 'qtbase', '--outputdir', $qtRoot)
        } else {
            Write-Host "Reusing Qt $qtVersion $($kit.Arch)"
        }
        foreach ($file in $kit.Files) { Require-File (Join-Path $kit.Path $file) }
    }
    $ndk = Join-Path $env:ANDROID_HOME "ndk/$ndkVersion"
    $ndkCompiler = Join-Path $ndk 'toolchains/llvm/prebuilt/windows-x86_64/bin/clang++.exe'
    if (!(Test-Path -LiteralPath $ndkCompiler)) {
        Invoke-Tool $sdkManager @("--sdk_root=$env:ANDROID_HOME", "ndk;$ndkVersion")
    }
    Require-File $ndkCompiler

    Write-Host '[3/4] Build native library'
    $pluginPath = Join-Path $PSScriptRoot 'native-plugin'
    $buildPath = Join-Path $pluginPath 'build'
    $toolchain = Join-Path $qtAndroid 'lib/cmake/Qt6/qt.toolchain.cmake'
    Invoke-Tool $cmake @('--fresh', '-S', $pluginPath, '-B', $buildPath, '-G', 'Ninja',
        "-DCMAKE_TOOLCHAIN_FILE=$toolchain", "-DQT_HOST_PATH=$qtHost",
        "-DANDROID_NDK=$ndk", "-DCMAKE_MAKE_PROGRAM=$ninja",
        '-DANDROID_ABI=arm64-v8a', '-DANDROID_PLATFORM=android-28', '-DCMAKE_BUILD_TYPE=Debug')
    Invoke-Tool $cmake @('--build', $buildPath)

    $libsPath = Join-Path $pluginPath 'src/android/libs'
    $armPath = Join-Path $libsPath 'arm64-v8a'
    New-Item -ItemType Directory -Path $armPath -Force | Out-Null
    $files = @{
        (Join-Path $buildPath 'libSqlitePoc.so') = (Join-Path $armPath 'libSqlitePoc.so')
        (Join-Path $qtAndroid 'lib/libQt6Core_arm64-v8a.so') = (Join-Path $armPath 'libQt6Core_arm64-v8a.so')
        (Join-Path $qtAndroid 'lib/libQt6Sql_arm64-v8a.so') = (Join-Path $armPath 'libQt6Sql_arm64-v8a.so')
        (Join-Path $qtAndroid 'plugins/sqldrivers/libplugins_sqldrivers_qsqlite_arm64-v8a.so') = (Join-Path $armPath 'libplugins_sqldrivers_qsqlite_arm64-v8a.so')
        (Join-Path $qtAndroid 'jar/Qt6Android.jar') = (Join-Path $libsPath 'Qt6Android.jar')
        (Join-Path $ndk 'toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so') = (Join-Path $armPath 'libc++_shared.so')
    }
    foreach ($source in $files.Keys) {
        Require-File $source
        Copy-Item -LiteralPath $source -Destination $files[$source] -Force
    }

    Write-Host '[4/4] Build APK'
    Invoke-Tool 'npm' @('ci')
    Invoke-Tool 'npm' @('test')
    Invoke-Tool 'cordova' @('prepare', 'android')
    Invoke-Tool 'cordova' @('plugin', 'remove', 'cordova-plugin-sqlite-poc', '--nosave')
    Invoke-Tool 'cordova' @('plugin', 'add', './native-plugin', '--nosave')
    Invoke-Tool 'cordova' @('build', 'android', '--debug')
    $apk = Join-Path $PSScriptRoot 'platforms/android/app/build/outputs/apk/debug/app-debug.apk'
    Require-File $apk
    Write-Host "APK: $apk"
    Write-Host "Install separately: adb install -r `"$apk`""
} finally {
    Pop-Location
}
