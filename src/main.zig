const std = @import("std");
const Buffer = @import("std").Buffer;

const mod = @import("mod.zig");
const Parser = @import("parser.zig").Parser;
const mod2gltf = @import("mod2gltf.zig");
const gltf = @import("gltf.zig");

error CLIBadArguments;
error CLINoInputFile;
error CouldntOpenInputFile;
error CouldntReadInputFile;
error CouldntOpenOutputFile;
error CouldntWriteOutputFile;

pub fn main() -> %void {
    main2() %% |err| {
        print_error(err);
        return err;
    };
}

fn main2() -> %void {
    // Parse CLI arguments
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

    // Do the conversion

    var input_file = %return read_file(path);
    defer input_file.deinit();

    var parser = Parser.new(input_file.toSliceConst());
    parser.logging_on = true;
    var mod_file = %return mod.parse(&parser);
    defer mod_file.deinit();

    var g = %return mod2gltf.convert(&mod_file);
    defer g.deinit();

    var glb_buffer = %return gltf.write_glb(&g);
    defer glb_buffer.deinit();

    %return write_file("out.glb", glb_buffer.toSlice());
}

/// Read a whole file into a Buffer.
fn read_file(path: []const u8) -> %Buffer {
    var buffer = Buffer.initNull(&std.mem.c_allocator);
    %defer buffer.deinit();

    var in = std.io.InStream.open(path, &std.mem.c_allocator)
        %% return error.CouldntOpenInputFile;
    defer in.close();
    in.readAll(&buffer) %% return error.CouldntReadInputFile;

    buffer
}

fn write_file(path: []const u8, contents: []const u8) -> %void {
    var out = std.io.OutStream.open(path, &std.mem.c_allocator)
        %% return error.CouldntOpenOutputFile;
    defer out.close();
    out.write(contents) %% return error.CouldntWriteOutputFile;
    out.flush() %% return error.CouldntWriteOutputFile;
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
        error.CouldntOpenInputFile => {
            %%o.printf("input file: Couldn't open for reading\n");
        },
        error.CouldntReadInputFile => {
            %%o.printf("input file: Couldn't read file\n");
        },
        error.CouldntOpenOutputFile => {
            %%o.printf("output file: Couldn't open for writing\n");
        },
        error.CouldntWriteOutputFile => {
            %%o.printf("output file: Couldn't write file\n");
        },
        else => {
            %%o.printf("error: nonspecific error -- everyone's favorite kind :)\n");
        }
    }
}

fn usage() {
    var o = std.io.stderr;
    %%o.printf("Usage: zimodre [input]\n");
}
