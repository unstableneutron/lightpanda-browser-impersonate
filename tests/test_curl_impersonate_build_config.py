from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def test_build_zon_pins_curl_impersonate_sources() -> None:
    zon = read("build.zig.zon")

    assert ".curl_impersonate" in zon
    assert "unstableneutron/curl-impersonate" in zon
    assert "bf7d25e39a55f7122a349e207d2b3da1d903629c.tar.gz" in zon
    assert ".curl_impersonate_curl" in zon
    assert "curl-8_15_0.tar.gz" in zon


def test_build_zig_exposes_curl_impersonate_build_option() -> None:
    build = read("build.zig")

    assert "use_curl_impersonate" in build
    assert "Use curl-impersonate forked source" in build
    assert "if (use_curl_impersonate)" in build


def test_build_zig_uses_curl_impersonate_as_an_isolated_build_artifact() -> None:
    build = read("build.zig")

    assert "fn linkCurlImpersonate(" in build
    assert "fn buildCurlImpersonateArtifact(" in build
    assert "curl_impersonate_curl" in build
    assert "curl_impersonate" in build
    assert "curl-8_15_0.tar.gz" in build
    assert "gmake" in build
    assert "libcurl-impersonate.a" in build
    assert "mod.addObjectFile" in build
    assert "fn buildCurlFromSource(" not in build
    assert "patches/curl.patch" not in build
    assert "patches/curl-websocket-readfunction-backport.patch" not in build
