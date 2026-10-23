package inklib

import "core:fmt"
import "core:os"
import "core:strings"

AVAILABLE_COMMANDS ::
`available commands:
    help / listcmd
    exit
    clear
    ls
    cd
    say
    tree
`

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
    commands:    [dynamic]string,

    vfs: ^VFS,
    current_path_str: string,

    should_exit: bool,
}

terminal_create :: proc(self: ^Terminal, config: TerminalConfig = {}) {
    // os info fetch
    u := os.get_env("USER", context.allocator)
    if len(u) == 0 do u = strings.clone("user")
    h := os.get_env("HOSTNAME", context.allocator)
    if len(h) == 0 {
        if data, err := os.read_entire_file_from_path("/etc/hostname", context.allocator); err == nil {
            defer delete(data)

            h = strings.clone(strings.trim_space(string(data)))
        }
    }
    if len(h) == 0 do h = strings.clone("localhost")

    self.user = u
    self.host = h
    self.prompt = fmt.aprintf("[%s@%s] $ ", self.user, self.host)


    // config processing
    // vfs
    if path, ok := config.vfs_root.?; ok {
        if vfs_instance, err := vfs_create(path); err == .None {
            self.vfs = vfs_instance
            append(&self.history, fmt.aprintf("success: initialized VFS: %s", path))
            fmt.printfln("success: loaded vfs from %s", path)
        } else {
            append(&self.history, strings.clone(to_string(err)))
            append(&self.history, fmt.aprintf("error: failed to init VFS: %s", path))
            fmt.eprintfln("%s\nerror: failed to load vfs: %s", to_string(err), path)
        }
    }
    if self.vfs == nil {
        append(&self.history, strings.clone("info: using empty VFS"))
        fmt.println("info: vfs not loaded. initializing default empty one.")
        self.vfs = vfs_create_empty()
    }

    // default message
    append(&self.history, strings.clone("To get a list of commands, type `help` or `listcmd`"))

    // start script
    if path, ok := config.start_script.?; ok {
        if data, err := os.read_entire_file_from_path(path, context.allocator); err == nil {
            defer delete(data)

            it := string(data)
            for line in strings.split_lines_iterator(&it) {
                terminal_exec(self, line)
                if self.should_exit do break
            }
            fmt.println("success: used start script")
        } else {
            append(&self.history, fmt.aprintf("error: failed to read start script: %s", path))
            fmt.eprintfln("error: failed to read start script file: %s", path)
        }
    }
}

terminal_destroy :: proc(self: ^Terminal) {
    vfs_destroy(self.vfs)
    self.vfs = nil

    for cmd in self.commands do delete(cmd)
    delete(self.commands)

    for line in self.history do delete(line)
    delete(self.history)

    delete(self.current_path_str)
    delete(self.prompt)
    delete(self.host)
    delete(self.user)
}


terminal_exec :: proc(self: ^Terminal, cmd_raw: string) {
    if len(cmd_raw) == 0 {
        append(&self.history, strings.clone(self.prompt))
        return
    }

    append(&self.history, fmt.aprintf("%s%s", self.prompt, cmd_raw))

    is_blank := len(strings.trim_space(cmd_raw)) == 0
    is_repeat := len(self.commands) > 0 && self.commands[len(self.commands) - 1] == cmd_raw
    if !is_blank && !is_repeat {
        append(&self.commands, strings.clone(cmd_raw))
    }

    args, err := parse_command(cmd_raw)
    if err != .None {
        append(&self.history, strings.clone(to_string(err)))
        return
    }

    if len(args) == 0 do return

    cmd := args[0]
    cmd_args := args[1:]
    no_args := len(cmd_args) == 0

    switch cmd {
        case "listcmd": fallthrough // alias
        case "help":
            append(&self.history, strings.clone(AVAILABLE_COMMANDS))

        case "exit":
            self.should_exit = true

        case "clear":
            for line in self.history do delete(line)
            clear(&self.history)

        case "ls":
            append(&self.history, fmt.aprintf("ls: called with: %v", cmd_args))

        case "cd":
            if no_args {
                append(&self.history, strings.clone("error: not enough arguments: required: 1 path"))
                break
            }

            append(&self.history, fmt.aprintf("cd: called with: %v", cmd_args))

        case "say":
            if no_args {
                append(&self.history, strings.clone("error: not enough arguments: required: 1 string"))
                break
            }

            append(&self.history, strings.clone(cmd_args[0]))

        case "tree":
            append(&self.history, vfs_tree_string(self.vfs))

        case:
            append(&self.history, fmt.aprintf("error: command not found: %s", cmd))
    }
}