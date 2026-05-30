const std = @import("std");
const cli = @import("cli");

const SortBy = enum(u8) {
    hue = '1',
    saturation = '2',
    lightness = '3',
    brightness = '4',
    red = '5',
    green = '6',
    blue = '7',

    pub fn fromChar(ch: u8) SortBy {
        return switch (ch) {
            '1' => .hue,
            '2' => .saturation,
            '3' => .lightness,
            '4' => .brightness,
            '5' => .red,
            '6' => .green,
            '7' => .blue,
            else => error.InvalidSortBy,
        };
    }
};

const Direction = enum(u8) {
    column = '1',
    row = '2',
    both = '3',

    pub fn fromChar(ch: u8) Direction {
        return switch (ch) {
            '1' => .column,
            '2' => .row,
            '3' => .both,
            else => error.InvalidDirection,
        };
    }
};

const Mode = enum(u8) {
    light = '1',
    dark = '2',

    pub fn fromChar(ch: u8) Mode {
        return switch (ch) {
            '1' => .light,
            '2' => .dark,
            else => error.InvalidMode,
        };
    }
};

var config = struct {
    input_file: []const u8 = undefined,
    threshold: u8 = undefined,
    direction: Direction = undefined,
    sortby: SortBy = undefined,
    mode: Mode = undefined,
    output_file: []const u8 = undefined,
}{};

pub fn main(init: std.process.Init) !void {
    var r = cli.AppRunner.init(&init);
    defer r.deinit();

    const app = cli.App{
        .command = cli.Command{
            .name = "run",
            .options = try r.allocOptions(&.{
                .{
                    .long_name = "input file",
                    .help = "Path to the input image file. Required. Supported formats: JPG, PNG, PPM.",
                    .required = true,
                    .value_ref = r.mkRef(&config.input_file),
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
                    .long_name = "sort by",
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
                    .long_name = "output file",
                    .help = "Path to save the output image.",
                    .required = true,
                    .value_ref = r.mkRef(&config.mode),
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
    std.log.info("config {}", .{});
}
