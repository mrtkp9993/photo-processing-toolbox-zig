const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // deps
    const cli_dep = b.dependency("cli", .{});

    const shared_mod = b.addModule("photo_processing_toolbox_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const shared_lib = b.addLibrary(.{
        .name = "photo_processing_toolbox_zig",
        .linkage = .dynamic,
        .root_module = shared_mod,
    });
    b.installArtifact(shared_lib);

    const pixelsort = addTool(b, .{
        .name = "pixelsort",
        .source = "src/pixel-sort.zig",
        .target = target,
        .optimize = optimize,
        .shared_mod = shared_mod,
    });
    pixelsort.root_module.addImport("cli", cli_dep.module("cli"));

    addRunStep(b, "run-psort", "Run pixelsort", pixelsort);

    const test_step = b.step("test", "Run tests");
    addTestStep(b, test_step, shared_mod);
    addTestStep(b, test_step, pixelsort.root_module);
}

const ToolOptions = struct {
    name: []const u8,
    source: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    shared_mod: *std.Build.Module,
};

fn addTool(b: *std.Build, options: ToolOptions) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = options.name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(options.source),
            .target = options.target,
            .optimize = options.optimize,
            .imports = &.{
                .{
                    .name = "photo_processing_toolbox_zig",
                    .module = options.shared_mod,
                },
            },
        }),
    });

    b.installArtifact(exe);
    return exe;
}

fn addRunStep(
    b: *std.Build,
    name: []const u8,
    description: []const u8,
    exe: *std.Build.Step.Compile,
) void {
    const run_step = b.step(name, description);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    run_step.dependOn(&run_cmd.step);
}

fn addTestStep(
    b: *std.Build,
    test_step: *std.Build.Step,
    module: *std.Build.Module,
) void {
    const tests = b.addTest(.{
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);
}
