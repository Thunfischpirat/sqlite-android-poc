[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$QtAndroidPath,
    [Parameter(Mandatory)][string]$QtHostPath,
    [Parameter(Mandatory)][string]$NdkPath,
    [string]$CMake = 'cmake',
    [string]$Ninja = 'ninja',
    [string]$AndroidPlatform = 'android-28'
)
$ErrorActionPreference = 'Stop'
$pluginPath = Join-Path $PSScriptRoot '../native-plugin'
$pluginPath = (Resolve-Path -LiteralPath $pluginPath).Path
$buildPath = Join-Path $pluginPath 'build'
$toolchain = Join-Path $QtAndroidPath 'lib/cmake/Qt6/qt.toolchain.cmake'
foreach ($required in @($toolchain, $QtHostPath, $NdkPath)) {
    if (!(Test-Path -LiteralPath $required)) { throw "Missing required path: $required" }
}
$cmakeCommand = (Get-Command $CMake -ErrorAction Stop).Source
$ninjaCommand = (Get-Command $Ninja -ErrorAction Stop).Source
& $cmakeCommand -S $pluginPath -B $buildPath -G Ninja `
    "-DCMAKE_TOOLCHAIN_FILE=$toolchain" "-DQT_HOST_PATH=$QtHostPath" `
    "-DANDROID_NDK=$NdkPath" "-DCMAKE_MAKE_PROGRAM=$ninjaCommand" `
    '-DANDROID_ABI=arm64-v8a' "-DANDROID_PLATFORM=$AndroidPlatform" '-DCMAKE_BUILD_TYPE=Debug'
if ($LASTEXITCODE -ne 0) { throw 'Native configuration failed' }
& $cmakeCommand --build $buildPath
if ($LASTEXITCODE -ne 0) { throw 'Native compilation failed' }

$libsPath = Join-Path $pluginPath 'src/android/libs'
$armPath = Join-Path $libsPath 'arm64-v8a'
New-Item -ItemType Directory -Path $armPath -Force | Out-Null
$files = @{
    (Join-Path $buildPath 'libSqlitePoc.so') = (Join-Path $armPath 'libSqlitePoc.so')
    (Join-Path $QtAndroidPath 'lib/libQt6Core_arm64-v8a.so') = (Join-Path $armPath 'libQt6Core_arm64-v8a.so')
    (Join-Path $QtAndroidPath 'lib/libQt6Sql_arm64-v8a.so') = (Join-Path $armPath 'libQt6Sql_arm64-v8a.so')
    (Join-Path $QtAndroidPath 'plugins/sqldrivers/libplugins_sqldrivers_qsqlite_arm64-v8a.so') = (Join-Path $armPath 'libplugins_sqldrivers_qsqlite_arm64-v8a.so')
    (Join-Path $QtAndroidPath 'jar/Qt6Android.jar') = (Join-Path $libsPath 'Qt6Android.jar')
    (Join-Path $NdkPath 'toolchains/llvm/prebuilt/windows-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so') = (Join-Path $armPath 'libc++_shared.so')
}
foreach ($source in $files.Keys) {
    if (!(Test-Path -LiteralPath $source)) { throw "Required runtime missing: $source" }
    Copy-Item -LiteralPath $source -Destination $files[$source] -Force
}
Write-Host 'Native plugin and runtime files staged. Install/reinstall the Cordova plugin before building the app.'
