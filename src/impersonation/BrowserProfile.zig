const std = @import("std");
const curl_impersonate_profiles = @import("curl_impersonate_profiles");

const Allocator = std.mem.Allocator;

pub const BrowserFamily = enum {
    chrome,
    firefox,
    safari,
    unknown,
};

pub const BrowserIdentity = struct {
    pub const Brand = struct {
        brand: []const u8,
        version: []const u8,
    };

    family: BrowserFamily,
    user_agent: [:0]const u8,
    app_version: []const u8,
    ua_platform: []const u8,
    navigator_platform: []const u8,
    mobile: bool,
    ua_full_version: []const u8,
    brands: []Brand,
    supports_ua_data: bool,
    window_chrome: bool,
    app_code_name: []const u8,
    app_name: []const u8,
    product: []const u8,
    product_sub: []const u8,
    vendor: []const u8,
    vendor_sub: []const u8,
    do_not_track: ?[]const u8,
    global_privacy_control: ?bool,
    hardware_concurrency: u8,
    device_memory: ?f64,
    pdf_viewer_enabled: bool,

    pub fn deinit(self: BrowserIdentity, allocator: Allocator) void {
        allocator.free(self.user_agent);
        allocator.free(self.ua_full_version);
        for (self.brands) |brand| allocator.free(brand.version);
        allocator.free(self.brands);
    }
};

pub fn identityForImpersonateProfile(allocator: Allocator, profile_name: []const u8) !?BrowserIdentity {
    const profile = lookupImpersonateProfile(profile_name) orelse return null;
    if (std.mem.eql(u8, profile.family, "chrome")) {
        return try chromiumIdentity(allocator, profile);
    }
    if (std.mem.eql(u8, profile.family, "firefox")) {
        return try firefoxIdentity(allocator, profile);
    }
    if (std.mem.eql(u8, profile.family, "safari")) {
        return try safariIdentity(allocator, profile);
    }
    return null;
}

fn lookupImpersonateProfile(profile_name: []const u8) ?curl_impersonate_profiles.Profile {
    for (curl_impersonate_profiles.profiles) |profile| {
        if (std.mem.eql(u8, profile.name, profile_name)) return profile;
    }
    return null;
}

fn appVersionFromUserAgent(user_agent: []const u8) []const u8 {
    return if (std.mem.startsWith(u8, user_agent, "Mozilla/")) user_agent["Mozilla/".len..] else user_agent;
}

fn chromiumIdentity(allocator: Allocator, profile: curl_impersonate_profiles.Profile) !BrowserIdentity {
    const full_version = try std.fmt.allocPrint(allocator, "{d}.0.0.0", .{profile.version});
    errdefer allocator.free(full_version);

    const is_android = if (profile.platform) |platform| std.mem.eql(u8, platform, "android") else false;
    const user_agent = if (is_android)
        try std.fmt.allocPrintSentinel(allocator, "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/{s} Mobile Safari/537.36", .{full_version}, 0)
    else
        try std.fmt.allocPrintSentinel(allocator, "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/{s} Safari/537.36", .{full_version}, 0);
    errdefer allocator.free(user_agent);

    const major = try std.fmt.allocPrint(allocator, "{d}", .{profile.version});
    errdefer allocator.free(major);

    var brands = try allocator.alloc(BrowserIdentity.Brand, 3);
    errdefer allocator.free(brands);
    brands[0] = .{ .brand = "Chromium", .version = try allocator.dupe(u8, major) };
    errdefer allocator.free(brands[0].version);
    brands[1] = .{ .brand = "Not-A.Brand", .version = try allocator.dupe(u8, "24") };
    errdefer allocator.free(brands[1].version);
    brands[2] = .{ .brand = "Google Chrome", .version = major };

    return .{
        .family = .chrome,
        .user_agent = user_agent,
        .app_version = appVersionFromUserAgent(user_agent),
        .ua_platform = if (is_android) "Android" else "macOS",
        .navigator_platform = if (is_android) "Linux armv8l" else "MacIntel",
        .mobile = is_android,
        .ua_full_version = full_version,
        .brands = brands,
        .supports_ua_data = true,
        .window_chrome = true,
        .app_code_name = "Mozilla",
        .app_name = "Netscape",
        .product = "Gecko",
        .product_sub = "20030107",
        .vendor = "Google Inc.",
        .vendor_sub = "",
        .do_not_track = null,
        .global_privacy_control = null,
        .hardware_concurrency = 16,
        .device_memory = if (is_android) null else 8.0,
        .pdf_viewer_enabled = true,
    };
}

