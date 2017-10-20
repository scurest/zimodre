const parser = @import("parser.zig");
const Parser = parser.Parser;

pub const Mod = struct {};

pub fn parse(ctx: &Parser) -> %Mod {
    ctx.begin("MOD Header");
    const magic = %return ctx.next_n(u8, 3, "magic"); // offset 0
    const unknown1 = %return ctx.next_n(u8, 3, "unknown1"); // 3
    const bone_count = %return ctx.next(u16, "bone_count"); // 6
    const mesh_count = %return ctx.next(u16, "mesh_count"); // 8
    const unknown2 = %return ctx.next_n(u8, 2, "unknown2"); // 10
    const vertex_count = %return ctx.next(u32, "vertex_count"); // 12
    const unknown3 = %return ctx.next_n(u8, 8, "unknown3"); // 16
    const vertex_size = %return ctx.next(u32, "vertex_size"); // 24
    const unknown4 = %return ctx.next_n(u8, 8, "unknown4"); // 28
    const used_bone_count = %return ctx.next(u32, "used_bone_count"); // 36
    const bone_offset = %return ctx.next(u32, "bone_offset"); // 40
    const mat_count2 = %return ctx.next(u16, "mat_count2"); // 44
    const unknown5 = %return ctx.next_n(u8, 2, "unknown5"); // 46
    const mat_offset = %return ctx.next(u32, "mat_offset"); // 48
    const item_offset = %return ctx.next(u32, "item_offset"); // 52
    const vert_offset = %return ctx.next(u32, "vert_offset"); // 56
    const face_offset = %return ctx.next(u32, "face_offset"); // 60
    ctx.end();

    Mod {}
}
