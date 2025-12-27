# LightPanda Bot Detection Reduction - Integration Plan

## Status: Phase 2 Complete ✅

### Completed
- ✅ `--impersonate` CLI flag with browser profile support
- ✅ JavaScript Navigator properties match selected browser profile
- ✅ User-Agent header matches selected browser profile
- ✅ Anti-bot detection properties (webdriver=false, hardwareConcurrency, deviceMemory, etc.)
- ✅ **curl-impersonate TLS/HTTP2 fingerprint matching** (git submodule, built from source)

---

## Overview

This plan outlines steps to reduce bot detection by:
1. ✅ Adding `--impersonate` CLI flag with browser profile support
2. ✅ Integrating `curl-impersonate` for TLS/HTTP2 fingerprint matching
3. ✅ Fixing JavaScript Navigator properties to match selected browser
4. ✅ Ensuring consistency between HTTP headers and JS properties

**Default Profile**: `firefox144` (latest Firefox)
**Fallback Profile**: `lightpanda` or `default` (no impersonation, original behavior)

---

## Supported Browser Profiles

| Profile | Description | Status |
|---------|-------------|--------|
| `firefox144` | **Default** - Firefox 144 | ✅ Implemented |
| `firefox135` | Firefox 135 | ✅ Implemented |
| `chrome136` | Chrome 136 | ✅ Implemented |
| `chrome131` | Chrome 131 | ✅ Implemented |
| `safari180` | Safari 18.0 | ✅ Implemented |
| `edge101` | Edge 101 | ✅ Implemented |
| `lightpanda` | No impersonation - original behavior | ✅ Implemented |
| `default` | Alias for `lightpanda` | ✅ Implemented |

---

## Usage

### Building with curl-impersonate (TLS fingerprinting enabled)

```bash
# First, build curl-impersonate (one-time, takes ~5-10 minutes)
make install-curl-impersonate

# Build LightPanda with TLS fingerprinting
zig build -Duse_curl_impersonate=true

# Start with Firefox 144 TLS fingerprint
./zig-out/bin/lightpanda serve --host 127.0.0.1 --port 9222 --impersonate firefox144

# Start with Chrome profile
./zig-out/bin/lightpanda serve --host 127.0.0.1 --port 9222 --impersonate chrome136
```

### Building without curl-impersonate (standard build)

```bash
# Standard build (Navigator properties only, no TLS fingerprinting)
zig build

# Start with default Firefox profile
./zig-out/bin/lightpanda serve --host 127.0.0.1 --port 9222
```

### Prerequisites for curl-impersonate build

On macOS:
```bash
brew install cmake ninja autoconf automake libtool go zstd
```

On Ubuntu/Debian:
```bash
sudo apt install build-essential pkg-config cmake ninja-build curl autoconf automake libtool golang-go zstd libzstd-dev
```

---

## Implementation Details

### Files Modified

| File | Changes |
|------|---------|
| `src/browser_profile.zig` | Browser profile enum with UA/platform/vendor/curlTarget mappings |
| `src/main.zig` | `--impersonate` CLI flag, profile parsing |
| `src/app.zig` | `impersonate` field in Config struct |
| `src/browser/html/navigator.zig` | Dynamic Navigator properties from profile |
| `src/browser/page.zig` | Wire profile from App to Window/Navigator |
| `src/http/Http.zig` | Profile field in Opts, `curl_easy_impersonate()` call |
| `build.zig` | `-Duse_curl_impersonate` flag, linking curl-impersonate libs |
| `Makefile` | `install-curl-impersonate` target |
| `vendor/curl-impersonate/` | Git submodule (lexiforest/curl-impersonate) |

### Directory Structure

```
vendor/curl-impersonate/
├── (git submodule → github.com/lexiforest/curl-impersonate)
├── build/                    # Build directory (created by make)
│   ├── boringssl-*/
│   ├── brotli-*/
│   ├── curl-*/
│   ├── nghttp2-*/
│   ├── ngtcp2-*/
│   ├── nghttp3-*/
│   └── c-ares-*/
└── out/
    └── macos-aarch64/        # Platform-specific outputs
        ├── lib/
        │   ├── libcurl-impersonate.a
        │   ├── libssl.a
        │   ├── libcrypto.a
        │   └── ...
        └── include/
            ├── curl/
            └── openssl/
```

### Navigator Properties by Profile

