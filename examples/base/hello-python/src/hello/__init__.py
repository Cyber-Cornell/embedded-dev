"""Hello world for this computer. Run it with `uv run hello [name]`."""

import sys


def greeting(name: str | None = None) -> str:
    return f"Hello, {name or 'world'}!"


def main() -> None:
    print(greeting(sys.argv[1] if len(sys.argv) > 1 else None))
