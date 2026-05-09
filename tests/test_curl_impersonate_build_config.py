from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def test_build_zon_pins_curl_impersonate_sources() -> None:
    zon = read("build.zig.zon")

    assert ".curl_impersonate" in zon
    assert "unstableneutron/curl-impersonate" in zon
    assert "e56e9e735b76d814217845d76fa328dc183225c9.tar.gz" in zon
    assert "bf7d25e39a55f7122a349e207d2b3da1d903629c.tar.gz" not in zon
    assert ".curl_impersonate_curl" in zon
    assert "curl-8_15_0.tar.gz" in zon


def test_build_zig_exposes_curl_impersonate_build_option() -> None:
    build = read("build.zig")

    assert "use_curl_impersonate" in build
    assert "Use curl-impersonate forked source" in build
    assert "if (use_curl_impersonate)" in build


def test_release_workflow_uses_available_static_release_runners() -> None:
    release = read(".github/workflows/release.yml")
    install = read(".github/actions/install/action.yml")

    assert "ubuntu-24.04" in release
    assert "ubuntu-24.04-arm" in release
    assert "ubuntu-22.04" not in release
    assert "ubuntu-22.04-arm" not in release
    assert "macos-15" in release
    assert "macos-15-intel" in release
    assert "macos-13" not in release
    assert "macos-14-large" not in release
    assert "HOMEBREW_NO_AUTO_UPDATE=1" in install
    assert "brew update" not in install
    assert "cache-key:" in install
    assert "cache-size-limit:" in install
    assert "inputs.os" in install
    assert "inputs.arch" in install
    assert "inputs.curl-impersonate" in install


def test_curl_impersonate_archive_does_not_bundle_duplicate_idn_libraries() -> None:
    build = read("build.zig")

    assert "const libidn2 = buildLibidn2" in build
    assert "mod.linkLibrary(libidn2)" in build
    assert "libidn2*/installed/lib/lib*.a" not in build
    assert "libunistring*/installed/lib/lib*.a" not in build
    assert "libidn2.a libunistring.a" not in build


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
