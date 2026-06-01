const std = @import("std");
const cli = @import("cli");
const zigimg = @import("zigimg");
const lib = @import("pptzig");

const SortBy = enum {
    hue,
    saturation,
    lightness,
    brightness,
    red,
    green,
    blue,
};

const Direction = enum {
    column,
    row,
    both,
};

const Mode = enum {
    light,
    dark,
};

var config = struct {
    inputfile: []const u8 = undefined,
    threshold: u8 = undefined,
    direction: Direction = undefined,
    sortby: SortBy = undefined,
    mode: Mode = undefined,
    outputfile: []const u8 = undefined,
}{};

var g_init: *std.process.Init = undefined;

pub fn main(init: std.process.Init) !void {
    g_init = @constCast(&init);

    var r = cli.AppRunner.init(&init);
    defer r.deinit();

    const app = cli.App{
        .command = cli.Command{
            .name = "run",
            .options = try r.allocOptions(&.{
                .{
                    .long_name = "inputfile",
                    .help = "Path to the input image file. Required. Supported formats: JPG, PNG, PPM.",
                    .required = true,
                    .value_ref = r.mkRef(&config.inputfile),
                },
                .{
                    .long_name = "threshold",
                    .help = "Pixel value threshold for detecting segments to sort. Range: 0–255. ",
                    .required = true,
                    .value_ref = r.mkRef(&config.threshold),
                },
                .{
                    .long_name = "direction",
                    .help = "Sorting direction. 1: Column-wise sorting, 2: Row-wise sorting, 3: Both (first sort columns, then rows)",
                    .required = true,
                    .value_ref = r.mkRef(&config.direction),
                },
                .{
                    .long_name = "sortby",
                    .help = "Color attribute to use for sorting. 1: Hue, 2: Saturation, 3: Lightness, 4: Brightness, 5: Red, 6: Green, 7: Blue",
                    .required = true,
                    .value_ref = r.mkRef(&config.sortby),
                },
                .{
                    .long_name = "mode",
                    .help = "Sorting mode. 1: Light — segments start/end at lighter colors, 2: Dark — segments start/end at darker colors",
                    .required = true,
                    .value_ref = r.mkRef(&config.mode),
                },
                .{
                    .long_name = "outputfile",
                    .help = "Path to save the output image.",
                    .required = true,
                    .value_ref = r.mkRef(&config.outputfile),
                },
            }),
            .target = cli.CommandTarget{
                .action = cli.CommandAction{ .exec = run },
            },
        },
    };
    return r.run(&app);
}

fn run() !void {
    const init = g_init;
    const allocator = init.gpa;
    const io = init.io;

    var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    var image = try zigimg.Image.fromFilePath(
        allocator,
        io,
        config.inputfile,
        read_buffer[0..],
    );
    defer image.deinit(allocator);

    try image.convert(allocator, .rgba32);

    const width = image.width;
    const height = image.height;

    const pixels = image.pixels.rgba32;

    try psort(
        allocator,
        pixels,
        width,
        height,
        config.threshold,
        config.direction,
        config.sortby,
        config.mode,
    );

    var write_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;

    try image.writeToFilePath(
        allocator,
        io,
        config.outputfile,
        write_buffer[0..],
        .{ .png = .{} },
    );
}

fn psort(
    allocator: std.mem.Allocator,
    pixels: []zigimg.color.Rgba32,
    width: usize,
    height: usize,
    threshold: u8,
    direction: Direction,
    sortby: SortBy,
    mode: Mode,
) !void {
    const scratch_len = @max(width, height);
    const scratch = try allocator.alloc(zigimg.color.Rgba32, scratch_len);
    defer allocator.free(scratch);

    switch (direction) {
        .column => {
            for (0..width) |x| {
                sortCols(pixels, width, height, x, scratch, threshold, sortby, mode);
            }
        },
        .row => {
            for (0..height) |y| {
                sortRows(pixels, width, height, y, scratch, threshold, sortby, mode);
            }
        },
        .both => {
            for (0..width) |x| {
                sortCols(pixels, width, height, x, scratch, threshold, sortby, mode);
            }
            for (0..height) |y| {
                sortRows(pixels, width, height, y, scratch, threshold, sortby, mode);
            }
        },
    }
}

