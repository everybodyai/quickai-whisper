#!/usr/bin/env bash
# Linux x86_64: quickai-whisper (portable) and quickai-whisper-avx2, built in Ubuntu 20.04 (build/docker/linux.Dockerfile),
# into dist/quickai-whisper-<version>-linux-x86_64.tar.gz. Needs Docker.
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
IMAGE=quickai-whisper/linux:focal
docker build -q -t "$IMAGE" -f "$BUILD_DIR/docker/linux.Dockerfile" "$BUILD_DIR/docker" >/dev/null
OUT="$ROOT_DIR/build/out/linux"
rm -rf "$OUT" && mkdir -p "$OUT"
for cpu in portable avx2; do
    name=quickai-whisper
    [ "$cpu" = avx2 ] && name=quickai-whisper-avx2
    echo "==> Linux, $cpu"
    docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT_DIR:/src" -w /src "$IMAGE" sh -c "
        cmake -S . -B build/out/linux-$cpu -DQUICKAI_WHISPER_CPU=$cpu -DQUICKAI_WHISPER_NAME=$name >/dev/null &&
        cmake --build build/out/linux-$cpu -j \$(nproc) --target quickai-whisper"
    cp "$ROOT_DIR/build/out/linux-$cpu/$name" "$OUT/"
done
strip "$OUT"/quickai-whisper* 2>/dev/null || true
stage_notices "$OUT"
PKG="quickai-whisper-$VERSION-linux-x86_64"
rm -rf "$ROOT_DIR/build/out/$PKG" && cp -r "$OUT" "$ROOT_DIR/build/out/$PKG"
tar -C "$ROOT_DIR/build/out" -czf "$DIST_DIR/$PKG.tar.gz" "$PKG"
echo "==> $DIST_DIR/$PKG.tar.gz"
