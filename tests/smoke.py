#!/usr/bin/env python3
"""Smoke test of a built quickai-whisper: it starts with the speech model QuickAI uses, writes down whisper.cpp's own
sample (whisper.cpp/samples/jfk.wav) right, says when nothing was said, answers a language it does not know with an
error and goes on, and ends at the end of its input.

    tests/smoke.py <program> [<model>]

The model is QUICKAI_WHISPER_MODEL or the second argument, else Whisper base in 8 bits (82 MB), downloaded once into
models/ (pinned by sha256, as QuickAI pins it)."""

import hashlib
import json
import os
import struct
import subprocess
import sys
import time
import urllib.request
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_URL = ("https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/"
             "ggml-base-q8_0.bin")
MODEL_SHA256 = "c577b9a86e7e048a0b7eada054f4dd79a56bbfa911fbdacf900ac5b567cbb7d9"


def model_path(given):
    path = given or os.environ.get("QUICKAI_WHISPER_MODEL")
    if path:
        return path
    path = os.path.join(ROOT, "models", "ggml-base-q8_0.bin")
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        print(f"downloading {MODEL_URL}", file=sys.stderr)
        urllib.request.urlretrieve(MODEL_URL, path + ".part")
        os.replace(path + ".part", path)
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    if digest != MODEL_SHA256:
        sys.exit(f"{path} is not the pinned model (sha256 {digest})")
    return path


def samples_of(path):
    with wave.open(path) as w:
        assert (w.getnchannels(), w.getframerate(), w.getsampwidth()) == (1, 16000, 2), "16 kHz mono 16-bit"
        frames = w.readframes(w.getnframes())
    return [s / 32768.0 for s in struct.unpack(f"<{len(frames) // 2}h", frames)]


def request(proc, rid, samples, language="auto"):
    proc.stdin.write(f"transcribe {rid} {len(samples)} {language}\n".encode())
    proc.stdin.write(struct.pack(f"<{len(samples)}f", *samples))
    proc.stdin.flush()
    return json.loads(proc.stdout.readline())


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    program = sys.argv[1]
    model = model_path(sys.argv[2] if len(sys.argv) > 2 else None)
    proc = subprocess.Popen([program, "--model", model], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    started = time.time()
    hello = json.loads(proc.stdout.readline())
    assert hello.get("ready") is True, hello
    print(f"ready in {time.time() - started:.2f} s: quickai-whisper {hello['version']}, whisper.cpp {hello['whisper']}")
    print(f"  {hello['system']}")

    jfk = samples_of(os.path.join(ROOT, "whisper.cpp", "samples", "jfk.wav"))
    said = request(proc, 1, jfk)
    assert said["id"] == 1, said
    assert "ask not what your country can do for you" in said["text"], said
    assert said["language"] == "en", said
    print(f"jfk.wav (11 s) in {said['ms']} ms: {said['text'].strip()}")

    short = request(proc, 2, jfk[: 16000 * 3], "en")
    assert "fellow Americans" in short["text"], short
    print(f"3 s in {short['ms']} ms: {short['text'].strip()}")

    nothing = request(proc, 3, [0.0] * 1000)
    assert nothing == {"id": 3, "text": "", "language": None, "ms": nothing["ms"]}, nothing

    unknown = request(proc, 4, [0.0] * 8000, "xx")
    assert unknown["id"] == 4 and "no language" in unknown["error"], unknown
    still = request(proc, 5, jfk[: 16000 * 3], "en")
    assert "fellow Americans" in still["text"], still

    proc.stdin.close()
    assert proc.wait(timeout=30) == 0
    print("all well")


if __name__ == "__main__":
    main()
