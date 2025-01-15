const std = @import("std");

pub fn build(b: *std.Build) !void {
    const name = "playdate-proxy";

    const optimize = b.standardOptimizeOption(.{});

    const target = b.resolveTargetQuery(try std.Target.Query.parse(.{
        .arch_os_abi = "thumb-freestanding-eabihf",
        .cpu_features = "cortex_m7+vfp4d16sp",
    }));

    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
        .single_threaded = true,
    });
    exe.link_emit_relocs = true;
    exe.entry = .{ .symbol_name = "event_handler" };

    const sdk_path = try std.process.getEnvVarOwned(b.allocator, "PLAYDATE_SDK_PATH");
    const gcc_path = try std.process.getEnvVarOwned(b.allocator, "ARM_GCC_PATH");

    const c_api_path = b.pathJoin(&.{ sdk_path, "C_API" });
    const gcc_includes = b.pathJoin(&.{ gcc_path, "arm-none-eabi/include/" });

    exe.addIncludePath(std.Build.LazyPath{ .cwd_relative = c_api_path });
    exe.addIncludePath(std.Build.LazyPath{ .cwd_relative = gcc_includes });

    exe.setLinkerScript(b.path("./link_map.ld"));

    const write_files = b.addNamedWriteFiles("output source directory");
    _ = write_files.addCopyFile(exe.getEmittedBin(), "pdex.elf");
    _ = write_files.addCopyFile(b.path("pdxinfo"), "pdxinfo");
    _ = write_files.addCopyDirectory(b.path("assets"), "assets", .{ .exclude_extensions = &.{"keep"} });

    b.getInstallStep().dependOn(&write_files.step);

    const src_dir = write_files.getDirectory();

    const pdc = b.addSystemCommand(&.{b.pathJoin(&.{ sdk_path, "bin/pdc" })});
    pdc.setName("run pdc");
    pdc.addDirectoryArg(src_dir);
    const pdx_dir_name = name ++ ".pdx";
    const pdx = pdc.addOutputFileArg(pdx_dir_name);

    b.installDirectory(.{
        .source_dir = pdx,
        .install_dir = .{ .prefix = {} },
        .install_subdir = pdx_dir_name,
    });

    b.installDirectory(.{
        .source_dir = src_dir,
        .install_dir = .{ .prefix = {} },
        .install_subdir = "pdx_src",
    });
}
