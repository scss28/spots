const std = @import("std");
const fs = std.fs;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zgl = b.dependency("zgl", .{ .target = target, .optimize = optimize });
    const true_type = b.dependency("TrueType", .{ .target = target, .optimize = optimize });

    const lib_mod = b.addModule("spots", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gl", .module = zgl.module("zgl") },
            .{ .name = "TrueType", .module = true_type.module("TrueType") },
        },
    });

    const Example = enum {
        spinning_quad,
        terra,
        particles,
    };

    inline for (@typeInfo(Example).@"enum".fields) |field| {
        const example = @field(Example, field.name);
        const example_name = @tagName(example);

        const path = b.fmt("examples/{s}.zig", .{example_name});
        const zglfw = b.dependency("zglfw", .{ .target = target, .optimize = optimize });

        const example_mod = b.addModule(example_name, .{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "spots", .module = lib_mod },
                .{ .name = "glfw", .module = zglfw.module("glfw") },
            },
        });

        const example_exe = b.addExecutable(.{
            .name = example_name,
            .root_module = example_mod,
        });

        b.installArtifact(example_exe);

        const run_cmd = b.addRunArtifact(example_exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(b.fmt("run-{s}", .{example_name}), "Run the example");
        run_step.dependOn(&run_cmd.step);
    }
}
