# CLAUDE.md

## Project

Annotated disassembly of "Lestnica" (ЛЕСТНИЦА) — an i8080 game for the RK86 (Радио-86РК) computer.

## Build

```
just ci        # build + test
just build     # assemble only
just test      # compare against golden binary
just disasm    # regenerate lestnica.asm from LESTNICA.GAM (overwrites!)
```

Requires `bun` (for `bunx asm8080`), `just`, and `python3`.

## Key files

- `lestnica.asm` — the annotated disassembly (source of truth)
- `LESTNICA.GAM` — golden original binary (7712 bytes, load address 0100h)
- `LESTNICA-TAPE.GAM` — tape copy with 5-byte header + 3-byte trailer
- `lestnica.bin` — assembled output (must match LESTNICA.GAM exactly)
- `lestnica.lst` — assembler listing with addresses and symbol table
- `disasm.py` — single-file i8080 linear disassembler (asm8080 syntax)
- `Justfile` — build recipes
- `info/rk86-charmap.md` — RK86 character set (ASCII + Cyrillic + block glyphs)

## Tape format

`LESTNICA-TAPE.GAM` = `E6 AA AA BB BB` + raw bytes + `E6 XX YY` where
`AAAA`=start address (0100h), `BBBB`=end address, `XXYY`=checksum.

## Rules

- **Every change must pass `just ci`** — the assembled binary must match LESTNICA.GAM byte-for-byte.
- When renaming a label (e.g. `loc_05B2` to `init_stone`), add `; offset=05B2h` comment to preserve the original address.
- Use `bunx asm8080 --split -l lestnica.asm` to regenerate the listing and verify offsets against the symbol table.
- Comments and labels are free — only `db`/`dw`/instructions produce bytes.

## Code origin — likely compiler output

The code is almost certainly **compiler-generated**, not hand-written assembly.
Telltale signs:

- **Uniform prologue**: every routine begins with `push psw / push h / push d / push b`
  and ends at a shared epilogue that pops in reverse. A human would save only
  clobbered registers.
- **Convergent tail**: all branches of a routine `jmp` to one common exit label
  (e.g. `loc_0416`) that contains the pops and `ret`.
- **No register allocator**: variables are fetched fresh from memory on every
  use (`lxi h, 0803h; mov a, m; …`) rather than cached across branches.
- **Cookie-cutter switch/if-else**: long chains of `cpi XX; jnz next; <same
  body with different immediate>; jmp exit` blocks — textbook codegen for a
  `switch` or cascaded `if` statements.
- **Globals at fixed addresses**: game state lives in the 08xxh region
  (0802h, 0803h, 0814h, 0815h, 0817h, 0818h, 0819h, 081Ah, …), accessed as
  raw memory rather than via indexed/register-based addressing.

Most plausible source languages on an RK86 of the period: **PL/M-80** or a
small C compiler (Small-C / BDS C). Turbo Pascal is less likely given the
calling convention.

**Implications for annotation:**
- Treat each "routine" as a function — the prologue/epilogue pair delimits it.
- Name the 08xxh memory cells as global variables as their roles become clear.
- Don't try to rewrite the codegen patterns into tighter asm — we're preserving
  the original bytes, and recognizing the compiler idioms makes the intent
  readable without changing anything.

## Known game concepts

Findings accumulated while annotating. Update as more becomes clear.

### Tile characters

From the in-game legend on the title screen (decoded via `render_screen.py`):

- `H` (48h) — **лестница** (ladder)
- `O` (4Fh) — **увесистый булыжник** (heavy boulder)
- `$` (24h) — **выход из уровня** (level exit)
- `↑` (0Bh) — **очень плохая штука** (very bad thing — hazard/spike)
- `.` (2Eh) — **очень хитрая штука** (very tricky thing — trap)
- `⌐` (1Eh) — **приятная вещь** (pleasant thing — bonus/pickup)
- `✿` (09h) — **the player** (flower glyph; position cached in `var_0812`)
- `=` (3Dh), `#` (23h), `-` (2Dh) — solid/floor/wall tiles (treated
  equivalently in the check near offset 05B0h)
