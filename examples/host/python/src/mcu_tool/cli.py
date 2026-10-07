"""mcu: talk to a microcontroller over a serial port.

    mcu ports                      list serial ports and guess what's on them
    mcu monitor [-p PORT] [-b N]   interactive terminal (Ctrl-C to quit)
    mcu send [-p PORT] DATA        send one message, print the reply
    mcu bootsel [-p PORT]          reboot a Pico running pico-sdk USB stdio
                                   into BOOTSEL mode

With one USB serial device plugged in, --port can be left out. MCU_PORT and
MCU_BAUD set defaults. --port also takes pyserial URLs such as loop:// (an
echo port for trying things out) or rfc2217://host:port.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import threading
import time
from collections.abc import Sequence
from datetime import datetime
from pathlib import Path
from typing import BinaryIO, TextIO

import serial
from serial.tools import list_ports
from serial.tools.list_ports_common import ListPortInfo

# USB vendor/product IDs of the boards and probes in this repo's examples.
KNOWN_USB_IDS: dict[tuple[int, int], str] = {
    (0x2E8A, 0x0009): "Raspberry Pi Pico 2 (pico-sdk USB stdio)",
    (0x2E8A, 0x000A): "Raspberry Pi Pico (pico-sdk USB stdio)",
    (0x2E8A, 0x0005): "Raspberry Pi Pico (MicroPython)",
    (0x2E8A, 0x000C): "Raspberry Pi Debug Probe (UART)",
    (0x0483, 0x374B): "ST-LINK/V2-1 (Nucleo virtual COM port)",
    (0x0483, 0x374E): "STLINK-V3 (virtual COM port)",
    (0x0483, 0x3752): "ST-LINK/V2-1 (Nucleo virtual COM port)",
    (0x0483, 0x3753): "STLINK-V3 (virtual COM port)",
    (0x10C4, 0xEA60): "CP210x USB-UART (ESP32 DevKit)",
    (0x1A86, 0x7523): "CH340 USB-UART (ESP32 DevKit clone)",
    (0x1A86, 0x55D4): "CH9102 USB-UART (ESP32 DevKit)",
    (0x303A, 0x1001): "Espressif USB-Serial/JTAG (ESP32-S3/C3/C6)",
    (0x0403, 0x6001): "FTDI FT232R USB-UART",
    (0x0403, 0x6010): "FTDI FT2232 USB-UART",
    (0x0403, 0x6014): "FTDI FT232H USB-UART",
    (0x0403, 0x6015): "FTDI FT-X USB-UART",
    (0x2047, 0x0013): "TI eZ-FET (MSP430 LaunchPad backchannel UART)",
}

EOLS = {"lf": b"\n", "cr": b"\r", "crlf": b"\r\n", "none": b""}

# pico-sdk's USB stdio reboots into BOOTSEL when the host opens it at this rate.
PICO_BOOTSEL_BAUD = 1200


def describe(port: ListPortInfo) -> str:
    """A human description of what is probably on a serial port."""
    if port.vid is not None and port.pid is not None:
        known = KNOWN_USB_IDS.get((port.vid, port.pid))
        if known:
            return known
    return port.description if port.description != "n/a" else ""


def usb_ports() -> list[ListPortInfo]:
    """Serial ports backed by a USB device, i.e. ones you can plug in."""
    return [p for p in list_ports.comports() if p.vid is not None]


def pick_port(requested: str | None) -> str:
    """The port to use: --port, else $MCU_PORT, else the only USB serial port."""
    port = requested or os.environ.get("MCU_PORT")
    if port:
        return port
    ports = usb_ports()
    if len(ports) == 1:
        return ports[0].device
    if not ports:
        sys.exit("mcu: no USB serial port found; plug the board in or pass --port")
    names = ", ".join(p.device for p in ports)
    sys.exit(f"mcu: several serial ports found ({names}); pass --port")


def open_port(args: argparse.Namespace, timeout: float = 0.1) -> serial.SerialBase:
    port = pick_port(args.port)
    try:
        return serial.serial_for_url(port, baudrate=args.baud, timeout=timeout)
    except serial.SerialException as e:
        hint = ""
        if "Permission denied" in str(e):
            hint = " (is your user in the dialout group? see README)"
        sys.exit(f"mcu: {e}{hint}")


def parse_payload(text: str, *, hex_mode: bool, eol: str) -> bytes:
    """Bytes to send: text plus the line ending, or hex digits ("de ad be ef")."""
    if hex_mode:
        return bytes.fromhex(text)
    return text.encode() + EOLS[eol]


def render(data: bytes, *, hex_mode: bool) -> str:
    """Received bytes as text, or as space-separated hex."""
    if hex_mode:
        return data.hex(" ") + " "
    return data.decode(errors="replace")


def exchange(
    ser: serial.SerialBase, payload: bytes, *, timeout: float, idle: float
) -> bytes:
    """Sends payload, then collects the reply until `idle` seconds pass with no
    new bytes, or `timeout` seconds in total."""
    ser.read_all()  # drop output that arrived before the request
    ser.write(payload)
    ser.flush()
    reply = bytearray()
    start = last = time.monotonic()
    while (now := time.monotonic()) - start < timeout:
        chunk = ser.read_all() or ser.read(1)
        if chunk:
            reply += chunk
            last = now
        elif reply and now - last >= idle:
            break
    return bytes(reply)


class Printer:
    """Writes received data to the terminal (optionally timestamping each line)
    and appends the raw bytes to a log file."""

    def __init__(
        self, out: TextIO, *, hex_mode: bool, timestamps: bool, log: BinaryIO | None
    ) -> None:
        self.out = out
        self.hex_mode = hex_mode
        self.timestamps = timestamps
        self.log = log
        self.at_line_start = True

    def __call__(self, data: bytes) -> None:
        if self.log:
            self.log.write(data)
            self.log.flush()
        text = render(data, hex_mode=self.hex_mode)
        if self.timestamps:
            parts = []
            for piece in text.splitlines(keepends=True):
                if self.at_line_start:
                    parts.append(datetime.now().strftime("[%H:%M:%S.%f")[:-3] + "] ")
                parts.append(piece)
                self.at_line_start = piece.endswith("\n")
            text = "".join(parts)
        self.out.write(text)
        self.out.flush()


def cmd_ports(args: argparse.Namespace) -> int:
    ports = list_ports.comports() if args.all else usb_ports()
    if not ports:
        print("no serial ports found" if args.all else "no USB serial ports found")
        return 1
    for p in sorted(ports, key=lambda p: p.device):
        ids = f"{p.vid:04x}:{p.pid:04x}" if p.vid is not None else "         "
        serial_no = f"  serial {p.serial_number}" if p.serial_number else ""
        print(f"{p.device:<16} {ids}  {describe(p)}{serial_no}")
    return 0


def cmd_monitor(args: argparse.Namespace) -> int:
    ser = open_port(args)
    log = Path(args.log).open("ab") if args.log else None  # noqa: SIM115
    show = Printer(sys.stdout, hex_mode=args.hex, timestamps=args.timestamps, log=log)
    stop = threading.Event()

    def reader() -> None:
        while not stop.is_set():
            try:
                data = ser.read_all() or ser.read(1)
            except serial.SerialException as e:  # e.g. the board was unplugged
                print(f"\nmcu: {e}", file=sys.stderr)
                stop.set()
                return
            if data:
                show(data)

    print(
        f"mcu: {ser.name} at {args.baud} baud. Type a line and press Enter to "
        "send it; Ctrl-C quits.",
        file=sys.stderr,
    )
    thread = threading.Thread(target=reader, daemon=True)
    thread.start()
    try:
        for line in sys.stdin:
            if stop.is_set():
                break
            try:
                payload = parse_payload(
                    line.rstrip("\r\n"), hex_mode=args.hex, eol=args.eol
                )
            except ValueError as e:
                print(f"mcu: not hex: {e}", file=sys.stderr)
                continue
            ser.write(payload)
        # stdin closed (Ctrl-D or piped input): keep showing output until Ctrl-C.
        while not stop.is_set():
            stop.wait(0.2)
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        thread.join(timeout=1)
        ser.close()
        if log:
            log.close()
    return 0


def cmd_send(args: argparse.Namespace) -> int:
    try:
        payload = parse_payload(args.data, hex_mode=args.hex, eol=args.eol)
    except ValueError as e:
        sys.exit(f"mcu: not hex: {e}")
    with open_port(args, timeout=0.05) as ser:
        reply = exchange(ser, payload, timeout=args.timeout, idle=args.idle)
    if reply:
        text = render(reply, hex_mode=args.hex)
        print(text, end="" if text.endswith("\n") else "\n")
    if args.expect and not re.search(args.expect.encode(), reply):
        print(f"mcu: reply did not match {args.expect!r}", file=sys.stderr)
        return 1
    if not reply:
        print("mcu: no reply", file=sys.stderr)
        return 1
    return 0


def cmd_bootsel(args: argparse.Namespace) -> int:
    args.baud = PICO_BOOTSEL_BAUD
    open_port(args).close()
    print("mcu: requested BOOTSEL; the Pico should now mount as a USB drive")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="mcu",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="command", required=True)

    def with_port(p: argparse.ArgumentParser) -> argparse.ArgumentParser:
        p.add_argument("-p", "--port", help="serial port or pyserial URL")
        p.add_argument(
            "-b",
            "--baud",
            type=int,
            default=int(os.environ.get("MCU_BAUD", "115200")),
            help="baud rate (default: $MCU_BAUD or 115200)",
        )
        return p

    def with_data_options(p: argparse.ArgumentParser) -> None:
        p.add_argument("--hex", action="store_true", help="send and show bytes as hex")
        p.add_argument(
            "--eol",
            choices=EOLS,
            default="lf",
            help="line ending added to text you send (default: lf)",
        )

    ports = sub.add_parser("ports", help="list serial ports")
    ports.add_argument("-a", "--all", action="store_true", help="include non-USB ports")
    ports.set_defaults(func=cmd_ports)

    monitor = with_port(sub.add_parser("monitor", help="interactive terminal"))
    with_data_options(monitor)
    monitor.add_argument(
        "-t", "--timestamps", action="store_true", help="timestamp each line"
    )
    monitor.add_argument("--log", help="append everything received to this file")
    monitor.set_defaults(func=cmd_monitor)

    send = with_port(sub.add_parser("send", help="send a message, print the reply"))
    with_data_options(send)
    send.add_argument("data", help="text to send, or hex bytes with --hex")
    send.add_argument(
        "--timeout", type=float, default=2.0, help="max seconds to wait (default: 2)"
    )
    send.add_argument(
        "--idle",
        type=float,
        default=0.2,
        help="reply is complete after this many quiet seconds (default: 0.2)",
    )
    send.add_argument("--expect", help="regex the reply must match, else exit status 1")
    send.set_defaults(func=cmd_send)

    bootsel = with_port(
        sub.add_parser("bootsel", help="reboot a pico-sdk Pico into BOOTSEL mode")
    )
    bootsel.set_defaults(func=cmd_bootsel)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)
