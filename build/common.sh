# What the build scripts share: the version, where packages go, and how a package is made.
set -euo pipefail
BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$BUILD_DIR")"
VERSION="$(head -n 1 "$ROOT_DIR/VERSION")"
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"

if [ ! -f "$ROOT_DIR/whisper.cpp/CMakeLists.txt" ]; then
    echo "error: whisper.cpp/ is empty: git submodule update --init --depth 1" >&2
    exit 1
fi

# The files every package has beside the programs: the licences, and what the package is.
stage_notices() {
    local out="$1"
    cp "$ROOT_DIR/LICENSE" "$out/LICENSE"
    cp "$ROOT_DIR/whisper.cpp/LICENSE" "$out/LICENSE-whisper.cpp"
    cat >"$out/README.txt" <<NOTE
quickai-whisper $VERSION (whisper.cpp $(git -C "$ROOT_DIR/whisper.cpp" describe --tags 2>/dev/null || echo unknown))

The program QuickAI runs to write down what you say: https://github.com/everybodyai/quickai-whisper
It is started by QuickAI with a speech model; README.md of the repository says how it is talked to.
LICENSE is its own (MIT), LICENSE-whisper.cpp that of whisper.cpp and ggml (MIT), which it is built from.
NOTE
}

# The SHA-256 of every package of this version, in dist/SHA256SUMS.
write_sums() {
    (cd "$DIST_DIR" && shasum -a 256 quickai-whisper-"$VERSION"-* 2>/dev/null || sha256sum quickai-whisper-"$VERSION"-*) |
        grep -v SHA256SUMS >"$DIST_DIR/SHA256SUMS"
    echo "==> $DIST_DIR/SHA256SUMS"
    cat "$DIST_DIR/SHA256SUMS"
}
