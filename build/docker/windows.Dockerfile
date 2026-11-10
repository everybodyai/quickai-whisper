# Windows x86_64, cross-built with MinGW-w64 (GCC 13, POSIX threads) on Ubuntu 24.04. Everything is linked in, so the
# programs need no DLL beside them.
FROM ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates cmake make g++-mingw-w64-x86-64-posix gcc-mingw-w64-x86-64-posix zip \
    && rm -rf /var/lib/apt/lists/*
