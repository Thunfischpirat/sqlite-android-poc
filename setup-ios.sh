#!/bin/bash
set -euo pipefail

# Install project-specific tools without changing the Mac's global configuration.
tools="${SQLITE_POC_TOOLS:-$HOME/Christian/sqlite-poc-tools}"
version=6.12.0
host="$tools/Qt/$version/macos"
simulator="$tools/Qt/$version/ios-simulator-arm64"
mkdir -p "$tools"

for command in python3 curl tar xcodebuild brew; do
    command -v "$command" >/dev/null || { echo "Missing prerequisite: $command"; exit 1; }
done
ruby_bin="$(brew --prefix ruby)/bin"
if [[ ! -x "$ruby_bin/gem" ]]; then
    echo 'Homebrew Ruby is required to install CocoaPods.'
    exit 1
fi

if [[ ! -x "$tools/venv/bin/python" ]]; then
    python3 -m venv "$tools/venv"
fi
"$tools/venv/bin/python" -m pip install 'aqtinstall==3.3.0' 'cmake==4.4.4' 'ninja==1.13.2'
export PATH="$tools/venv/bin:$PATH"
if [[ ! -x "$tools/gems/bin/pod" ]]; then
    "$ruby_bin/gem" install cocoapods -v 1.16.2 --install-dir "$tools/gems" --no-document
fi

if [[ ! -x "$host/libexec/moc" ]]; then
    aqt install-qt mac desktop "$version" clang_64 --archives qtbase --outputdir "$tools/Qt"
fi

# Qt's prebuilt iOS kit has an Intel simulator slice. Build an ARM64 simulator
# kit locally so the app runs natively on an Apple Silicon Mac.
if [[ ! -x "$simulator/bin/qt-cmake" ]]; then
    source_dir="$tools/qtbase-everywhere-src-$version"
    archive="$tools/qtbase-$version.tar.xz"
    if [[ ! -d "$source_dir" ]]; then
        curl -fL --retry 2 -o "$archive" "https://download.qt.io/official_releases/qt/6.12/$version/submodules/qtbase-everywhere-src-$version.tar.xz"
        tar -xf "$archive" -C "$tools"
    fi
    mkdir -p "$tools/qt-simulator-build"
    cd "$tools/qt-simulator-build"
    "$source_dir/configure" -platform macx-ios-clang -sdk iphonesimulator -release \
        -opensource -confirm-license -nomake examples -nomake tests \
        -qt-host-path "$host" -prefix "$simulator" -- -DCMAKE_OSX_ARCHITECTURES=arm64
    cmake --build . --parallel 4
    cmake --install .
fi
echo 'iOS tools are ready. Run: bash build-ios.sh'
