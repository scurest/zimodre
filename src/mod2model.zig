const mem = @import("std").mem;
const ArrayList = @import("std").ArrayList;
const Buffer = @import("std").Buffer;

const mod = @import("mod.zig");
const Mod = mod.Mod;
const byteorder = @import("byteorder.zig");

error ValidateNotEnoughVertexData;
error ValidateNotEnoughIndexData;
error UnsupportedVertexSize;

/// Intermediate model representation that's very close to a glTF file.
/// Should be really easy to emit a GLB once you have this.
pub const Model = struct {
    /// The GLB buffer holding glTF binary data.
    /// Must always be padded to a multiple of 4 bytes.
    buffer: Buffer,
    accessors: ArrayList(Accessor),
    meshes: ArrayList(Mesh),

    pub fn init() -> Model {
        Model {
            .buffer = %%Buffer.initSize(&mem.c_allocator, 0),
            .accessors = ArrayList.init(&mem.c_allocator),
            .meshes = ArrayList.init(&mem.c_allocator),
        }
    }

    pub fn deinit(self: &Model) {
        self.buffer.deinit();
        self.accessors.deinit();
        self.meshes.deinit();
    }
};

pub const AccessorFormat = enum {
    F32F32,
    F32F32F32,
    U16,
};

pub const Accessor = struct {
    buffer_start: usize,
    buffer_end: usize,
    count: u32,
    format: AccessorFormat,
    /// Only for position; minimum of each coordinate
    /// (required by glTF).
    min: ?[3]f32,
    /// Only for position; maximum of each coordinate.
    max: ?[3]f32,
};

pub const Mesh = struct {
    positions: usize,
    uvs: ?usize,
    indices: usize,
};

pub fn convert(m: &const Mod) ->%Model {
    var model = Model {
        .buffer = %%Buffer.initSize(&mem.c_allocator, 0),
        .accessors = ArrayList(Accessor).init(&mem.c_allocator),
        .meshes = ArrayList(Mesh).init(&mem.c_allocator),
    };
    %defer model.deinit();

    { var i: usize = 0; while (i != m.mesh_info.len) : (i += 1) {
        %return convert_mesh(&model, m, i);
    }}

    model
}

fn convert_mesh(model: &Model, m: &const Mod, id: usize) -> %void {
    const mi = &m.mesh_info.items[id];

    const v_start = m.vertex_offset + mi.vertex_size * u32(mi.vertex_start);
    const v_end = v_start + mi.vertex_size * u32(mi.vertex_count);
    if (v_end > m.file.len) {
        return error.ValidateNotEnoughVertexData;
    }
    const data = m.file[v_start..v_end];

    const sz = mi.vertex_size;
    if (sz != 24 and sz != 28 and sz != 32 and sz != 36) {
        return error.UnsupportedVertexSize;
    }

    // Vertex format is
    //
    // - x: f32,
    // - y: f32,
    // - z: f32,
    // - ?: [4]u8,
    // - u: f32,
    // - v: f32,
    // - bone1: u8, // below here only if sz >= 28
    // - bone2: u8,
    // - weight1: u8 normalized,
    // - weight2: u8 normalized,
    // - ?: [4]u8, // below here only if sz >= 32
    // - bone3: u8, // below here only if sx >= 36
    // - bone4: u8,
    // - weight3: u8 normalized,
    // - weight4: u8 normalized,

    //TODO we know all the sizes in advance; resize at the beginning
    // and make one pass copying the data over.
    const positions_start = model.buffer.len();
    var min: ?[3]f32 = null;
    var max: ?[3]f32 = null;
    { var i: usize = 0; while (i != mi.vertex_count) : (i += 1) {
        const attrib = data[sz*i..sz*(i+1)];
        const xyz = attrib[0..12];
        %%model.buffer.append(xyz);

        // Find min/max
        const x = byteorder.read_f32(xyz[0..4]);
        const y = byteorder.read_f32(xyz[4..8]);
        const z = byteorder.read_f32(xyz[8..12]);
        if (min) |*v| {
            if (x < (*v)[0]) { (*v)[0] = x; }
            else if (y < (*v)[1]) { (*v)[1] = y; }
            else if (z < (*v)[2]) { (*v)[2] = z; }
        } else {
            min = []f32 {x, y, z};
        }
        if (max) |*v| {
            if (x > (*v)[0]) { (*v)[0] = x; }
            else if (y > (*v)[1]) { (*v)[1] = y; }
            else if (z > (*v)[2]) { (*v)[2] = z; }
        } else {
            max = []f32 {x, y, z};
        }
    }}
    const positions_end = model.buffer.len();

    const uvs_start = model.buffer.len();
    { var i: usize = 0; while (i != mi.vertex_count) : (i += 1) {
        const attrib = data[sz*i..sz*(i+1)];
        const uv = attrib[16..24];
        %%model.buffer.append(uv);
    }}
    const uvs_end = model.buffer.len();

    //TODO handle joints and weights

    const position_accessor_id = model.accessors.len;
    %%model.accessors.append(Accessor {
        .buffer_start = positions_start,
        .buffer_end = positions_end,
        .count = mi.vertex_count,
        .format = AccessorFormat.F32F32F32,
        .min = min,
        .max = max,
    });
    const uv_accessor_id = model.accessors.len;
    %%model.accessors.append(Accessor {
        .buffer_start = uvs_start,
        .buffer_end = uvs_end,
        .count = mi.vertex_count,
        .format = AccessorFormat.F32F32,
        .min = null,
        .max = null,
    });

    const f_start = m.index_offset + 2 * mi.index_pos;
    const f_end = f_start + 2 * mi.index_count;
    if (f_end > m.file.len) {
        return error.ValidateNotEnoughIndexData;
    }
    const index_data = m.file[f_start..f_end];
    const indices_start = model.buffer.len();
    { var i: usize = 0; while (i != mi.index_count) : (i += 1) {
        const index =
            byteorder.read_u16(index_data[2*i..2*i+2]) - u16(mi.vertex_start);
        %%byteorder.write_u16(&model.buffer, index);
    }}
    const indices_end = model.buffer.len();

    // Since shorts are 2 bytes, we might not be aligned to 4 anymore.
    if (model.buffer.len() % 4 != 0) {
        %%model.buffer.appendByteNTimes(0, 4 - model.buffer.len() % 4);
    }

    const index_accessor_id = model.accessors.len;
    %%model.accessors.append(Accessor {
        .buffer_start = indices_start,
        .buffer_end = indices_end,
        .count = mi.index_count,
        .format = AccessorFormat.U16,
        .min = null,
        .max = null,
    });

    %%model.meshes.append(Mesh {
        .positions = position_accessor_id,
        .uvs = uv_accessor_id,
        .indices = index_accessor_id,
    });
}
