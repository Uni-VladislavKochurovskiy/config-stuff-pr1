package inklib

import "core:fmt"
import "core:strings"

cmd_ls :: proc(self: ^Terminal, args: []string) {
    show_hidden := false
    paths := make([dynamic]string, context.temp_allocator)

    for arg in args {
        if len(arg) > 1 && arg[0] == '-' {
            for flag in arg[1:] {
                switch flag {
                    case 'a':
                        show_hidden = true
                    case:
                        terminal_print(self, "ls: invalid option: `%c`", flag)
                        return
                }
            }
        } else {
            append(&paths, arg)
        }
    }
    if len(paths) == 0 do append(&paths, ".")

    for path in paths {
        node, err := vfs_resolve(self.vfs, path)
        if err != .None {
            terminal_print(self, "ls: cannot access `%s`: %s", path, to_string(err))
            continue
        }

        children, is_dir := node.content.(VFSNode_Content_Directory)
        if !is_dir {
            terminal_print(self, "%s", path)
            continue
        }

        sb := strings.builder_make(context.temp_allocator)
        if len(paths) > 1 do fmt.sbprintf(&sb, "%s:\n", path)
        if show_hidden do strings.write_string(&sb, "./  ../  ")

        for child in children {
            if !show_hidden && strings.has_prefix(child.name, ".") do continue

            strings.write_string(&sb, child.name)
            if _, child_is_dir := child.content.(VFSNode_Content_Directory); child_is_dir {
                strings.write_byte(&sb, '/')
            }
            strings.write_string(&sb, "  ")
        }

        terminal_print(self, "%s", strings.trim_right_space(strings.to_string(sb)))
    }
}

cmd_cd :: proc(self: ^Terminal, args: []string) {
    if len(args) > 1 {
        terminal_print(self, "cd: too many arguments")
        return
    }

    path := len(args) == 0 ? "/" : args[0]
    if err := vfs_change_dir(self.vfs, path); err != .None {
        terminal_print(self, "cd: %s: %s", path, to_string(err))
        return
    }

    terminal_update_prompt(self)
}

cmd_cat :: proc(self: ^Terminal, args: []string) {
    if len(args) == 0 {
        terminal_print(self, "cat: missing file")
        return
    }

    for path in args {
        node, err := vfs_resolve(self.vfs, path)
        if err != .None {
            terminal_print(self, "cat: %s: %s", path, to_string(err))
            continue
        }

        switch content in node.content {
            case VFSNode_Content_Directory:
                terminal_print(self, "cat: %s: %s", path, to_string(Error.IsDirectory))

            case VFSNode_Content_File:
                text := strings.trim_right(content, "\r\n")
                if len(text) > 0 do terminal_print(self, "%s", text)
        }
    }
}

cmd_who :: proc(self: ^Terminal, args: []string) {
    show_header := false
    only_count := false

    is_am_i := len(args) == 2 && args[0] == "am" && (args[1] == "i" || args[1] == "I")
    if !is_am_i {
        for arg in args {
            switch arg {
                case "-H":
                    show_header = true
                case "-q":
                    only_count = true
                case:
                    if strings.has_prefix(arg, "-") {
                        terminal_print(self, "who: invalid option: `%s`", arg[1:])
                    } else {
                        terminal_print(self, "who: extra operand `%s`", arg)
                    }
                    return
            }
        }
    }

    if only_count {
        terminal_print(self, "%s\n# users=1", self.user)
        return
    }

    line := fmt.tprintf("%-8s %-12s %s", self.user, "pts/0", self.login_time)
    if show_header {
        terminal_print(self, "%-8s %-12s %s\n%s", "NAME", "LINE", "TIME", line)
    } else {
        terminal_print(self, "%s", line)
    }
}
