const std = @import("std");
const ArrayList = std.ArrayList;

const parser = @import("parser.zig");
const Parser = parser.Parser;

pub const Mod = struct {
    file: []const u8,
    vertex_offset: u32,
    index_offset: u32,
    mesh_info: ArrayList(MeshInfo),

    pub fn deinit(self: &Mod) {
        self.mesh_info.deinit();
    }
};

pub fn parse(ctx: &Parser) -> %Mod {
    ctx.begin("MOD Header");
    const magic = %return ctx.next_n(u8, 4, "magic"); // offset 0
    const unknown1 = %return ctx.next_n(u8, 2, "unknown1"); // 3
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
    const vertex_offset = %return ctx.next(u32, "vertex_offset"); // 56
    const index_offset = %return ctx.next(u32, "index_offset"); // 60
    ctx.end();


    var meshes = ArrayList(MeshInfo).init(&std.mem.c_allocator);
    %defer meshes.deinit();

    ctx.pos = item_offset;
    ctx.begin("Mesh Info List");
    { var i: usize = 0; while (i != mesh_count) : (i += 1) {
        const item = %return parse_mesh_info(ctx);
        %%meshes.append(&item);
    }}
    ctx.end();


    Mod {
        .file = ctx.buffer,
        .vertex_offset = vertex_offset,
        .index_offset = index_offset,
        .mesh_info = meshes,
    }
}

const MeshInfo = struct {
    vertex_count: u16,
    vertex_size: u8,
    vertex_type: u8,
    vertex_start: u32,
    index_pos: u32,
    index_count: u32,
};

fn parse_mesh_info(ctx: &Parser) -> %MeshInfo {
    ctx.begin("Mesh Info");
    const unknown1 = %return ctx.next(u16, "unknown1"); // offset 0
    const vertex_count = %return ctx.next(u16, "vertex_count"); // 2
    const unknown2 = %return ctx.next_n(u8, 6, "unknown2"); // 4
    const vertex_size = %return ctx.next(u8, "vertex_size"); // 10
    const vertex_type = %return ctx.next(u8, "vertex_type"); // 11
    const vertex_start = %return ctx.next(u32, "vertex_start"); // 12
    const unknown3 = %return ctx.next_n(u8, 8, "unknown3"); // 16
    const index_pos = %return ctx.next(u32, "index_pos"); // 24
    const index_count = %return ctx.next(u32, "index_count"); // 28
    const unknown4 = %return ctx.next_n(u8, 16, "unknown4"); // 32
    ctx.end();

    MeshInfo {
        .vertex_count = vertex_count,
        .vertex_size = vertex_size,
        .vertex_type = vertex_type,
        .vertex_start = vertex_start,
        .index_pos = index_pos,
        .index_count = index_count,
    }
}
