const std = @import("std");

pub const AudioData = struct {
    samples: []f32,
    sample_rate: u32,
    channels: u16,
};

pub const FmtChunk = struct {
    audio_format: u16,
    num_channels: u16,
    sample_rate: u32,
    bits_per_sample: u16,
};

pub const DataChunk = struct {
    raw_samples: []const u8,
    sample_count: usize,
};

const RIFF_HEADER = 12;

pub fn parse(allocator: std.mem.Allocator, path: []const u8) !AudioData {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const data = try file.readToEndAlloc(allocator, stat.size);
    if (!std.mem.eql(u8, data[0..4], "RIFF")) {
        return error.ImproperFileFormat;
    }

    const fmt = try extractFmt(data);
    if (fmt.audio_format != 1) {
        return error.MalformedPCM;
    } else if (fmt.bits_per_sample != 16) {
        return error.MalformedSample;
    }

    const sample_bytes = try extractData(data, fmt);
    var samples = std.ArrayList(f32).init(allocator);
    var i: usize = 0;
    while (i + 1 < sample_bytes.raw_samples.len) : (i += 2) {
        const lo = sample_bytes.raw_samples[i];
        const hi = sample_bytes.raw_samples[i + 1];

        const sample = @as(i16, @intCast(lo)) | (@as(i16, @intCast(hi)) << 8);
        const normalized = @as(f32, @floatFromInt(sample)) / 32768.0;
        try samples.append(normalized);
    }

    return AudioData{
        .samples = try samples.toOwnedSlice(),
        .channels = fmt.num_channels,
        .sample_rate = fmt.sample_rate,
    };
}

fn extractFmt(data: []const u8) !FmtChunk {
    var i: usize = RIFF_HEADER;
    while (i + 8 <= data.len) {
        const chunk_id = data[i .. i + 4];
        const chunk_size = readLE32(data[i + 4 .. i + 8]);
        const chunk_start = i + 8;
        const chunk_end = chunk_start + chunk_size;

        if (chunk_end > data.len) {
            return error.MalformedWav;
        }

        if (std.mem.eql(u8, chunk_id, "fmt ")) {
            const buf = data[chunk_start..chunk_end];
            if (buf.len < 16) {
                return error.MalformedFmtChunk;
            }

            return FmtChunk{
                .audio_format = readLE16(buf[0..2]),
                .num_channels = readLE16(buf[2..4]),
                .sample_rate = readLE32(buf[4..8]),
                .bits_per_sample = readLE16(buf[14..16]),
            };
        }

        // Increase i and check if chunks are word aligned
        i = chunk_end;
        if (chunk_size % 2 != 0) {
            i += 1;
        }
    }

    return error.FmtChunkNotFound;
}

fn extractData(data: []const u8, fmt: FmtChunk) !DataChunk {
    var i: usize = RIFF_HEADER;

    while (i + 8 <= data.len) {
        const chunk_id = data[i .. i + 4];
        const chunk_size = readLE32(data[i + 4 .. i + 8]);
        const chunk_start = i + 8;
        const chunk_end = chunk_start + chunk_size;

        if (chunk_end > data.len) {
            return error.MalformedWav;
        }

        if (std.mem.eql(u8, chunk_id, "data")) {
            const raw = data[chunk_start..chunk_end];
            const bps = @divFloor(fmt.bits_per_sample, 8);
            const total_samples = @divFloor(raw.len, bps);

            return DataChunk{
                .raw_samples = raw,
                .sample_count = total_samples,
            };
        }

        i = chunk_end;
        if (chunk_size % 2 != 0) {
            i += 1;
        }
    }

    return error.DataChunkNotFound;
}

fn readLE16(bytes: []const u8) u16 {
    return @as(u16, bytes[0]) | (@as(u16, bytes[1]) << 8);
}

fn readLE32(bytes: []const u8) u32 {
    return @as(u32, bytes[0]) |
        (@as(u32, bytes[1]) << 8) |
        (@as(u32, bytes[2]) << 16) |
        (@as(u32, bytes[3]) << 24);
}
