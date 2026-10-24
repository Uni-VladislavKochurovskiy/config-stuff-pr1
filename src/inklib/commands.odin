package inklib

import "core:fmt"
import "core:path/slashpath"
import "core:strconv"
import "core:strings"

cmd_ls :: proc(self: ^Terminal, args: []string) {
    show_hidden := false
    long_format := false
    paths := make([dynamic]string, context.temp_allocator)

    for arg in args {
        if len(arg) > 1 && arg[0] == '-' {
            for flag in arg[1:] {
                switch flag {
                    case 'a':
                        show_hidden = true
                    case 'l':
                        long_format = true
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

        sb := strings.builder_make(context.temp_allocator)

        children, is_dir := node.content.(VFSNode_Content_Directory)
        if !is_dir {
            ls_write_entry(self, &sb, node, path, long_format)
            terminal_print(self, "%s", strings.trim_right_space(strings.to_string(sb)))
            continue
        }

        if len(paths) > 1 do fmt.sbprintf(&sb, "%s:\n", path)
        if show_hidden {
            ls_write_entry(self, &sb, node, ".", long_format)
            parent, _ := vfs_resolve(self.vfs, strings.concatenate({path, "/.."}, context.temp_allocator))
            ls_write_entry(self, &sb, parent, "..", long_format)
        }

        for child in children {
            if !show_hidden && strings.has_prefix(child.name, ".") do continue
            ls_write_entry(self, &sb, child, child.name, long_format)
        }

        terminal_print(self, "%s", strings.trim_right_space(strings.to_string(sb)))
    }
}

ls_write_entry :: proc(self: ^Terminal, sb: ^strings.Builder, node: ^VFSNode, name: string, long_format: bool) {
    size := 4096
    suffix := ""
    switch content in node.content {
        case VFSNode_Content_File:
            size = len(content)
        case VFSNode_Content_Directory:
            suffix = "/"
    }

    if long_format {
        fmt.sbprintf(sb, "%s %-8s %6s %s%s\n", vfs_mode_string(node), self.user, fmt.tprint(size), name, suffix)
    } else {
        fmt.sbprintf(sb, "%s%s  ", name, suffix)
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

cmd_chmod :: proc(self: ^Terminal, args: []string) {
    recursive := false
    operands := make([dynamic]string, context.temp_allocator)

    for arg in args {
        if arg == "-R" {
            recursive = true
        } else {
            append(&operands, arg)
        }
    }

    if len(operands) == 0 {
        terminal_print(self, "chmod: missing operand")
        return
    }
    if len(operands) == 1 {
        terminal_print(self, "chmod: missing operand after `%s`", operands[0])
        return
    }

    spec := operands[0]
    if _, ok := chmod_apply(spec, 0); !ok {
        terminal_print(self, "chmod: invalid mode: `%s`", spec)
        return
    }

    for path in operands[1:] {
        node, err := vfs_resolve(self.vfs, path)
        if err != .None {
            terminal_print(self, "chmod: cannot access `%s`: %s", path, to_string(err))
            continue
        }
        chmod_node(node, spec, recursive)
    }
}

chmod_node :: proc(node: ^VFSNode, spec: string, recursive: bool) {
    node.mode, _ = chmod_apply(spec, node.mode)

    if !recursive do return
    if children, is_dir := node.content.(VFSNode_Content_Directory); is_dir {
        for child in children do chmod_node(child, spec, true)
    }
}

chmod_apply :: proc(spec: string, mode: u32) -> (result: u32, ok: bool) {
    if len(spec) == 0 || strings.has_suffix(spec, ",") do return mode, false

    if value, parsed := strconv.parse_uint(spec, 8); parsed {
        if value > 0o7777 do return mode, false
        return u32(value) & 0o777, true
    }

    result = mode
    it := spec
    for clause in strings.split_iterator(&it, ",") {
        who: u32
        i := 0
        who_loop: for ; i < len(clause); i += 1 {
            switch clause[i] {
                case 'u': who |= 0o700
                case 'g': who |= 0o070
                case 'o': who |= 0o007
                case 'a': who |= 0o777
                case: break who_loop
            }
        }
        // complicated stuff ahead

        if who == 0 do who = 0o777
        if i >= len(clause) do return mode, false

        op := clause[i]
        if op != '+' && op != '-' && op != '=' do return mode, false

        perms: u32
        for c in clause[i + 1:] {
            switch c {
                case 'r': perms |= 0o444
                case 'w': perms |= 0o222
                case 'x': perms |= 0o111
                case: return mode, false
            }
        }
        perms &= who

        switch op {
            case '+': result |= perms
            case '-': result &~= perms
            case '=': result = (result &~ who) | perms
        }
    }
    return result, true

    // i almost have no idea how all of this work.
}

cmd_rmdir :: proc(self: ^Terminal, args: []string) {
    with_parents := false
    paths := make([dynamic]string, context.temp_allocator)

    for arg in args {
        if arg == "-p" {
            with_parents = true
        } else if len(arg) > 1 && arg[0] == '-' {
            terminal_print(self, "rmdir: invalid option: `%s`", arg[1:])
            return
        } else {
            append(&paths, arg)
        }
    }

    if len(paths) == 0 {
        terminal_print(self, "rmdir: missing operand")
        return
    }

    for path in paths {
        current := path
        for {
            if err := vfs_remove_dir(self.vfs, current); err != .None {
                terminal_print(self, "rmdir: failed to remove `%s`: %s", current, to_string(err))
                break
            }
            if !with_parents do break

            current = slashpath.dir(current, context.temp_allocator)
            if current == "." || current == "/" do break
        }
    }
}
