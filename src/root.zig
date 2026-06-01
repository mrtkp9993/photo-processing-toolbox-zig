pub const color_funcs = @import("color_funcs.zig");

pub const Rgba32 = color_funcs.Rgba32;

pub const brightness = color_funcs.brightness;
pub const lightness = color_funcs.lightness;
pub const saturation = color_funcs.saturation;
pub const hue = color_funcs.hue;

pub const pixels = @import("pixels.zig");

pub const pixelIndex = pixels.pixelIndex;
