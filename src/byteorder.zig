//! Read/write litte-endian binary data

const builtin = @import("builtin");
const Buffer = @import("std").Buffer;

pub fn byte_swap16(x: u16) -> u16 { (x >> 8) | (x << 8) }
pub fn byte_swap32(x: u32) -> u32 {
    (x >> 24) | ((x & 0x00ff0000) >> 8) | ((x & 0x0000ff00) << 8) | (x << 24)
}

pub fn from_le32(x: u32) -> u32 {
    if (builtin.is_big_endian) { byte_swap32(x) } else { x }
}
pub fn to_le32(x: u32) -> u32 {
    if (builtin.is_big_endian) { byte_swap32(x) } else { x }
}

//TODO use unaligned reads for the following?

pub fn read_u8(b: []const u8) -> u8 { b[0] }
pub fn read_u16(b: []const u8) -> u16 { u16(b[0]) | (u16(b[1]) << 8) }
pub fn read_u32(b: []const u8) -> u32 {
    u32(b[0]) | (u32(b[1]) << 8) | (u32(b[2]) << 16) | (u32(b[3]) << 24)
}
pub fn read_f32(b: []const u8) -> f32 {
    @bitCast(f32, from_le32(read_u32(b)))
}

pub fn write_u8(b: &Buffer, x: u8) -> %void {
    %return b.appendByte(x);
}
pub fn write_u16(b: &Buffer, x: u16) -> %void {
    %return b.appendByte(@truncate(u8, x));
    %return b.appendByte(@truncate(u8, x >> 8));
}
pub fn write_u32(b: &Buffer, x: u32) -> %void {
    %return b.appendByte(@truncate(u8, x));
    %return b.appendByte(@truncate(u8, x >> 8));
    %return b.appendByte(@truncate(u8, x >> 16));
    %return b.appendByte(@truncate(u8, x >> 24));
}
pub fn write_f32(b: &Buffer, x: f32) -> %void {
    write_u32(to_le32(@bitCast(u32, x)))
}
