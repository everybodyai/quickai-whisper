#!/usr/bin/env bash
# macOS: one quickai-whisper for Apple silicon and Intel (each built on its own, then merged with lipo), for macOS 13.3 and
# later as QuickAI, into dist/quickai-whisper-<version>-macos-universal.tar.gz. Runs on a Mac with the Xcode Command Line
# Tools and cmake. Apple silicon's is NEON with Accelerate; Intel's is the avx2 build (every Mac macOS 13 runs on has it).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
if [ "$(uname -s)" != Darwin ]; then
    echo "error: build/macos.sh runs on macOS (it needs lipo)" >&2
    exit 1
fi
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.3}"
OUT="$ROOT_DIR/build/out/macos"
rm -rf "$OUT" && mkdir -p "$OUT"
for arch in arm64 x86_64; do
    echo "==> macOS, $arch"
    extra=()
    [ "$arch" = x86_64 ] && extra=(-DQUICKAI_WHISPER_CPU=avx2)
    cmake -S "$ROOT_DIR" -B "$ROOT_DIR/build/out/macos-$arch" -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_SYSTEM_PROCESSOR="$arch" -DGGML_METAL=OFF ${extra[@]+"${extra[@]}"} >/dev/null
    cmake --build "$ROOT_DIR/build/out/macos-$arch" -j "$(sysctl -n hw.ncpu)" --target quickai-whisper
done
lipo -create -output "$OUT/quickai-whisper" \
    "$ROOT_DIR/build/out/macos-arm64/quickai-whisper" "$ROOT_DIR/build/out/macos-x86_64/quickai-whisper"
strip "$OUT/quickai-whisper"
if [ -n "${MACOS_SIGN_IDENTITY:-}" ]; then
    codesign --sign "$MACOS_SIGN_IDENTITY" --timestamp --options runtime "$OUT/quickai-whisper"
else
    codesign --sign - "$OUT/quickai-whisper"
fi
stage_notices "$OUT"
PKG="quickai-whisper-$VERSION-macos-universal"
rm -rf "$ROOT_DIR/build/out/$PKG" && cp -r "$OUT" "$ROOT_DIR/build/out/$PKG"
tar -C "$ROOT_DIR/build/out" -czf "$DIST_DIR/$PKG.tar.gz" "$PKG"
echo "==> $DIST_DIR/$PKG.tar.gz"
