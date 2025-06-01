const std = @import("std");

pub const RenderData = struct {
    samples: []const f32,
    width: usize,
    height: usize,
    outfile: []const u8,
    allocator: ?std.mem.Allocator = null,
};

pub fn renderASCII(data: RenderData) !void {
    const samples = data.samples;
    const width = data.width;
    const height = data.height;

    if (std.fs.path.dirname(data.outfile)) |directory| {
        try std.fs.cwd().makePath(directory);
    }

    const file = try std.fs.cwd().createFile(data.outfile, .{});
    const writer = file.writer();
    defer file.close();

    const step = @divFloor(samples.len, width);
    for (0..width) |x| {
        var sum: f32 = 0;
        for (0..step) |i| {
            sum += @abs(samples[x * step + i]);
        }
        const avg = sum / @as(f32, @floatFromInt(step));

        const bar_height: usize = @intFromFloat(avg * @as(f32, @floatFromInt(height)));
        for (0..height) |y| {
            if (y < height - bar_height) {
                _ = try writer.write(" ");
            } else {
                _ = try writer.write("|");
            }
        }
        _ = try writer.write("\n");
    }
}

pub fn renderPPM(data: RenderData) !void {
    const samples = data.samples;
    const width = data.width;
    const height = data.height;

    if (std.fs.path.dirname(data.outfile)) |directory| {
        try std.fs.cwd().makePath(directory);
    }

    const file = try std.fs.cwd().createFile(data.outfile, .{});
    const writer = file.writer();
    defer file.close();

    var pixels: []u8 = undefined;
    if (data.allocator) |allocator| {
        pixels = try allocator.alloc(u8, width * height * 3);
    } else {
        return error.MissingAllocator;
    }

    @memset(pixels, 0);
    for (0..width) |x| {
        const start: usize = @divFloor(x * samples.len, width);
        const end: usize = @divFloor((x + 1) * samples.len, width);

        var sum: f32 = 0;
        for (start..end) |i| {
            sum += samples[i];
        }
        const avg = sum / @as(f32, @floatFromInt(end - start));

        // Scale sample [-1, 1] to image height
        const mid: usize = @divFloor(height, 2);
        const sample_offset = avg * @as(f32, @floatFromInt(mid));
        const y: usize = @intCast(@max(0, @min(@as(i32, @intCast(height - 1)), @as(i32, (@intFromFloat(@as(f32, @floatFromInt(mid)) - sample_offset))))));

        if (y < height) {
            const idx = (y * width + x) * 3;
            pixels[idx + 0] = 255; // R
            pixels[idx + 1] = 255; // G
            pixels[idx + 2] = 255; // B
        }
    }

    try writer.print("P6\n{} {}\n255\n", .{ width, height });
    try writer.writeAll(pixels);
}
