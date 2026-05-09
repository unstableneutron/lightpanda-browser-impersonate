// Copyright (C) 2023-2026  Lightpanda (Selecy SAS)
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
const js = @import("../js/js.zig");
const Frame = @import("../Frame.zig");

pub fn registerTypes() []const type {
    return &.{ PluginArray, Plugin, MimeTypeArray, MimeType };
}

pub const MimeType = struct {
    type: []const u8 = "",
    suffixes: []const u8 = "",
    description: []const u8 = "",
    enabled_plugin_name: []const u8 = "",

    fn getType(self: *const MimeType) []const u8 {
        return self.type;
    }

    fn getSuffixes(self: *const MimeType) []const u8 {
        return self.suffixes;
    }

    fn getDescription(self: *const MimeType) []const u8 {
        return self.description;
    }

    fn getEnabledPlugin(self: *const MimeType, frame: *Frame) ?Plugin {
        return frame.window.getNavigator().getPlugins().getByName(self.enabled_plugin_name);
    }

    pub const JsApi = struct {
        pub const bridge = js.Bridge(MimeType);
        pub const Meta = struct {
            pub const name = "MimeType";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };

        pub const @"type" = bridge.accessor(MimeType.getType, null, .{});
        pub const suffixes = bridge.accessor(MimeType.getSuffixes, null, .{});
        pub const description = bridge.accessor(MimeType.getDescription, null, .{});
        pub const enabledPlugin = bridge.accessor(MimeType.getEnabledPlugin, null, .{});
    };
};

pub const default_mime_types = [_]MimeType{
    .{ .type = "application/pdf", .suffixes = "pdf", .description = "Portable Document Format", .enabled_plugin_name = "PDF Viewer" },
    .{ .type = "text/pdf", .suffixes = "pdf", .description = "Portable Document Format", .enabled_plugin_name = "PDF Viewer" },
};

pub const Plugin = struct {
    name: []const u8 = "",
    filename: []const u8 = "",
    description: []const u8 = "",
    mime_types: [default_mime_types.len]MimeType = default_mime_types,

    pub const JsApi = struct {
        pub const bridge = js.Bridge(Plugin);
        pub const Meta = struct {
            pub const name = "Plugin";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };

        pub const name = bridge.accessor(struct {
            fn get(self: *const Plugin) []const u8 {
                return self.name;
            }
        }.get, null, .{});
        pub const filename = bridge.accessor(struct {
            fn get(self: *const Plugin) []const u8 {
                return self.filename;
            }
        }.get, null, .{});
        pub const description = bridge.accessor(struct {
            fn get(self: *const Plugin) []const u8 {
                return self.description;
            }
        }.get, null, .{});
        pub const length = bridge.property(default_mime_types.len, .{ .template = false });
        pub const @"[int]" = bridge.indexed(Plugin.getMimeAtIndex, null, .{ .null_as_undefined = true });
        pub const @"[str]" = bridge.namedIndexed(Plugin.getMimeByName, null, null, .{ .null_as_undefined = true });
        pub const item = bridge.function(_item, .{});
        fn _item(self: *Plugin, index: i32) ?MimeType {
            if (index < 0) return null;
            return self.getMimeAtIndex(@intCast(index));
        }
        pub const namedItem = bridge.function(Plugin.getMimeByName, .{});
    };

    pub fn getMimeAtIndex(self: *Plugin, index: usize) ?MimeType {
        if (index >= self.mime_types.len) return null;
        return self.mime_types[index];
    }

    pub fn getMimeByName(self: *Plugin, name: []const u8) ?MimeType {
        for (self.mime_types) |mime_type| {
            if (std.mem.eql(u8, mime_type.type, name)) return mime_type;
        }
        return null;
    }
};

const PluginArray = @This();

