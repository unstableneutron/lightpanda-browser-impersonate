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
/// Profiles match curl-impersonate targets from https://github.com/lexiforest/curl-impersonate
pub const Profile = enum {
    // === No impersonation ===
    /// No impersonation - original LightPanda behavior (default)
    lightpanda,

    // === Chrome (Windows) ===
    /// Chrome 99.0.4844.51 (Windows 10)
    chrome99,
    /// Chrome 100.0.4896.75 (Windows 10)
    chrome100,
    /// Chrome 101.0.4951.67 (Windows 10)
    chrome101,
    /// Chrome 104.0.0.0 (Windows 10)
    chrome104,
    /// Chrome 107.0.0.0 (Windows 10)
    chrome107,
    /// Chrome 110.0.0.0 (Windows 10)
    chrome110,
    /// Chrome 116.0.0.0 (Windows 10)
    chrome116,

    // === Chrome (macOS) ===
    /// Chrome 119.0.0.0 (macOS Sonoma)
    chrome119,
    /// Chrome 120.0.0.0 (macOS Sonoma)
    chrome120,
    /// Chrome 123.0.0.0 (macOS Sonoma)
    chrome123,
    /// Chrome 124.0.0.0 (macOS Sonoma)
    chrome124,
    /// Chrome 131.0.0.0 (macOS Sonoma)
    chrome131,
    /// Chrome 133.0.0.0 (macOS Sequoia) - alternative build
    chrome133a,
    /// Chrome 136.0.0.0 (macOS Sequoia)
    chrome136,
    /// Chrome 142.0.0.0 (macOS Tahoe)
    chrome142,

    // === Chrome (Android) ===
    /// Chrome 99.0.4844.58 (Android 12, Pixel 6)
    chrome99_android,
    /// Chrome 131.0.0.0 (Android 10)
    chrome131_android,

    // === Edge (Windows) ===
    /// Edge 99.0.1150.30 (Windows 10)
    edge99,
    /// Edge 101.0.1210.47 (Windows 10)
    edge101,

    // === Safari (macOS) ===
    /// Safari 15.3 (macOS Big Sur)
    safari153,
    /// Safari 15.5 (macOS Monterey)
    safari155,
    /// Safari 17.0 (macOS Sonoma)
    safari170,
    /// Safari 18.0 (macOS Sequoia)
    safari180,
    /// Safari 18.4 (macOS Sequoia)
    safari184,
    /// Safari 26.0 (macOS Tahoe)
    safari260,

    // === Safari (iOS) ===
    /// Safari 17.2 (iOS 17.2)
    safari172_ios,
    /// Safari 18.0 (iOS 18.0)
    safari180_ios,
    /// Safari 18.4 (iOS 18.0)
    safari184_ios,
    /// Safari 26.0 (iOS 26.0)
    safari260_ios,

    // === Firefox (Windows) ===
    /// Firefox 91 ESR (Windows 10)
    firefox91esr,
    /// Firefox 95 (Windows 10)
    firefox95,
    /// Firefox 98 (Windows 10)
    firefox98,
    /// Firefox 100 (Windows 10)
    firefox100,
    /// Firefox 102 (Windows 10)
    firefox102,
    /// Firefox 109 (Windows 10)
    firefox109,
    /// Firefox 117 (Windows 10)
    firefox117,

    // === Firefox (macOS) ===
    /// Firefox 133 (macOS Sonoma)
    firefox133,
    /// Firefox 135 (macOS Sonoma)
    firefox135,
    /// Firefox 144 (macOS Tahoe)
    firefox144,

    // === Tor ===
    /// Tor Browser 14.5 (macOS Sonoma, based on Firefox 128 ESR)
    tor145,

    /// Parse a profile name string into a Profile enum.
    /// Returns null if the string doesn't match any known profile.
    pub fn fromString(s: []const u8) ?Profile {
        const map = std.StaticStringMap(Profile).initComptime(.{
            // Default
            .{ "lightpanda", .lightpanda },
            .{ "default", .lightpanda },
            // Chrome Windows
            .{ "chrome99", .chrome99 },
            .{ "chrome100", .chrome100 },
            .{ "chrome101", .chrome101 },
            .{ "chrome104", .chrome104 },
            .{ "chrome107", .chrome107 },
            .{ "chrome110", .chrome110 },
            .{ "chrome116", .chrome116 },
            // Chrome macOS
            .{ "chrome119", .chrome119 },
            .{ "chrome120", .chrome120 },
            .{ "chrome123", .chrome123 },
            .{ "chrome124", .chrome124 },
            .{ "chrome131", .chrome131 },
            .{ "chrome133a", .chrome133a },
            .{ "chrome136", .chrome136 },
            .{ "chrome142", .chrome142 },
            // Chrome Android
            .{ "chrome99_android", .chrome99_android },
            .{ "chrome131_android", .chrome131_android },
            // Edge
            .{ "edge99", .edge99 },
            .{ "edge101", .edge101 },
            // Safari macOS
            .{ "safari153", .safari153 },
            .{ "safari155", .safari155 },
            .{ "safari170", .safari170 },
            .{ "safari180", .safari180 },
            .{ "safari184", .safari184 },
            .{ "safari260", .safari260 },
            // Safari iOS
            .{ "safari172_ios", .safari172_ios },
            .{ "safari180_ios", .safari180_ios },
            .{ "safari184_ios", .safari184_ios },
            .{ "safari260_ios", .safari260_ios },
            // Firefox Windows
            .{ "firefox91esr", .firefox91esr },
            .{ "firefox95", .firefox95 },
            .{ "firefox98", .firefox98 },
            .{ "firefox100", .firefox100 },
            .{ "firefox102", .firefox102 },
            .{ "firefox109", .firefox109 },
            .{ "firefox117", .firefox117 },
            // Firefox macOS
            .{ "firefox133", .firefox133 },
            .{ "firefox135", .firefox135 },
            .{ "firefox144", .firefox144 },
            // Tor
            .{ "tor145", .tor145 },
        });
        return map.get(s);
    }

    /// Returns the curl-impersonate target string, or null for no impersonation.
    /// This is passed to curl_easy_impersonate().
    pub fn curlTarget(self: Profile) ?[:0]const u8 {
        return switch (self) {
            .lightpanda => null,
            // Chrome Windows
            .chrome99 => "chrome99",
            .chrome100 => "chrome100",
            .chrome101 => "chrome101",
            .chrome104 => "chrome104",
            .chrome107 => "chrome107",
            .chrome110 => "chrome110",
            .chrome116 => "chrome116",
            // Chrome macOS
            .chrome119 => "chrome119",
            .chrome120 => "chrome120",
            .chrome123 => "chrome123",
            .chrome124 => "chrome124",
            .chrome131 => "chrome131",
            .chrome133a => "chrome133a",
            .chrome136 => "chrome136",
            .chrome142 => "chrome142",
            // Chrome Android
            .chrome99_android => "chrome99_android",
            .chrome131_android => "chrome131_android",
            // Edge
            .edge99 => "edge99",
            .edge101 => "edge101",
            // Safari macOS
            .safari153 => "safari153",
            .safari155 => "safari155",
            .safari170 => "safari170",
            .safari180 => "safari180",
            .safari184 => "safari184",
            .safari260 => "safari260",
            // Safari iOS
            .safari172_ios => "safari172_ios",
            .safari180_ios => "safari180_ios",
            .safari184_ios => "safari184_ios",
            .safari260_ios => "safari260_ios",
            // Firefox Windows
            .firefox91esr => "firefox91esr",
            .firefox95 => "firefox95",
            .firefox98 => "firefox98",
            .firefox100 => "firefox100",
            .firefox102 => "firefox102",
            .firefox109 => "firefox109",
            .firefox117 => "firefox117",
            // Firefox macOS
            .firefox133 => "firefox133",
            .firefox135 => "firefox135",
            .firefox144 => "firefox144",
            // Tor
            .tor145 => "tor145",
        };
    }

    /// Returns the full User-Agent header line (with "User-Agent: " prefix).
    /// Used for HTTP requests.
    pub fn userAgent(self: Profile) [:0]const u8 {
        return switch (self) {
            .lightpanda => "User-Agent: Lightpanda/1.0",
            // Chrome Windows
            .chrome99 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.51 Safari/537.36",
            .chrome100 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.75 Safari/537.36",
            .chrome101 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.67 Safari/537.36",
            .chrome104 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36",
            .chrome107 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36",
            .chrome110 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36",
            .chrome116 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
            // Chrome macOS
            .chrome119 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
            .chrome120 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            .chrome123 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
            .chrome124 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            .chrome131 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            .chrome133a => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36",
            .chrome136 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36",
            .chrome142 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
            // Chrome Android
            .chrome99_android => "User-Agent: Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.58 Mobile Safari/537.36",
            .chrome131_android => "User-Agent: Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36",
            // Edge
            .edge99 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.51 Safari/537.36 Edg/99.0.1150.30",
            .edge101 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.64 Safari/537.36 Edg/101.0.1210.47",
            // Safari macOS
            .safari153 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.3 Safari/605.1.15",
            .safari155 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15",
            .safari170 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            .safari180 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            .safari184 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15",
            .safari260 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15",
            // Safari iOS
            .safari172_ios => "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
            .safari180_ios => "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            .safari184_ios => "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
            .safari260_ios => "User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1",
            // Firefox Windows
            .firefox91esr => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:91.0) Gecko/20100101 Firefox/91.0",
            .firefox95 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:95.0) Gecko/20100101 Firefox/95.0",
            .firefox98 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:98.0) Gecko/20100101 Firefox/98.0",
            .firefox100 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:100.0) Gecko/20100101 Firefox/100.0",
            .firefox102 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:102.0) Gecko/20100101 Firefox/102.0",
            .firefox109 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/109.0",
            .firefox117 => "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/117.0",
            // Firefox macOS
            .firefox133 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:133.0) Gecko/20100101 Firefox/133.0",
            .firefox135 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:135.0) Gecko/20100101 Firefox/135.0",
            .firefox144 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:135.0) Gecko/20100101 Firefox/144.0",
            // Tor (based on Firefox 128 ESR)
            .tor145 => "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:128.0) Gecko/20100101 Firefox/128.0",
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
            .lightpanda => "MacIntel",
            // Chrome Windows
            .chrome99, .chrome100, .chrome101, .chrome104, .chrome107, .chrome110, .chrome116 => "Win32",
            // Chrome macOS
            .chrome119, .chrome120, .chrome123, .chrome124, .chrome131, .chrome133a, .chrome136, .chrome142 => "MacIntel",
            // Chrome Android
            .chrome99_android, .chrome131_android => "Linux armv8l",
            // Edge Windows
            .edge99, .edge101 => "Win32",
            // Safari macOS
            .safari153, .safari155, .safari170, .safari180, .safari184, .safari260 => "MacIntel",
            // Safari iOS
            .safari172_ios, .safari180_ios, .safari184_ios, .safari260_ios => "iPhone",
            // Firefox Windows
            .firefox91esr, .firefox95, .firefox98, .firefox100, .firefox102, .firefox109, .firefox117 => "Win32",
            // Firefox macOS
            .firefox133, .firefox135, .firefox144 => "MacIntel",
            // Tor (macOS)
            .tor145 => "MacIntel",
        };
    }

    /// Returns navigator.vendor value.
    pub fn vendor(self: Profile) []const u8 {
        return switch (self) {
            .lightpanda => "",
            // Chrome (all platforms) - Google Inc.
            .chrome99, .chrome100, .chrome101, .chrome104, .chrome107, .chrome110, .chrome116 => "Google Inc.",
            .chrome119, .chrome120, .chrome123, .chrome124, .chrome131, .chrome133a, .chrome136, .chrome142 => "Google Inc.",
            .chrome99_android, .chrome131_android => "Google Inc.",
            // Edge - Google Inc. (Chromium-based)
            .edge99, .edge101 => "Google Inc.",
            // Safari - Apple
            .safari153, .safari155, .safari170, .safari180, .safari184, .safari260 => "Apple Computer, Inc.",
            .safari172_ios, .safari180_ios, .safari184_ios, .safari260_ios => "Apple Computer, Inc.",
            // Firefox - empty string
            .firefox91esr, .firefox95, .firefox98, .firefox100, .firefox102, .firefox109, .firefox117 => "",
            .firefox133, .firefox135, .firefox144 => "",
            // Tor - empty string (Firefox-based)
            .tor145 => "",
        };
    }

    /// Returns navigator.appVersion value.
    pub fn appVersion(self: Profile) []const u8 {
        return switch (self) {
            .lightpanda => "5.0 (Macintosh)",
            // Chrome Windows
            .chrome99 => "5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.51 Safari/537.36",
            .chrome100 => "5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.75 Safari/537.36",
            .chrome101 => "5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.67 Safari/537.36",
            .chrome104 => "5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36",
            .chrome107 => "5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36",
            .chrome110 => "5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36",
            .chrome116 => "5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
            // Chrome macOS
            .chrome119 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
            .chrome120 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            .chrome123 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
            .chrome124 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            .chrome131 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            .chrome133a => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36",
            .chrome136 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36",
            .chrome142 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
            // Chrome Android
            .chrome99_android => "5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.58 Mobile Safari/537.36",
            .chrome131_android => "5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36",
            // Edge
            .edge99 => "5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.51 Safari/537.36 Edg/99.0.1150.30",
            .edge101 => "5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.64 Safari/537.36 Edg/101.0.1210.47",
            // Safari macOS
            .safari153 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.3 Safari/605.1.15",
            .safari155 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15",
            .safari170 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            .safari180 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            .safari184 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Safari/605.1.15",
            .safari260 => "5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15",
            // Safari iOS
            .safari172_ios => "5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
            .safari180_ios => "5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            .safari184_ios => "5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.4 Mobile/15E148 Safari/604.1",
            .safari260_ios => "5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1",
            // Firefox Windows
            .firefox91esr => "5.0 (Windows)",
            .firefox95 => "5.0 (Windows)",
            .firefox98 => "5.0 (Windows)",
            .firefox100 => "5.0 (Windows)",
            .firefox102 => "5.0 (Windows)",
            .firefox109 => "5.0 (Windows)",
            .firefox117 => "5.0 (Windows)",
            // Firefox macOS
            .firefox133 => "5.0 (Macintosh)",
            .firefox135 => "5.0 (Macintosh)",
            .firefox144 => "5.0 (Macintosh)",
            // Tor
            .tor145 => "5.0 (Macintosh)",
        };
    }

    /// Returns Accept-Language header.
    pub fn acceptLanguage(self: Profile) [:0]const u8 {
        _ = self;
        return "Accept-Language: en-US,en;q=0.9";
    }

    /// Returns navigator.languages array.
    pub fn languages(self: Profile) []const []const u8 {
        _ = self;
        return &[_][]const u8{ "en-US", "en" };
    }

    /// Returns a list of supported profile names for help text.
    pub fn supportedProfiles() []const u8 {
        return "lightpanda (default), " ++
            "chrome99, chrome100, chrome101, chrome104, chrome107, chrome110, chrome116, " ++
            "chrome119, chrome120, chrome123, chrome124, chrome131, chrome133a, chrome136, chrome142, " ++
            "chrome99_android, chrome131_android, " ++
            "edge99, edge101, " ++
            "safari153, safari155, safari170, safari180, safari184, safari260, " ++
            "safari172_ios, safari180_ios, safari184_ios, safari260_ios, " ++
            "firefox91esr, firefox95, firefox98, firefox100, firefox102, firefox109, firefox117, " ++
            "firefox133, firefox135, firefox144, " ++
            "tor145";
    }
};

