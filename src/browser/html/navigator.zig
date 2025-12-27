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

const BrowserProfile = @import("../../browser_profile.zig").Profile;

// https://html.spec.whatwg.org/multipage/system-state.html#navigator
pub const Navigator = struct {
    profile: BrowserProfile = .firefox144,
    language: []const u8 = "en-US",

    pub fn get_userAgent(self: *Navigator) []const u8 {
        return self.profile.navigatorUserAgent();
    }
    pub fn get_appCodeName(_: *Navigator) []const u8 {
        return "Mozilla";
    }
    pub fn get_appName(_: *Navigator) []const u8 {
        return "Netscape";
    }
    pub fn get_appVersion(self: *Navigator) []const u8 {
        return self.profile.appVersion();
    }
    pub fn get_platform(self: *Navigator) []const u8 {
        return self.profile.platform();
    }
    pub fn get_product(_: *Navigator) []const u8 {
        return "Gecko";
    }
    pub fn get_productSub(_: *Navigator) []const u8 {
        return "20030107";
    }
    pub fn get_vendor(self: *Navigator) []const u8 {
        return self.profile.vendor();
    }
    pub fn get_vendorSub(_: *Navigator) []const u8 {
        return "";
    }
    pub fn get_language(self: *Navigator) []const u8 {
        return self.language;
    }
    // TODO wait for arrays.
    //pub fn get_languages(self: *Navigator) [][]const u8 {
    //    return .{self.language};
    //}
    pub fn get_online(_: *Navigator) bool {
        return true;
    }
    pub fn _registerProtocolHandler(_: *Navigator, scheme: []const u8, url: []const u8) void {
        _ = scheme;
        _ = url;
    }
    pub fn _unregisterProtocolHandler(_: *Navigator, scheme: []const u8, url: []const u8) void {
        _ = scheme;
        _ = url;
    }

    pub fn get_cookieEnabled(_: *Navigator) bool {
        return true;
    }

    pub fn get_hardwareConcurrency(_: *Navigator) u32 {
        return 8;
    }

    pub fn get_deviceMemory(_: *Navigator) f64 {
        return 8.0;
    }

    pub fn get_maxTouchPoints(_: *Navigator) u32 {
        return 0;
    }

    pub fn get_webdriver(_: *Navigator) bool {
        return false;
    }

    pub fn get_pdfViewerEnabled(_: *Navigator) bool {
        return true;
    }
};

const testing = @import("../../testing.zig");
test "Browser: HTML.Navigator" {
    try testing.htmlRunner("html/navigator.html");
}
