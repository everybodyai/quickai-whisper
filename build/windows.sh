#!/usr/bin/env bash
# Windows x86_64: quickai-whisper.exe (portable) and quickai-whisper-avx2.exe, cross-built with MinGW-w64
# (build/docker/windows.Dockerfile, build/mingw-w64-x86_64.cmake) into dist/quickai-whisper-<version>-windows-x86_64.zip.
# Needs Docker.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
IMAGE=quickai-whisper/mingw:noble
docker build -q -t "$IMAGE" -f "$BUILD_DIR/docker/windows.Dockerfile" "$BUILD_DIR/docker" >/dev/null
OUT="$ROOT_DIR/build/out/windows"
rm -rf "$OUT" && mkdir -p "$OUT"
for cpu in portable avx2; do
    name=quickai-whisper
    [ "$cpu" = avx2 ] && name=quickai-whisper-avx2
    echo "==> Windows, $cpu"
    docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT_DIR:/src" -w /src "$IMAGE" sh -c "
        cmake -S . -B build/out/windows-$cpu -DCMAKE_TOOLCHAIN_FILE=build/mingw-w64-x86_64.cmake \
            -DQUICKAI_WHISPER_CPU=$cpu -DQUICKAI_WHISPER_NAME=$name >/dev/null &&
        cmake --build build/out/windows-$cpu -j \$(nproc) --target quickai-whisper &&
        x86_64-w64-mingw32-strip build/out/windows-$cpu/$name.exe"
    cp "$ROOT_DIR/build/out/windows-$cpu/$name.exe" "$OUT/"
done
stage_notices "$OUT"
PKG="quickai-whisper-$VERSION-windows-x86_64"
rm -rf "$ROOT_DIR/build/out/$PKG" && cp -r "$OUT" "$ROOT_DIR/build/out/$PKG"
rm -f "$DIST_DIR/$PKG.zip"
(cd "$ROOT_DIR/build/out" && zip -qr "$DIST_DIR/$PKG.zip" "$PKG")
echo "==> $DIST_DIR/$PKG.zip"
