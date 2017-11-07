//! Poor-man's JSON writer.

const std = @import("std");
const Buffer = std.Buffer;

fn bufFmtOutput(b: &Buffer, out: []const u8) -> %void {
    b.append(out)
}

fn bufFmt(b: &Buffer, comptime fmt: []const u8, args: ...) {
    _ = std.fmt.format(b, bufFmtOutput, fmt, args);
}

pub const Json = struct {
    buffer: &Buffer,
    needs_prefix_comma: bool,

    pub fn new(buffer: &Buffer) -> Json {
        Json {
            .buffer = buffer,
            .needs_prefix_comma = false,
        }
    }

    pub fn beginObj(self: &Json) {
        prefixComma(self);
        %%self.buffer.appendByte('{');
        self.needs_prefix_comma = false;
    }

    pub fn endObj(self: &Json) {
        %%self.buffer.appendByte('}');
        self.needs_prefix_comma = true;
    }

    pub fn beginArray(self: &Json) {
        prefixComma(self);
        %%self.buffer.appendByte('[');
        self.needs_prefix_comma = false;
    }

    pub fn endArray(self: &Json) {
        %%self.buffer.appendByte(']');
        self.needs_prefix_comma = true;
    }

    pub fn prop(self: &Json, s: []const u8) {
        prefixComma(self);
        printStr(self, s);
        %%self.buffer.appendByte(':');
        self.needs_prefix_comma = false;
    }

    pub fn val(self: &Json, x: var) {
        prefixComma(self);
        bufFmt(self.buffer, "{}", x);
        self.needs_prefix_comma = true;
    }

    pub fn str(self: &Json, s: []const u8) {
        prefixComma(self);
        printStr(self, s);
        self.needs_prefix_comma = true;
    }
};

fn printStr(j: &Json, s: []const u8) {
    %%j.buffer.appendByte('"');
    { var i: usize = 0; while (i != s.len) : (i += 1) {
        // Escape s[i]
        //TODO check for correctness
        switch (s[i]) {
            '"' => j.buffer.append("\\\""),
            '\\' => j.buffer.append("\\\\"),
            '\n' => j.buffer.append("\\n"),
            '\r' => j.buffer.append("\\r"),
            '\t' => j.buffer.append("\\t"),
            0...31 => bufFmt(j.buffer, "\\u{x4}", s[i]),
            else => j.buffer.appendByte(s[i]),
        }
    }}
    %%j.buffer.appendByte('"');
}

fn prefixComma(j: &Json) {
    if (j.needs_prefix_comma) {
        %%j.buffer.appendByte(',');
    }
}
