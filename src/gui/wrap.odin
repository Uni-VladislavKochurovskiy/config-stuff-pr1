package gui

import "core:fmt"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

import "../inklib"

GuiConfig :: struct {
    font:      Maybe(string),
    font_size: Maybe(int),
}

gui_config_string :: proc(config: GuiConfig) -> string {
    not_set := "[not_set]"

    return fmt.tprintf("GuiConfig(\n\tfont = %s,\n\tfont_size = %s\n)",
    config.font.? or_else not_set,
    config.font_size != nil ? fmt.tprint(config.font_size.?) : not_set,
    )
}


gui_run :: proc(terminal: ^inklib.Terminal, config: GuiConfig = {}) {
    rl.SetTraceLogLevel(.WARNING)
    rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .WINDOW_ALWAYS_RUN, .WINDOW_HIGHDPI})

    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, fmt.ctprintf("%s@%s - raycommands", terminal.user, terminal.host))
    defer rl.CloseWindow()

    font_size := config.font_size.? or_else DEFAULT_FONT_SIZE
    font, is_custom_font := font_load(config.font, font_size)
    defer if is_custom_font do rl.UnloadFont(font)

    view := View{font = font, font_size = f32(font_size), recall_index = len(terminal.commands)}
    defer view_destroy(&view)

    for {
        if rl.WindowShouldClose() do break
        if terminal.should_exit do break

        view_update(&view, terminal)

        rl.BeginDrawing()
        rl.ClearBackground(CONSOLE_BG)
        view_draw(&view, terminal)
        rl.EndDrawing()

        free_all(context.temp_allocator)
    }
}

font_load :: proc(path: Maybe(string), size: int) -> (font: rl.Font, custom: bool) {
    codepoints := make([dynamic]rune, context.temp_allocator)
    for r in CODEPOINT_RANGES {
        for codepoint := r[0]; codepoint <= r[1]; codepoint += 1 {
            append(&codepoints, codepoint)
        }
    }

    try_load :: proc(path: string, size: int, codepoints: []rune) -> (rl.Font, bool) {
        if !os.exists(path) do return {}, false

        dpi_x := rl.GetWindowScaleDPI().x
        font := rl.LoadFontEx(
            strings.clone_to_cstring(path, context.temp_allocator),
            i32(f32(size) * dpi_x),
            raw_data(codepoints),
            i32(len(codepoints)),
        )
        if !rl.IsFontValid(font) do return {}, false

        return font, true
    }

    if p, ok := path.?; ok {
        if f, loaded := try_load(p, size, codepoints[:]); loaded {
            fmt.printfln("success: font loaded: %s", p)
            return f, true
        }
        fmt.eprintfln("error: unable to load font: %s", p)
    }

    for p in POSSIBLE_LOCAL_FONTS {
        if f, loaded := try_load(p, size, codepoints[:]); loaded {
            fmt.printfln("info: using system font: %s", p)
            return f, true
        }
    }

    fmt.println("warning: no usable font found, using raylib default font (no cyrillic)")
    return rl.GetFontDefault(), false
}
