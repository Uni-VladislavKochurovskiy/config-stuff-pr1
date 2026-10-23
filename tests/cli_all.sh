#!/usr/bin/env bash
"$(dirname "$0")/../run.sh" \
    -v resources/vfs/medium \
    -ss resources/scripts/stage3.txt \
    -f /usr/share/fonts/google-noto/NotoSansMono-Regular.ttf \
    -fs 20

# every supported param at once

# if you dont have NotoSandMono-Regular font
# at this specific filepath - god bless you