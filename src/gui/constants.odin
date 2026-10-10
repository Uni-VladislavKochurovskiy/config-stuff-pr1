package gui

GLSL_VERSION :: "#version 330"
GL_MAJOR :: 3
GL_MINOR :: 3

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

cyrillic_ranges := [?]u16{
    0x0020, 0x00FF,
    0x0400, 0x052F,
    0,
}

// ---

INPUT_BUFFER_SIZE :: 512