const default_plugins = [_]Plugin{
    .{ .name = "PDF Viewer", .filename = "internal-pdf-viewer", .description = "Portable Document Format", .mime_types = default_mime_types },
    .{ .name = "Chrome PDF Viewer", .filename = "internal-pdf-viewer", .description = "Portable Document Format", .mime_types = pluginMimeTypes("Chrome PDF Viewer") },
    .{ .name = "Chromium PDF Viewer", .filename = "internal-pdf-viewer", .description = "Portable Document Format", .mime_types = pluginMimeTypes("Chromium PDF Viewer") },
    .{ .name = "Microsoft Edge PDF Viewer", .filename = "internal-pdf-viewer", .description = "Portable Document Format", .mime_types = pluginMimeTypes("Microsoft Edge PDF Viewer") },
    .{ .name = "WebKit built-in PDF", .filename = "internal-pdf-viewer", .description = "Portable Document Format", .mime_types = pluginMimeTypes("WebKit built-in PDF") },
};

fn pluginMimeTypes(comptime plugin_name: []const u8) [default_mime_types.len]MimeType {
    return .{
        .{ .type = "application/pdf", .suffixes = "pdf", .description = "Portable Document Format", .enabled_plugin_name = plugin_name },
        .{ .type = "text/pdf", .suffixes = "pdf", .description = "Portable Document Format", .enabled_plugin_name = plugin_name },
    };
}

pub const MimeTypeArray = struct {
    _pad: bool = false,
    mime_types: [default_mime_types.len]MimeType = default_mime_types,

    pub fn getAtIndex(self: *MimeTypeArray, index: usize) ?MimeType {
        if (index >= self.mime_types.len) return null;
        return self.mime_types[index];
    }

    pub fn getByName(self: *MimeTypeArray, name: []const u8) ?MimeType {
        for (self.mime_types) |mime_type| {
            if (std.mem.eql(u8, mime_type.type, name)) return mime_type;
        }
        return null;
    }

    pub const JsApi = struct {
        pub const bridge = js.Bridge(MimeTypeArray);

        pub const Meta = struct {
            pub const name = "MimeTypeArray";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };

        pub const length = bridge.property(default_mime_types.len, .{ .template = false });
        pub const @"[int]" = bridge.indexed(MimeTypeArray.getAtIndex, null, .{ .null_as_undefined = true });
        pub const @"[str]" = bridge.namedIndexed(MimeTypeArray.getByName, null, null, .{ .null_as_undefined = true });
        pub const item = bridge.function(_item, .{});
        fn _item(self: *MimeTypeArray, index: i32) ?MimeType {
            if (index < 0) return null;
            return self.getAtIndex(@intCast(index));
        }
        pub const namedItem = bridge.function(MimeTypeArray.getByName, .{});
    };
};

_pad: bool = false,
plugins: [default_plugins.len]Plugin = default_plugins,

pub fn refresh(_: *const PluginArray) void {}
pub fn getAtIndex(self: *PluginArray, index: usize) ?Plugin {
    if (index >= self.plugins.len) return null;
    return self.plugins[index];
}

pub fn getByName(self: *PluginArray, name: []const u8) ?Plugin {
    for (self.plugins) |plugin| {
        if (std.mem.eql(u8, plugin.name, name)) return plugin;
    }
    return null;
}

pub const JsApi = struct {
    pub const bridge = js.Bridge(PluginArray);

    pub const Meta = struct {
        pub const name = "PluginArray";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const length = bridge.property(default_plugins.len, .{ .template = false });
    pub const refresh = bridge.function(PluginArray.refresh, .{});
    pub const @"[int]" = bridge.indexed(PluginArray.getAtIndex, null, .{ .null_as_undefined = true });
    pub const @"[str]" = bridge.namedIndexed(PluginArray.getByName, null, null, .{ .null_as_undefined = true });
    pub const item = bridge.function(_item, .{});
    fn _item(self: *PluginArray, index: i32) ?Plugin {
        if (index < 0) {
            return null;
        }
        return self.getAtIndex(@intCast(index));
    }
    pub const namedItem = bridge.function(PluginArray.getByName, .{});
};
