const std = @import("std");
const color = @import("../../color.zig");

const Allocator = std.mem.Allocator;

const CanvasBitmap = @This();

pub const max_width = 8192;
pub const max_height = 8192;
pub const max_bytes = 64 * 1024 * 1024;

data: ?[]u8 = null,
version: u64 = 0,

pub fn reset(self: *CanvasBitmap) void {
    self.data = null;
    self.version += 1;
}

pub fn ensure(self: *CanvasBitmap, allocator: Allocator, width: u32, height: u32) ![]u8 {
    const len = try byteLen(width, height);
    if (self.data) |buf| {
        if (buf.len == len) return buf;
    }
    const buf = try allocator.alloc(u8, len);
    @memset(buf, 0);
    self.data = buf;
    self.version += 1;
    return buf;
}

pub fn snapshot(self: *CanvasBitmap, allocator: Allocator, width: u32, height: u32) ![]const u8 {
    const len = try byteLen(width, height);
    if (self.data) |buf| return buf[0..len];
    const blank = try allocator.alloc(u8, len);
    @memset(blank, 0);
    return blank;
}

pub fn fillRect(self: *CanvasBitmap, allocator: Allocator, width: u32, height: u32, x: f64, y: f64, w: f64, h: f64, rgba: color.RGBA) !void {
    if (w == 0 or h == 0 or width == 0 or height == 0) return;
    const rect = clipRect(width, height, x, y, w, h) orelse return;
    const buf = try self.ensure(allocator, width, height);
    var yy = rect.y0;
    while (yy < rect.y1) : (yy += 1) {
        var xx = rect.x0;
        while (xx < rect.x1) : (xx += 1) {
            const off = (@as(usize, yy) * width + xx) * 4;
            buf[off + 0] = rgba.r;
            buf[off + 1] = rgba.g;
            buf[off + 2] = rgba.b;
            buf[off + 3] = rgba.a;
        }
    }
    self.version += 1;
}

pub fn clearRect(self: *CanvasBitmap, allocator: Allocator, width: u32, height: u32, x: f64, y: f64, w: f64, h: f64) !void {
    if (w == 0 or h == 0 or width == 0 or height == 0) return;
    const rect = clipRect(width, height, x, y, w, h) orelse return;
    const buf = try self.ensure(allocator, width, height);
    var yy = rect.y0;
    while (yy < rect.y1) : (yy += 1) {
        var xx = rect.x0;
        while (xx < rect.x1) : (xx += 1) {
            const off = (@as(usize, yy) * width + xx) * 4;
            @memset(buf[off..][0..4], 0);
        }
    }
    self.version += 1;
}

pub fn getImageData(self: *CanvasBitmap, allocator: Allocator, width: u32, height: u32, sx: i32, sy: i32, sw: u32, sh: u32) ![]u8 {
    const out = try allocator.alloc(u8, try byteLen(sw, sh));
    @memset(out, 0);
    if (self.data == null or width == 0 or height == 0) return out;
    const buf = self.data.?;
    var yy: u32 = 0;
    while (yy < sh) : (yy += 1) {
        const src_y = sy + @as(i32, @intCast(yy));
        if (src_y < 0 or src_y >= height) continue;
        var xx: u32 = 0;
        while (xx < sw) : (xx += 1) {
            const src_x = sx + @as(i32, @intCast(xx));
            if (src_x < 0 or src_x >= width) continue;
            const src_off = (@as(usize, @intCast(src_y)) * width + @as(usize, @intCast(src_x))) * 4;
            const dst_off = (@as(usize, yy) * sw + xx) * 4;
            @memcpy(out[dst_off..][0..4], buf[src_off..][0..4]);
        }
    }
    return out;
}

pub fn putImageData(self: *CanvasBitmap, allocator: Allocator, width: u32, height: u32, bytes: []const u8, image_width: u32, image_height: u32, dx: i32, dy: i32) !void {
    if (width == 0 or height == 0) return;
    const buf = try self.ensure(allocator, width, height);
    var yy: u32 = 0;
    while (yy < image_height) : (yy += 1) {
        const dst_y = dy + @as(i32, @intCast(yy));
        if (dst_y < 0 or dst_y >= height) continue;
        var xx: u32 = 0;
        while (xx < image_width) : (xx += 1) {
            const dst_x = dx + @as(i32, @intCast(xx));
            if (dst_x < 0 or dst_x >= width) continue;
            const src_off = (@as(usize, yy) * image_width + xx) * 4;
            if (src_off + 4 > bytes.len) return;
            const dst_off = (@as(usize, @intCast(dst_y)) * width + @as(usize, @intCast(dst_x))) * 4;
            @memcpy(buf[dst_off..][0..4], bytes[src_off..][0..4]);
        }
    }
    self.version += 1;
}