| Property | firefox144 | chrome136 | safari180 | edge101 | lightpanda |
|----------|------------|-----------|-----------|---------|------------|
| userAgent | Firefox/144.0 | Chrome/136.0.0.0 | Safari/605.1.15 | Edge/101.0.1210.53 | Lightpanda/1.0 |
| platform | MacIntel | MacIntel | MacIntel | Win32 | MacIntel |
| vendor | "" | Google Inc. | Apple Computer, Inc. | Google Inc. | "" |
| webdriver | false | false | false | false | false |
| hardwareConcurrency | 8 | 8 | 8 | 8 | 8 |
| deviceMemory | 8 | 8 | 8 | 8 | 8 |
| maxTouchPoints | 0 | 0 | 0 | 0 | 0 |
| pdfViewerEnabled | true | true | true | true | true |

---

## Phase 2: curl-impersonate Integration

### Why Build from Source?

The curl-impersonate integration requires building from source because:
- It uses a **patched BoringSSL** with custom TLS fingerprinting extensions
- The patched BoringSSL includes: delegated credentials, extension order control, key shares limit, etc.
- Standard boringssl-zig lacks these patched functions
- Pre-built binaries have incompatible dependencies

### Git Submodule

curl-impersonate is added as a git submodule pointing to upstream:
```
[submodule "vendor/curl-impersonate"]
    path = vendor/curl-impersonate
    url = https://github.com/lexiforest/curl-impersonate.git
```

### Dependencies Built by `make install-curl-impersonate`

| Library | Version | Purpose |
|---------|---------|---------|
| BoringSSL | patched | TLS with custom fingerprinting extensions |
| brotli | 1.1.0 | Compression |
| nghttp2 | 1.63.0 | HTTP/2 support |
| ngtcp2 | 1.11.0 | QUIC/HTTP/3 support |
| nghttp3 | 1.9.0 | HTTP/3 support |
| c-ares | 1.30.0 | Async DNS resolution |
| curl | 8.15.0-IMPERSONATE | Modified curl with impersonation |

### TLS Fingerprint Features

When built with `-Duse_curl_impersonate=true`:
- Cipher suites match real browser ordering
- TLS extensions match browser fingerprint
- HTTP/2 settings (SETTINGS frame) match browser
- Pseudo-header order matches browser
- ECH (Encrypted Client Hello) support
- Post-quantum key exchange (X25519MLKEM768)

### curl_easy_impersonate API

In Http.zig:
```zig
if (comptime USE_CURL_IMPERSONATE) {
    if (opts.impersonate.curlTarget()) |target| {
        // curl_easy_impersonate must be called BEFORE other curl options
        // The second parameter (1) means use default headers matching the browser
        try errorCheck(c.curl_easy_impersonate(easy, target.ptr, 1));
    }
}
```

---

## Verification

### Test Navigator Properties

```bash
# Start server with TLS fingerprinting
./zig-out/bin/lightpanda serve --host 127.0.0.1 --port 9222 --impersonate firefox144

# Run test
cd bot-test && node test-ua.mjs
```

### Test TLS Fingerprint

```bash
# Build and test curl-impersonate directly
./vendor/curl-impersonate/build/curl-*/src/curl-impersonate \
    --impersonate firefox144 \
    https://tls.peet.ws/api/all
```

### Expected Navigator Output

```json
{
  "userAgent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:144.0) Gecko/20100101 Firefox/144.0",
  "platform": "MacIntel",
  "vendor": "",
  "webdriver": false,
  "hardwareConcurrency": 8,
  "deviceMemory": 8,
  "maxTouchPoints": 0,
  "pdfViewerEnabled": true
}
```

---

## Updating curl-impersonate

To update to a newer version:

```bash
# Update submodule to latest
cd vendor/curl-impersonate
git fetch origin
git checkout <new-tag-or-commit>
cd ../..

# Rebuild
make clean-curl-impersonate
make install-curl-impersonate

# Test
zig build -Duse_curl_impersonate=true
```

---

## References

- [lexiforest/curl-impersonate](https://github.com/lexiforest/curl-impersonate) - curl fork with browser TLS fingerprinting
- [TLS Fingerprinting](https://lwthiker.com/networks/2022/06/17/tls-fingerprinting.html) - Background on TLS fingerprinting
- [HTTP/2 Fingerprinting](https://lwthiker.com/networks/2022/06/17/http2-fingerprinting.html) - Background on HTTP/2 fingerprinting
- [tls.peet.ws](https://tls.peet.ws/api/all) - TLS fingerprint testing service
