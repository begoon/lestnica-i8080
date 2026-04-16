# RK86 Character Map

The Radio-86RK uses a KOI-7-like encoding: ASCII in 0x20–0x5F, Cyrillic
uppercase in 0x60–0x7F, and block/line-drawing glyphs in 0x00–0x1F.

| hex  | glyph | notes |
|------|-------|-------|
| 0x00 |   (space) | empty cell |
| 0x01 | ▘ | top-left quadrant |
| 0x02 | ▝ | top-right quadrant |
| 0x03 | ▀ | top half |
| 0x04 | ▗ | bottom-right quadrant |
| 0x05 | ▚ | diagonal |
| 0x06 | ▐ | right half |
| 0x07 | ▜ | 3/4 block (bell in text ctx) |
| 0x08 |   (space) | |
| 0x09 | ✿ | flower |
| 0x0A |   (space) | LF in text ctx |
| 0x0B | ↑ | arrow up |
| 0x0C |   (space) | |
| 0x0D |   (space) | CR in text ctx |
| 0x0E | ◀ | arrow left |
| 0x0F | ▼ | arrow down |
| 0x10 | ▖ | bottom-left quadrant |
| 0x11 | ▌ | left half |
| 0x12 | ▞ | diagonal |
| 0x13 | ▛ | 3/4 block |
| 0x14 | ▄ | bottom half |
| 0x15 | ▙ | 3/4 block |
| 0x16 | ▟ | 3/4 block |
| 0x17 | █ | full block |
| 0x18 |   (space) | |
| 0x19 |   (space) | |
| 0x1A |   (space) | |
| 0x1B | │ | vertical line (also ESC in text ctx) |
| 0x1C | ─ | horizontal line |
| 0x1D | ▶ | arrow right |
| 0x1E | ⌐ | connector |
| 0x1F |   (space) | |

**0x20–0x5F: standard ASCII** (space, punctuation, digits, uppercase Latin, etc.)

**0x60–0x7F: Cyrillic uppercase**

| hex  | glyph | latin in source |
|------|-------|-----------------|
| 0x60 | Ю | `` ` `` |
| 0x61 | А | a |
| 0x62 | Б | b |
| 0x63 | Ц | c |
| 0x64 | Д | d |
| 0x65 | Е | e |
| 0x66 | Ф | f |
| 0x67 | Г | g |
| 0x68 | Х | h |
| 0x69 | И | i |
| 0x6A | Й | j |
| 0x6B | К | k |
| 0x6C | Л | l |
| 0x6D | М | m |
| 0x6E | Н | n |
| 0x6F | О | o |
| 0x70 | П | p |
| 0x71 | Я | q |
| 0x72 | Р | r |
| 0x73 | С | s |
| 0x74 | Т | t |
| 0x75 | У | u |
| 0x76 | Ж | v |
| 0x77 | В | w |
| 0x78 | Ь | x |
| 0x79 | Ы | y |
| 0x7A | З | z |
| 0x7B | Ш | { |
| 0x7C | Э | \| |
| 0x7D | Щ | } |
| 0x7E | Ч | ~ |
| 0x7F | █ | DEL (full block glyph) |

## Control bytes used as text codes

- `0x07` — beep (bell)
- `0x0A` — LF
- `0x0D` — CR
- `0x1B` — ESC (followed by 'Y' + row+20h + col+20h for cursor positioning)

## Quick reference for strings in lestnica.asm

When decoding source strings that use Latin letters to spell Russian words:
- "pozdrawlq` s pobedoj" → поздравляю с победой
- "prigotowxtesx" → приготовьтесь
