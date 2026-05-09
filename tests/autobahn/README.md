# Autobahn WebSocket client compliance

This directory contains a manual/CI-friendly harness for validating
Lightpanda's browser-facing WebSocket implementation against the Autobahn
Testsuite fuzzing server.

The harness intentionally lives in Lightpanda, not curl-impersonate: the goal is
to validate the full browser API + event loop + libcurl integration path.

## Run locally

Build Lightpanda first, preferably with curl-impersonate enabled:

```sh
zig build -Duse_curl_impersonate=true --release=fast
```

Then run:

```sh
uv run --isolated python tests/autobahn/run.py --lightpanda ./zig-out/bin/lightpanda
```

The runner starts `crossbario/autobahn-testsuite` with Docker, serves
`client.html` from a local HTTP server, and asks Lightpanda to load it. Reports
are written to `tests/autobahn/reports/`.

Use `--cases 1,2,6.*` for a quick subset while iterating. The runner treats
Autobahn `UNIMPLEMENTED` results with a clean close as optional skips. In
practice these are permessage-deflate extension cases: Lightpanda's libcurl
WebSocket path does not send a `Sec-WebSocket-Extensions` offer, so those cases
are not negotiated and are not protocol failures.
