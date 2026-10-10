"""Logic-analyzer capture: plot the channels and decode UART.

Open with `uv run marimo edit notebooks/capture.py`. Export a PulseView or
sigrok-cli capture as CSV first, e.g.

    sigrok-cli -d fx2lafw --config samplerate=1m --samples 1m -O csv > capture.csv

Without a file the notebook makes up a capture: "Hi\\n" at 115200 baud.
"""

import marimo

__generated_with = "0.25.1"
app = marimo.App(width="medium")


@app.cell
def _():
    import pathlib

    import marimo as mo
    import matplotlib.pyplot as plt
    import numpy as np

    return mo, np, pathlib, plt


@app.cell
def _(mo):
    path = mo.ui.text(value="capture.csv", label="sigrok CSV export")
    baud = mo.ui.number(start=300, stop=3_000_000, value=115_200, label="baud")
    mo.hstack([path, baud])
    return baud, path


@app.cell
def _(baud, np, path, pathlib):
    def load_sigrok_csv(file):
        """Returns the sample rate, channel names and a samples x channels array."""
        rate, names, rows = 1.0, [], []
        for line in file.read_text().splitlines():
            if line.startswith("; Samplerate:"):
                value, unit = line.split(":", 1)[1].split()
                rate = (
                    float(value) * {"Hz": 1, "kHz": 1e3, "MHz": 1e6, "GHz": 1e9}[unit]
                )
            elif line.startswith("; Channels"):
                names = [n.strip() for n in line.split(":", 1)[1].split(",")]
            elif line and not line.startswith((";", "logic")):
                rows.append([int(v) for v in line.split(",")])
        return rate, names, np.array(rows, dtype=np.uint8)

    def fake_uart(text: bytes, rate: float, bits_per_s: int):
        """8N1 UART, idle high, sampled at `rate`."""
        bits = [1] * 20
        for byte in text:
            bits += [0, *((byte >> i) & 1 for i in range(8)), 1]
        bits += [1] * 20
        return np.repeat(bits, round(rate / bits_per_s)).astype(np.uint8)[:, None]

    file = pathlib.Path(path.value)
    if file.is_file():
        rate, names, samples = load_sigrok_csv(file)
        source = str(file)
    else:
        rate, names = 4e6, ["D0 (made up)"]
        samples = fake_uart(b"Hi\n", rate, baud.value)
        source = "made-up capture"
    return names, rate, samples, source


@app.cell
def _(mo, names, rate, samples, source):
    channel = mo.ui.dropdown(
        options={name: i for i, name in enumerate(names)},
        value=names[0],
        label="UART channel",
    )
    mo.vstack(
        [
            mo.md(f"**{source}**: {len(samples):,} samples at {rate / 1e6:g} MHz"),
            channel,
        ]
    )
    return (channel,)


@app.cell
def _(mo, names, np, plt, rate, samples):
    t = np.arange(len(samples)) / rate * 1e3
    fig, axes = plt.subplots(
        len(names), 1, sharex=True, squeeze=False, figsize=(10, 1.2 * len(names) + 1)
    )
    for i, ax in enumerate(axes[:, 0]):
        ax.step(t, samples[:, i], where="post", linewidth=0.8)
        ax.set_yticks([0, 1])
        ax.set_ylabel(names[i], rotation=0, ha="right")
    axes[-1, 0].set_xlabel("time (ms)")
    fig.tight_layout()
    mo.as_html(fig)
    return


@app.cell
def _(baud, channel, mo, rate, samples):
    def decode_uart(line, rate: float, bits_per_s: int) -> bytes:
        """Decodes 8N1 UART: finds each start bit, samples mid-bit."""
        per_bit = rate / bits_per_s
        out, i = bytearray(), 1
        while i < len(line) - 10 * per_bit:
            if line[i - 1] == 1 and line[i] == 0:  # falling edge: start bit
                mid = i + per_bit / 2
                byte = sum(
                    int(line[int(mid + (k + 1) * per_bit)]) << k for k in range(8)
                )
                out.append(byte)
                i = int(mid + 9 * per_bit)  # skip to the stop bit
            i += 1
        return bytes(out)

    decoded = decode_uart(samples[:, channel.value], rate, baud.value)
    mo.md(f"Decoded: `{decoded!r}` (hex `{decoded.hex(' ')}`)")
    return


if __name__ == "__main__":
    app.run()
