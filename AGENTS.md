# Lightpanda Browser - Agent Instructions

## Build & Test Commands
- **Build debug**: `zig build` or `make build-dev`
- **Build release**: `make build` or `zig build -Doptimize=ReleaseSafe`
- **Run all tests**: `make test` or `zig build test --summary all`
- **Run single test**: `make test F="test_name"` (e.g., `make test F="xhr"`)
- **Run with curl-impersonate**: `USE_CURL_IMPERSONATE=1 make build`

## Architecture
- **Language**: Zig (0.15.2) with V8 JavaScript engine
- **src/browser/**: Core browser engine (DOM, page lifecycle, XHR, storage)
- **src/http/**: HTTP client using libcurl (Client.zig manages transfers)
- **src/cdp/**: Chrome DevTools Protocol server for Puppeteer/Playwright
- **vendor/**: Dependencies (curl, netsurf DOM parser, nghttp2, boringssl)

## Code Style
- Use `std.debug.assert` for invariants; use `log.err/warn/debug` for logging
- Error handling: Return errors with `try`, use `catch |err|` for handling
- Naming: snake_case for functions/variables, PascalCase for types
- No comments unless complex logic requires explanation
- Use `error.X` for error comparisons (e.g., `err == error.RecursiveApiCall`)
- Prefer `orelse return null` pattern over explicit null checks
