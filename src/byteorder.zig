//! Read/write litte-endian binary data

const builtin = @import("builtin");
const Buffer = @import("std").Buffer;

pub fn byteSwap16(x: u16) -> u16 { (x >> 8) | (x << 8) }
pub fn byteSwap32(x: u32) -> u32 {
    (x >> 24) | ((x & 0x00ff0000) >> 8) | ((x & 0x0000ff00) << 8) | (x << 24)
}

pub fn fromLe32(x: u32) -> u32 {
    if (builtin.is_big_endian) { byteSwap32(x) } else { x }
}
pub fn toLe32(x: u32) -> u32 {
    if (builtin.is_big_endian) { byteSwap32(x) } else { x }
}

//TODO use unaligned reads for the following?

pub fn readU8(b: []const u8) -> u8 { b[0] }
pub fn readU16(b: []const u8) -> u16 { u16(b[0]) | (u16(b[1]) << 8) }
pub fn readU32(b: []const u8) -> u32 {
    u32(b[0]) | (u32(b[1]) << 8) | (u32(b[2]) << 16) | (u32(b[3]) << 24)
}
pub fn readF32(b: []const u8) -> f32 {
    @bitCast(f32, fromLe32(readU32(b)))
}

pub fn writeU8(b: &Buffer, x: u8) -> %void {
    %return b.appendByte(x);
}
pub fn writeU16(b: &Buffer, x: u16) -> %void {
    %return b.appendByte(@truncate(u8, x));
    %return b.appendByte(@truncate(u8, x >> 8));
}
pub fn writeU32(b: &Buffer, x: u32) -> %void {
    %return b.appendByte(@truncate(u8, x));
    %return b.appendByte(@truncate(u8, x >> 8));
    %return b.appendByte(@truncate(u8, x >> 16));
    %return b.appendByte(@truncate(u8, x >> 24));
}
pub fn writeF32(b: &Buffer, x: f32) -> %void {
    writeU32(toLe32(@bitCast(u32, x)))
}
