import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def test_build_zon_uses_0_2_9_dev_base_version() -> None:
    zon = read("build.zig.zon")

    assert '.version = "0.2.9-dev"' in zon
    assert '.version = "1.0.0-dev"' not in zon


def test_build_zon_pins_curl_impersonate_sources_for_source_build_fallback() -> None:
    zon = read("build.zig.zon")

    assert ".curl_impersonate" in zon
    assert "unstableneutron/curl-impersonate" in zon
    assert "e56e9e735b76d814217845d76fa328dc183225c9.tar.gz" in zon
    assert "bf7d25e39a55f7122a349e207d2b3da1d903629c.tar.gz" not in zon
    assert ".curl_impersonate_curl" in zon
    assert "curl-8_15_0.tar.gz" in zon


def test_build_zig_exposes_curl_impersonate_build_options() -> None:
    build = read("build.zig")

    assert "use_curl_impersonate" in build
    assert "Use curl-impersonate fork release artifacts" in build
    assert "curl_impersonate_source_build" in build
    assert "Build curl-impersonate from source instead of using release artifacts" in build
    assert "if (use_curl_impersonate)" in build


def test_release_workflow_uses_short_tag_as_release_version() -> None:
    release = read(".github/workflows/release.yml")

    assert "VERSION_FLAG: ${{ github.ref_type == 'tag' && format('-Dversion={0}', github.ref_name) || '-Dversion=nightly' }}" in release
    assert "CURL_IMPERSONATE_VERSION" not in release
    assert "+curlimp" not in release
    assert "+curl-impersonate" not in release


def test_release_workflow_uses_available_static_release_runners() -> None:
    release = read(".github/workflows/release.yml")
    install = read(".github/actions/install/action.yml")

    assert "ubuntu-24.04" in release
    assert "ubuntu-24.04-arm" in release
    assert "target_flag: -Dtarget=x86_64-linux-gnu" in release
    assert "target_flag: -Dtarget=aarch64-linux-gnu" in release
    assert "${{ matrix.target_flag }} ${{ matrix.cpu_flag }}" in release
    assert "ubuntu-22.04" not in release
    assert "ubuntu-22.04-arm" not in release
    assert "macos-15" in release
    assert "macos-15-intel" in release
    assert "macos-13" not in release
    assert "macos-14-large" not in release
    assert "curl-impersonate-source-build" in install
    assert "inputs.curl-impersonate-source-build == 'true'" in install
    assert "sudo apt-get install -y wget curl" in install
    assert "HOMEBREW_NO_AUTO_UPDATE=1" in install
    assert "brew update" not in install
    assert "cache-key:" in install
    assert "cache-size-limit:" in install
    assert "inputs.os" in install
    assert "inputs.arch" in install
    assert "inputs.curl-impersonate" in install


def test_source_built_curl_impersonate_archive_does_not_bundle_duplicate_idn_libraries() -> None:
    build = read("build.zig")

    assert "if (source_build or target.result.os.tag == .macos)" in build
    assert "addLibidn2Headers(b, mod)" in build
    assert "const libidn2 = buildLibidn2" in build
    assert "mod.linkLibrary(libidn2)" in build
    assert "libidn2*/installed/lib/lib*.a" not in build
    assert "libunistring*/installed/lib/lib*.a" not in build
    assert "libidn2.a libunistring.a" not in build


def test_build_zig_uses_curl_impersonate_release_archives_by_default() -> None:
    build = read("build.zig")

    tag = "v1.5.6-lightpanda.wsstartframe.1"
    assert "fn linkCurlImpersonate(" in build
    assert "fn curlImpersonatePrebuiltArtifact(" in build
    assert f'const curl_impersonate_release_tag = "{tag}";' in build
    assert f'const curl_impersonate_version_metadata = "curl-impersonate-" ++ curl_impersonate_release_tag;' in build
    assert 'const tag = curl_impersonate_release_tag;' in build
    assert len(re.findall(tag, build)) == 1
    assert f"libcurl-impersonate-{{s}}.{{s}}.tar.gz" in build
    for host in (
        "x86_64-linux-gnu",
        "aarch64-linux-gnu",
        "x86_64-macos",
        "arm64-macos",
    ):
        assert host in build
    for sha256 in (
        "5a6863e5552494446d81742bc8c2a611b1c071d0777ffe3f1f85d21ac80b84b2",
        "f060c1209613e3023ddfbc64d06c246cb55f4126af44f794fad691fe0da358bb",
        "516136a7af2e62981cfeffcc91a92cbcae33b8babf7161160edccc2400d4334b",
        "9684ddbbc2f996eaaacb2f7a4fa8207d7db794e0687c175b99d2fb0f4002ac04",
    ):
        assert sha256 in build
    assert "curl -fL --retry 3" in build
    assert "sha256sum -c -" in build
    assert "shasum -a 256 -c -" in build
    assert "libcurl-impersonate.a" in build
    assert "mod.addObjectFile" in build


def test_build_zig_embeds_curl_impersonate_version_metadata() -> None:
    build = read("build.zig")

    assert "resolveVersion(b, use_curl_impersonate)" in build
    assert "fn withCurlImpersonateMetadata(" in build
    assert "curl_impersonate_version_metadata" in build
    assert "curl-impersonate-" in build
    assert "Explicit semantic versions are" in build
    assert "not commit-count enriched" in build


def test_build_zig_keeps_curl_impersonate_source_build_as_fallback() -> None:
    build = read("build.zig")

    assert "fn buildCurlImpersonateArtifact(" in build
    assert "curl_impersonate_curl" in build
    assert "curl_impersonate" in build
    assert "curl-8_15_0.tar.gz" in build
    assert "gmake" in build
    assert "fn buildCurlFromSource(" not in build
    assert "patches/curl.patch" not in build
    assert "patches/curl-websocket-readfunction-backport.patch" not in build
