const zigimg = @import("zigimg");

pub const Rgba32 = zigimg.color.Rgba32;

pub fn brightness(p: Rgba32) f32 {
    const maxp = @max(p.r, @max(p.g, p.b));
    return @floatFromInt(maxp);
}

pub fn lightness(p: Rgba32) f32 {
    const maxp = @max(p.r, @max(p.g, p.b));
    const minp = @min(p.r, @min(p.g, p.b));

    return (@as(f32, @floatFromInt(maxp)) + @as(f32, @floatFromInt(minp))) / 2.0;
}

pub fn saturation(p: Rgba32) f32 {
    const maxp = @max(p.r, @max(p.g, p.b));
    const minp = @min(p.r, @min(p.g, p.b));

    if (maxp == minp) return 0.0;

    const maxf: f32 = @floatFromInt(maxp);
    const minf: f32 = @floatFromInt(minp);
    const denom = 255.0 - @abs(maxf + minf - 255.0);
    return ((maxf - minf) / denom) * 255.0;
}

pub fn hue(p: Rgba32) f32 {
    const maxp = @max(p.r, @max(p.g, p.b));
    const minp = @min(p.r, @min(p.g, p.b));

    if (maxp == minp) return 0.0;

    const red: f32 = @floatFromInt(p.r);
    const green: f32 = @floatFromInt(p.g);
    const blue: f32 = @floatFromInt(p.b);
    const maxf: f32 = @floatFromInt(maxp);
    const minf: f32 = @floatFromInt(minp);
    const delta = maxf - minf;

    var h: f32 = 0.0;
    if (maxp == p.r) {
        h = @mod((green - blue) / delta, 6.0);
    } else if (maxp == p.g) {
        h = ((blue - red) / delta) + 2.0;
    } else {
        h = ((red - green) / delta) + 4.0;
    }
    h *= 60.0;

    return h / 360.0 * 255.0;
}
