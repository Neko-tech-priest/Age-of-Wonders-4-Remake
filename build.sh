#!/usr/bin/env sh

export LC_ALL=C

#-freference-trace
zig build-exe src/main.zig --cache-dir .zig-cache -ODebug -fno-llvm -fno-lld -fno-compiler-rt -fstrip -lc -lSDL2 -llz4
#strip -s main
# zig build-exe srcs/main.zig --cache-dir .zig-cache -OReleaseFast -fstrip -flto -fno-compiler-rt -I srcs -lc -lSDL2 -llz4
