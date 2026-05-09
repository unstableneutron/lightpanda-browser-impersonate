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
    assert "--impersonate" in config
    assert "inlineValue" in cli
    assert "std.mem.indexOfScalar(u8, option_arg, '=')" in cli


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
