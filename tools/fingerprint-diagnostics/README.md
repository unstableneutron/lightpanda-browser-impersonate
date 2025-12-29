# Fingerprint Diagnostics

Manual diagnostic tools for testing browser fingerprinting and bot detection. These are **not automated tests** — they require a running LightPanda browser and external network access, with results that need human interpretation.

## Prerequisites

1. LightPanda browser running with CDP enabled:
   ```bash
   # From repo root
   ./zig-out/bin/lightpanda serve --host 127.0.0.1 --port 9222
   ```

2. [Bun](https://bun.sh) runtime

## Setup

```bash
cd tools/fingerprint-diagnostics
bun install
```

## Usage

### Bot Detection Test
Tests against [browserscan.net](https://www.browserscan.net/bot-detection) to see if the browser is detected as a bot:

```bash
bun run bot-detection
```

### User-Agent Check
Checks navigator properties and verifies the UA seen by external servers:

```bash
bun run ua-check
```

### Run All Diagnostics
```bash
bun run all
```

## Configuration

Set `LIGHTPANDA_WS` environment variable to use a different WebSocket endpoint:

```bash
LIGHTPANDA_WS=ws://192.168.1.100:9222 bun run bot-detection
```

## Interpreting Results

### Bot Detection
- Look for "Human" vs "Bot" indicators in the page content
- Check navigator properties for suspicious values (e.g., `webdriver: true`)

### UA Check
- Verify `userAgent` matches expected Chrome/browser string
- Confirm `platform`, `vendor`, `languages` are consistent
- Compare ifconfig.co response UA with navigator.userAgent

## Adding New Diagnostics

Create new `.mjs` files in `src/` and add corresponding npm scripts to `package.json`.

Common fingerprinting vectors to test:
- Canvas fingerprint
- WebGL renderer/vendor
- AudioContext fingerprint
- Screen resolution/color depth
- Timezone consistency
- Font enumeration
