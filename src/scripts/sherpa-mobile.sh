#!/usr/bin/env bash
set -euo pipefail

target=${1:?target triple: armv7-linux-androideabi, aarch64-linux-android or aarch64-apple-ios}
workspace=$(cd "$(dirname "$0")/.." && pwd)
version=$(grep -A1 'name = "sherpa-onnx-sys"' "$workspace/Cargo.lock" | sed -n 's/^version = "\(.*\)"/\1/p')
release=https://github.com/k2-fsa/sherpa-onnx/releases/download

case "$target" in
  armv7-linux-androideabi)
    out=${2:-$workspace/vendor/sherpa-onnx}
    ndk=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}
    if [ -z "$ndk" ]; then
      sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
      ndk=$(ls -d "$sdk"/ndk/* 2>/dev/null | sort -V | tail -1 || true)
    fi
    [ -d "$ndk" ] || { echo "no Android NDK: set ANDROID_NDK_HOME" >&2; exit 1; }
    host_tag=$(ls "$ndk/toolchains/llvm/prebuilt" | head -1)
    echo "Fetching sherpa-onnx $version for Android armv7"
    mkdir -p "$out"
    curl -fsSL --retry 5 --retry-all-errors -o "$out/sherpa-onnx-android.tar.bz2" \
      "$release/v$version/sherpa-onnx-v$version-android.tar.bz2"
    tar -xjf "$out/sherpa-onnx-android.tar.bz2" -C "$out"
    rm "$out/sherpa-onnx-android.tar.bz2"
    find "$out/jniLibs" -mindepth 1 -maxdepth 1 -type d ! -name armeabi-v7a -exec rm -rf {} +
    rm -f "$out"/jniLibs/armeabi-v7a/libsherpa-onnx-jni.so "$out"/jniLibs/armeabi-v7a/libsherpa-onnx-cxx-api.so
    cp "$ndk/toolchains/llvm/prebuilt/$host_tag/sysroot/usr/lib/armv7-linux-androideabi/libc++_shared.so" \
      "$out/jniLibs/armeabi-v7a/"
    echo "sherpa-onnx for Android is in $out/jniLibs"
    echo "  export SHERPA_ONNX_LIB_DIR=$out/jniLibs/armeabi-v7a"
    ;;
  aarch64-linux-android)
    out=${2:-$workspace/vendor/sherpa-onnx}
    ndk=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}
    if [ -z "$ndk" ]; then
      sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
      ndk=$(ls -d "$sdk"/ndk/* 2>/dev/null | sort -V | tail -1 || true)
    fi
    [ -d "$ndk" ] || { echo "no Android NDK: set ANDROID_NDK_HOME" >&2; exit 1; }
    host_tag=$(ls "$ndk/toolchains/llvm/prebuilt" | head -1)
    echo "Fetching sherpa-onnx $version for Android"
    mkdir -p "$out"
    curl -fsSL --retry 5 --retry-all-errors -o "$out/sherpa-onnx-android.tar.bz2" \
      "$release/v$version/sherpa-onnx-v$version-android.tar.bz2"
    tar -xjf "$out/sherpa-onnx-android.tar.bz2" -C "$out"
    rm "$out/sherpa-onnx-android.tar.bz2"
    find "$out/jniLibs" -mindepth 1 -maxdepth 1 -type d ! -name arm64-v8a -exec rm -rf {} +
    rm -f "$out"/jniLibs/arm64-v8a/libsherpa-onnx-jni.so "$out"/jniLibs/arm64-v8a/libsherpa-onnx-cxx-api.so
    cp "$ndk/toolchains/llvm/prebuilt/$host_tag/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so" \
      "$out/jniLibs/arm64-v8a/"
    echo "sherpa-onnx for Android is in $out/jniLibs"
    echo "  export SHERPA_ONNX_LIB_DIR=$out/jniLibs/arm64-v8a"
    ;;
  aarch64-apple-ios)
    out=${2:-$workspace/vendor/sherpa-onnx/ios}
    echo "Fetching sherpa-onnx $version for iOS"
    mkdir -p "$out"
    curl -fsSL --retry 5 --retry-all-errors -o "$out/sherpa-onnx-ios.zip" \
      "$release/xcframework/sherpa-onnx-v$version-ios-shared-onnxruntime-static.xcframework.zip"
    (cd "$out" && unzip -qo sherpa-onnx-ios.zip && rm sherpa-onnx-ios.zip)
    framework=$(find "$out" -maxdepth 2 -name '*.xcframework' | head -1)
    [ -n "$framework" ] || { echo "no xcframework in the archive" >&2; exit 1; }
    binary=$framework/ios-arm64/SherpaOnnxC.framework/SherpaOnnxC
    [ -f "$binary" ] || { echo "no device slice in $framework" >&2; exit 1; }
    mkdir -p "$out/lib"
    ln -sf "$binary" "$out/lib/libsherpa-onnx-c-api.dylib"
    echo "sherpa-onnx for iOS is $framework"
    echo "  export SHERPA_ONNX_LIB_DIR=$out/lib"
    ;;
  *)
    echo "unknown target $target" >&2; exit 1 ;;
esac
