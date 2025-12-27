# LightPanda Bot Detection Reduction - Integration Plan

## Status: Phase 1 Complete ✅

### Completed
- ✅ `--impersonate` CLI flag with browser profile support
- ✅ JavaScript Navigator properties match selected browser profile
- ✅ User-Agent header matches selected browser profile
- ✅ Anti-bot detection properties (webdriver=false, hardwareConcurrency, deviceMemory, etc.)

### Deferred
- ⏳ `curl-impersonate` TLS/HTTP2 fingerprint matching (requires building from source with patched BoringSSL)

---

## Overview

This plan outlines steps to reduce bot detection by:
1. ✅ Adding `--impersonate` CLI flag with browser profile support
2. ⏳ Integrating `curl-impersonate` for TLS/HTTP2 fingerprint matching
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

```bash
# Start with default Firefox 144 profile
./lightpanda serve --host 127.0.0.1 --port 9222

# Start with Chrome profile
./lightpanda serve --host 127.0.0.1 --port 9222 --impersonate chrome136

# Start with Safari profile
./lightpanda serve --host 127.0.0.1 --port 9222 --impersonate safari180

# Start with original LightPanda behavior (no impersonation)
./lightpanda serve --host 127.0.0.1 --port 9222 --impersonate lightpanda
```

---

## Implementation Details

### Files Modified

| File | Changes |
|------|---------|
| `src/browser_profile.zig` | **NEW** - Browser profile enum with UA/platform/vendor mappings |
| `src/main.zig` | Added `--impersonate` CLI flag, profile parsing |
| `src/app.zig` | Added `impersonate` to Config struct |
| `src/browser/html/navigator.zig` | Dynamic Navigator properties from profile |
| `src/browser/page.zig` | Wire profile from App to Window/Navigator |
| `src/http/Http.zig` | Profile field in HTTP Opts (for future TLS use) |

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

## Phase 2: TLS Fingerprinting (Deferred)

### Why Deferred

The prebuilt `libcurl-impersonate` binaries from lexiforest/curl-impersonate have incompatible dependencies:
- Built against a **patched BoringSSL** with custom functions (`SSL_CTX_set_delegated_credentials`, etc.)
- Requires c-ares, ngtcp2, nghttp3 for HTTP/3 support
- LightPanda uses standard boringssl-zig which lacks the patched functions

### Future Implementation Options

1. **Build curl-impersonate from source** with its patched BoringSSL
   - Clone lexiforest/curl-impersonate
   - Build with their patched BoringSSL fork
   - Link all dependencies (ngtcp2, nghttp3, c-ares, zstd, brotli)

2. **Replace boringssl-zig** with curl-impersonate's patched version
   - Significant build system changes
   - May affect V8 compatibility

3. **Application-level TLS options** (limited effectiveness)
   - Set cipher suites, curves, TLS version via standard curl options
   - Won't match browser fingerprints exactly

### curl-impersonate API Reference

```c
// Function signature from curl-impersonate
CURLcode curl_easy_impersonate(CURL *curl, const char *target, int default_headers);

// Example usage (when integrated)
curl_easy_impersonate(easy_handle, "firefox144", 1);
```

---

## Verification

### Test Script

```bash
# Start server
./lightpanda serve --host 127.0.0.1 --port 9222 --impersonate firefox144

# Run test
cd bot-test && node test-ua.mjs
```

### Expected Output

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

## References

- [lexiforest/curl-impersonate](https://github.com/lexiforest/curl-impersonate) - curl fork with browser TLS fingerprinting
- [TLS Fingerprinting](https://lwthiker.com/networks/2022/06/17/tls-fingerprinting.html) - Background on TLS fingerprinting
- [HTTP/2 Fingerprinting](https://lwthiker.com/networks/2022/06/17/http2-fingerprinting.html) - Background on HTTP/2 fingerprinting
