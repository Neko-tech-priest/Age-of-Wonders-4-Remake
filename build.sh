#!/usr/bin/env sh

export LC_ALL=C

#-freference-trace
#--debug-incremental
# -OReleaseSmall
zig build-exe src/main.zig --cache-dir .zig-cache -fno-llvm -fno-lld -fstrip -lc -lSDL2 -llz4
# strip -s main
