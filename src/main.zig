const std = @import("std");
const mem = @import("std").mem;
const Buffer = @import("std").Buffer;

const allocator = &@import("std").heap.c_allocator;

const mod = @import("mod.zig");
const Parser = @import("parser.zig").Parser;
const mod2model = @import("mod2model.zig");
const gltf = @import("gltf.zig");

error CLIBadArguments;
error CLINoInputFile;
error CouldntReadInputFile;
error CouldntWriteOutputFile;

pub fn main() -> %void {
    main2() %% |err| {
        printError(err);
        return err;
    };
}

fn main2() -> %void {
    // Parse CLI arguments

    var maybe_in_path: ?Buffer = null;
    defer if (maybe_in_path) |*b| { b.deinit(); };
    var maybe_out_path: ?Buffer = null;
    defer if (maybe_out_path) |*b| { b.deinit(); };
    var verbose = false;
    var dry_run = false;

    var args = std.os.args();
    _ = args.skip(); // skip exe name
    while (args.next(allocator)) |arg_or_err| {
        const arg = %return arg_or_err;
        defer allocator.free(arg);

        if (mem.eql(u8, "-h", arg) or mem.eql(u8, "--help", arg)) {
            help();
            return;
        }
        if (mem.eql(u8, "-v", arg) or mem.eql(u8, "--verbose", arg)) {
            verbose = true;
            continue;
        }
        if (mem.eql(u8, "--dry-run", arg)) {
            dry_run = true;
            continue;
        }
        if (arg[0] == '-') {
            return error.CLIBadArguments;
        }

        if (maybe_in_path == null) {
            maybe_in_path = %%Buffer.init(allocator, arg);
        } else if (maybe_out_path == null) {
            maybe_out_path = %%Buffer.init(allocator, arg);
        } else {
            // Too many arguments
            return error.CLIBadArguments;
        }
    }

    var in_path = maybe_in_path ?? return error.CLIBadArguments;
    maybe_in_path = null;
    defer in_path.deinit();
    var out_path = maybe_out_path ?? return error.CLIBadArguments;
    maybe_out_path = null;
    defer out_path.deinit();


    // Do the conversion

    var input_file = %return readFile(in_path.toSliceConst());
    defer input_file.deinit();

    var parser = Parser.new(input_file.toSliceConst());
    parser.logging_on = verbose;
    var mod_file = %return mod.parse(&parser);
    defer mod_file.deinit();

    var model = %return mod2model.convert(&mod_file);
    defer model.deinit();

    var glb_buffer = %return gltf.writeGlb(&model);
    defer glb_buffer.deinit();

    if (!dry_run) {
        %return writeFile(out_path.toSliceConst(), glb_buffer.toSlice());
    }
}

/// Read a whole file into a Buffer.
fn readFile(path: []const u8) -> %Buffer {
    var buffer = Buffer.initNull(allocator);
    %defer buffer.deinit();

    var file = std.io.File.openRead(path, allocator)
        %% return error.CouldntReadInputFile;
    defer file.close();
    var in = &file.in_stream;
    in.readAllBuffer(&buffer, @maxValue(usize))
        %% return error.CouldntReadInputFile;

    buffer
}

fn writeFile(path: []const u8, contents: []const u8) -> %void {
    std.io.writeFile(path, contents, allocator)
        %% return error.CouldntWriteOutputFile;
}

fn printError(err: error) {
    var stderr = %%std.io.getStdErr();
    var o = &stderr.out_stream;
    switch (err) {
        error.CLIBadArguments => {
            %%o.print("cli: bad command-line arguments\n");
            usage();
        },
        error.CLINoInputFile => {
            %%o.print("cli: need an input file\n");
            usage();
        },
        error.ParseErrorUnexpectedEOF => {
            %%o.print(
                "parser: unexpected EOF\n" ++
                "parser: file couldn't be understood as MOD\n");
        },
        error.CouldntReadInputFile => {
            %%o.print("input file: couldn't read file\n");
        },
        error.CouldntWriteOutputFile => {
            %%o.print("output file: couldn't write file\n");
        },
        error.ValidateNotEnoughVertexData => {
            %%o.print("validation: file asked for too much vertex data\n");
        },
        error.ValidateNotEnoughIndexData => {
            %%o.print("validation: file asked for too much index data\n");
        },
        error.UnsupportedVertexSize => {
            %%o.print("unimplemented: unsupported vertex format in MOD file\n");
        },
        else => {
            %%o.print("error: nonspecific error -- everyone's favorite kind :)\n");
        }
    }
}

fn help() {
    var stderr = %%std.io.getStdErr();
    var o = &stderr.out_stream;
    %%o.print("zimodre: convert Monster Hunter Stories MOD files to GLB\n");
    usage();
}

fn usage() {
    var stderr = %%std.io.getStdErr();
    var o = &stderr.out_stream;
    %%o.print(
        \\Usage: zimodre [options...] <input> <output>
        \\Options:
        \\  --dry-run        Don't write the output file
        \\  -v, --verbose    Show debugging output
        \\  -h, --help       Show this help message
        ++"\n"
    );
}
