#!/usr/bin/env bash
cd "$(dirname "$0")/.."
odin build src/gui/ -out:bin/raycommands.x86_64
bin/raycommands.x86_64

# no params at all