test "Profile.fromString" {
    const testing = std.testing;

    try testing.expectEqual(Profile.lightpanda, Profile.fromString("lightpanda").?);
    try testing.expectEqual(Profile.lightpanda, Profile.fromString("default").?);
    try testing.expectEqual(Profile.firefox144, Profile.fromString("firefox144").?);
    try testing.expectEqual(Profile.chrome136, Profile.fromString("chrome136").?);
    try testing.expectEqual(Profile.chrome99, Profile.fromString("chrome99").?);
    try testing.expectEqual(Profile.chrome142, Profile.fromString("chrome142").?);
    try testing.expectEqual(Profile.safari260, Profile.fromString("safari260").?);
    try testing.expectEqual(Profile.safari172_ios, Profile.fromString("safari172_ios").?);
    try testing.expectEqual(Profile.tor145, Profile.fromString("tor145").?);
    try testing.expectEqual(@as(?Profile, null), Profile.fromString("invalid"));
}

test "Profile.curlTarget" {
    const testing = std.testing;

    try testing.expectEqual(@as(?[:0]const u8, null), Profile.lightpanda.curlTarget());
    try testing.expectEqualStrings("firefox144", Profile.firefox144.curlTarget().?);
    try testing.expectEqualStrings("chrome136", Profile.chrome136.curlTarget().?);
    try testing.expectEqualStrings("chrome99", Profile.chrome99.curlTarget().?);
    try testing.expectEqualStrings("safari260_ios", Profile.safari260_ios.curlTarget().?);
    try testing.expectEqualStrings("tor145", Profile.tor145.curlTarget().?);
}

