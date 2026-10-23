package gui

import "core:fmt"
import "core:os"
import "../inklib"
import strconv "core:strconv"

CliDealResult :: struct {
    terminal_config: inklib.TerminalConfig,
    gui_config: GuiConfig,
}


cli_deal :: proc() -> (should_exit := false, res: CliDealResult = {}) {
    args := os.args[1:]

    for i := 0; i < len(args); i += 1 {
        arg := args[i]

        switch arg {
            case "-h", "--help":
                cli_print_help()
                should_exit = true

            case "-v", "--vfs":
                if i + 1 < len(args) {
                    res.terminal_config.vfs_root = args[i + 1]
                    i += 1
                } else {
                    fmt.eprintln("error: vfs flag needs a path.")
                }

            case "-ss", "--start-script":
                if i + 1 < len(args) {
                    res.terminal_config.start_script = args[i + 1]
                    i += 1
                } else {
                    fmt.eprintln("error: start script flag needs a path.")
                }

            case "-f", "--font":
                if i + 1 < len(args) {
                    res.gui_config.font = args[i + 1]
                    i += 1
                } else {
                    fmt.eprintln("error: font flag needs a path.")
                }

            case "-fs", "--font-size":
                if i + 1 < len(args) {
                    val, ok := strconv.parse_int(args[i + 1])
                    if !ok {
                        fmt.eprintln("error: given font size flag value is not an integer.")
                        break
                    }
                    res.gui_config.font_size = val
                    i += 1
                } else {
                    fmt.eprintln("error: font size flag needs an integer.")
                }

            case:
                fmt.eprintfln("warning: unknown argument: %s", arg)
        }
    }

    return should_exit, res
}

cli_print_help :: proc() {
    fmt.println("Using: <program> [options]")
    fmt.println()
    fmt.println("Options:")
    fmt.println("   -h,    --help                               Show this help message")
    fmt.println("   -v,    --vfs <path>                         Set VFS root")
    fmt.println("   -ss,   --start-script <path>                Set start script")
    fmt.println("   -f,    --font <path>                        Set font used by terminal")
    fmt.println("   -fs,   --font-size <integer> (default=24)   Set font size")
    fmt.println()
    fmt.println("Description:")
    fmt.println("   VFS - virtual filesystem")
    fmt.println("   Start script - a script that plays at the start of terminal")
}