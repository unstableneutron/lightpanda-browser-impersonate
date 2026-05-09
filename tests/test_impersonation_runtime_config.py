from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def test_config_accepts_cli_and_env_impersonation() -> None:
    config = read("src/Config.zig")
    cli = read("src/cli.zig")

    assert '.{ .name = "impersonate", .type = ?[:0]const u8 }' in config
    assert "LIGHTPANDA_IMPERSONATE" in config
    assert "pub fn impersonateProfile" in config
    assert "curl_impersonate_profiles.aliases" in config
    assert "canonicalizeImpersonateAlias" in config
    assert "--impersonate" in config
    assert "inlineValue" in cli
    assert "std.mem.indexOfScalar(u8, option_arg, '=')" in cli


def test_build_zig_generates_impersonation_aliases_from_curl_impersonate_profiles() -> None:
    build = read("build.zig")

    assert "fn generateCurlImpersonateProfilesModule" in build
    assert 'b.dependency("curl_impersonate", .{})' in build
    assert 'impersonate.path("bin")' in build
    assert 'std.mem.startsWith(u8, entry.name, "curl_")' in build
    assert "fn parseImpersonateProfile" in build
    assert "fn bestProfile" in build
    assert "addSafariMajorAliases" in build
    assert "addMobileAliases" in build
    assert 'mod.addImport("curl_impersonate_profiles", curl_impersonate_profiles)' in build


def test_impersonation_aliases_support_bare_browser_major_mobile_and_separator_forms() -> None:
    config = read("src/Config.zig")

    assert 'expectNormalizedImpersonateProfile("chrome", "chrome146")' in config
    assert 'expectNormalizedImpersonateProfile("firefox", "firefox147")' in config
    assert 'expectNormalizedImpersonateProfile("safari", "safari2601")' in config
    assert 'expectNormalizedImpersonateProfile("safari26", "safari2601")' in config
    assert 'expectNormalizedImpersonateProfile("safari18", "safari184")' in config
    assert 'expectNormalizedImpersonateProfile("safari-ios", "safari260_ios")' in config
    assert 'expectNormalizedImpersonateProfile("safari_ios26", "safari260_ios")' in config
    assert 'expectNormalizedImpersonateProfile("safari26_ios", "safari260_ios")' in config
    assert 'expectNormalizedImpersonateProfile("chrome-android", "chrome131_android")' in config
    assert 'expectNormalizedImpersonateProfile("chrome_mobile", "chrome131_android")' in config


def test_libcurl_wrapper_exposes_impersonation_only_for_impersonate_builds() -> None:
    wrapper = read("src/sys/libcurl.zig")

    assert 'const build_config = @import("build_config");' in wrapper
    assert "pub fn curl_easy_impersonate" in wrapper
    assert "build_config.use_curl_impersonate" in wrapper
    assert "c.curl_easy_impersonate" in wrapper
    assert "Error.NotBuiltIn" in wrapper


def test_connection_applies_impersonation_before_other_easy_options() -> None:
    http = read("src/network/http.zig")

    reset = http[http.index("pub fn reset(") : http.index("    fn discardBody", http.index("pub fn reset("))]

    assert "config.impersonateProfile()" in reset
    assert "curl_easy_impersonate" in reset
    assert reset.index("curl_easy_impersonate") < reset.index(".timeout_ms")


def test_impersonation_keeps_curl_impersonate_default_headers_in_control() -> None:
    http_client = read("src/browser/HttpClient.zig")
    http = read("src/network/http.zig")

    assert "if (self.network.config.impersonateProfile() != null)" in http_client
    assert "return .{ .headers = null }" in http_client
    assert "if (http_headers.impersonated)" in http
