const std = @import("std");
const Buffer = @import("std").Buffer;

const mod = @import("mod.zig");
const Parser = @import("parser.zig").Parser;

error CLIBadArguments;
error CLINoInputFile;

pub fn main() -> %void {
    main2() %% |err| {
        print_error(err);
        return err;
    };
}

fn main2() -> %void {
    const path = {
        var args_it = std.os.args();
        const exe = %return ??args_it.next(&std.mem.c_allocator);
        var path: ?[]const u8 = null;
        while (args_it.next(&std.mem.c_allocator)) |arg_or_err| {
            const arg = %return arg_or_err;
            if (path != null) {
                return error.CLIBadArguments;
            }
            path = arg;
        }
        path ?? return error.CLINoInputFile
    };

    var input_buffer = %return read_file(path);
    defer input_buffer.deinit();
    const file = input_buffer.toSliceConst();

    var parser = Parser.new(file);
    parser.logging_on = true;
    const mod_file = %return mod.parse(&parser);
}

/// Read a whole file into a Buffer.
fn read_file(path: []const u8) -> %Buffer {
    var buffer = Buffer.initNull(&std.mem.c_allocator);
    %defer buffer.deinit();

    //TODO more specific error
    var in = %return std.io.InStream.open(path, &std.mem.c_allocator);
    defer in.close();
    %return in.readAll(&buffer);

    buffer
}

fn print_error(err: error) {
    var o = std.io.stderr;
    switch (err) {
        error.CLIBadArguments => {
            %%o.printf("cli: bad command-line arguments\n");
            usage();
        },
        error.CLINoInputFile => {
            %%o.printf("cli: need an input file\n");
            usage();
        },
        error.ParseErrorUnexpectedEOF => {
            %%o.printf(
                "parser: unexpected EOF\n" ++
                "parser: file couldn't be understood as MOD\n");
        },
        else => {
            %%o.printf("error: nonspecific error\n");
        }
    }
}

fn usage() {
    var o = std.io.stderr;
    %%o.printf("Usage: zimodre [input]\n");
}
