"""Package SAPLING.txt as a TI-84 Plus CE TI-BASIC program.

Uses only Python's standard library. This intentionally supports only the token
subset used by this program, not the whole TI-BASIC language. Token values are
from TI-Toolkit's token sheet: https://github.com/TI-Toolkit/tokens/blob/main/8X.xml
File layout: https://github.com/TI-Toolkit/tivars_lib_py/blob/main/tivars/var.py
"""

from pathlib import Path
import struct


TOKENS = {
    "→": "04", "{": "08", "}": "09", "(": "10", ")": "11",
    "round(": "12", "min(": "1a", " ": "29", '"': "2a",
    ",": "2b", ".": "3a", " or ": "3c", ":": "3e", "\n": "3f",
    " and ": "40", "SetUpEditor ": "bb4a", "Float": "69", "=": "6a",
    "<": "6b", ">": "6c", "≤": "6d", "≥": "6e", "≠": "6f",
    "+": "70", "-": "71", "Full": "75", "*": "82", "/": "83",
    "getKey": "ad", "int(": "b1", "dim(": "b5", "not(": "b8",
    "Real": "bb4d", "√(": "bc", "If ": "ce", "Then": "cf",
    "Else": "d0", "While ": "d1", "End": "d4", "Stop": "d9",
    "Disp ": "de", "Output(": "e0", "ClrHome": "e1", "ʟ": "eb",
    "checkTmr(": "ef02", "startTmr": "ef0b", "isClockOn": "ef0e",
    "^": "f0",
    "augment(": "14", "max(": "19", "seq(": "23", "Func": "76",
    "Xmin": "630a", "Xmax": "630b", "Ymin": "630c", "Ymax": "630d",
    "AxesOff": "7e09", "GridOff": "7e0b", "LabelOff": "7e0d",
    "ClrDraw": "85", "Text(": "93", "FnOff": "97", "Line(": "9c",
    "Circle(": "a5", "⁻": "b0", "sum(": "b6", "ExprOff": "bb51",
    "Repeat ": "d2", "For(": "d3", "PlotsOff": "ea",
    "BackgroundOff": "ef64", "TextColor(": "ef67", "%": "bbda",
}
TOKENS = {name: bytes.fromhex(value) for name, value in TOKENS.items()}
TOKENS.update({char: char.encode("ascii") for char in "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"})
ORDERED = sorted(TOKENS, key=len, reverse=True)


def tokenize(source: str) -> bytes:
    """Use command tokens in code and individual character tokens in strings."""
    output = bytearray()
    quoted = False
    offset = 0
    while offset < len(source):
        char = source[offset]
        if char == "\n" and quoted:
            raise ValueError("A display string crosses a line boundary")
        if quoted:
            if char not in TOKENS or len(char) != 1:
                raise ValueError(f"Unsupported string character {char!r}")
            output.extend(TOKENS[char])
            quoted = char != '"'
            offset += 1
            continue
        for name in ORDERED:
            if source.startswith(name, offset):
                output.extend(TOKENS[name])
                quoted = name == '"'
                offset += len(name)
                break
        else:
            line = source.count("\n", 0, offset) + 1
            raise ValueError(f"Unsupported token on line {line}: {source[offset:offset + 20]!r}")
    if quoted:
        raise ValueError("Unclosed display string")
    return bytes(output)


def package(tokens: bytes) -> bytes:
    # TI files have a 55-byte header, a variable entry, and a 16-bit checksum.
    # 0x05 = editable BASIC; 0x2a = color-era tokens plus TI-84 clock tokens.
    data = struct.pack("<H", len(tokens)) + tokens
    entry = (
        struct.pack("<HHB", 13, len(data), 5)
        + b"SAPLING\0"
        + bytes((0x2A, 0))  # version, unarchived
        + struct.pack("<H", len(data))
        + data
    )
    comment = b"Sapling calculator graphical edition".ljust(42, b"\0")
    header = b"**TI83F*\x1a\x0a\x00" + comment + struct.pack("<H", len(entry))
    return header + entry + struct.pack("<H", sum(entry) & 0xFFFF)


if __name__ == "__main__":
    folder = Path(__file__).resolve().parent
    source = (folder / "SAPLING.txt").read_text(encoding="utf-8")
    tokens = tokenize(source)
    output = folder / "SAPLING.8xp"
    output.write_bytes(package(tokens))
    print(f"Wrote {output.name}: {output.stat().st_size} bytes ({len(tokens)} program bytes)")
