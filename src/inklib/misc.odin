package inklib

Error :: enum {
    None = 0,

    // parser.parse_command
    QuotesNotClosed,
}

error_string :: proc(err: Error) -> string {
    switch err {
        case .None:
            return "ok"

        case .QuotesNotClosed:
            return "error: quotes not closed"

        case:
            return "error: unknown error"
    }

    unreachable()
}

to_string :: proc {
    error_string,
    terminal_config_string,
}