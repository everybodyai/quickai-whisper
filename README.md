# quickai-whisper

The program [QuickAI](https://github.com/everybodyai/quickai) runs to write down what you say to it: whisper.cpp, built
for every computer QuickAI runs on, with a small program in front of it that keeps a speech model loaded and answers
each recording with its words. It runs on the processor alone, opens nothing but the model, and connects to nothing.

QuickAI starts it the first time the microphone is used and keeps it running; the packages of QuickAI carry it next to
the app (as they carry llama.cpp's `llama-server`), so QuickAI itself is plain Rust and needs no C++ compiler to build.

| What | Where |
|---|---|
| The program | [`src/main.cpp`](src/main.cpp) |
| whisper.cpp | [`whisper.cpp/`](whisper.cpp), a git submodule at a release tag (now `v1.8.3`) |
| The builds | [`build/`](build): `linux.sh`, `windows.sh` (both in Docker), `macos.sh` (on a Mac), `local.sh` |
| The test | [`tests/smoke.py`](tests/smoke.py) |
| Releases | [`.github/workflows/release.yml`](.github/workflows/release.yml) |

## Using it

```
quickai-whisper --model <file.bin> [--threads N] [--verbose]
quickai-whisper --version
quickai-whisper --system-info
```

The model is a whisper.cpp model (`ggml-*.bin`); QuickAI uses `ggml-base-q8_0.bin` (82 MB) by default, and small and
large turbo when chosen, pinned from [ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp) on Hugging
Face. `--threads` is 8 at most by default. whisper.cpp says nothing on the error output unless `--verbose` is given.

It talks on its input and output, a request at a time:

1. Started, it loads the model and says one line:
   `{"ready":true,"version":"0.2.0","whisper":"1.8.3","system":"AVX = 1 | AVX2 = 1 | ..."}`, or
   `{"ready":false,"error":"..."}` and ends.
2. A request is a line, `transcribe <id> <samples> <language>`, where `language` is a code whisper knows (`en`, `ml`) or
   `auto`, followed by `<samples>` samples of 16 kHz mono sound as 32-bit floats from -1 to 1, little-endian.
3. Its answer is a line: `{"id":1,"text":" And so my fellow Americans ...","language":"en","ms":1845}`, or
   `{"id":1,"error":"..."}`. A recording shorter than a quarter of a second is `"text":""`, as is one whisper finds no
   speech in.
4. `quit`, or the end of its input, ends it. A line that is not a request ends it too, since what follows it cannot be
   told from samples.

It decodes as a person talking to an assistant needs: greedy, in one piece for anything under 30 seconds, and decoded
again at a higher temperature when what came out repeats itself or is unsure of every word (whisper's own fallback).
For English the encoder's window is fitted to the recording, at least 15 seconds of it, which is twice as quick as the
whole 30 seconds and as accurate; for every other language, and when the language is to be told, it is the whole 30
seconds whisper was trained on, since a smaller one makes it repeat a phrase or make up words. With the avx2 build on a
desktop processor, a 3-second English sentence takes about 0.5 s with the base model; a 5-second Hindi one about 1.3 s
with base and 4 to 5 s with small.

## The builds

| Package | What is in it |
|---|---|
| `quickai-whisper-<version>-linux-x86_64.tar.gz` | `quickai-whisper` and `quickai-whisper-avx2`, glibc 2.29 or newer, the C++ runtime linked in |
| `quickai-whisper-<version>-windows-x86_64.zip` | `quickai-whisper.exe` and `quickai-whisper-avx2.exe`, needing no DLL beside them |
| `quickai-whisper-<version>-macos-universal.tar.gz` | `quickai-whisper` for Apple silicon (Accelerate) and Intel, macOS 13.3 or newer |

Each package also has `LICENSE`, `LICENSE-whisper.cpp` and `README.txt`.

`quickai-whisper` runs on any x86-64 processor of the last fifteen years (SSE 4.2); `quickai-whisper-avx2` needs AVX2,
FMA, F16C and BMI2 (Intel Haswell, AMD Excavator, 2013) and is two to five times as fast. QuickAI runs the avx2 one where
the processor has them. Neither is built for the processor that builds it (`QUICKAI_WHISPER_CPU` in
[`CMakeLists.txt`](CMakeLists.txt) says every instruction set, since ggml turns AVX2 on by itself once `GGML_NATIVE` is
off).

```sh
git submodule update --init --depth 1   # whisper.cpp, once
build/linux.sh                          # Docker: Ubuntu 20.04, for glibc 2.31
build/windows.sh                        # Docker: MinGW-w64 on Ubuntu 24.04
build/macos.sh                          # on a Mac with the Xcode Command Line Tools and cmake
build/local.sh                          # this computer's cmake and compiler, for development
tests/smoke.py <program>                # downloads the base model into models/ once
```

The packages land in `dist/`, the builds in `build/out/` (both ignored by git).

## Releasing

1. Change `VERSION`, commit, and push a tag `vX.Y.Z` of the same version.
2. The Release workflow builds the three packages, runs the smoke test on Linux, Windows and macOS, and makes a **draft**
   release with the packages and `SHA256SUMS`.
3. Publish the draft. Then pin it in QuickAI's packaging (`quickai_base`, `build/config.env`: the tag and each
   package's sha256), which puts the program next to the app in every package of QuickAI.

## Updating whisper.cpp

```sh
git -C whisper.cpp fetch --depth 1 origin tag v1.8.4
git -C whisper.cpp checkout v1.8.4
build/local.sh && tests/smoke.py build/out/local-avx2/quickai-whisper-avx2
git commit -am "whisper.cpp v1.8.4"
```

## License

The program and the build scripts are under the [MIT License](LICENSE). whisper.cpp and ggml are under the MIT License
too ([`whisper.cpp/LICENSE`](whisper.cpp/LICENSE)), as is every package's `LICENSE-whisper.cpp`.
