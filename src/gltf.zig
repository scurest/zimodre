const std = @import("std");
const Buffer = std.Buffer;

const byteorder = @import("byteorder.zig");
const Json = @import("json.zig").Json;
const GlTF = @import("mod2gltf.zig").GlTF;
const AccessorFormat = @import("mod2gltf.zig").AccessorFormat;

pub fn write_glb(gltf: &const GlTF) -> %Buffer {
    var gltf_buf = %return write_gltf(gltf);
    defer gltf_buf.deinit();

    if (gltf_buf.len() % 4 != 0) {
        %%gltf_buf.appendByteNTimes(' ', 4 - gltf_buf.len() % 4);
    }

    const total_len =
        12 + // header
        8 + // JSON chunk header
        gltf_buf.len() + // JSON payload len
        8 + // BIN chunk header
        gltf.buffer.len(); // BIN payload len


    var glb = %%Buffer.initSize(&std.mem.c_allocator, 0);
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
    %%byteorder.write_u32(&glb, u32(gltf.buffer.len()));
    %%glb.append("BIN\x00");
    %%glb.append(gltf.buffer.toSliceConst());

    glb
}

fn write_gltf(gltf: &const GlTF) -> %Buffer {
    var b = %%Buffer.initSize(&std.mem.c_allocator, 0);
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
        j.val(gltf.buffer.len());
        j.end_obj();
    j.end_array();
    if (gltf.accessors.len != 0) {
        j.prop("bufferViews");
        j.begin_array();
        { var i:usize = 0; while (i != gltf.accessors.len) : (i += 1) {
            const a = &gltf.accessors.items[i];
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
        { var i:usize = 0; while (i != gltf.accessors.len) : (i += 1) {
            const a = &gltf.accessors.items[i];
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
    if (gltf.meshes.len != 0) {
        j.prop("meshes");
        j.begin_array();
        { var i:usize = 0; while (i != gltf.meshes.len) : (i += 1) {
            const m = &gltf.meshes.items[i];
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
        { var i:usize = 0; while (i != gltf.meshes.len) : (i += 1) {
            const m = &gltf.meshes.items[i];
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
                { var i:usize = 0; while (i != gltf.meshes.len) : (i += 1) {
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
