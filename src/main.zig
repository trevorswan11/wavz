const std = @import("std");

const wav = @import("wav.zig");
const renderer = @import("renderer.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const filepath = "examples/thrust.wav";
    const data = try wav.parse(allocator, filepath);

    const ascii = renderer.RenderData{
        .samples = data.samples,
        .width = 25,
        .height = 30,
        .outfile = "zig-out/rendered/out.txt",
    };
    try renderer.renderASCII(ascii);

    const ppm = renderer.RenderData{
        .samples = data.samples,
        .width = 1024,
        .height = 256,
        .outfile = "zig-out/rendered/out.ppm",
        .allocator = allocator,
    };
    try renderer.renderPPM(ppm);
}
