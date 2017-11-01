const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: &Builder) {
    var exe = b.addExecutable("zimodre", "src/main.zig");
    exe.setBuildMode(b.standardReleaseOptions());
    exe.linkSystemLibrary("c");
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
