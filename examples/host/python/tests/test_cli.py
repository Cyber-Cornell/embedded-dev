"""Tests against pyserial's loop:// port, which echoes back what it is sent."""

from __future__ import annotations

import io

import pytest
import serial
from serial.tools.list_ports_common import ListPortInfo
from serial.urlhandler.protocol_loop import Serial as LoopSerial

from mcu_tool import cli


@pytest.fixture
def loop() -> serial.SerialBase:
    return serial.serial_for_url("loop://", timeout=0.05)


def test_parse_payload_text_adds_line_ending() -> None:
    assert cli.parse_payload("ping", hex_mode=False, eol="crlf") == b"ping\r\n"
    assert cli.parse_payload("ping", hex_mode=False, eol="none") == b"ping"


def test_parse_payload_hex_ignores_eol() -> None:
    assert (
        cli.parse_payload("de ad BE ef", hex_mode=True, eol="lf") == b"\xde\xad\xbe\xef"
    )
    with pytest.raises(ValueError, match="non-hexadecimal"):
        cli.parse_payload("xyz", hex_mode=True, eol="lf")


def test_render() -> None:
    assert cli.render(b"hi\xff", hex_mode=False) == "hi�"
    assert cli.render(b"\x01\xab", hex_mode=True) == "01 ab "


def test_exchange_returns_reply(loop: serial.SerialBase) -> None:
    assert cli.exchange(loop, b"ping\n", timeout=1, idle=0.05) == b"ping\n"


class SilentPort(LoopSerial):
    """A loop:// port whose far end never answers."""

    def write(self, b: bytes) -> int:  # type: ignore[override]
        return len(b)


def test_exchange_times_out_without_reply() -> None:
    silent = SilentPort("loop://", timeout=0.01)
    assert cli.exchange(silent, b"ping", timeout=0.1, idle=0.05) == b""


def test_printer_timestamps_each_line() -> None:
    out, log = io.StringIO(), io.BytesIO()
    show = cli.Printer(out, hex_mode=False, timestamps=True, log=log)
    show(b"one\ntw")
    show(b"o\nthree")
    lines = out.getvalue().splitlines()
    assert [line.split("] ", 1)[1] for line in lines] == ["one", "two", "three"]
    assert all(line.startswith("[") for line in lines)
    assert log.getvalue() == b"one\ntwo\nthree"


def test_describe_known_board() -> None:
    port = ListPortInfo("/dev/ttyACM0")
    port.vid, port.pid = 0x2E8A, 0x000A
    assert "Pico" in cli.describe(port)


def test_send_command(capsys: pytest.CaptureFixture[str]) -> None:
    status = cli.main(["send", "--port", "loop://", "--expect", "hel+o", "hello"])
    assert status == 0
    assert capsys.readouterr().out == "hello\n"


def test_send_command_expect_mismatch(capsys: pytest.CaptureFixture[str]) -> None:
    assert cli.main(["send", "-p", "loop://", "--expect", "^bye", "hello"]) == 1
    assert "did not match" in capsys.readouterr().err


def test_pick_port_prefers_argument_then_environment(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("MCU_PORT", "/dev/ttyUSB7")
    assert cli.pick_port("/dev/ttyACM0") == "/dev/ttyACM0"
    assert cli.pick_port(None) == "/dev/ttyUSB7"
