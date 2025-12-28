// Copyright (C) 2023-2024  Lightpanda (Selecy SAS)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

const std = @import("std");

/// Represents a browser plugin (e.g., PDF Viewer).
/// https://html.spec.whatwg.org/multipage/system-state.html#dom-plugin
pub const Plugin = struct {
    name: []const u8,
    description: []const u8,
    filename: []const u8,

    pub fn get_name(self: *const Plugin) []const u8 {
        return self.name;
    }

    pub fn get_description(self: *const Plugin) []const u8 {
        return self.description;
    }

    pub fn get_filename(self: *const Plugin) []const u8 {
        return self.filename;
    }

    pub fn get_length(_: *const Plugin) u32 {
        return 1; // Each plugin has 1 mime type
    }

    pub fn _item(_: *const Plugin, index: u32) ?*const MimeType {
        if (index == 0) return &pdf_mime_type;
        return null;
    }

    pub fn _namedItem(_: *const Plugin, name: []const u8) ?*const MimeType {
        if (std.mem.eql(u8, name, "application/pdf")) return &pdf_mime_type;
        return null;
    }
};

/// Represents a MIME type supported by a plugin.
/// https://html.spec.whatwg.org/multipage/system-state.html#dom-mimetype
pub const MimeType = struct {
    type_string: []const u8,
    description: []const u8,
    suffixes: []const u8,

    pub fn get_type(self: *const MimeType) []const u8 {
        return self.type_string;
    }

    pub fn get_description(self: *const MimeType) []const u8 {
        return self.description;
    }

    pub fn get_suffixes(self: *const MimeType) []const u8 {
        return self.suffixes;
    }

    pub fn get_enabledPlugin(_: *const MimeType) *const Plugin {
        return &pdf_plugin;
    }
};

/// Array-like object containing plugins.
/// https://html.spec.whatwg.org/multipage/system-state.html#pluginarray
pub const PluginArray = struct {
    pub fn get_length(_: *const PluginArray) u32 {
        return 1; // One PDF plugin
    }

    pub fn _item(_: *const PluginArray, index: u32) ?*const Plugin {
        if (index == 0) return &pdf_plugin;
        return null;
    }

    pub fn _namedItem(_: *const PluginArray, name: []const u8) ?*const Plugin {
        if (std.mem.eql(u8, name, "PDF Viewer") or
            std.mem.eql(u8, name, "Chrome PDF Viewer") or
            std.mem.eql(u8, name, "Chromium PDF Viewer") or
            std.mem.eql(u8, name, "Mozilla PDF Viewer") or
            std.mem.eql(u8, name, "WebKit built-in PDF"))
        {
            return &pdf_plugin;
        }
        return null;
    }

    pub fn _refresh(_: *const PluginArray) void {
        // No-op, plugins don't change
    }

    /// Indexed getter for plugins[0] syntax
    pub fn indexed_get(_: *const PluginArray, index: u32, has_value: *bool) *const Plugin {
        if (index == 0) {
            has_value.* = true;
            return &pdf_plugin;
        }
        has_value.* = false;
        return &pdf_plugin; // Won't be used since has_value is false
    }
};

/// Array-like object containing MIME types.
/// https://html.spec.whatwg.org/multipage/system-state.html#mimetypearray
pub const MimeTypeArray = struct {
    pub fn get_length(_: *const MimeTypeArray) u32 {
        return 1; // One PDF mime type
    }

    pub fn _item(_: *const MimeTypeArray, index: u32) ?*const MimeType {
        if (index == 0) return &pdf_mime_type;
        return null;
    }

    pub fn _namedItem(_: *const MimeTypeArray, name: []const u8) ?*const MimeType {
        if (std.mem.eql(u8, name, "application/pdf")) return &pdf_mime_type;
        return null;
    }

    /// Indexed getter for mimeTypes[0] syntax
    pub fn indexed_get(_: *const MimeTypeArray, index: u32, has_value: *bool) *const MimeType {
        if (index == 0) {
            has_value.* = true;
            return &pdf_mime_type;
        }
        has_value.* = false;
        return &pdf_mime_type; // Won't be used since has_value is false
    }
};

// Static plugin and mime type instances (shared across all navigators)
pub const pdf_plugin = Plugin{
    .name = "PDF Viewer",
    .description = "Portable Document Format",
    .filename = "internal-pdf-viewer",
};

pub const pdf_mime_type = MimeType{
    .type_string = "application/pdf",
    .description = "Portable Document Format",
    .suffixes = "pdf",
};

pub const Interfaces = .{
    Plugin,
    MimeType,
    PluginArray,
    MimeTypeArray,
};
