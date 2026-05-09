// Copyright (C) 2023-2025  Lightpanda (Selecy SAS)
//
// Francis Bouvier <francis@lightpanda.io>
// Pierre Tachoire <pierre@lightpanda.io>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");

const js = @import("../../js/js.zig");

const color = @import("../../color.zig");
const Frame = @import("../../Frame.zig");

const Canvas = @import("../element/html/Canvas.zig");
const OffscreenCanvas = @import("OffscreenCanvas.zig");
const ImageData = @import("../ImageData.zig");

/// This class doesn't implement a `constructor`.
/// It can be obtained with a call to `HTMLCanvasElement#getContext`.
/// https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D
pub fn registerTypes() []const type {
    return &.{ CanvasRenderingContext2D, TextMetrics };
}

const CanvasRenderingContext2D = @This();
/// Reference to the parent canvas element.
/// https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/canvas
_canvas: *Canvas,
/// Fill color.
/// TODO: Add support for `CanvasGradient` and `CanvasPattern`.
_fill_style: color.RGBA = color.RGBA.Named.black,

pub fn getCanvas(self: *const CanvasRenderingContext2D) *Canvas {
    return self._canvas;
}

pub fn getFillStyle(self: *const CanvasRenderingContext2D, frame: *Frame) ![]const u8 {
    var w = std.Io.Writer.Allocating.init(frame.call_arena);
    try self._fill_style.format(&w.writer);
    return w.written();
}

pub fn setFillStyle(
    self: *CanvasRenderingContext2D,
    value: []const u8,
) !void {
    // Prefer the same fill_style if fails.
    self._fill_style = color.RGBA.parse(value) catch self._fill_style;
}

const WidthOrImageData = union(enum) {
    width: u32,
    image_data: *ImageData,
};

pub fn createImageData(
    _: *const CanvasRenderingContext2D,
    width_or_image_data: WidthOrImageData,
    /// If `ImageData` variant preferred, this is null.
    maybe_height: ?u32,
    /// Can be used if width and height provided.
    maybe_settings: ?ImageData.ConstructorSettings,
    frame: *Frame,
) !*ImageData {
    switch (width_or_image_data) {
        .width => |width| {
            const height = maybe_height orelse return error.TypeError;
            return ImageData.init(width, height, maybe_settings, frame);
        },
        .image_data => |image_data| {
            return ImageData.init(image_data._width, image_data._height, null, frame);
        },
    }
}

pub fn putImageData(self: *CanvasRenderingContext2D, image_data: *ImageData, dx: f64, dy: f64, _: ?f64, _: ?f64, _: ?f64, _: ?f64, frame: *Frame) !void {
    try self._canvas._bitmap.putImageData(
        frame.arena,
        self._canvas.getWidth(),
        self._canvas.getHeight(),
        image_data.bytes(frame.js.local.?),
        image_data._width,
        image_data._height,
        @intFromFloat(@round(dx)),
        @intFromFloat(@round(dy)),
    );
}

pub fn getImageData(
    self: *CanvasRenderingContext2D,
    sx: i32,
    sy: i32,
    sw: i32,
    sh: i32,
    frame: *Frame,
) !*ImageData {
    if (sw <= 0 or sh <= 0) {
        return error.IndexSizeError;
    }
    const bytes = try self._canvas._bitmap.getImageData(frame.call_arena, self._canvas.getWidth(), self._canvas.getHeight(), sx, sy, @intCast(sw), @intCast(sh));
    return ImageData.initWithBytes(@intCast(sw), @intCast(sh), bytes, null, frame);
}

pub fn save(_: *CanvasRenderingContext2D) void {}
pub fn restore(_: *CanvasRenderingContext2D) void {}
pub fn scale(_: *CanvasRenderingContext2D, _: f64, _: f64) void {}
pub fn rotate(_: *CanvasRenderingContext2D, _: f64) void {}
pub fn translate(_: *CanvasRenderingContext2D, _: f64, _: f64) void {}
pub fn transform(_: *CanvasRenderingContext2D, _: f64, _: f64, _: f64, _: f64, _: f64, _: f64) void {}
pub fn setTransform(_: *CanvasRenderingContext2D, _: f64, _: f64, _: f64, _: f64, _: f64, _: f64) void {}
pub fn resetTransform(_: *CanvasRenderingContext2D) void {}
pub fn setStrokeStyle(_: *CanvasRenderingContext2D, _: []const u8) void {}
pub fn clearRect(self: *CanvasRenderingContext2D, x: f64, y: f64, w: f64, h: f64, frame: *Frame) !void {
    try self._canvas._bitmap.clearRect(frame.arena, self._canvas.getWidth(), self._canvas.getHeight(), x, y, w, h);
}

