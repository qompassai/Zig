const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zfetch_dep = b.dependency("zfetch", .{});
    const json_decode_dep = b.dependency("zig_json_decode", .{});

    const exe = b.addExecutable(.{
        .name = "metadata-updater",
        .root_source_file = .{ .path = "src/metadata.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("zfetch", zfetch_dep.module("zfetch"));
    exe.addModule("zig-json-decode", json_decode_dep.module("zig-json-decode"));
    
    b.installArtifact(exe);
    
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    const run_step = b.step("run", "Run the metadata updater");
    run_step.dependOn(&run_cmd.step);
}

