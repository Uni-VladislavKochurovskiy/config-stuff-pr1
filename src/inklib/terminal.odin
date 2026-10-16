package inklib

import "core:fmt"
import "core:os"
import "core:strings"

TerminalConfig :: struct {
    vfs_root:     Maybe(string),
    start_script: Maybe(string)
}

terminal_config_string :: proc(config: TerminalConfig) -> string {
    not_set := "[not_set]"

    return fmt.tprintf("TerminalConfig(\n\tvfs_root = %s,\n\tstart_script = %s\n)",
    config.vfs_root.? or_else not_set,
    config.start_script.? or_else not_set,
    )
}


Terminal :: struct {
    user:        string,
    host:        string,
    prompt:      string,
    history:     [dynamic]string,
    should_exit: bool,
}

terminal_create :: proc(self: ^Terminal, config: TerminalConfig = {}) {
    // os info fetch
    u := os.get_env("USER", context.allocator)
    if len(u) == 0 do u = "user"
    h := os.get_env("HOSTNAME", context.allocator)
    if len(h) == 0 do h = "localhost"

    self.user = u
    self.host = h
    self.prompt = fmt.aprintf("[%s@%s] $ ", self.user, self.host)

    // default message
    append(&self.history, fmt.aprintf("To get a list of commands, type `help` or `listcmd`"))


    // config processing
    fmt.printfln("info: using vfs = %s", config.vfs_root.? or_else "none")

    if path, ok := config.start_script.?; ok {
        if data, err := os.read_entire_file_from_path(path, context.allocator); err == nil {
            defer delete(data)

            it := string(data)
            for line in strings.split_lines_iterator(&it) {
                terminal_exec(self, line)
            }
            fmt.println("success: used start script")
        } else {
            fmt.eprintfln("error: failed to read start script file: %s", path)
        }
    }
}

terminal_destroy :: proc(self: ^Terminal) {
    delete(self.user)
    delete(self.host)
    delete(self.prompt)
    for line in self.history do delete(line)
    delete(self.history)
}


terminal_exec :: proc(self: ^Terminal, cmd_raw: string) {
    if len(cmd_raw) == 0 {
        append(&self.history, strings.clone(self.prompt))
        return
    }

    append(&self.history, fmt.aprintf("%s%s", self.prompt, cmd_raw))

    args, err := parse_command(cmd_raw)
    if err != .None {
        append(&self.history, to_string(err))
        return
    }

    if len(args) == 0 do return

    cmd := args[0]
    cmd_args := args[1:]
    no_args := len(cmd_args) == 0

    switch cmd {
        case "listcmd": fallthrough // alias
        case "help":
            append(&self.history, strings.clone(
            "available commands:\n\thelp / listcmd\n\texit\n\tclear\n\tls\n\tcd\n\tsay"
            ))

        case "exit":
            self.should_exit = true

        case "clear":
            for line in self.history do delete(line)
            clear(&self.history)

        case "ls":
            append(&self.history, fmt.aprintf("ls: called with: %v", cmd_args))

        case "cd":
            if no_args {
                append(&self.history, "error: not enough arguments: required: 1 path")
                break
            }

            append(&self.history, fmt.aprintf("cd: called with: %v", cmd_args))

        case "say":
            if no_args {
                append(&self.history, "error: not enough arguments: required: 1 string")
                break
            }

            append(&self.history, strings.clone(cmd_args[0]))

        case:
            append(&self.history, fmt.aprintf("error: command not found: %s", cmd))
    }
}