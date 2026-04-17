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

Cross-referenced with a Z80 port of the same game at
https://github.com/imsushka/TangNano20K-VIDEO/blob/main/soft/LESTNICA.asm
which has preserved full semantic names. See `CHR_*` equates in the asm.

- `CHR_PLAYER` = 09h (`✿`) — the player; position cached in `var_0812`
- `CHR_MUSHROOM` = 0Bh (`↑`) — "очень плохая штука"; touching = dead
- `CHR_APPLE` = 1Eh (`⌐`) — "приятная вещь"; +90 BCD points
- `CHR_STONEHOLDER` = 55h (`U`) — spawns falling stones (two per level,
  positions cached in `var_0805` and `var_0807` by `loc_07C2`)
- `CHR_STONE` = 4Fh (`O`) — "увесистый булыжник"; kills on contact,
  supports player weight (prevents fall)
- `CHR_STONEKILL` = 2Ah (`*`) — stone-kill splat animation
- `CHR_LAD` = 48h (`H`) — "лестница"; press UP with jump-flag set to climb
- `CHR_JOKER` = 2Eh (`.`) — "очень хитрая штука"; sets random direction,
  50% chance of jump-2 (uses `prng_next`)
- `CHR_EXIT` = 24h (`$`) — "выход из уровня"; awards `vTime × 2` bonus
- `CHR_BRICK` = 23h (`#`) — solid wall
- `CHR_BRIDGE` = 2Dh (`-`) — horizontal bridge
- `CHR_FLOOR` = 3Dh (`=`) — horizontal floor
- `1Ah` — blank glyph ("empty" marker)

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

- `0800h:0801h` (`var_player_addr`) — player's video-memory pointer
  (`PS_AddrTmp` in Z80 port). Initially set to the flower's position.
- `0802h` (`var_player_stat`) — **tile under the player** (`PlayerStat`
  in Z80 port). Driven by `player_step` to detect apple / mushroom /
  stone / ladder / joker / exit on each frame.
- `0803h` (`var_key`) — low 7 bits = last arrow code, bit 7 = queued jump flag.
- `0804h` (`var_jump_byte`) — jump-trajectory bit-pattern (7-frame arc).
- `0809h..080Ch` — 32-bit PRNG state (`prng_state`); seeded at boot with
  `5A 34 17 71`. Advanced by `prng_next` (LFSR, taps at bits 30 & 6).
- `0811h` (`var_dead`) — set to `0FFh` when player dies (stone/mushroom hit).
- `081Ah` (`var_exit_touched`) — set to `0FFh` when player reaches the exit.
- `0814h` (`var_attempts`) — **LIVES / attempts** counter (BCD); HUD at row 24
  col 21. Init 07h. Wrap-to-zero → `jmp loc_0100` = game over; +1 every 100
  score points (bonus-life mechanic). Z80 port calls it `vPopitok`.
- `0815h` (`var_time`) — **TIME LIMIT** per level (BCD); HUD at row 24 col 44.
  Reset to 40h each life. Decremented when `var_0816` sub-tick underflows.
  Wrap-to-zero → player dies. 2× BEL warns on low time.
- `0816h` — sub-tick counter (init 0Fh in `game_tick_outer`), decremented
  every iteration of the inner loop. Drives per-frame cadence.
- `0817h` (`var_level`) — **LEVEL NUMBER**; HUD at row 24 col 8 (BCD). Init 01h.
  Incremented on exit touch.
- `0818h:0819h` (`var_score`) — 4-digit BCD **SCORE**; HUD at row 24 col 31.
  Lo at 0818h, hi at 0819h — rendered hi-then-lo.

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

### Gameplay mechanics

Confirmed via cross-reference with the Z80 port and the in-game legend.

- **Player death**: stepping onto a cell containing `CHR_STONE` or
  `CHR_MUSHROOM` sets a `PlayerDead` flag and ends the life.
- **Exit**: touching `CHR_EXIT` completes the level (`inc_level`). Bonus
  awarded = `var_time` (plain BCD); `var_time` is then zeroed,
  `var_level++` is BCD-incremented, and the next level pointer loads.
  (Z80 port doubles the bonus via `RLC c`; RK86 original does not.)
- **Apple**: `CHR_APPLE` is consumed on touch, awards **45 BCD** points
  (the Z80 port doubles this with `RLC c` to 90; the RK86 original does not).
- **Joker** (`CHR_JOKER`): when the player stands on it, calls `prng_next`
  twice — first to pick random L/R direction, second to decide (50%)
  whether to queue a 2-cell jump.
- **Ladder** (`CHR_LAD`): UP or DOWN arrow climbs while standing on it.
  Jump-from-ladder is consumed (clears the jump flag in `var_key`).
- **Bridge** (`CHR_BRIDGE`) is **one-use** — stepping onto it writes `0`
  into the cell, so the bridge disappears after crossing.
- **Fall rule**: if the cell directly below the player is not
  `CHR_FLOOR`/`CHR_BRICK`/`CHR_BRIDGE` and no stone is within 3 cells
  below, the player falls.
- **Jump arc** — 7-frame parabola encoded in `var_key + 1`. Each frame
  shifts the byte left (RLA); tests of bits `0Ch` and `0C0h` pick the
  horizontal/vertical deltas. Landing frame (byte=80h) clears the flag.
  Trajectory: `2→(0,0), 4→(+1,+1), 8→(+2,+2), 10→(+2,+3), 20→(+2,+4),
  40→(+1,+5), 80→(0,+6)`.
- **Stone AI**: each tick every `stone_table` slot tries to move DOWN;
  blocked by FLOOR/BRICK/BRIDGE/LAD (on LAD 50% override to go L/R);
  on a wall it flips direction via `ARROW_INVERSE` XOR. Stones falling onto
  the player → death. Stone-on-stone creates a "double-stone" blank
  placeholder. New stones spawn at `CHR_STONEHOLDER` cells.
- **Screen wrap**: horizontal movement wraps at the map width
  (our `video_width` = 78; the Z80 port uses 64). Logic masks L/E
  with `MAP_WIDTH - 1` to detect wrap, then rolls back.

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