test "Profile.navigatorUserAgent" {
    const testing = std.testing;

    try testing.expectEqualStrings("Lightpanda/1.0", Profile.lightpanda.navigatorUserAgent());
    try testing.expect(std.mem.startsWith(u8, Profile.firefox144.navigatorUserAgent(), "Mozilla/5.0"));
    try testing.expect(std.mem.indexOf(u8, Profile.firefox144.navigatorUserAgent(), "Firefox/144.0") != null);
    try testing.expect(std.mem.indexOf(u8, Profile.chrome99.navigatorUserAgent(), "Chrome/99.0.4844.51") != null);
    try testing.expect(std.mem.indexOf(u8, Profile.safari172_ios.navigatorUserAgent(), "iPhone") != null);
}

test "Profile.platform" {
    const testing = std.testing;

    try testing.expectEqualStrings("MacIntel", Profile.lightpanda.platform());
    try testing.expectEqualStrings("MacIntel", Profile.firefox144.platform());
    try testing.expectEqualStrings("Win32", Profile.edge101.platform());
    try testing.expectEqualStrings("Win32", Profile.chrome99.platform());
    try testing.expectEqualStrings("MacIntel", Profile.chrome136.platform());
    try testing.expectEqualStrings("iPhone", Profile.safari172_ios.platform());
    try testing.expectEqualStrings("Linux armv8l", Profile.chrome99_android.platform());
}

test "Profile.vendor" {
    const testing = std.testing;

    try testing.expectEqualStrings("", Profile.lightpanda.vendor());
    try testing.expectEqualStrings("", Profile.firefox144.vendor());
    try testing.expectEqualStrings("Google Inc.", Profile.chrome136.vendor());
    try testing.expectEqualStrings("Google Inc.", Profile.chrome99.vendor());
    try testing.expectEqualStrings("Apple Computer, Inc.", Profile.safari180.vendor());
    try testing.expectEqualStrings("Apple Computer, Inc.", Profile.safari172_ios.vendor());
    try testing.expectEqualStrings("", Profile.tor145.vendor());
}