fn pixelValue(p: zigimg.color.Rgba32, sortBy: SortBy) f32 {
    return switch (sortBy) {
        .hue => lib.hue(p),
        .saturation => lib.saturation(p),
        .lightness => lib.lightness(p),
        .brightness => lib.brightness(p),
        .red => @floatFromInt(p.r),
        .green => @floatFromInt(p.g),
        .blue => @floatFromInt(p.b),
    };
}

fn compareLowerByMode(mode: Mode, v: f32, threshold: f32) bool {
    return switch (mode) {
        .light => v > threshold,
        .dark => v < threshold,
    };
}

fn compareUpperByMode(mode: Mode, v: f32, threshold: f32) bool {
    return switch (mode) {
        .light => v < threshold,
        .dark => v > threshold,
    };
}

fn sortPixels(pixels: []zigimg.color.Rgba32, sortby: SortBy) void {
    if (pixels.len < 2) return;

    std.mem.sortUnstable(
        zigimg.color.Rgba32,
        pixels,
        sortby,
        pixelLessThan,
    );
}

fn pixelLessThan(sortby: SortBy, a: zigimg.color.Rgba32, b: zigimg.color.Rgba32) bool {
    return pixelValue(a, sortby) < pixelValue(b, sortby);
}

fn sortCols(
    pixels: []zigimg.color.Rgba32,
    width: usize,
    height: usize,
    x: usize,
    scratch: []zigimg.color.Rgba32,
    threshold: u8,
    sortby: SortBy,
    mode: Mode,
) void {
    var y: usize = 0;
    const t: f32 = @floatFromInt(threshold);

    while (y < height) {
        while (y < height) : (y += 1) {
            const p = pixels[lib.pixelIndex(width, x, y)];
            const v = pixelValue(p, sortby);

            if (compareLowerByMode(mode, v, t)) {
                break;
            }
        }
        const start_y = y;
        while (y < height) : (y += 1) {
            const p = pixels[lib.pixelIndex(width, x, y)];
            const v = pixelValue(p, sortby);

            if (compareUpperByMode(mode, v, t)) {
                break;
            }
        }
        const end_y = y;

        if (start_y < end_y) {
            const len = end_y - start_y;
            for (0..len) |i| {
                scratch[i] = pixels[lib.pixelIndex(width, x, start_y + i)];
            }
            sortPixels(scratch[0..len], sortby);
            for (0..len) |i| {
                pixels[lib.pixelIndex(width, x, start_y + i)] = scratch[i];
            }
        }

        if (y < height) {
            y += 1;
        }
    }
}

fn sortRows(
    pixels: []zigimg.color.Rgba32,
    width: usize,
    _: usize,
    y: usize,
    scratch: []zigimg.color.Rgba32,
    threshold: u8,
    sortby: SortBy,
    mode: Mode,
) void {
    var x: usize = 0;
    const t: f32 = @floatFromInt(threshold);

    while (x < width) {
        while (x < width) : (x += 1) {
            const p = pixels[lib.pixelIndex(width, x, y)];
            const v = pixelValue(p, sortby);

            if (compareLowerByMode(mode, v, t)) {
                break;
            }
        }
        const start_x = x;
        while (x < width) : (x += 1) {
            const p = pixels[lib.pixelIndex(width, x, y)];
            const v = pixelValue(p, sortby);

            if (compareUpperByMode(mode, v, t)) {
                break;
            }
        }
        const end_x = x;

        if (start_x < end_x) {
            const len = end_x - start_x;
            for (0..len) |i| {
                scratch[i] = pixels[lib.pixelIndex(width, start_x + i, y)];
            }
            sortPixels(scratch[0..len], sortby);
            for (0..len) |i| {
                pixels[lib.pixelIndex(width, start_x + i, y)] = scratch[i];
            }
        }

        if (x < width) {
            x += 1;
        }
    }
}
