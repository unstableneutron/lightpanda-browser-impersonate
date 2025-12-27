// Copyright (C) 2023-2024  Lightpanda (Selecy SAS)
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

/// Browser profiles for TLS/HTTP fingerprint impersonation.
/// Used to reduce bot detection by matching browser signatures.
pub const Profile = enum {
    /// No impersonation - original LightPanda behavior
    lightpanda,
    /// Firefox 144 (default impersonation profile)
    firefox144,
    /// Firefox 135
    firefox135,
    /// Chrome 136
    chrome136,
    /// Chrome 131
    chrome131,
    /// Safari 18.0
    safari180,
    /// Edge 101
    edge101,

    /// Parse a profile name string into a Profile enum.
    /// Returns null if the string doesn't match any known profile.
    pub fn fromString(s: []const u8) ?Profile {
        const map = std.StaticStringMap(Profile).initComptime(.{
            .{ "lightpanda", .lightpanda },
            .{ "default", .lightpanda },
            .{ "firefox144", .firefox144 },
            .{ "firefox135", .firefox135 },
            .{ "chrome136", .chrome136 },
            .{ "chrome131", .chrome131 },
            .{ "safari180", .safari180 },
            .{ "edge101", .edge101 },
        });
        return map.get(s);
    }

    /// Returns the curl-impersonate target string, or null for no impersonation.
    /// This is passed to curl_easy_impersonate().
    pub fn curlTarget(self: Profile) ?[:0]const u8 {
        return switch (self) {
            .lightpanda => null,
            .firefox144 => "firefox144",
            .firefox135 => "firefox135",
            .chrome136 => "chrome136",
            .chrome131 => "chrome131",
            .safari180 => "safari180",
            .edge101 => "edge101",
        };
    }

    /// Returns the full User-Agent header line (with "User-Agent: " prefix).
    /// Used for HTTP requests.
    pub fn userAgent(self: Profile) [:0]const u8 {
        return switch (self) {
            .lightpanda => "User-Agent: Lightpanda/1.0",
            .firefox144 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:144.0) Gecko/20100101 Firefox/144.0",
            .firefox135 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:135.0) Gecko/20100101 Firefox/135.0",
            .chrome136 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36",
            .chrome131 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            .safari180 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            .edge101 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.64 Safari/537.36 Edg/101.0.1210.53",
        };
    }

    /// Returns navigator.userAgent (without "User-Agent: " prefix).
    /// Used for JavaScript navigator.userAgent property.
    pub fn navigatorUserAgent(self: Profile) []const u8 {
        const ua = self.userAgent();
        const prefix = "User-Agent: ";
        return ua[prefix.len..];
    }

    /// Returns navigator.platform value.
    pub fn platform(self: Profile) []const u8 {
        return switch (self) {
            .lightpanda => "MacIntel", // Changed from weird ".macos .aarch64"
            .firefox144, .firefox135 => "MacIntel",
            .chrome136, .chrome131, .safari180 => "MacIntel",
            .edge101 => "Win32",
        };
    }

    /// Returns navigator.vendor value.
    pub fn vendor(self: Profile) []const u8 {
        return switch (self) {
            .lightpanda => "",
            .firefox144, .firefox135 => "", // Firefox has empty vendor
            .chrome136, .chrome131 => "Google Inc.",
            .safari180 => "Apple Computer, Inc.",
            .edge101 => "Google Inc.",
        };
    }

    /// Returns navigator.appVersion value.
    pub fn appVersion(self: Profile) []const u8 {
        return switch (self) {
            .lightpanda => "5.0 (Macintosh)",
            .firefox144 => "5.0 (Macintosh)",
            .firefox135 => "5.0 (Macintosh)",
            .chrome136 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36",
            .chrome131 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            .safari180 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            .edge101 => "5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.64 Safari/537.36 Edg/101.0.1210.53",
        };
    }

    /// Returns Accept-Language header.
    pub fn acceptLanguage(self: Profile) [:0]const u8 {
        _ = self;
        return "Accept-Language: en-US,en;q=0.9";
    }

    /// Returns a list of supported profile names for help text.
    pub fn supportedProfiles() []const u8 {
        return "firefox144 (default), firefox135, chrome136, chrome131, safari180, edge101, lightpanda, default";
    }
};

test "Profile.fromString" {
    const testing = std.testing;

    try testing.expectEqual(Profile.lightpanda, Profile.fromString("lightpanda").?);
    try testing.expectEqual(Profile.lightpanda, Profile.fromString("default").?);
    try testing.expectEqual(Profile.firefox144, Profile.fromString("firefox144").?);
    try testing.expectEqual(Profile.chrome136, Profile.fromString("chrome136").?);
    try testing.expectEqual(@as(?Profile, null), Profile.fromString("invalid"));
}

test "Profile.curlTarget" {
    const testing = std.testing;

    try testing.expectEqual(@as(?[:0]const u8, null), Profile.lightpanda.curlTarget());
    try testing.expectEqualStrings("firefox144", Profile.firefox144.curlTarget().?);
    try testing.expectEqualStrings("chrome136", Profile.chrome136.curlTarget().?);
}

test "Profile.navigatorUserAgent" {
    const testing = std.testing;

    try testing.expectEqualStrings("Lightpanda/1.0", Profile.lightpanda.navigatorUserAgent());
    try testing.expect(std.mem.startsWith(u8, Profile.firefox144.navigatorUserAgent(), "Mozilla/5.0"));
    try testing.expect(std.mem.indexOf(u8, Profile.firefox144.navigatorUserAgent(), "Firefox/144.0") != null);
}

test "Profile.platform" {
    const testing = std.testing;

    try testing.expectEqualStrings("MacIntel", Profile.lightpanda.platform());
    try testing.expectEqualStrings("MacIntel", Profile.firefox144.platform());
    try testing.expectEqualStrings("Win32", Profile.edge101.platform());
}

test "Profile.vendor" {
    const testing = std.testing;

    try testing.expectEqualStrings("", Profile.lightpanda.vendor());
    try testing.expectEqualStrings("", Profile.firefox144.vendor());
    try testing.expectEqualStrings("Google Inc.", Profile.chrome136.vendor());
    try testing.expectEqualStrings("Apple Computer, Inc.", Profile.safari180.vendor());
}
