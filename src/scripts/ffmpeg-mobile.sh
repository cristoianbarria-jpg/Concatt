#!/usr/bin/env bash
set -euo pipefail

target=${1:?target triple: armv7-linux-androideabi or aarch64-linux-android}
workspace=$(cd "$(dirname "$0")/.." && pwd)
out=${2:-$workspace/vendor/ffmpeg/$target}
version=${FFMPEG_VERSION:-8.1}
android_api=${ANDROID_API:-26}
jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

work=${FFMPEG_WORK_DIR:-$workspace/vendor/ffmpeg/src}
src=$work/ffmpeg-$version
mkdir -p "$work"
if [ ! -f "$src/configure" ]; then
  echo "Fetching FFmpeg $version"
  curl -fsSL --retry 5 --retry-all-errors -o "$work/ffmpeg-$version.tar.xz" \
    "https://ffmpeg.org/releases/ffmpeg-$version.tar.xz"
  tar -xf "$work/ffmpeg-$version.tar.xz" -C "$work"
fi

build=$work/build-$target
rm -rf "$build"
mkdir -p "$build"

common=(
  --prefix="$out"
  --enable-cross-compile
  --enable-static --disable-shared --enable-pic
  --disable-programs --disable-doc
  --disable-debug
  --enable-zlib --disable-bzlib --disable-lzma
  --disable-iconv --disable-sdl2 --disable-xlib --disable-libxcb
  --disable-vulkan --disable-opencl --disable-vaapi --disable-vdpau
)

case "$target" in
  armv7-linux-androideabi)
    ndk=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}
    if [ -z "$ndk" ]; then
      sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
      ndk=$(ls -d "$sdk"/ndk/* 2>/dev/null | sort -V | tail -1 || true)
    fi
    [ -d "$ndk" ] || { echo "no Android NDK: set ANDROID_NDK_HOME" >&2; exit 1; }
    host_tag=$(ls "$ndk/toolchains/llvm/prebuilt" | head -1)
    bin=$ndk/toolchains/llvm/prebuilt/$host_tag/bin
    echo "Building FFmpeg $version for $target with NDK at $ndk (API $android_api)"
    (cd "$build" && "$src/configure" "${common[@]}" \
      --target-os=android --arch=arm --cpu=armv7-a \
      --sysroot="$ndk/toolchains/llvm/prebuilt/$host_tag/sysroot" \
      --cc="$bin/armv7a-linux-androideabi$android_api-clang" \
      --cxx="$bin/armv7a-linux-androideabi$android_api-clang++" \
      --ar="$bin/llvm-ar" --nm="$bin/llvm-nm" --ranlib="$bin/llvm-ranlib" --strip="$bin/llvm-strip" \
      --enable-jni --enable-mediacodec \
      --extra-cflags="-fno-omit-frame-pointer")
    ;;
  aarch64-linux-android)
    ndk=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}
    if [ -z "$ndk" ]; then
      sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
      ndk=$(ls -d "$sdk"/ndk/* 2>/dev/null | sort -V | tail -1 || true)
    fi
    [ -d "$ndk" ] || { echo "no Android NDK: set ANDROID_NDK_HOME" >&2; exit 1; }
    host_tag=$(ls "$ndk/toolchains/llvm/prebuilt" | head -1)
    bin=$ndk/toolchains/llvm/prebuilt/$host_tag/bin
    echo "Building FFmpeg $version for $target with NDK at $ndk (API $android_api)"
    (cd "$build" && "$src/configure" "${common[@]}" \
      --target-os=android --arch=aarch64 --cpu=armv8-a \
      --sysroot="$ndk/toolchains/llvm/prebuilt/$host_tag/sysroot" \
      --cc="$bin/aarch64-linux-android$android_api-clang" \
      --cxx="$bin/aarch64-linux-android$android_api-clang++" \
      --ar="$bin/llvm-ar" --nm="$bin/llvm-nm" --ranlib="$bin/llvm-ranlib" --strip="$bin/llvm-strip" \
      --enable-jni --enable-mediacodec \
      --extra-cflags="-fno-omit-frame-pointer" \
      --extra-ldflags="-Wl,-z,max-page-size=16384")
    ;;
  *)
    echo "unknown target $target" >&2; exit 1 ;;
esac

make -C "$build" -j"$jobs" install
echo "FFmpeg $version for $target is in $out"
echo "  export FFMPEG_DIR=$out"
