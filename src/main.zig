const std = @import("std");
const mem = @import("std").mem;
const Buffer = @import("std").Buffer;

const mod = @import("mod.zig");
const Parser = @import("parser.zig").Parser;
const mod2model = @import("mod2model.zig");
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

    var maybe_in_path: ?Buffer = null;
    defer if (maybe_in_path) |*b| { b.deinit(); };
    var maybe_out_path: ?Buffer = null;
    defer if (maybe_out_path) |*b| { b.deinit(); };
    var verbose = false;
    var help = false;
    var dry_run = false;

    var args = std.os.args();
    _ = args.skip(); // skip exe name
    while (args.next(&mem.c_allocator)) |arg_or_err| {
        const arg = %return arg_or_err;
        defer mem.c_allocator.free(arg);

        if (mem.eql(u8, "-h", arg) or mem.eql(u8, "--help", arg)) {
            help = true;
            break;
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
            maybe_in_path = %%Buffer.init(&mem.c_allocator, arg);
        } else if (maybe_out_path == null) {
            maybe_out_path = %%Buffer.init(&mem.c_allocator, arg);
        } else {
            // Too many arguments
            return error.CLIBadArguments;
        }
    }

    if (help) {
        %%std.io.stderr.printf("zimodre: convert Monster Hunter Stories MOD files to GLB\n");
        usage();
        return;
    }

    var in_path = maybe_in_path ?? return error.CLIBadArguments;
    maybe_in_path = null;
    defer in_path.deinit();
    var out_path = maybe_out_path ?? return error.CLIBadArguments;
    maybe_out_path = null;
    defer out_path.deinit();


    // Do the conversion

    var input_file = %return read_file(in_path.toSliceConst());
    defer input_file.deinit();

    var parser = Parser.new(input_file.toSliceConst());
    parser.logging_on = verbose;
    var mod_file = %return mod.parse(&parser);
    defer mod_file.deinit();

    var model = %return mod2model.convert(&mod_file);
    defer model.deinit();

    var glb_buffer = %return gltf.write_glb(&model);
    defer glb_buffer.deinit();

    if (!dry_run) {
        %return write_file(out_path.toSliceConst(), glb_buffer.toSlice());
    }
}

/// Read a whole file into a Buffer.
fn read_file(path: []const u8) -> %Buffer {
    var buffer = Buffer.initNull(&mem.c_allocator);
    %defer buffer.deinit();

    var in = std.io.InStream.open(path, &mem.c_allocator)
        %% return error.CouldntOpenInputFile;
    defer in.close();
    in.readAll(&buffer) %% return error.CouldntReadInputFile;

    buffer
}

fn write_file(path: []const u8, contents: []const u8) -> %void {
    var out = std.io.OutStream.open(path, &mem.c_allocator)
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
            %%o.printf("input file: couldn't open for reading\n");
        },
        error.CouldntReadInputFile => {
            %%o.printf("input file: couldn't read file\n");
        },
        error.CouldntOpenOutputFile => {
            %%o.printf("output file: couldn't open for writing\n");
        },
        error.CouldntWriteOutputFile => {
            %%o.printf("output file: couldn't write file\n");
        },
        error.ValidateNotEnoughVertexData => {
            %%o.printf("validation: file asked for too much vertex data\n");
        },
        error.ValidateNotEnoughIndexData => {
            %%o.printf("validation: file asked for too much index data\n");
        },
        error.UnsupportedVertexSize => {
            %%o.printf("unimplemented: unsupported vertex format in MOD file\n");
        },
        else => {
            %%o.printf("error: nonspecific error -- everyone's favorite kind :)\n");
        }
    }
}

fn usage() {
    var o = std.io.stderr;
    %%o.printf(
        \\Usage: zimodre [options...] <input> <output>
        \\Options:
        \\  --dry-run        Don't write the output file
        \\  -v, --verbose    Show debugging output
        \\  -h, --help       Show this help message
        ++"\n"
    );
}