fn firefoxIdentity(allocator: Allocator, profile: curl_impersonate_profiles.Profile) !BrowserIdentity {
    const full_version = try std.fmt.allocPrint(allocator, "{d}.0", .{profile.version});
    errdefer allocator.free(full_version);
    const user_agent = try std.fmt.allocPrintSentinel(allocator, "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:{s}) Gecko/20100101 Firefox/{s}", .{ full_version, full_version }, 0);
    errdefer allocator.free(user_agent);
    const brands = try allocator.alloc(BrowserIdentity.Brand, 0);

    return .{
        .family = .firefox,
        .user_agent = user_agent,
        .app_version = "5.0 (Macintosh)",
        .ua_platform = "",
        .navigator_platform = "MacIntel",
        .mobile = false,
        .ua_full_version = full_version,
        .brands = brands,
        .supports_ua_data = false,
        .window_chrome = false,
        .app_code_name = "Mozilla",
        .app_name = "Netscape",
        .product = "Gecko",
        .product_sub = "20100101",
        .vendor = "",
        .vendor_sub = "",
        .do_not_track = "1",
        .global_privacy_control = true,
        .hardware_concurrency = 16,
        .device_memory = null,
        .pdf_viewer_enabled = true,
    };
}

fn safariIdentity(allocator: Allocator, profile: curl_impersonate_profiles.Profile) !BrowserIdentity {
    const major = @divTrunc(profile.version, 100);
    const minor = @mod(profile.version, 100);
    const full_version = try std.fmt.allocPrint(allocator, "{d}.{d}", .{ major, minor });
    errdefer allocator.free(full_version);
    const user_agent = try std.fmt.allocPrintSentinel(allocator, "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/{s} Safari/605.1.15", .{full_version}, 0);
    errdefer allocator.free(user_agent);
    const brands = try allocator.alloc(BrowserIdentity.Brand, 0);

    return .{
        .family = .safari,
        .user_agent = user_agent,
        .app_version = appVersionFromUserAgent(user_agent),
        .ua_platform = "",
        .navigator_platform = "MacIntel",
        .mobile = false,
        .ua_full_version = full_version,
        .brands = brands,
        .supports_ua_data = false,
        .window_chrome = false,
        .app_code_name = "Mozilla",
        .app_name = "Netscape",
        .product = "Gecko",
        .product_sub = "20030107",
        .vendor = "Apple Computer, Inc.",
        .vendor_sub = "",
        .do_not_track = null,
        .global_privacy_control = null,
        .hardware_concurrency = 8,
        .device_memory = null,
        .pdf_viewer_enabled = true,
    };
}

test "identityForImpersonateProfile exposes Chrome legacy fields" {
    var identity = (try identityForImpersonateProfile(std.testing.allocator, "chrome146")).?;
    defer identity.deinit(std.testing.allocator);

    try std.testing.expectEqual(.chrome, identity.family);
    try std.testing.expectEqualStrings("Mozilla", identity.app_code_name);
    try std.testing.expectEqualStrings("Netscape", identity.app_name);
    try std.testing.expectEqualStrings("5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36", identity.app_version);
    try std.testing.expectEqualStrings("20030107", identity.product_sub);
    try std.testing.expectEqualStrings("Google Inc.", identity.vendor);
    try std.testing.expect(identity.supports_ua_data);
    try std.testing.expect(identity.window_chrome);
}

test "identityForImpersonateProfile exposes Firefox legacy fields" {
    var identity = (try identityForImpersonateProfile(std.testing.allocator, "firefox147")).?;
    defer identity.deinit(std.testing.allocator);

    try std.testing.expectEqual(.firefox, identity.family);
    try std.testing.expectEqualStrings("Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:147.0) Gecko/20100101 Firefox/147.0", identity.user_agent);
    try std.testing.expectEqualStrings("5.0 (Macintosh)", identity.app_version);
    try std.testing.expectEqualStrings("20100101", identity.product_sub);
    try std.testing.expectEqualStrings("", identity.vendor);
    try std.testing.expectEqualStrings("1", identity.do_not_track.?);
    try std.testing.expectEqual(true, identity.global_privacy_control.?);
    try std.testing.expect(!identity.supports_ua_data);
    try std.testing.expect(!identity.window_chrome);
}

test "identityForImpersonateProfile exposes Safari legacy fields" {
    var identity = (try identityForImpersonateProfile(std.testing.allocator, "safari2601")).?;
    defer identity.deinit(std.testing.allocator);

    try std.testing.expectEqual(.safari, identity.family);
    try std.testing.expectEqualStrings("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.1 Safari/605.1.15", identity.user_agent);
    try std.testing.expectEqualStrings("Apple Computer, Inc.", identity.vendor);
    try std.testing.expectEqualStrings("20030107", identity.product_sub);
    try std.testing.expect(!identity.supports_ua_data);
    try std.testing.expect(!identity.window_chrome);
}
