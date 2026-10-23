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
}

VFS :: struct {
    root:        ^VFSNode,
    current_dir: []string,
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

    self := new(VFS)
    self.root = root_node
    self.current_dir = {}

    return self
}

vfs_destroy :: proc(self: ^VFS) {
    if self == nil do return
    vfs_node_destroy(self.root)
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
        child := new(VFSNode)
        child.name = strings.clone(h.name)
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
