#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

odin build src/gui/ -out:bin/raycommands.x86_64
echo built project, starting

# no arguments = default
if [ $# -eq 0 ]; then
    set -- -v resources/vfs/rich -ss resources/scripts/stage3.txt
fi

bin/raycommands.x86_64 "$@"
