const Buffer = @import("std").Buffer;

const allocator = &@import("std").heap.c_allocator;

const byteorder = @import("byteorder.zig");
const Json = @import("json.zig").Json;
const Model = @import("mod2model.zig").Model;
const AccessorFormat = @import("mod2model.zig").AccessorFormat;

pub fn write_glb(model: &const Model) -> %Buffer {
    var gltf_buf = %return write_gltf(model);
    defer gltf_buf.deinit();

    if (gltf_buf.len() % 4 != 0) {
        %%gltf_buf.appendByteNTimes(' ', 4 - gltf_buf.len() % 4);
    }

    const total_len =
        12 + // header
        8 + // JSON chunk header
        gltf_buf.len() + // JSON payload len
        8 + // BIN chunk header
        model.buffer.len(); // BIN payload len


    var glb = %%Buffer.initSize(allocator, 0);
    %defer glb.deinit();

    // Header
    %%glb.append("glTF"); // magic
    %%byteorder.write_u32(&glb, 2) ; // version
    %%byteorder.write_u32(&glb, u32(total_len)); // total length

    // JSON chunk
    %%byteorder.write_u32(&glb, u32(gltf_buf.len()));
    %%glb.append("JSON");
    %%glb.append(gltf_buf.toSliceConst());

    // BIN chunk
    %%byteorder.write_u32(&glb, u32(model.buffer.len()));
    %%glb.append("BIN\x00");
    %%glb.append(model.buffer.toSliceConst());

    glb
}

fn write_gltf(model: &const Model) -> %Buffer {
    var b = %%Buffer.initSize(allocator, 0);
    %defer b.deinit();

    var j = Json.new(&b);
    j.begin_obj();
    j.prop("asset");
        j.begin_obj();
        j.prop("version");
        j.str("2.0");
        j.prop("generator");
        j.str("zimodre");
        j.end_obj();
    j.prop("buffers");
    j.begin_array();
        j.begin_obj();
        j.prop("byteLength");
        j.val(model.buffer.len());
        j.end_obj();
    j.end_array();
    if (model.accessors.len != 0) {
        j.prop("bufferViews");
        j.begin_array();
        { var i:usize = 0; while (i != model.accessors.len) : (i += 1) {
            const a = &model.accessors.items[i];
            j.begin_obj();
            j.prop("buffer");
            j.val(i32(0));
            j.prop("byteOffset");
            j.val(a.buffer_start);
            j.prop("byteLength");
            j.val(a.buffer_end - a.buffer_start);
            j.end_obj();
        }}
        j.end_array();
        j.prop("accessors");
        j.begin_array();
        { var i:usize = 0; while (i != model.accessors.len) : (i += 1) {
            const a = &model.accessors.items[i];
            j.begin_obj();
            j.prop("bufferView");
            j.val(i);
            j.prop("type");
            switch (a.format) {
                AccessorFormat.F32F32 => j.str("VEC2"),
                AccessorFormat.F32F32F32 => j.str("VEC3"),
                AccessorFormat.U16 => j.str("SCALAR"),
            }
            j.prop("componentType");
            switch (a.format) {
                AccessorFormat.F32F32 => j.val(i32(5126)),
                AccessorFormat.F32F32F32 => j.val(i32(5126)),
                AccessorFormat.U16 => j.val(i32(5123)),
            }
            if (a.min) |min| {
                j.prop("min");
                j.begin_array();
                j.val(min[0]);
                j.val(min[1]);
                j.val(min[2]);
                j.end_array();
            }
            if (a.max) |max| {
                j.prop("max");
                j.begin_array();
                j.val(max[0]);
                j.val(max[1]);
                j.val(max[2]);
                j.end_array();
            }
            j.prop("count");
            j.val(a.count);
            j.end_obj();
        }}
        j.end_array();
    }
    if (model.meshes.len != 0) {
        j.prop("meshes");
        j.begin_array();
        { var i: usize = 0; while (i != model.meshes.len) : (i += 1) {
            const m = &model.meshes.items[i];
            j.begin_obj();
            j.prop("primitives");
                j.begin_array();
                    j.begin_obj();
                    j.prop("attributes");
                        j.begin_obj();
                        j.prop("POSITION");
                        j.val(m.positions);
                        if (m.uvs) |uvs| {
                            j.prop("TEXCOORD_0");
                            j.val(uvs);
                        }
                        j.end_obj();
                    j.prop("indices");
                    j.val(m.indices);
                    j.prop("mode");
                    j.val(i32(5));
                    j.end_obj();
                j.end_array();
            j.end_obj();
        }}
        j.end_array();
        j.prop("nodes");
        j.begin_array();
        { var i: usize = 0; while (i != model.meshes.len) : (i += 1) {
            const m = &model.meshes.items[i];
            j.begin_obj();
            j.prop("mesh");
            j.val(i);
            j.end_obj();
        }}
        j.end_array();
        j.prop("scenes");
        j.begin_array();
            j.begin_obj();
            j.prop("nodes");
                j.begin_array();
                { var i: usize = 0; while (i != model.meshes.len) : (i += 1) {
                    j.val(i);
                }}
                j.end_array();
            j.end_obj();
        j.end_array();
        j.prop("scene");
        j.val(i32(0));
    }
    j.end_obj();

    b
}
