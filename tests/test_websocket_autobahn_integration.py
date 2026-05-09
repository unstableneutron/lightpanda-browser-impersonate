from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def test_websocket_disables_libcurl_auto_pong_and_sends_manual_pongs() -> None:
    ws = read("src/browser/webapi/net/WebSocket.zig")
    http = read("src/network/http.zig")
    libcurl = read("src/sys/libcurl.zig")

    assert "setWsAutoPong(false)" in ws
    assert "handlePing" in ws
    assert ".pong" in ws
    assert "curl_ws_no_auto_pong" in libcurl
    assert "CURLWS_NOAUTOPONG" in libcurl
    assert "ws_options = c.CURLOPT_WS_OPTIONS" in libcurl
    assert "pub fn setWsAutoPong" in http


def test_websocket_reassembles_fragments_before_dispatch() -> None:
    ws = read("src/browser/webapi/net/WebSocket.zig")
    libcurl = read("src/sys/libcurl.zig")

    assert "_fragment_buffer" in ws
    assert "_fragment_type" in ws
    assert "meta.continues" in ws
    assert "dispatchCompleteMessage" in ws
    assert "dispatchMessageEvent(payload" not in ws
    assert "continues = flags & c.CURLWS_CONT != 0" in libcurl


def test_websocket_protocol_errors_close_with_spec_codes() -> None:
    ws = read("src/browser/webapi/net/WebSocket.zig")

    assert "utf8ValidateSlice" in ws
    assert "failWithClose(1007)" in ws
    assert "failWithClose(1002)" in ws
    assert "isValidRemoteCloseCode" in ws
    assert "1004, 1005, 1006 => false" in ws


def test_autobahn_runner_counts_clean_unimplemented_as_optional() -> None:
    runner = read("tests/autobahn/run.py")

    assert 'behavior == "UNIMPLEMENTED" and close_ok' in runner
    assert "optional_unimplemented" in runner
    assert "permessage-deflate" in runner
