//! Poor-man's JSON writer.

const std = @import("std");
const Buffer = std.Buffer;

fn buf_fmt_output(b: &Buffer, out: []const u8) -> bool {
    b.append(out) %% return false;
    true
}

fn buf_fmt(b: &Buffer, comptime fmt: []const u8, args: ...) {
    _ = std.fmt.format(b, buf_fmt_output, fmt, args);
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

    pub fn begin_obj(self: &Json) {
        prefix_comma(self);
        %%self.buffer.appendByte('{');
        self.needs_prefix_comma = false;
    }

    pub fn end_obj(self: &Json) {
        %%self.buffer.appendByte('}');
        self.needs_prefix_comma = true;
    }

    pub fn begin_array(self: &Json) {
        prefix_comma(self);
        %%self.buffer.appendByte('[');
        self.needs_prefix_comma = false;
    }

    pub fn end_array(self: &Json) {
        %%self.buffer.appendByte(']');
        self.needs_prefix_comma = true;
    }

    pub fn prop(self: &Json, s: []const u8) {
        prefix_comma(self);
        print_str(self, s);
        %%self.buffer.appendByte(':');
        self.needs_prefix_comma = false;
    }

    pub fn val(self: &Json, x: var) {
        prefix_comma(self);
        buf_fmt(self.buffer, "{}", x);
        self.needs_prefix_comma = true;
    }

    pub fn str(self: &Json, s: []const u8) {
        prefix_comma(self);
        print_str(self, s);
        self.needs_prefix_comma = true;
    }
};

fn print_str(j: &Json, s: []const u8) {
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
            0...31 => buf_fmt(j.buffer, "\\u{x4}", s[i]),
            else => j.buffer.appendByte(s[i]),
        }
    }}
    %%j.buffer.appendByte('"');
}

fn prefix_comma(j: &Json) {
    if (j.needs_prefix_comma) {
        %%j.buffer.appendByte(',');
    }
}
