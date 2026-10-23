package inklib

Error :: enum {
    None = 0,

    // parser.parse_command
    QuotesNotClosed,

    // vfs.vfs_create
    UnableToOpen,
    IsNotDirectory,
    UnableToRead,

    // vfs paths
    NotFound,
    NotDirectory,
    IsDirectory,
}

error_string :: proc(err: Error) -> string {
    switch err {
        case .None:
            return "ok"

        case .QuotesNotClosed:
            return "error: quotes not closed"

        case .UnableToOpen:
            return "error: unable to open"

        case .IsNotDirectory:
            return "error: expected directory"

        case .UnableToRead:
            return "error: unable to read file or directory inside vfs"

        case .NotFound:
            return "No such file or directory"

        case .NotDirectory:
            return "Not a directory"

        case .IsDirectory:
            return "Is a directory"

        case:
            return "error: unknown error"
    }

    unreachable()
}

to_string :: proc {
    error_string,
    terminal_config_string,
}