const std = @import("std");
const cli = @import("cli");
const zigimg = @import("zigimg");
const lib = @import("pptzig");

var config = struct {
    left: u32 = 0,
    right: u32 = 0,
    top: u32 = 0,
    bottom: u32 = 0,
    color: []const u8 = undefined,
    inputfile: []const u8 = undefined,
    outputfile: []const u8 = undefined,
}{};

const BorderParseError = error{
    Empty,
    TooManyArgs,
};

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
                    .long_name = "left",
                    .help = "",
                    .required = true,
                    .value_ref = r.mkRef(&config.left),
                },
                .{
                    .long_name = "right",
                    .help = "",
                    .required = true,
                    .value_ref = r.mkRef(&config.right),
                },
                .{
                    .long_name = "top",
                    .help = "",
                    .required = true,
                    .value_ref = r.mkRef(&config.top),
                },
                .{
                    .long_name = "bottom",
                    .help = "",
                    .required = true,
                    .value_ref = r.mkRef(&config.bottom),
                },
                .{
                    .long_name = "color",
                    .help = "color in hex.",
                    .required = true,
                    .value_ref = r.mkRef(&config.color),
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
    const color = try zigimg.color.Rgba32.from.htmlHex(config.color);
    const new_width = image.width + config.left + config.right;
    const new_hegiht = image.height + config.top + config.bottom;

    var output = try zigimg.Image.create(
        allocator,
        new_width,
        new_hegiht,
        zigimg.PixelFormat.rgba32,
    );
    defer output.deinit(allocator);
    const output_pixels = output.pixels.rgba32;
    @memset(output_pixels, color);

    for (0..height) |y| {
        const src_row_start = y * width;
        const src_row_end = src_row_start + width;

        const dst_row_start = (y + config.top) * new_width + config.left;
        const dst_row_end = dst_row_start + width;

        @memcpy(
            output_pixels[dst_row_start..dst_row_end],
            pixels[src_row_start..src_row_end],
        );
    }

    var write_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    try output.writeToFilePath(
        allocator,
        io,
        config.outputfile,
        write_buffer[0..],
        .{ .png = .{} },
    );
}
