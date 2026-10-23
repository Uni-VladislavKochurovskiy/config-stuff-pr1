package gui

import "core:fmt"
import "../inklib"

terminal: inklib.Terminal

main :: proc() {
    should_exit, res := cli_deal()
    if should_exit do return

    fmt.printfln("debug: terminal args: %s", inklib.to_string(res.terminal_config))
    fmt.printfln("debug: gui args: %s", to_string(res.gui_config))
    fmt.println()

    inklib.terminal_create(&terminal, res.terminal_config)
    defer inklib.terminal_destroy(&terminal)

    gui_run(&terminal, res.gui_config)
}