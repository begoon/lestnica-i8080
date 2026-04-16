#!/usr/bin/env python3
"""Decode RLE-encoded screen data from LESTNICA.GAM.

paint_screen reads bytes from (DE) and writes into video memory
starting at row 3 col 7. Literal bytes pass through; 0FFh N writes N
zero bytes. Rendering stops when the dest pointer reaches 7FA0h
(row 28 col 72).

Usage:
    ./render_screen.py                # render title + 7 levels to stdout
    ./render_screen.py --extract      # also write each to levels/levelX.txt
"""
import sys
import os

WIDTH = 78
HEIGHT = 30
VIDEO_START = 0x76D0
VIDEO_END = 0x7FA0
DEST_START_ROW = 3
DEST_START_COL = 7

# RK86 glyph map (subset of info/rk86-charmap.md)
RK86 = {
    0x00: ' ', 0x01: '▘', 0x02: '▝', 0x03: '▀', 0x04: '▗', 0x05: '▚',
    0x06: '▐', 0x07: '▜', 0x08: ' ', 0x09: '✿', 0x0A: ' ', 0x0B: '↑',
    0x0C: ' ', 0x0D: ' ', 0x0E: '◀', 0x0F: '▼', 0x10: '▖', 0x11: '▌',
    0x12: '▞', 0x13: '▛', 0x14: '▄', 0x15: '▙', 0x16: '▟', 0x17: '█',
    0x18: ' ', 0x19: ' ', 0x1A: ' ', 0x1B: '│', 0x1C: '─', 0x1D: '▶',
    0x1E: '⌐', 0x1F: ' ', 0x7F: '█',
}
CYR = 'ЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧ'
for i, ch in enumerate(CYR):
    RK86[0x60 + i] = ch


def glyph(b: int) -> str:
    if b in RK86:
        return RK86[b]
    if 0x20 <= b <= 0x5F:
        return chr(b)
    return '·'


def decode(data: bytes, rom_addr: int):
    """Decode RLE screen data starting at ROM address rom_addr.
    Returns (screen_rows, consumed_bytes)."""
    file_off = rom_addr - 0x0100
    src = data[file_off:]
    screen = [[' '] * WIDTH for _ in range(HEIGHT)]
    cursor = VIDEO_START + DEST_START_ROW * WIDTH + DEST_START_COL
    si = 0
    while cursor < VIDEO_END:
        b = src[si]
        si += 1
        if b == 0xFF:
            n = src[si]
            si += 1
            for _ in range(n):
                if cursor >= VIDEO_END:
                    break
                off = cursor - VIDEO_START
                screen[off // WIDTH][off % WIDTH] = ' '
                cursor += 1
        else:
            off = cursor - VIDEO_START
            screen[off // WIDTH][off % WIDTH] = glyph(b)
            cursor += 1
    return screen, si


def frame(screen, title=''):
    top = '┌' + ('─' * WIDTH) + '┐'
    bot = '└' + ('─' * WIDTH) + '┘'
    out = []
    if title:
        out.append(title)
    out.append(top)
    for row in screen:
        out.append('│' + ''.join(row) + '│')
    out.append(bot)
    return '\n'.join(out)


def main():
    extract = '--extract' in sys.argv
    with open('LESTNICA.GAM', 'rb') as f:
        data = f.read()

    if extract:
        os.makedirs('levels', exist_ok=True)

    # Title/menu screen at 0900h
    title_screen, n = decode(data, 0x0900)
    print(frame(title_screen, 'TITLE (0900h)'))
    print(f'  (consumed {n} bytes)\n')
    if extract:
        path = 'levels/title.txt'
        with open(path, 'w') as f:
            f.write(frame(title_screen, 'TITLE (0900h)') + '\n')
        print(f'  → wrote {path}\n')

    # 7 unique level pointers from level_table (gathered earlier)
    level_ptrs = [
        ('A', 0x0C40),
        ('B', 0x0E20),
        ('C', 0x13A0),
        ('D', 0x1080),
        ('E', 0x15D0),
        ('F', 0x18D0),
        ('G', 0x1C00),
    ]

    for name, addr in level_ptrs:
        screen, n = decode(data, addr)
        header = f'LEVEL {name} ({addr:04X}h)'
        print(frame(screen, header))
        print(f'  (consumed {n} bytes)\n')
        if extract:
            path = f'levels/level_{name}.txt'
            with open(path, 'w') as f:
                f.write(frame(screen, header) + '\n')
            print(f'  → wrote {path}')


if __name__ == '__main__':
    main()
