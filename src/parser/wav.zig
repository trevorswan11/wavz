const std = @import("std");

pub const AudioData = struct {
    samples: []f32,
    sample_data: u32,
    channels: u16,
};

pub fn parse(allocator: std.mem.Allocator, path: []const u8) !AudioData {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const data = try file.readToEndAlloc(allocator, stat.size);
    if (!std.mem.eql([]u8, data[0..4], "RIFF")) {
        return error.ImproperFileFormat;
    }

    const extension = std.fs.path.extension(path);
}