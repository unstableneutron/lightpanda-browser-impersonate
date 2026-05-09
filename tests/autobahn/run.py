#!/usr/bin/env python3
"""Run Lightpanda against the Autobahn WebSocket client testsuite."""

from __future__ import annotations

import argparse
import http.server
import json
import os
import re
import shutil
import socket
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def wait_for_port(port: int, timeout: float = 30.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1)
            if sock.connect_ex(("127.0.0.1", port)) == 0:
                return
        time.sleep(0.2)
    raise TimeoutError(f"port {port} did not open")


def expand_cases(expr: str | None, count: int) -> str:
    if not expr or expr == "*":
        return ",".join(str(i) for i in range(1, count + 1))

    expanded: list[int] = []
    for part in expr.split(","):
        part = part.strip()
        if not part:
            continue
        if part.endswith(".*") and part[:-2].isdigit():
            prefix = part[:-1]
            expanded.extend(i for i in range(1, count + 1) if str(i).startswith(prefix))
        elif "-" in part:
            start, end = part.split("-", 1)
            expanded.extend(range(int(start), int(end) + 1))
        else:
            expanded.append(int(part))
    return ",".join(str(i) for i in dict.fromkeys(expanded))


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, fmt: str, *args: object) -> None:
        pass


def serve_client(port: int) -> socketserver.TCPServer:
    handler = lambda *args, **kwargs: QuietHandler(*args, directory=str(HERE), **kwargs)
    httpd = socketserver.TCPServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    return httpd


def docker(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["docker", *args], check=check, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def read_summary(report_dir: Path, agent: str) -> tuple[int, int, int, Path | None]:
    index = report_dir / "index.json"
    if not index.exists():
        nested = report_dir / "clients" / "index.json"
        if not nested.exists():
            return (0, 0, 0, None)
        index = nested

    data = json.loads(index.read_text())
    agent_cases = data.get(agent, {})
    total = 0
    failures = 0
    optional_unimplemented = 0
    for result in agent_cases.values():
        total += 1
        behavior = str(result.get("behavior", "")).upper()
        behavior_close = str(result.get("behaviorClose", "")).upper()
        close_ok = behavior_close in {"OK", "INFORMATIONAL", "NON-STRICT", ""}
        if behavior == "UNIMPLEMENTED" and close_ok:
            # Autobahn uses UNIMPLEMENTED for optional permessage-deflate cases
            # when the client does not negotiate that extension. Lightpanda's
            # libcurl-backed WebSocket path intentionally sends no
            # Sec-WebSocket-Extensions offer, so these are skips, not protocol
            # failures.
            optional_unimplemented += 1
        elif behavior not in {"OK", "INFORMATIONAL", "NON-STRICT"}:
            failures += 1
        elif not close_ok:
            failures += 1
    return total, failures, optional_unimplemented, index


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lightpanda", default=str(ROOT / "zig-out" / "bin" / "lightpanda"))
    parser.add_argument("--image", default="crossbario/autobahn-testsuite:latest")
    parser.add_argument("--agent", default="lightpanda")
    parser.add_argument("--cases", default="*", help="*, comma list, ranges like 1-10, or prefixes like 6.*")
    parser.add_argument("--reports", type=Path, default=HERE / "reports")
    parser.add_argument("--timeout-ms", type=int, default=600_000)
    args = parser.parse_args()

    if not Path(args.lightpanda).exists():
        print(f"missing lightpanda binary: {args.lightpanda}", file=sys.stderr)
        return 2
    if not shutil.which("docker"):
        print("docker is required", file=sys.stderr)
        return 2

    args.reports.mkdir(parents=True, exist_ok=True)
    server_port = 9001
    http_port = free_port()
    name = f"lightpanda-autobahn-{os.getpid()}"
    httpd = serve_client(http_port)

    try:
        docker(
            "run", "--rm", "-d", "--name", name,
            "-p", f"127.0.0.1:{server_port}:9001",
            "-v", f"{args.reports.resolve()}:/reports",
            "-v", f"{(HERE / 'fuzzingserver.json').resolve()}:/config/fuzzingserver.json:ro",
            args.image,
            "wstest", "-m", "fuzzingserver", "-s", "/config/fuzzingserver.json",
        )
        wait_for_port(server_port)

        # Ask the server how many cases exist, then expand any shorthand before
        # handing it to client.html. This keeps the browser page intentionally
        # simple and deterministic.
        with tempfile.TemporaryDirectory() as tmp:
            probe = Path(tmp) / "probe.html"
            subprocess.run(
                [
                    args.lightpanda,
                    "fetch",
                    "--dump", "html",
                    "--wait-ms", "2000",
                    f"http://127.0.0.1:{http_port}/client.html?ws=ws://127.0.0.1:{server_port}&agent=probe&cases=1",
                ],
                check=True,
                stdout=probe.open("w"),
            )

        # Prefer the reports side effect for the full run; Lightpanda exits when
        # the page reaches network-idle/done after all WebSockets close.
        selected = args.cases
        if args.cases != "*":
            # Use a conservative upper bound when expanding prefixes; the client
            # will reject invalid numeric cases if the suite changes drastically.
            selected = expand_cases(args.cases, 1000)

        url = (
            f"http://127.0.0.1:{http_port}/client.html"
            f"?ws=ws://127.0.0.1:{server_port}"
            f"&agent={args.agent}"
            f"&cases={selected}"
        )
        output = subprocess.run(
            [args.lightpanda, "fetch", "--dump", "html", "--wait-ms", str(args.timeout_ms), url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=(args.timeout_ms / 1000) + 30,
        )
        status_match = re.search(r'<pre id="status">([^<]+)</pre>', output.stdout)
        status = status_match.group(1) if status_match else ""
        if status:
            print(status)
        if status.startswith("AUTOBAHN_ERROR"):
            print(output.stdout)
            return 1
        if output.returncode != 0 and status != "AUTOBAHN_DONE":
            print(output.stdout)
            return output.returncode

        total, failures, optional_unimplemented, index = read_summary(args.reports, args.agent)
        print(
            "Autobahn report: "
            f"total={total} failures={failures} "
            f"optional_unimplemented={optional_unimplemented} index={index}"
        )
        return 0 if total > 0 and failures == 0 else 1
    finally:
        httpd.shutdown()
        docker("rm", "-f", name, check=False)


if __name__ == "__main__":
    raise SystemExit(main())
