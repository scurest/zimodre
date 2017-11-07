const Buffer = @import("std").Buffer;

const allocator = &@import("std").heap.c_allocator;

const byteorder = @import("byteorder.zig");
const Json = @import("json.zig").Json;
const Model = @import("mod2model.zig").Model;
const AccessorFormat = @import("mod2model.zig").AccessorFormat;

pub fn writeGlb(model: &const Model) -> %Buffer {
    var gltf_buf = %return writeGltf(model);
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
    %%byteorder.writeU32(&glb, 2) ; // version
    %%byteorder.writeU32(&glb, u32(total_len)); // total length

    // JSON chunk
    %%byteorder.writeU32(&glb, u32(gltf_buf.len()));
    %%glb.append("JSON");
    %%glb.append(gltf_buf.toSliceConst());

    // BIN chunk
    %%byteorder.writeU32(&glb, u32(model.buffer.len()));
    %%glb.append("BIN\x00");
    %%glb.append(model.buffer.toSliceConst());

    glb
}

fn writeGltf(model: &const Model) -> %Buffer {
    var b = %%Buffer.initSize(allocator, 0);
    %defer b.deinit();

    var j = Json.new(&b);
    j.beginObj();
    j.prop("asset");
        j.beginObj();
        j.prop("version");
        j.str("2.0");
        j.prop("generator");
        j.str("zimodre");
        j.endObj();
    j.prop("buffers");
    j.beginArray();
        j.beginObj();
        j.prop("byteLength");
        j.val(model.buffer.len());
        j.endObj();
    j.endArray();
    if (model.accessors.len != 0) {
        j.prop("bufferViews");
        j.beginArray();
        { var i:usize = 0; while (i != model.accessors.len) : (i += 1) {
            const a = &model.accessors.items[i];
            j.beginObj();
            j.prop("buffer");
            j.val(i32(0));
            j.prop("byteOffset");
            j.val(a.buffer_start);
            j.prop("byteLength");
            j.val(a.buffer_end - a.buffer_start);
            j.endObj();
        }}
        j.endArray();
        j.prop("accessors");
        j.beginArray();
        { var i:usize = 0; while (i != model.accessors.len) : (i += 1) {
            const a = &model.accessors.items[i];
            j.beginObj();
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
                j.beginArray();
                j.val(min[0]);
                j.val(min[1]);
                j.val(min[2]);
                j.endArray();
            }
            if (a.max) |max| {
                j.prop("max");
                j.beginArray();
                j.val(max[0]);
                j.val(max[1]);
                j.val(max[2]);
                j.endArray();
            }
            j.prop("count");
            j.val(a.count);
            j.endObj();
        }}
        j.endArray();
    }
    if (model.meshes.len != 0) {
        j.prop("meshes");
        j.beginArray();
        { var i: usize = 0; while (i != model.meshes.len) : (i += 1) {
            const m = &model.meshes.items[i];
            j.beginObj();
            j.prop("primitives");
                j.beginArray();
                    j.beginObj();
                    j.prop("attributes");
                        j.beginObj();
                        j.prop("POSITION");
                        j.val(m.positions);
                        if (m.uvs) |uvs| {
                            j.prop("TEXCOORD_0");
                            j.val(uvs);
                        }
                        j.endObj();
                    j.prop("indices");
                    j.val(m.indices);
                    j.prop("mode");
                    j.val(i32(5));
                    j.endObj();
                j.endArray();
            j.endObj();
        }}
        j.endArray();
        j.prop("nodes");
        j.beginArray();
        { var i: usize = 0; while (i != model.meshes.len) : (i += 1) {
            const m = &model.meshes.items[i];
            j.beginObj();
            j.prop("mesh");
            j.val(i);
            j.endObj();
        }}
        j.endArray();
        j.prop("scenes");
        j.beginArray();
            j.beginObj();
            j.prop("nodes");
                j.beginArray();
                { var i: usize = 0; while (i != model.meshes.len) : (i += 1) {
                    j.val(i);
                }}
                j.endArray();
            j.endObj();
        j.endArray();
        j.prop("scene");
        j.val(i32(0));
    }
    j.endObj();

    b
}