pub fn fillRect(self: *CanvasRenderingContext2D, x: f64, y: f64, w: f64, h: f64, frame: *Frame) !void {
    try self._canvas._bitmap.fillRect(frame.arena, self._canvas.getWidth(), self._canvas.getHeight(), x, y, w, h, self._fill_style);
}
pub fn strokeRect(_: *CanvasRenderingContext2D, _: f64, _: f64, _: f64, _: f64) void {}
pub fn beginPath(_: *CanvasRenderingContext2D) void {}
pub fn closePath(_: *CanvasRenderingContext2D) void {}
pub fn moveTo(_: *CanvasRenderingContext2D, _: f64, _: f64) void {}
pub fn lineTo(_: *CanvasRenderingContext2D, _: f64, _: f64) void {}
pub fn quadraticCurveTo(_: *CanvasRenderingContext2D, _: f64, _: f64, _: f64, _: f64) void {}
pub fn bezierCurveTo(_: *CanvasRenderingContext2D, _: f64, _: f64, _: f64, _: f64, _: f64, _: f64) void {}
pub fn arc(_: *CanvasRenderingContext2D, _: f64, _: f64, _: f64, _: f64, _: f64, _: ?bool) void {}
pub fn arcTo(_: *CanvasRenderingContext2D, _: f64, _: f64, _: f64, _: f64, _: f64) void {}
pub fn rect(_: *CanvasRenderingContext2D, _: f64, _: f64, _: f64, _: f64) void {}
pub fn fill(_: *CanvasRenderingContext2D) void {}
pub fn stroke(_: *CanvasRenderingContext2D) void {}
pub fn clip(_: *CanvasRenderingContext2D) void {}
const ImageSource = union(enum) {
    canvas: *Canvas,
    offscreen_canvas: *OffscreenCanvas,
};

pub fn drawImage(self: *CanvasRenderingContext2D, source: ImageSource, dx: f64, dy: f64, frame: *Frame) !void {
    switch (source) {
        .canvas => |canvas| try self._canvas._bitmap.drawImage(frame.arena, self._canvas.getWidth(), self._canvas.getHeight(), &canvas._bitmap, canvas.getWidth(), canvas.getHeight(), @intFromFloat(@round(dx)), @intFromFloat(@round(dy))),
        .offscreen_canvas => |canvas| try self._canvas._bitmap.drawImage(frame.arena, self._canvas.getWidth(), self._canvas.getHeight(), &canvas._bitmap, canvas._width, canvas._height, @intFromFloat(@round(dx)), @intFromFloat(@round(dy))),
    }
}

pub fn measureText(_: *CanvasRenderingContext2D, text: []const u8, frame: *Frame) !*TextMetrics {
    return TextMetrics.init(text, frame);
}

pub fn fillText(self: *CanvasRenderingContext2D, text: []const u8, x: f64, y: f64, _: ?f64, frame: *Frame) !void {
    const width = @max(1, @as(u32, @intFromFloat(@ceil(estimateTextWidth(text)))));
    try self._canvas._bitmap.fillRect(frame.arena, self._canvas.getWidth(), self._canvas.getHeight(), x, y - 12, @floatFromInt(width), 14, self._fill_style);
}

pub fn strokeText(self: *CanvasRenderingContext2D, text: []const u8, x: f64, y: f64, max_width: ?f64, frame: *Frame) !void {
    try self.fillText(text, x, y, max_width, frame);
}

const TextMetrics = struct {
    width: f64,
    actual_bounding_box_ascent: f64 = 10,
    actual_bounding_box_descent: f64 = 3,
    font_bounding_box_ascent: f64 = 10,
    font_bounding_box_descent: f64 = 3,

    pub fn init(text: []const u8, frame: *Frame) !*TextMetrics {
        return frame._factory.create(TextMetrics{ .width = estimateTextWidth(text) });
    }

    pub fn getWidth(self: *const TextMetrics) f64 {
        return self.width;
    }

    pub fn getActualBoundingBoxAscent(self: *const TextMetrics) f64 {
        return self.actual_bounding_box_ascent;
    }

    pub fn getActualBoundingBoxDescent(self: *const TextMetrics) f64 {
        return self.actual_bounding_box_descent;
    }

    pub fn getFontBoundingBoxAscent(self: *const TextMetrics) f64 {
        return self.font_bounding_box_ascent;
    }

    pub fn getFontBoundingBoxDescent(self: *const TextMetrics) f64 {
        return self.font_bounding_box_descent;
    }

    pub const JsApi = struct {
        pub const bridge = js.Bridge(TextMetrics);

        pub const Meta = struct {
            pub const name = "TextMetrics";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };

        pub const width = bridge.accessor(TextMetrics.getWidth, null, .{});
        pub const actualBoundingBoxAscent = bridge.accessor(TextMetrics.getActualBoundingBoxAscent, null, .{});
        pub const actualBoundingBoxDescent = bridge.accessor(TextMetrics.getActualBoundingBoxDescent, null, .{});
        pub const fontBoundingBoxAscent = bridge.accessor(TextMetrics.getFontBoundingBoxAscent, null, .{});
        pub const fontBoundingBoxDescent = bridge.accessor(TextMetrics.getFontBoundingBoxDescent, null, .{});
    };
};

