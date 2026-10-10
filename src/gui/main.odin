package gui

import "core:mem"
import "core:strings"

import "vendor:glfw"

import im "../../lib/imgui"
import "../inklib"
import fmt "core:fmt"
import runtime "base:runtime"

terminal: inklib.Terminal

main :: proc() {
    inklib.terminal_create(&terminal)

    glfw_wrap(&terminal, imgui_func)

    inklib.terminal_destroy(&terminal)
}

imgui_func :: proc() -> () {
    @static input_buf: [INPUT_BUFFER_SIZE]u8
    @static scroll_to_bottom := true
    @static reclaim_focus := true


    im.SetNextWindowPos({0, 0})
    im.SetNextWindowSize(im.GetIO().DisplaySize)
    flags := im.WindowFlags{
        .NoTitleBar,
        .NoResize,
        .NoMove,
        .NoCollapse,
        .NoBackground,
        .NoSavedSettings,
        .NoScrollbar,
    }
    if im.Begin("##Emulator", nil, flags) {
        if im.IsWindowHovered() && im.IsMouseClicked(.Left) do reclaim_focus = true
        if im.IsKeyPressed(.Escape) do reclaim_focus = true

        for line in terminal.history {
            line_c := strings.clone_to_cstring(line, context.temp_allocator)
            im.TextWrapped(line_c)
        }

        im.PushStyleColorVec4(.Text, {0.0, 1.0, 0.0, 1.0})
        prompt_c := strings.clone_to_cstring(terminal.prompt, context.temp_allocator)
        im.TextUnformatted(prompt_c)
        im.PopStyleColor()

        im.SameLine(0.0, 0.0)

        im.PushStyleColorVec4(.FrameBg, {0.0, 0.0, 0.0, 0.0})
        im.PushStyleColorVec4(.FrameBgHovered, {0.0, 0.0, 0.0, 0.0})
        im.PushStyleColorVec4(.FrameBgActive, {0.0, 0.0, 0.0, 0.0})
        im.PushStyleColorVec4(.NavCursor, {0.0, 0.0, 0.0, 0.0})
        im.PushStyleColorVec4(.Border, {0.0, 0.0, 0.0, 0.0})

        im.PushStyleVarVec2(.FramePadding, {0, 0})
        im.PushStyleVar(.FrameBorderSize, 0.0)

        im.SetNextItemWidth(-1)

        if reclaim_focus {
            im.SetKeyboardFocusHere()
            reclaim_focus = false
        }

        buffer := cstring(raw_data(input_buf[:]))
        input_flags := im.InputTextFlags{
            .EnterReturnsTrue,
        }
        if im.InputText("##Input", buffer, len(input_buf), input_flags) {
            cmd_raw := string(buffer)

            inklib.terminal_exec(&terminal, cmd_raw)

            mem.zero_slice(input_buf[:])
            scroll_to_bottom = true
            reclaim_focus = true
        }

        im.PopStyleColor(5)
        im.PopStyleVar(2)

        if scroll_to_bottom {
            im.SetScrollHereY(1.0)
            scroll_to_bottom = false
        }

        if terminal.should_exit {
            if window := glfw.GetCurrentContext(); window != nil {
                glfw.SetWindowShouldClose(window, true)
            }
        }
    }
    im.End()
}