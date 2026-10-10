package inklib

import "core:fmt"
import "core:os"
import "core:strings"

Terminal :: struct {
    user:        string,
    host:        string,
    prompt:      string,
    history:     [dynamic]string,
    should_exit: bool,
}

terminal_create :: proc(self: ^Terminal) {
    u := os.get_env("USER", context.temp_allocator)
    if len(u) == 0 do u = "user"
    h := os.get_env("HOSTNAME", context.temp_allocator)
    if len(h) == 0 do h = "localhost"

    self.user = strings.clone(u)
    self.host = strings.clone(h)
    self.prompt = fmt.aprintf("[%s@%s] $ ", self.user, self.host)
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
        append(&self.history, error_string(err))
        return
    }

    if len(args) == 0 do return

    cmd := args[0]
    cmd_args := args[1:]

    switch cmd {
        case "exit":
            self.should_exit = true
        case "clear":
            for line in self.history do delete(line)
            clear(&self.history)
        case "ls":
            append(&self.history, fmt.aprintf("ls: called with: %v", cmd_args))
        case "cd":
            append(&self.history, fmt.aprintf("cd: called with: %v", cmd_args))
        case:
            append(&self.history, fmt.aprintf("error: command not found: %s", cmd))
    }
}