fn estimateTextWidth(text: []const u8) f64 {
    return @as(f64, @floatFromInt(std.unicode.utf8CountCodepoints(text) catch text.len)) * 7.5;
}

pub const JsApi = struct {
    pub const bridge = js.Bridge(CanvasRenderingContext2D);

    pub const Meta = struct {
        pub const name = "CanvasRenderingContext2D";

        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const canvas = bridge.accessor(CanvasRenderingContext2D.getCanvas, null, .{});
    pub const font = bridge.property("10px sans-serif", .{ .template = false, .readonly = false });
    pub const globalAlpha = bridge.property(1.0, .{ .template = false, .readonly = false });
    pub const globalCompositeOperation = bridge.property("source-over", .{ .template = false, .readonly = false });
    pub const strokeStyle = bridge.property("#000000", .{ .template = false, .readonly = false });
    pub const lineWidth = bridge.property(1.0, .{ .template = false, .readonly = false });
    pub const lineCap = bridge.property("butt", .{ .template = false, .readonly = false });
    pub const lineJoin = bridge.property("miter", .{ .template = false, .readonly = false });
    pub const miterLimit = bridge.property(10.0, .{ .template = false, .readonly = false });
    pub const textAlign = bridge.property("start", .{ .template = false, .readonly = false });
    pub const textBaseline = bridge.property("alphabetic", .{ .template = false, .readonly = false });

    pub const fillStyle = bridge.accessor(CanvasRenderingContext2D.getFillStyle, CanvasRenderingContext2D.setFillStyle, .{});
    pub const createImageData = bridge.function(CanvasRenderingContext2D.createImageData, .{ .dom_exception = true });

    pub const putImageData = bridge.function(CanvasRenderingContext2D.putImageData, .{ .dom_exception = true });
    pub const getImageData = bridge.function(CanvasRenderingContext2D.getImageData, .{ .dom_exception = true });
    pub const save = bridge.function(CanvasRenderingContext2D.save, .{ .noop = true });
    pub const restore = bridge.function(CanvasRenderingContext2D.restore, .{ .noop = true });
    pub const scale = bridge.function(CanvasRenderingContext2D.scale, .{ .noop = true });
    pub const rotate = bridge.function(CanvasRenderingContext2D.rotate, .{ .noop = true });
    pub const translate = bridge.function(CanvasRenderingContext2D.translate, .{ .noop = true });
    pub const transform = bridge.function(CanvasRenderingContext2D.transform, .{ .noop = true });
    pub const setTransform = bridge.function(CanvasRenderingContext2D.setTransform, .{ .noop = true });
    pub const resetTransform = bridge.function(CanvasRenderingContext2D.resetTransform, .{ .noop = true });
    pub const clearRect = bridge.function(CanvasRenderingContext2D.clearRect, .{ .dom_exception = true });
    pub const fillRect = bridge.function(CanvasRenderingContext2D.fillRect, .{ .dom_exception = true });
    pub const strokeRect = bridge.function(CanvasRenderingContext2D.strokeRect, .{ .noop = true });
    pub const beginPath = bridge.function(CanvasRenderingContext2D.beginPath, .{ .noop = true });
    pub const closePath = bridge.function(CanvasRenderingContext2D.closePath, .{ .noop = true });
    pub const moveTo = bridge.function(CanvasRenderingContext2D.moveTo, .{ .noop = true });
    pub const lineTo = bridge.function(CanvasRenderingContext2D.lineTo, .{ .noop = true });
    pub const quadraticCurveTo = bridge.function(CanvasRenderingContext2D.quadraticCurveTo, .{ .noop = true });
    pub const bezierCurveTo = bridge.function(CanvasRenderingContext2D.bezierCurveTo, .{ .noop = true });
    pub const arc = bridge.function(CanvasRenderingContext2D.arc, .{ .noop = true });
    pub const arcTo = bridge.function(CanvasRenderingContext2D.arcTo, .{ .noop = true });
    pub const rect = bridge.function(CanvasRenderingContext2D.rect, .{ .noop = true });
    pub const fill = bridge.function(CanvasRenderingContext2D.fill, .{ .noop = true });
    pub const stroke = bridge.function(CanvasRenderingContext2D.stroke, .{ .noop = true });
    pub const clip = bridge.function(CanvasRenderingContext2D.clip, .{ .noop = true });
    pub const fillText = bridge.function(CanvasRenderingContext2D.fillText, .{ .dom_exception = true });
    pub const strokeText = bridge.function(CanvasRenderingContext2D.strokeText, .{ .dom_exception = true });
    pub const drawImage = bridge.function(CanvasRenderingContext2D.drawImage, .{ .dom_exception = true });
    pub const measureText = bridge.function(CanvasRenderingContext2D.measureText, .{});
};

const testing = @import("../../../testing.zig");
test "WebApi: CanvasRenderingContext2D" {
    try testing.htmlRunner("canvas/canvas_rendering_context_2d.html", .{});
}
