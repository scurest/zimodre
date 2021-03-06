const io = @import("std").io;

const byteorder = @import("byteorder.zig");

error ParseErrorUnexpectedEOF;

pub const Parser = struct {
    buffer: []const u8,
    pos: usize,
    logging_on: bool,

    pub fn new(buffer: []const u8) -> Parser {
        Parser {
            .buffer = buffer,
            .pos = 0,
            .logging_on = false,
        }
    }

    pub fn begin(self: &Parser, name: []const u8) {
        self.log("# {}\n", name);
    }

    pub fn end(self: &Parser) {
        self.log("------\n");
    }

    pub fn checkSize(self: &Parser, count: usize) -> %void {
        if (self.pos + count > self.buffer.len) {
            return error.ParseErrorUnexpectedEOF;
        }
    }

    fn checkAlignment(self: &Parser, align_to: usize) {
        if (self.pos % align_to != 0) {
            self.warn("expected 0x{x} to be aligned to {} bytes\n",
                self.pos, align_to);
        }
    }

    pub fn nextNBytes(self: &Parser, n: usize) -> %[]const u8 {
        %return self.checkSize(n);
        const p = self.pos;
        self.pos += n;
        self.buffer[p..p+n]
    }

    pub fn nextN(self: &Parser, comptime T: type, n: usize, name: []const u8) -> %View(T) {
        self.log("===read {} at 0x{x} ({}*{}) ", name, self.pos, @typeName(T), n);
        defer self.log("\n");

        const buffer =
            if (T == u8) {
                %return self.nextNBytes(n)
            } else if (T == u16) {
                self.checkAlignment(2);
                %return self.nextNBytes(2*n)
            } else if (T == u32) {
                self.checkAlignment(4);
                %return self.nextNBytes(4*n)
            } else {
                @compileError("unsupported type: " ++ @typeName(T));
            };

        const result = View(T) { .buffer = buffer };
        logView(self, T, &result);
        result
    }

    pub fn next(self: &Parser, comptime T: type, name: []const u8) -> %T {
        const view = %return self.nextN(T, 1, name);
        view.nth(0)
    }

    pub fn log(self: &Parser, comptime format: []const u8, args: ...) {
        if (!self.logging_on) { return; }
        var stderr = %%io.getStdErr();
        %%stderr.out_stream.print(format, args);
    }

    pub fn warn(self: &Parser, comptime format: []const u8, args: ...) {
        self.log(format, args);
    }
};

/// Non-owning view of a byte slice as a sequence of uints.
pub fn View(comptime T: type) -> type {
    struct {
        buffer: []const u8,

        pub fn len(self: &const View(T)) -> usize {
            const element_size =
                if (T == u8) { 1 }
                else if (T == u16) { 2 }
                else if (T == u32) { 4 }
                else { @compileError("unsupported type: " ++ @typeName(T)) };
            self.buffer.len / element_size
        }

        pub fn nth(self: &const View(T), n: usize) -> T {
            if (T == u8) {
                self.buffer[n]
            } else if (T == u16) {
                byteorder.readU16(self.buffer[2*n..2*n+2])
            } else if (T == u32) {
                byteorder.readU32(self.buffer[4*n..4*n+4])
            } else {
                @compileError("unsupported type: " ++ @typeName(T));
            }
        }
    }
}

fn logView(ctx: &Parser, comptime T: type, view: &const View(T)) {
    // Show at most 10 elements so we don't print huge binary blobs.
    const view_len = view.len();
    const num = if (view_len > 10) { 8 } else { view_len };
    ctx.log("[");
    { var i: usize = 0; while (i != num) : (i += 1) {
        ctx.log("{}", view.nth(i));
        if (i + 1 != view_len) { ctx.log(", "); }
    }}
    if (num < view_len) {
        ctx.log("...and {} more", view_len - num);
    }
    ctx.log("]");
}
