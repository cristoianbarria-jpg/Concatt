#!/usr/bin/env bash
set -euo pipefail

target=${1:?target triple: armv7-linux-androideabi or aarch64-linux-android}
workspace=$(cd "$(dirname "$0")/.." && pwd)
ffmpeg=$workspace/vendor/ffmpeg/$target
[ -d "$ffmpeg/lib" ] || { echo "no FFmpeg for $target: run scripts/ffmpeg-mobile.sh $target" >&2; exit 1; }
echo "export FFMPEG_DIR='$ffmpeg'"

case "$target" in
  armv7-linux-androideabi)
    sherpa=$workspace/vendor/sherpa-onnx/jniLibs/armeabi-v7a
    [ -d "$sherpa" ] || { echo "no sherpa-onnx for $target: run scripts/sherpa-mobile.sh $target" >&2; exit 1; }
    echo "export SHERPA_ONNX_LIB_DIR='$sherpa'"

    sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
    ndk=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-$(ls -d "$sdk"/ndk/* 2>/dev/null | sort -V | tail -1 || true)}}
    [ -d "$ndk" ] || { echo "no Android NDK: set ANDROID_NDK_HOME" >&2; exit 1; }
    echo "export ANDROID_HOME='$sdk' ANDROID_NDK_HOME='$ndk' ANDROID_NDK_ROOT='$ndk' ANDROID_NDK='$ndk'"
    
    host_tag=$(ls "$ndk/toolchains/llvm/prebuilt" | head -1)
    echo "export BINDGEN_EXTRA_CLANG_ARGS_armv7_linux_androideabi='--sysroot=$ndk/toolchains/llvm/prebuilt/$host_tag/sysroot'"
    
    platform=$(ls -d "$sdk"/platforms/android-* 2>/dev/null | sort -V | tail -1 || true)
    [ -f "$platform/android.jar" ] || { echo "no SDK platform under $sdk/platforms" >&2; exit 1; }
    echo "export ANDROID_JAR='$platform/android.jar'"

    if [ "$(uname -s)" = Darwin ]; then
      shim=$workspace/vendor/shim/$target
      mkdir -p "$shim"
      printf '!<arch>\n' > "$shim/libggml-blas.a"
      echo "export RUSTFLAGS='-L native=$shim'"
    fi
    ;;
  aarch64-linux-android)
    sherpa=$workspace/vendor/sherpa-onnx/jniLibs/arm64-v8a
    [ -d "$sherpa" ] || { echo "no sherpa-onnx for $target: run scripts/sherpa-mobile.sh $target" >&2; exit 1; }
    echo "export SHERPA_ONNX_LIB_DIR='$sherpa'"

    sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
    ndk=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-$(ls -d "$sdk"/ndk/* 2>/dev/null | sort -V | tail -1 || true)}}
    [ -d "$ndk" ] || { echo "no Android NDK: set ANDROID_NDK_HOME" >&2; exit 1; }
    echo "export ANDROID_HOME='$sdk' ANDROID_NDK_HOME='$ndk' ANDROID_NDK_ROOT='$ndk' ANDROID_NDK='$ndk'"
    host_tag=$(ls "$ndk/toolchains/llvm/prebuilt" | head -1)
    echo "export BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android='--sysroot=$ndk/toolchains/llvm/prebuilt/$host_tag/sysroot'"
    platform=$(ls -d "$sdk"/platforms/android-* 2>/dev/null | sort -V | tail -1 || true)
    [ -f "$platform/android.jar" ] || { echo "no SDK platform under $sdk/platforms" >&2; exit 1; }
    echo "export ANDROID_JAR='$platform/android.jar'"
    if [ "$(uname -s)" = Darwin ]; then
      shim=$workspace/vendor/shim/$target
      mkdir -p "$shim"
      printf '!<arch>\n' > "$shim/libggml-blas.a"
      echo "export RUSTFLAGS='-L native=$shim'"
    fi
    ;;
  *)
    echo "unknown target $target" >&2; exit 1 ;;
esac
