# Linux x86_64: Ubuntu 20.04, for its glibc 2.31 (what is linked against it starts on that and newer), as QuickAI's own
# Linux build. Its cmake (3.16) and GCC 9 build whisper.cpp; the C++ runtime is linked in.
FROM ubuntu:20.04@sha256:8feb4d8ca5354def3d8fce243717141ce31e2c428701f6682bd2fafe15388214

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates cmake g++ gcc make \
    && rm -rf /var/lib/apt/lists/*