pub fn drawImage(self: *CanvasBitmap, allocator: Allocator, dst_width: u32, dst_height: u32, src: *CanvasBitmap, src_width: u32, src_height: u32, dx: i32, dy: i32) !void {
    if (dst_width == 0 or dst_height == 0 or src_width == 0 or src_height == 0) return;
    const src_buf = src.data orelse return;
    const dst_buf = try self.ensure(allocator, dst_width, dst_height);
    var yy: u32 = 0;
    while (yy < src_height) : (yy += 1) {
        const dst_y = dy + @as(i32, @intCast(yy));
        if (dst_y < 0 or dst_y >= dst_height) continue;
        var xx: u32 = 0;
        while (xx < src_width) : (xx += 1) {
            const dst_x = dx + @as(i32, @intCast(xx));
            if (dst_x < 0 or dst_x >= dst_width) continue;
            const src_off = (@as(usize, yy) * src_width + xx) * 4;
            const dst_off = (@as(usize, @intCast(dst_y)) * dst_width + @as(usize, @intCast(dst_x))) * 4;
            @memcpy(dst_buf[dst_off..][0..4], src_buf[src_off..][0..4]);
        }
    }
    self.version += 1;
}

pub fn encodePng(self: *CanvasBitmap, allocator: Allocator, width: u32, height: u32) ![]const u8 {
    const pixels = try self.snapshot(allocator, width, height);
    var raw: std.Io.Writer.Allocating = .init(allocator);
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        try raw.writer.writeByte(0);
        const start = @as(usize, y) * width * 4;
        try raw.writer.writeAll(pixels[start..][0 .. @as(usize, width) * 4]);
    }

    const zlib = try zlibStore(allocator, raw.written());
    var png: std.Io.Writer.Allocating = .init(allocator);
    try png.writer.writeAll("\x89PNG\r\n\x1a\n");

    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], width, .big);
    std.mem.writeInt(u32, ihdr[4..8], height, .big);
    ihdr[8] = 8; // bit depth
    ihdr[9] = 6; // RGBA
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;
    try writeChunk(&png.writer, "IHDR", &ihdr);
    try writeChunk(&png.writer, "IDAT", zlib);
    try writeChunk(&png.writer, "IEND", "");
    return png.written();
}

fn byteLen(width: u32, height: u32) !usize {
    if (width > max_width or height > max_height) return error.IndexSizeError;
    var len, var overflow = @mulWithOverflow(width, height);
    if (overflow == 1) return error.IndexSizeError;
    len, overflow = @mulWithOverflow(len, 4);
    if (overflow == 1 or len > max_bytes) return error.IndexSizeError;
    return len;
}

const Rect = struct { x0: u32, y0: u32, x1: u32, y1: u32 };

fn clipRect(width: u32, height: u32, x: f64, y: f64, w: f64, h: f64) ?Rect {
    if (!std.math.isFinite(x) or !std.math.isFinite(y) or !std.math.isFinite(w) or !std.math.isFinite(h)) return null;
    const x2 = x + w;
    const y2 = y + h;
    const min_x = @max(0, @min(x, x2));
    const max_x = @min(@as(f64, @floatFromInt(width)), @max(x, x2));
    const min_y = @max(0, @min(y, y2));
    const max_y = @min(@as(f64, @floatFromInt(height)), @max(y, y2));
    if (max_x <= min_x or max_y <= min_y) return null;
    return .{
        .x0 = @intFromFloat(@floor(min_x)),
        .y0 = @intFromFloat(@floor(min_y)),
        .x1 = @intFromFloat(@ceil(max_x)),
        .y1 = @intFromFloat(@ceil(max_y)),
    };
}

fn writeChunk(writer: *std.Io.Writer, chunk_type: *const [4]u8, data: []const u8) !void {
    try writer.writeInt(u32, @intCast(data.len), .big);
    try writer.writeAll(chunk_type);
    try writer.writeAll(data);
    var crc = std.hash.Crc32.init();
    crc.update(chunk_type);
    crc.update(data);
    try writer.writeInt(u32, crc.final(), .big);
}

fn zlibStore(allocator: Allocator, data: []const u8) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    try out.writer.writeAll(&.{ 0x78, 0x01 });
    var pos: usize = 0;
    while (pos < data.len) {
        const remaining = data.len - pos;
        const block_len: u16 = @intCast(@min(remaining, 65535));
        const final: u8 = if (pos + block_len >= data.len) 1 else 0;
        try out.writer.writeByte(final);
        try out.writer.writeInt(u16, block_len, .little);
        try out.writer.writeInt(u16, ~block_len, .little);
        try out.writer.writeAll(data[pos..][0..block_len]);
        pos += block_len;
    }
    try out.writer.writeInt(u32, adler32(data), .big);
    return out.written();
}

fn adler32(data: []const u8) u32 {
    var a: u32 = 1;
    var b: u32 = 0;
    for (data) |byte| {
        a = (a + byte) % 65521;
        b = (b + a) % 65521;
    }
    return (b << 16) | a;
}
