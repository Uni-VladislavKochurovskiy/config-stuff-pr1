package gui

import rl "vendor:raylib"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
CONSOLE_BG :: rl.Color{16, 16, 16, 255}

DEFAULT_FONT_SIZE :: 24
TEXT_SPACING :: 1
LINE_SPACING :: 2
TEXT_PADDING :: 6
TAB_WIDTH :: 4

SCROLL_SPEED :: 3
CURSOR_WIDTH :: 2
CURSOR_BLINK :: 5.67

CODEPOINT_RANGES :: [?][2]rune{
    {0x0020, 0x00FF},
    {0x0400, 0x052F},
}

POSSIBLE_LOCAL_FONTS :: [?]string{
    "/usr/share/fonts/google-noto/NotoSansMono-Regular.ttf",
}

// ---

INPUT_BUFFER_SIZE :: 512
