#!/usr/bin/env python3
"""Emite cores OSC 21 do Kitty sem habilitar remote control."""
from pathlib import Path
import re
import sys

THEMES = {"changli", "hiyuki"}
SPECIAL = {
    "background": "background",
    "foreground": "foreground",
    "cursor": "cursor",
    "cursor_text_color": "cursor_text",
    "selection_background": "selection_background",
    "selection_foreground": "selection_foreground",
}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in THEMES:
        raise SystemExit("Tema deve ser changli ou hiyuki")
    file = Path.home() / ".config" / "kitty" / f"{sys.argv[1]}.conf"
    if not file.is_file():
        raise SystemExit(f"Arquivo ausente: {file}")
    values = []
    for line in file.read_text(encoding="utf-8").splitlines():
        fields = line.split()
        if len(fields) < 2 or fields[0].startswith("#"):
            continue
        name, value = fields[:2]
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
            continue
        key = SPECIAL.get(name)
        if key is None and re.fullmatch(r"color(?:[0-9]|1[0-5])", name):
            key = name[5:]
        if key is not None:
            values.append(f"{key}={value}")
    if values:
        sys.stdout.write("\033]21;" + ";".join(values) + "\033\\")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
