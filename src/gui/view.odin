package gui

import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"
import "../inklib"
import math "core:math"

View :: struct {
    font:      rl.Font,
    font_size: f32,
    input:     strings.Builder,
    scroll:    int,

    recall_index: int,
    recall_draft: string,
}

Line :: struct {
    text:       string,
    prompt_len: int,
}

view_destroy :: proc(self: ^View) {
    strings.builder_destroy(&self.input)
    delete(self.recall_draft)
}

view_update :: proc(self: ^View, terminal: ^inklib.Terminal) {
    for r := rl.GetCharPressed(); r != 0; r = rl.GetCharPressed() {
        if strings.builder_len(self.input) + utf8.rune_size(r) < INPUT_BUFFER_SIZE {
            strings.write_rune(&self.input, r)
        }
        self.scroll = 0
    }

    if rl.IsKeyPressed(.BACKSPACE) || rl.IsKeyPressedRepeat(.BACKSPACE) {
        strings.pop_rune(&self.input)
        self.scroll = 0
    }

    if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.KP_ENTER) {
        inklib.terminal_exec(terminal, strings.to_string(self.input))
        strings.builder_reset(&self.input)
        self.scroll = 0
        self.recall_index = len(terminal.commands)
    }

    if rl.IsKeyPressed(.UP) || rl.IsKeyPressedRepeat(.UP) do view_recall(self, terminal, -1)
    if rl.IsKeyPressed(.DOWN) || rl.IsKeyPressedRepeat(.DOWN) do view_recall(self, terminal, 1)

    self.scroll += int(rl.GetMouseWheelMove() * SCROLL_SPEED)
    if rl.IsKeyPressed(.PAGE_UP) || rl.IsKeyPressedRepeat(.PAGE_UP) do self.scroll += view_visible_lines(self) / 2
    if rl.IsKeyPressed(.PAGE_DOWN) || rl.IsKeyPressedRepeat(.PAGE_DOWN) do self.scroll -= view_visible_lines(self) / 2
}

view_recall :: proc(self: ^View, terminal: ^inklib.Terminal, step: int) {
    count := len(terminal.commands)
    target := clamp(self.recall_index + step, 0, count)
    if target == self.recall_index do return

    if self.recall_index == count {
        delete(self.recall_draft)
        self.recall_draft = strings.clone(strings.to_string(self.input))
    }
    self.recall_index = target

    strings.builder_reset(&self.input)
    strings.write_string(&self.input, target == count ? self.recall_draft : terminal.commands[target])
    self.scroll = 0
}

view_draw :: proc(self: ^View, terminal: ^inklib.Terminal) {
    width := f32(rl.GetScreenWidth()) - 2 * TEXT_PADDING

    lines := make([dynamic]Line, context.temp_allocator)
    for entry in terminal.history {
        view_text_wrapped(self, &lines, entry, 0, width)
    }
    input_line := strings.concatenate({terminal.prompt, strings.to_string(self.input)}, context.temp_allocator)
    view_text_wrapped(self, &lines, input_line, len(terminal.prompt), width)

    visible := view_visible_lines(self)
    self.scroll = clamp(self.scroll, 0, max(0, len(lines) - visible))
    first := max(0, len(lines) - visible - self.scroll)
    last := min(len(lines), first + visible)

    line_height := self.font_size + LINE_SPACING
    y := f32(TEXT_PADDING)
    for line, i in lines[first:last] {
        x := view_draw_line(self, line, { TEXT_PADDING, y })

        cursor_visible := math.sin(rl.GetTime() * CURSOR_BLINK) > 0
        if first + i == len(lines) - 1 && cursor_visible {
            rl.DrawRectangle(i32(x), i32(y), CURSOR_WIDTH, i32(self.font_size), rl.GREEN)
        }
        y += line_height
    }
}

view_visible_lines :: proc(self: ^View) -> int {
    height := rl.GetScreenHeight() - 2 * TEXT_PADDING
    return max(1, int(f32(height) / (self.font_size + LINE_SPACING)))
}

view_draw_line :: proc(self: ^View, line: Line, position: rl.Vector2) -> (end_x: f32) {
    x := position.x
    for char, i in line.text {
        color := i < line.prompt_len ? rl.GREEN : rl.WHITE
        if char != '\t' && char != ' ' {
            rl.DrawTextCodepoint(self.font, char, { x, position.y }, self.font_size, color)
        }
        x += view_next_char(self, char)
    }
    return x
}

view_next_char :: proc(self: ^View, char: rune) -> f32 {
    if char == '\t' do return TAB_WIDTH * view_next_char(self, ' ')

    idx := rl.GetGlyphIndex(self.font, char)
    advance := f32(self.font.glyphs[idx].advanceX)
    if advance == 0 do advance = self.font.recs[idx].width

    return advance * self.font_size / f32(self.font.baseSize) + TEXT_SPACING
}

view_text_wrapped :: proc(self: ^View, out_lines: ^[dynamic]Line, text: string, prompt_len: int, width: f32) {
    offset := 0
    it := text
    for raw in strings.split_lines_iterator(&it) {
        start := 0
        x : f32 = 0
        for r, i in raw {
            advance := view_next_char(self, r)
            if x + advance > width && i > start {
                append(out_lines, Line{ raw[start:i], clamp(prompt_len - offset - start, 0, i - start) })
                start = i
                x = 0
            }
            x += advance
        }
        append(out_lines, Line{ raw[start:], clamp(prompt_len - offset - start, 0, len(raw) - start) })
        offset += len(raw) + 1
    }
}