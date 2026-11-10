#!/usr/bin/env bash
# This computer's own build, for development: build/out/local-<cpu>/ with the host's cmake and compiler (for any processor
# of its kind, as the packages: QUICKAI_WHISPER_CPU=portable or avx2, avx2 by default).
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
CPU="${QUICKAI_WHISPER_CPU:-avx2}"
NAME=quickai-whisper
[ "$CPU" = avx2 ] && NAME=quickai-whisper-avx2
cmake -S "$ROOT_DIR" -B "$ROOT_DIR/build/out/local-$CPU" -DQUICKAI_WHISPER_CPU="$CPU" -DQUICKAI_WHISPER_NAME="$NAME" >/dev/null
cmake --build "$ROOT_DIR/build/out/local-$CPU" -j "$(nproc 2>/dev/null || sysctl -n hw.ncpu)" --target quickai-whisper
echo "==> $ROOT_DIR/build/out/local-$CPU/$NAME"
