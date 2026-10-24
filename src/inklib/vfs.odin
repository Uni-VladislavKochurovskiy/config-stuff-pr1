package inklib

import "core:os"
import "core:path/slashpath"
import "core:slice"
import "core:strings"


VFSNode_Content_File :: string
VFSNode_Content_Directory :: [dynamic]^VFSNode

VFSNode_Content :: union {
    VFSNode_Content_File,
    VFSNode_Content_Directory,
}

VFSNode :: struct {
    name:    string,
    content: VFSNode_Content,
    mode:    u32,
}

VFS :: struct {
    root:        ^VFSNode,
    current_dir: [dynamic]string,
}

vfs_create :: proc(rootpath: string) -> (^VFS, Error) {
    info, err := os.stat(rootpath, context.allocator)
    if err != nil {
        return nil, .UnableToOpen
    }
    defer os.file_info_delete(info, context.allocator)

    if info.type != .Directory {
        return nil, .IsNotDirectory
    }

    vfs := vfs_create_empty()
    if err := _vfs_load_recursive(rootpath, vfs.root); err != .None {
        vfs_destroy(vfs)
        return nil, err
    }

    return vfs, .None
}

vfs_create_empty :: proc() -> ^VFS {
    root_node := new(VFSNode)
    root_node.name = strings.clone("/")
    root_node.content = VFSNode_Content_Directory{}
    root_node.mode = 0o755

    self := new(VFS)
    self.root = root_node
    self.current_dir = {}

    return self
}

vfs_destroy :: proc(self: ^VFS) {
    if self == nil do return
    vfs_node_destroy(self.root)
    for part in self.current_dir do delete(part)
    delete(self.current_dir)
    free(self)
}

vfs_node_destroy :: proc(node: ^VFSNode) {
    if node == nil do return
    delete(node.name)

    switch resolved in node.content {
        case VFSNode_Content_File:
            delete(resolved)
        case VFSNode_Content_Directory:
            for child in resolved {
                vfs_node_destroy(child)
            }
            delete(resolved)
    }

    free(node)
}


_vfs_load_recursive :: proc(path: string, node: ^VFSNode) -> Error {
    handles, err := os.read_directory_by_path(path, -1, context.allocator)
    if err != nil do return .UnableToRead
    defer os.file_info_slice_delete(handles, context.allocator)

    dir := &node.content.(VFSNode_Content_Directory)

    for h in handles {
        if h.name == ".gitkeep" do continue

        child := new(VFSNode)
        child.name = strings.clone(h.name)
        child.mode = transmute(u32)h.mode & 0o777
        append(dir, child)

        fullpath := slashpath.join({path, h.name})
        defer delete(fullpath)

        if h.type == .Directory {
            child.content = VFSNode_Content_Directory{}
            _vfs_load_recursive(fullpath, child) or_return
        } else {
            data, read_err := os.read_entire_file_from_path(fullpath, context.allocator)
            if read_err != nil do return .UnableToRead
            child.content = string(data)
        }
    }

    slice.sort_by(dir[:], proc(a, b: ^VFSNode) -> bool { return a.name < b.name })
    return .None
}

vfs_tree_string :: proc(vfs: ^VFS, allocator := context.allocator) -> string {
    print_node :: proc(sb: ^strings.Builder, node: ^VFSNode, indent: string) {
        children := node.content.(VFSNode_Content_Directory) or_else nil

        for child, i in children {
            is_last := i == len(children) - 1
            _, is_dir := child.content.(VFSNode_Content_Directory)

            strings.write_string(sb, indent)
            strings.write_string(sb, is_last ? "'-- " : "|-- ")
            strings.write_string(sb, child.name)
            if is_dir do strings.write_byte(sb, '/')
            strings.write_byte(sb, '\n')

            if is_dir {
                next_indent := strings.concatenate({indent, is_last ? "    " : "|   "}, context.temp_allocator)
                print_node(sb, child, next_indent)
            }
        }
    }

    sb := strings.builder_make(allocator)
    strings.write_string(&sb, "/\n")
    print_node(&sb, vfs.root, "")
    return strings.to_string(sb)
}

vfs_split_path :: proc(self: ^VFS, path: string, allocator := context.temp_allocator) -> [dynamic]string {
    parts := make([dynamic]string, allocator)
    if !strings.has_prefix(path, "/") {
        append(&parts, ..self.current_dir[:])
    }

    it := path
    for part in strings.split_iterator(&it, "/") {
        switch part {
            case "", ".":
                break
            case "..":
                if len(parts) > 0 do pop(&parts)
            case:
                append(&parts, part)
        }
    }
    return parts
}

vfs_find :: proc(self: ^VFS, parts: []string) -> (^VFSNode, Error) {
    node := self.root
    for part in parts {
        children, is_dir := node.content.(VFSNode_Content_Directory)
        if !is_dir do return nil, .NotDirectory

        next: ^VFSNode
        for child in children {
            if child.name == part {
                next = child
                break
            }
        }
        if next == nil do return nil, .NotFound
        node = next
    }
    return node, .None
}

vfs_resolve :: proc(self: ^VFS, path: string) -> (^VFSNode, Error) {
    return vfs_find(self, vfs_split_path(self, path)[:])
}

vfs_change_dir :: proc(self: ^VFS, path: string) -> Error {
    parts := vfs_split_path(self, path)
    node := vfs_find(self, parts[:]) or_return
    if _, is_dir := node.content.(VFSNode_Content_Directory); !is_dir do return .NotDirectory

    new_dir := make([dynamic]string, 0, len(parts))
    for part in parts do append(&new_dir, strings.clone(part))

    for part in self.current_dir do delete(part)
    delete(self.current_dir)
    self.current_dir = new_dir
    return .None
}

vfs_current_dir_string :: proc(self: ^VFS, allocator := context.allocator) -> string {
    return strings.concatenate({"/", strings.join(self.current_dir[:], "/", context.temp_allocator)}, allocator)
}

vfs_remove_dir :: proc(self: ^VFS, path: string) -> Error {
    parts := vfs_split_path(self, path)
    if len(parts) == 0 do return .Busy

    if len(parts) <= len(self.current_dir) && slice.equal(parts[:], self.current_dir[:len(parts)]) {
        return .Busy
    }

    parent := vfs_find(self, parts[:len(parts) - 1]) or_return
    node := vfs_find(self, parts[:]) or_return

    children, is_dir := node.content.(VFSNode_Content_Directory)
    if !is_dir do return .NotDirectory
    if len(children) > 0 do return .NotEmpty

    siblings := &parent.content.(VFSNode_Content_Directory)
    for child, i in siblings {
        if child == node {
            ordered_remove(siblings, i)
            break
        }
    }
    vfs_node_destroy(node)
    return .None
}

vfs_mode_string :: proc(node: ^VFSNode, allocator := context.temp_allocator) -> string {
    _, is_dir := node.content.(VFSNode_Content_Directory)
    letters := "rwxrwxrwx"

    buf := make([]u8, 10, allocator)
    buf[0] = is_dir ? 'd' : '-'
    for i in 0..<9 {
        bit := u32(1) << u32(8 - i)
        buf[i + 1] = node.mode & bit != 0 ? letters[i] : '-'
    }
    return string(buf)
}