- `1Ah` — RK86 blank glyph (used as "empty" marker in some checks)

### Controls (from title screen legend)

- Arrows (08h/18h/19h/1Ah) — move/climb
- Space (20h) — jump
- `P` — new game, `L` — difficulty, `S` — speed, `E` — exit to monitor

### RK86 keyboard codes (seen so far)

Used by the game input handler near `loc_03BA`:

- `08h` = ← (left arrow)
- `18h` = → (right arrow)
- `19h` = ↑ (up arrow)
- `1Ah` = ↓ (down arrow)
- `03h` = Ctrl-C (break / wait-for-Enter branch)

### Global variables (08xxh RAM region)

Game state lives in fixed memory cells. Identified so far:

- `0809h..080Ch` — 32-bit PRNG state (`prng_state`); seeded at boot with
  `5A 34 17 71`. Advanced by `prng_next` (LFSR, taps at bits 30 & 6).
- `0814h` — 2-digit BCD **resource counter** (likely lives or time); HUD at
  row 24 col 21. Decremented elsewhere (wrap → `jmp loc_0100` = game restart),
  incremented by 1 every 100 score points (bonus-life mechanic)
- `0815h` — 2-digit BCD counter, HUD at row 24 col 44 (dec — wrap triggers 2× BEL)
- `0817h` — 2-digit BCD counter, HUD at row 24 col  8 (inc only seen)
- `0818h:0819h` — 4-digit BCD, HUD at row 24 col 31 (likely **score**; 16-bit, lo at 0818h, hi at 0819h — rendered hi-then-lo)

All four HUD fields use `monitor_hexb`. Because values are BCD, the hex
rendering also reads correctly as decimal (e.g. BCD byte 0x42 prints "42").

### Self-modifying code — difficulty / speed patch sites

The game stores difficulty and speed settings as **bytes inside live
instructions**, patched at runtime when the player presses L/S on the
menu. No separate variable — the code just writes to its own opcode
stream. Known patch sites:

| addr | lives in | default | controls |
|---|---|---|---|
| `018Eh` | hi-byte of `lxi b, 3001h` in `delay_preset` | `30h` | game speed (outer `delay_preset` tempo) |
| `01ACh` | immediate of `cpi 20h` in `new_life_reset_actors` | `20h` | actor-table iteration bound |
| `0242h` | immediate of `cpi 20h` in another actor-loop | `20h` | same (kept in sync) |
| `064Ch` | immediate of `sui 20h` in a third actor-loop | `20h` | same (kept in sync) |

Flipping the three `20h` bytes to `40h` doubles the loop count, which
activates the second 8-slot region at `0840h..085Fh` — the pre-placed
"hard mode" actors that `new_life_reset_actors` explicitly does *not*
clear. That's why the table has 16 slots but only the first 8 are
initialized on each new life.

When you see `lxi h, 018Eh` / `mvi m, XXh` near the menu handlers,
it's patching one of these — not reading a variable.

### BCD arithmetic idioms

- **Increment**: `mov a, m; adi 01h; daa; mov m, a`
- **Decrement**: `mov b, m; mvi a, 9Ah; sui 01h; add b; daa; mov m, a` (the
  "add 99" trick — 8080 has no BCD subtract; carry out = wrapped past zero)
- **16-bit BCD add**: low byte `add b / daa`, then capture carry via
  `mvi a, 0 / adc b / mov b, a`, then high byte `add b / daa`

## Formatting conventions

- 8-space indent for instructions and data
- Mnemonics padded to 4 chars: `mvi  a, 3` (not `mvi a, 3`)
- Arguments: `arg1, arg2` (comma-space)
- At least 5 spaces before inline `;` comments
- Comments aligned vertically within each code block
- Labels on their own line, `db`/`dw` on the next line
- Label offset annotations: `label_name:  ; offset=XXXXh`
- No tabs, spaces only
