package inklib

import "core:strings"

parse_command :: proc(
    input: string,
    allocator := context.temp_allocator
) -> (
    args: [dynamic]string,
    err: Error
) {
    try_push :: proc(args: ^[dynamic]string, sb: strings.Builder) -> bool {
        if strings.builder_len(sb) > 0 {
            append(args, strings.to_string(sb))
            return true
        }
        return false
    }

    trimmed := strings.trim_space(input)
    if len(trimmed) == 0 do return args, .None

    sb := strings.builder_make(allocator)
    in_quotes := false

    for i := 0; i < len(trimmed); i += 1 {
        char := trimmed[i]
        if char == '"' {
            in_quotes = !in_quotes
        } else if char == ' ' && !in_quotes {
            if try_push(&args, sb) {
                sb = strings.builder_make(allocator)
            }
        } else {
            strings.write_byte(&sb, char)
        }
    }

    if in_quotes {
        return nil, .QuotesNotClosed
    }

    try_push(&args, sb)

    return args, .None
}