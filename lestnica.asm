        org  0100h
        section lestnica

monitor_cin      equ 0F803h     ; read char from keyboard
monitor_cout     equ 0F809h     ; print char to screen
monitor_hexb     equ 0F815h     ; print byte in hex
monitor_puts     equ 0F818h     ; print zero-terminated string
monitor_scan_kbd equ 0F81Bh     ; scan keyboard (non-blocking)
monitor_curc     equ 0F821h     ; char under cursor
monitor_prompt   equ 0F86Ch     ; monitor prompt (warm start)

video_memory     equ 76D0h      ; start of video memory
video_width      equ 78         ; screen width in chars
video_height     equ 30         ; screen height in rows

prng_state       equ 0809h      ; 32-bit PRNG state (D:E at +0/+1, H:L at +2/+3)

loc_0100:
        lxi  sp, 69FFh
        lxi  h, var_0814
        mvi  m, 07h
        lxi  h, level_table
        shld var_081B
        lxi  h, prng_state
        mvi  m, 5Ah                  ; 'Z'
        inx  h
        mvi  m, 34h                  ; '4'
        inx  h
        mvi  m, 17h
        inx  h
        mvi  m, 71h                  ; 'q'
        lxi  h, var_0817
        mvi  m, 01h
        lxi  h, 0000h
        shld var_0818
        jmp  loc_06CB
loc_012A:
        lxi  h, var_0811
        mvi  m, 00h
        lxi  h, var_081A
        mvi  m, 00h
        lhld var_081B
        mov  e, m
        inx  h
        mov  d, m
        inx  h
        shld var_081B
        mov  a, e
        cpi  00h
        jnz  loc_014A
        mov  a, d
        cpi  00h
        jz   loc_07A1
loc_014A:
        call paint_screen
        call loc_07C2
        lxi  h, msg_get_ready
        call monitor_puts
        nop
        nop
        jmp  loc_07E7
; Paint the playfield from RLE-encoded data at (DE) into video memory
; starting at row 3, col 7. Literal bytes copy straight through;
; FFh N expands to N zero bytes. Loop stops when HL reaches 7FA0h
; (row 28 col 72), i.e. after painting most of the screen above the
; status row.
paint_screen:                                   ; offset=015Bh
        lxi  h, video_memory + 3*video_width + 7
paint_screen_loop:                              ; offset=015Eh
        ldax d
        cpi  0FFh
        jz   paint_screen_rle
        mov  m, a       ; literal byte
        inx  h
        inx  d
        mov  a, h
        cpi  7Fh
        jnz  paint_screen_loop
        mov  a, l
        cpi  0A0h
        jnz  paint_screen_loop
        ret
paint_screen_rle:                               ; offset=0174h
        inx  d
        ldax d
        mov  b, a       ; B = run length
        inx  d
paint_screen_fill:                              ; offset=0178h
        mvi  m, 00h
        inx  h
        dcr  b
        jnz  paint_screen_fill
        mov  a, h
        cpi  7Fh
        jnz  paint_screen_loop
        mov  a, l
        cpi  0A0h
        jnz  paint_screen_loop
        ret
; Busy-wait delay. Entry at delay_bc uses caller's BC;
; entry at delay_preset preloads BC=3001h.
; Iterations ≈ (initial BC − 00FFh). At ~1.78 MHz, BC=3001h ≈ 150 ms.
delay_preset:                                   ; offset=018Ch
        lxi  b, 3001h
delay_bc:                                       ; offset=018Fh
        dcx  b
        mov  a, b
        cpi  00h
        jnz  delay_bc
        ret
; New-game / new-life state reset, then fall through to main game loop.
; Clears the 8-slot dynamic actor table at 0820h, redraws the flower,
; resets tick counters, and primes HUD counter 0815h.
new_life:                                       ; offset=0197h
        lxi  b, table_0820        ; BC = base (for end-of-loop test)
        lxi  h, table_0820        ; HL = write ptr
; Fill 8 actor slots [addr_lo, addr_hi, 'U', 1Ah] = inactive defaults.
new_life_reset_actors:                          ; offset=019Dh
        mvi  m, 00h          ; slot+0: addr lo
        inx  h
        mvi  m, 00h          ; slot+1: addr hi
        inx  h
        mvi  m, 55h          ; slot+2: 'U' glyph
        inx  h
        mvi  m, 1Ah          ; slot+3: type = empty
        inx  h
        mov  a, l
        sub  c
        cpi  20h             ; stop after 32 bytes (8 slots)
        jnz  new_life_reset_actors
        lhld var_0812           ; cached flower address
        mvi  m, 09h          ; redraw flower glyph in video memory
        shld var_0800           ; working pointer = flower addr
        lxi  h, var_0802
        mvi  m, 00h          ; 0802h = tick counter
        inx  h
        mvi  m, 00h          ; 0803h = direction flag
        inx  h
        mvi  m, 00h          ; 0804h = 0
        lxi  h, var_0811
        mvi  m, 00h
        lxi  h, var_081A
        mvi  m, 00h
        lxi  h, var_0815
        mvi  m, 40h          ; HUD BCD counter = 40h
; Outer tick: reload sub-tick counter 0816h = 15.
game_tick_outer:                                ; offset=01D2h
        lxi  h, var_0816
        mvi  m, 0Fh
; Main game loop head: decrement sub-tick 0816h each iteration.
game_tick_inner:                                ; offset=01D7h
        lxi  h, var_0816
        mov  a, m
        dcr  a
        mov  m, a
        jz   loc_0249
        call delay_preset
        call loc_039E
        call loc_0616
        call loc_02E5
        call loc_0279
        lxi  h, var_081A
        mov  a, m
        cpi  0FFh
        jz   loc_02C7
        lxi  h, var_0815
        mov  a, m
        cpi  00h
        jz   loc_020A
        lxi  h, var_0811
        mov  a, m
        cpi  0FFh
        jnz  game_tick_inner
loc_020A:
        lxi  h, var_0802
        mov  a, m
        cpi  4Fh                     ; 'O'
        jz   loc_021C
        lhld var_0800
        mov  m, a
        mvi  c, 07h
        call monitor_cout
loc_021C:
        lxi  h, table_0820 + 2
        lxi  b, table_0820 + 2
loc_0222:
        mov  a, m
        cpi  09h
        jz   loc_023B
        cpi  4Fh                     ; 'O'
        jz   loc_023B
        cpi  20h                     ; ' '
        jz   loc_023B
        dcx  h
        mov  d, m
        dcx  h
        mov  e, m
        xchg
        mov  m, a
        xchg
        inx  h
        inx  h
loc_023B:
        inx  h
        inx  h
        inx  h
        inx  h
        mov  a, l
        sub  c
        cpi  20h                     ; ' '
        jnz  loc_0222
        jmp  loc_0265
loc_0249:
        lxi  h, var_0815
        mov  a, m
        mov  b, a
        mvi  a, 9Ah
        sui  01h
        add  b
        daa
        mov  m, a
        ani  0F0h
        jnz  game_tick_outer
        mvi  c, 07h
        call monitor_cout
        call monitor_cout
        jmp  game_tick_outer
loc_0265:
        lxi  h, var_0814
        mov  a, m
        mov  b, a
        mvi  a, 9Ah
        sui  01h
        add  b
        daa
        mov  m, a
        cpi  00h
        jnz  new_life
        jmp  loc_0100
loc_0279:
        lxi  h, cursor_r24_c8
        call monitor_puts
        lxi  h, var_0817
        mov  a, m
        call monitor_hexb
        lxi  h, cursor_r24_c21
        call monitor_puts
        lxi  h, var_0814
        mov  a, m
        call monitor_hexb
        lxi  h, cursor_r24_c31
        call monitor_puts
        lxi  h, var_0819
        mov  a, m
        call monitor_hexb
        dcx  h
        mov  a, m
        call monitor_hexb
        lxi  h, cursor_r24_c44
        call monitor_puts
        lxi  h, var_0815
        mov  a, m
        call monitor_hexb
        ret

; ESC-Y cursor positioning strings for the status row.
; Format: 1Bh, 'Y', row+20h, col+20h, 0 (NUL terminator for monitor_puts).
cursor_r24_c8:                                  ; offset=02B3h
        db   1Bh, "Y", 38h, 28h, 0
cursor_r24_c21:                                 ; offset=02B8h
        db   1Bh, "Y", 38h, 35h, 0
cursor_r24_c31:                                 ; offset=02BDh
        db   1Bh, "Y", 38h, 3Fh, 0
cursor_r24_c44:                                 ; offset=02C2h
        db   1Bh, "Y", 38h, 4Ch, 0
loc_02C7:
        call loc_02D5
        lxi  h, var_0817
        mov  a, m
        adi  01h
        daa
        mov  m, a
        jmp  loc_02E2
loc_02D5:
        lxi  h, var_0815
        mov  b, m
        mvi  m, 00h
        push psw
        push b
        push d
        push h
        jmp  loc_02F6
loc_02E2:
        jmp  loc_012A
loc_02E5:
        push psw
        push b
        push d
        push h
        lxi  h, var_0802
        mov  a, m
        cpi  1Eh
        jnz  loc_0319
        mvi  m, 00h
        mvi  b, 45h                  ; 'E'
; Add B (BCD amount) to the 4-digit BCD score at 0818h:0819h.
; Also bumps 0814h by 1 each time the low score byte rolls past 99
; (i.e. +1 per 100 score points — the bonus-life-per-100-pts mechanic).
; Beeps once on return.
loc_02F6:                                       ; offset=02F6h
        lxi  h, var_0818    ; score lo
        mov  a, m
        add  b           ; lo += B
        daa
        mov  m, a        ; carry = lo wrapped past 99
        mvi  b, 00h
        mvi  a, 00h
        adc  b           ; A = carry (0 or 1)
        mov  b, a        ; B = carry propagation
        inx  h           ; score hi
        mov  a, m
        add  b           ; hi += carry
        daa
        mov  m, a
        lxi  h, var_0814
        mov  a, m
        add  b           ; 0814h += carry (NOT original B) — +1 per 100 pts
        daa
        mov  m, a
        mvi  c, 07h      ; BEL
        call monitor_cout
loc_0314:
        pop  h
        pop  d
        pop  b
        pop  psw
        ret
loc_0319:
        cpi  0Bh
        jnz  loc_032B
loc_031E:
        lxi  h, var_0811
        mvi  m, 0FFh
        mvi  c, 07h
        call monitor_cout
        jmp  loc_0314
loc_032B:
        cpi  4Fh     ; 'O'
        jz   loc_031E
        cpi  48h     ; 'H'
        jnz  loc_0348
        lxi  h, var_0803
        mov  a, m
        ani  80h
        cpi  00h
        jz   loc_0348
        mvi  m, 00h
        inx  h
        mvi  m, 00h
        jmp  loc_0314
loc_0348:
        cpi  2Eh                     ; '.'
        jnz  loc_0391
        lxi  h, var_0803
        call prng_next
        sui  3Fh                     ; '?'
        jm   loc_035D
        mvi  m, 08h
        jmp  loc_035F
loc_035D:
        mvi  m, 18h
loc_035F:
        call prng_next
        sui  3Fh                     ; '?'
        jm   loc_0371
        mov  a, m
        adi  80h
        mov  m, a
        inx  h
        mvi  m, 02h
        jmp  loc_0314
loc_0371:
        inx  h
        mvi  m, 00h
        jmp  loc_0314
loc_0377:
        mvi  b, 03h
        lhld var_0800
loc_037C:
        xchg
        call de_row_down
        xchg
        mov  a, m
        cpi  4Fh                     ; 'O'
        jz   loc_02F6
        dcr  b
        mov  a, b
        cpi  01h
        jz   loc_0314
        jmp  loc_037C
loc_0391:
        cpi  24h                     ; '$'
        jnz  loc_0377
        lxi  h, var_081A
        mvi  m, 0FFh
        jmp  loc_0314
loc_039E:
        push psw
        push h
        push d
        push b
        call monitor_scan_kbd
        cpi  0FFh
        jz   loc_0416
        cpi  03h
        jnz  loc_03BA
loc_03AF:
        call monitor_cin
        cpi  0Dh
        jnz  loc_03AF
        jmp  loc_0416
; Arrow-key switch. Stores the pressed direction in the low 7 bits of
; var_0803 while preserving bit 7 (state flag). Pattern per arm:
;   var_0803 = (var_0803 & 80h) | key_code
loc_03BA:                                       ; offset=03BAh
        cpi  08h                                ; left arrow
        jnz  loc_03CB
        lxi  h, var_0803
        mov  a, m
        ani  80h
        adi  08h
        mov  m, a
        jmp  loc_0416
loc_03CB:                                       ; offset=03CBh
        cpi  18h                                ; right arrow
        jnz  loc_03DC
        lxi  h, var_0803
        mov  a, m
        ani  80h
        adi  18h
        mov  m, a
        jmp  loc_0416
loc_03DC:                                       ; offset=03DCh
        cpi  19h                                ; up arrow
        jnz  loc_03ED
        lxi  h, var_0803
        mov  a, m
        ani  80h
        adi  19h
        mov  m, a
        jmp  loc_0416
loc_03ED:                                       ; offset=03EDh
        cpi  1Ah                                ; down arrow
        jnz  loc_03FE
        lxi  h, var_0803
        mov  a, m
        ani  80h
        adi  1Ah
        mov  m, a
        jmp  loc_0416
loc_03FE:
        cpi  20h                     ; ' '
        jnz  loc_040F
        lxi  h, var_0803
        mov  a, m
        ani  7Fh
        adi  80h
        mov  m, a
        jmp  loc_0416
loc_040F:
        lxi  h, var_0803
        mov  a, m
        ani  80h
        mov  m, a
loc_0416:
        lxi  h, var_0804
        mov  a, m
        ani  7Fh
        cpi  00h
        jnz  loc_046E
        lxi  h, var_0800
        mov  e, m
        inx  h
        mov  d, m
        mov  a, e
        call de_row_down
        xchg
        mov  a, m
        cpi  3Dh                     ; '='
        jz   loc_046E
        cpi  23h                     ; '#'
        jz   loc_046E
        cpi  2Dh                     ; '-'
        jz   loc_043F
        jmp  loc_0444
loc_043F:
        mvi  m, 00h
        jmp  loc_046E
loc_0444:
        mov  b, h
        mov  c, l
        lxi  h, var_0802
        mov  a, m
        cpi  48h                     ; 'H'
        jnz  loc_0455
        mov  l, c
        mov  h, b
        xchg
        jmp  loc_046E
loc_0455:
        mov  h, b
        mov  l, c
        xchg
        lhld var_0800
        lda  var_0802
        mov  m, a
        xchg
        mov  a, m
        mvi  m, 09h
        sta  var_0802
        shld var_0800
        pop  b
        pop  d
        pop  h
        pop  psw
        ret
loc_046E:
        lhld var_0800
        xchg
        lxi  h, var_0803
        mov  a, m
        ani  80h
        jz   loc_04AA
        inx  h
        mov  a, m
        ani  7Fh
        cpi  00h
        jnz  loc_0486
        mvi  a, 02h
loc_0486:
        ral
        mov  m, a
        push psw
        ani  0Ch
        jz   loc_0492
        mov  a, e
        call de_row_up
loc_0492:
        pop  psw
        push psw
        ani  0C0h
        jz   loc_049D
        mov  a, e
        call de_row_down
loc_049D:
        pop  psw
        cpi  80h
        jnz  loc_04AA
        lxi  h, var_0803
        mov  a, m
        ani  7Fh
        mov  m, a
loc_04AA:
        lxi  h, var_0803
        mov  a, m
        ani  7Fh
        cpi  08h
        jnz  loc_04B9
        dcx  d
        jmp  loc_04EF
loc_04B9:
        cpi  18h
        jnz  loc_04C2
        inx  d
        jmp  loc_04EF
loc_04C2:
        cpi  1Ah
        jnz  loc_04D7
        lxi  h, var_0802
        mov  a, m
        cpi  48h                     ; 'H'
        jnz  loc_04EF
        mov  a, e
        call de_row_down
        jmp  loc_04EF
loc_04D7:
        cpi  19h
        jnz  loc_04EF
        lxi  h, var_0802
        mov  a, m
        cpi  48h                     ; 'H'
        jnz  loc_04EF
        lxi  h, var_0800
        mov  e, m
        inx  h
        mov  d, m
        mov  a, e
        call de_row_up
loc_04EF:
        xchg
        mov  a, m
        cpi  3Dh                     ; '='
        jnz  loc_0503
loc_04F6:
        lxi  h, var_0803
        mvi  m, 00h
        inx  h
        mvi  m, 00h
        pop  b
        pop  d
        pop  h
        pop  psw
        ret
loc_0503:
        cpi  23h                     ; '#'
        jnz  loc_050B
        jmp  loc_04F6
loc_050B:
        cpi  2Dh                     ; '-'
        jnz  loc_0513
        jmp  loc_04F6
loc_0513:
        xchg
        lhld var_0800
        lda  var_0802
        mov  m, a
        xchg
        mov  a, m
        sta  var_0802
        mvi  m, 09h
        shld var_0800
        pop  b
        pop  d
        pop  h
        pop  psw
        ret
; DE += video_width — move the video-memory pointer down one screen row.
de_row_down:                                    ; offset=052Ah
        push h
        push b
        mov  a, e
        adi  video_width
        mov  e, a
        jnc  de_row_down_ret
        inr  d
de_row_down_ret:                                ; offset=0534h
        pop  b
        pop  h
        ret

; DE -= video_width — move the video-memory pointer up one screen row.
de_row_up:                                      ; offset=0537h
        push h
        push b
        push psw
        mov  a, e
        sui  video_width
        mov  e, a
        jnc  de_row_up_ret
        dcr  d
de_row_up_ret:                                  ; offset=0542h
        pop  psw
        pop  b
        pop  h
        ret
; 32-bit LFSR PRNG. State = 4 bytes at prng_state (D:E:H:L, D is MSB).
; Seeded at boot with 5A 34 17 71.
;   Shift the full 32-bit state left by 1 (bits 0..30 carry upward).
;   Feedback: if (new D[7] XOR new L[7]) = 1 → set bit 0 of HL.
;   (Taps at bits 30 and 6 of the 32-bit state.)
; Returns A = one byte of pseudo-random data (new_D XOR new_L).
prng_next:                                      ; offset=0546h
        push h
        push d
        push b
        push psw
        lxi  h, prng_state   ; D:E = high 16 bits
        mov  d, m
        inx  h
        mov  e, m
        lhld prng_state + 2  ; H:L = low 16 bits
        dad  h               ; HL <<= 1, CY = old HL[15]
        mov  a, e
        ral                  ; E = (E<<1)|CY, new CY = old E[7]
        mov  e, a
        mov  a, d
        ral                  ; D = (D<<1)|CY, A = new D
        mov  d, a
        xra  l               ; A = new_D XOR new_L  (feedback + output)
        jp   prng_no_feedback
        inx  h               ; set bit 0 of HL (feedback tap fires)
prng_no_feedback:                               ; offset=055Fh
        shld prng_state + 2
        lxi  h, prng_state
        mov  m, d
        inx  h
        mov  m, e
        mov  b, a            ; preserve A (the random byte) across pop psw
        pop  psw
        mov  a, b
        pop  b
        pop  d
        pop  h
        ret
loc_056F:
        push b
        push psw
        shld var_080D
        xchg
        shld var_080F
        call de_row_down
        xchg
        mov  a, m
        cpi  3Dh     ; '='
        jz   loc_05C1
        cpi  23h     ; '#'
        jz   loc_05C1
        cpi  2Dh     ; '-'
        jz   loc_05C1
        cpi  48h     ; 'H'
        jnz  loc_059F
        mov  a, d
        cpi  1Ah     ; (RK86 blank glyph)
        jz   loc_059F
        call prng_next
        sui  7Fh
        jm   loc_05C1
loc_059F:
        lhld var_080F
        mvi  h, 1Ah
        shld var_080F
        lhld var_080D
        xchg
        lhld var_080F
        xchg
        mov  a, e
        cpi  20h                     ; ' '
        jz   loc_05B6
        mov  m, e
loc_05B6:
        xchg
        call de_row_down
        xchg
        mov  e, m
        mvi  m, 4Fh                  ; 'O'
        pop  psw
        pop  b
        ret
loc_05C1:
        lhld var_080F
        mov  a, h
        cpi  1Ah
        jnz  loc_05D9
        call prng_next
        sui  7Fh
        jm   loc_05D7
        mvi  h, 08h
        jmp  loc_05D9
loc_05D7:
        mvi  h, 18h
loc_05D9:
        xchg
loc_05DA:
        lhld var_080D
        mov  a, d
        cpi  08h
        jz   loc_05E7
        inx  h
        jmp  loc_05E8
loc_05E7:
        dcx  h
loc_05E8:
        mov  a, m
        cpi  23h                     ; '#'
        jnz  loc_05F5
loc_05EE:
        mov  a, d
        xri  10h
        mov  d, a
        jmp  loc_05DA
loc_05F5:
        cpi  48h                     ; 'H'
        jnz  loc_0602
        call prng_next
        sui  7Fh
        jm   loc_05EE
loc_0602:
        mov  b, h
        mov  c, l
        lhld var_080D
        mov  a, e
        cpi  20h                     ; ' '
        jz   loc_060E
        mov  m, e
loc_060E:
        mov  l, c
        mov  h, b
        mov  e, m
        mvi  m, 4Fh                  ; 'O'
        pop  psw
        pop  b
        ret
loc_0616:
        push h
        push d
        push b
        push psw
        lxi  h, table_0820 + 1
loc_061D:
        mov  a, m
        dcx  h
        cpi  00h
        jz   loc_0696
        mov  c, m
        inx  h
        mov  b, m
        inx  h
        mov  e, m
        inx  h
        mov  d, m
        push b
        push h
        pop  b
        pop  h
        call loc_056F
        call loc_0656
        dcx  b
        dcx  b
        dcx  b
        push b
        push h
        pop  b
        pop  h
        mov  m, c
        inx  h
        mov  m, b
        inx  h
        mov  m, e
        inx  h
        mov  m, d
        inx  h
loc_0644:
        mov  a, l
        push h
        lxi  h, table_0820
        sub  l
        pop  h
        sui  20h                     ; ' '
        inx  h
        jnz  loc_061D
        pop  psw
        pop  b
        pop  d
        pop  h
        ret
loc_0656:
        push psw
        push b
        push h
        push d
        mov  a, e
        cpi  09h
        jnz  loc_0668
        lxi  h, var_0811
        mvi  m, 0FFh
        jmp  loc_0691
loc_0668:
        cpi  20h                     ; ' '
        jnz  loc_0674
        pop  d
        mvi  e, 00h
        push d
        jmp  loc_0691
loc_0674:
        cpi  2Ah                     ; '*'
        jnz  loc_0688
        pop  d
        pop  h
        lxi  d, 1A55h
        mvi  m, 2Ah                  ; '*'
        lxi  h, 0000h
        push h
        push d
        jmp  loc_0691
loc_0688:
        cpi  4Fh                     ; 'O'
        jnz  loc_0691
        pop  d
        mvi  e, 20h                  ; ' '
        push d
loc_0691:
        pop  d
        pop  h
        pop  b
        pop  psw
        ret
loc_0696:
        push psw
        push b
        push h
        call prng_next
        sui  3Fh                     ; '?'
        jm   loc_06AB
loc_06A1:
        pop  h
        inx  h
loc_06A3:
        inx  h
        inx  h
        inx  h
        pop  b
        pop  psw
        jmp  loc_0644
loc_06AB:
        call prng_next
        sui  3Fh                     ; '?'
        jm   loc_06C5
        lhld var_0805
loc_06B6:
        mov  a, m
        cpi  55h                     ; 'U'
        jnz  loc_06A1
        push h
        pop  b
        pop  h
        mov  m, c
        inx  h
        mov  m, b
        jmp  loc_06A3
loc_06C5:
        lhld var_0807
        jmp  loc_06B6
loc_06CB:
        lxi  d, screen_data
        call paint_screen
        lxi  h, 018Eh
        mvi  m, 30h                  ; '0'
        lxi  h, 064Ch
        jmp  loc_0711
loc_06DC:
        call monitor_cin
        cpi  50h     ; 'P' — play
        jz   loc_012A
        cpi  45h     ; 'E' — exit (back to monitor)
        jz   monitor_prompt
        cpi  4Ch     ; 'L'
        jnz  loc_072B
        lxi  h, 064Ch
        mov  a, m
        cpi  20h     ; ' '
        jnz  loc_0711
        mvi  m, 40h                  ; '@'
        lxi  h, msg_cursor_r19_c21
        call monitor_puts
        mvi  c, 32h                  ; '2'
        call monitor_cout
        lxi  h, 01ACh
        mvi  m, 40h                  ; '@'
        lxi  h, 0242h
        mvi  m, 40h                  ; '@'
        jmp  loc_06DC
loc_0711:
        mvi  m, 20h                  ; ' '
        lxi  h, 01ACh
        mvi  m, 20h                  ; ' '
        lxi  h, 0242h
        mvi  m, 20h                  ; ' '
        lxi  h, msg_cursor_r19_c21
        call monitor_puts
        mvi  c, 31h     ; '1'
        call monitor_cout
        jmp  loc_06DC
loc_072B:
        cpi  53h                     ; 'S'
        jnz  loc_06DC
        lxi  h, 018Eh
        mov  a, m
        cpi  00h
        jz   loc_074D
        sui  08h
        mov  m, a
        lxi  h, msg_cursor_r21_c21
        call monitor_puts
        call monitor_curc
        inr  a
        mov  c, a
        call monitor_cout
        jmp  loc_06DC
loc_074D:
        mvi  m, 30h     ; '0'
        lxi  h, msg_cursor_r21_c21
        call monitor_puts
        mvi  c, 31h     ; '1'
        call monitor_cout
        jmp  loc_06DC

msg_cursor_r19_c21:                             ; offset=075Dh
        db   1Bh, "Y", 33h, 35h, 0
msg_cursor_r21_c21:                             ; offset=0762h
        db   1Bh, "Y", 35h, 35h, 0

; "поздравляю с победой!" + 5 beeps (07h), at screen home.
msg_congrats:                                   ; offset=0767h
        db   1Bh, "Y  "                      ; ESC-Y home cursor (row 0, col 0)
        db   "pozdrawlq` s pobedoj!"
        db   07h, 07h, 07h, 07h, 07h         ; 5 bells
        db   0

; Blanks at screen home — flashed alternately with msg_congrats for a blinking effect.
msg_clear_top:                                  ; offset=0786h
        db   1Bh, "Y  "                      ; ESC-Y home cursor
        db   "                      "         ; 22 spaces
        db   0

loc_07A1:
        mvi  d, 0Ah
loc_07A3:
        lxi  h, msg_congrats
        call monitor_puts
        lxi  b, 07FFh
        call delay_bc
        lxi  h, msg_clear_top
        call monitor_puts
        lxi  b, 07FFh
        call delay_bc
        dcr  d
        jnz  loc_07A3
        jmp  loc_0100
; Locate marker glyphs that screen_data painted into video memory,
; and cache their addresses for fast lookup during gameplay.
;   0812h : address of the flower (09h) glyph
;   0805h : address of the first  'U' (55h) glyph
;   0807h : address of the second 'U' glyph
loc_07C2:                                       ; offset=07C2h
        mvi  b, 09h                             ; flower glyph
        lxi  h, video_memory + 3*video_width + 7
        call find_byte_b
        shld var_0812
        mvi  b, 55h                             ; 'U'
        lxi  h, video_memory + 3*video_width + 7
        call find_byte_b
        shld var_0805
        inx  h                                  ; resume past the first 'U'
        call find_byte_b
        shld var_0807
        ret

; Scan memory forward from HL for the byte in B. Returns HL pointing at
; the first matching byte. No bounds check - caller guarantees B exists.
find_byte_b:                                    ; offset=07E0h
        mov  a, m
        cmp  b
        rz
        inx  h
        jmp  find_byte_b
loc_07E7:
        lxi  b, 0FFFFh
        call delay_bc
        lxi  h, msg_clear_ready
        call monitor_puts
        jmp  new_life

; ===========================================================================
; RAM data region. Initial byte values below are whatever the assembler left;
; the boot code at loc_0100 overwrites the ones the game actually reads
; before use. They still need to be preserved for a byte-exact round-trip.
; ===========================================================================

; 10 bytes of zero padding after the last code.               ; offset=07F6h
        db   00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h

var_0800:       db   77h                                       ; offset=0800h
var_0801:       db   7Eh                                       ; offset=0801h
var_0802:       db   2Ah                                       ; 0802h: tick counter (reset when it hits 1Eh)
var_0803:       db   00h                                       ; 0803h: direction flag (bit 7 mask in ani 80h)
var_0804:       db   00h                                       ; offset=0804h
; 0805h:0806h — address of 1st 'U' marker found by loc_07C2
var_0805:       db   79h, 78h
; 0807h:0808h — address of 2nd 'U' marker
var_0807:       db   83h, 78h
; 0809h..080Ch — prng_state (PRNG 32-bit state, reseeded at boot to 5A 34 17 71)
        db   5Ah, 34h, 17h, 71h
var_080D:       db   9Eh                                       ; offset=080Dh
var_080E:       db   7Dh
var_080F:       db   00h                                       ; offset=080Fh
var_0810:       db   08h
var_0811:       db   0FFh                                      ; offset=0811h
; 0812h:0813h — address of flower marker
var_0812:       db   0DBh, 7Dh
; HUD BCD counters (see CLAUDE.md "Known game concepts")
var_0814:       db   07h                                       ; 0814h BCD counter
var_0815:       db   35h                                       ; 0815h BCD counter
var_0816:       db   08h                                       ; offset=0816h
var_0817:       db   01h                                       ; 0817h BCD counter (boot = 01h)
; 0818h:0819h — 4-digit BCD score (lo, hi)
var_0818:       db   00h         ; score lo (BCD)
var_0819:       db   00h         ; score hi (BCD)
var_081A:       db   00h                                       ; offset=081Ah
; 081Bh:081Ch — 16-bit pointer, initialized at boot to 0862h (table base)
var_081B:       db   62h, 08h

; 3 bytes of zero padding                                     ; offset=081Dh
        db   00h, 00h, 00h

; Table of 16 x 4-byte records. Each record = [video_addr_lo,
; video_addr_hi, byte, byte]. The 16-bit address points into video memory
; (76D0h..7FF3h); the trailing two bytes are likely [glyph/count, tile_type].
; Terminated by FFFFh sentinel at 0860h.
table_0820:                                     ; offset=0820h
        db   8Ch, 7Eh, 00h, 08h      ; 7E8Ch + 00 08
        db   0A3h, 7Eh, 00h, 08h     ; 7EA3h + 00 08
        db   0ECh, 7Ah, 00h, 18h     ; 7AECh + 00 18
        db   9Bh, 7Eh, 00h, 18h      ; 7E9Bh + 00 18
        db   77h, 7Eh, 09h, 08h      ; 7E77h + 09 08
        db   7Ah, 7Eh, 00h, 08h      ; 7E7Ah + 00 08
        db   83h, 78h, 55h, 1Ah      ; 7883h + 'U' 1A
        db   9Dh, 7Dh, 00h, 08h      ; 7D9Dh + 00 08
        db   0F2h, 7Ah, 20h, 18h     ; 7AF2h + ' ' 18
        db   92h, 7Bh, 00h, 18h      ; 7B92h + 00 18
        db   9Eh, 79h, 00h, 1Ah      ; 799Eh + 00 1A
        db   90h, 7Bh, 00h, 18h      ; 7B90h + 00 18
        db   8Bh, 7Ah, 48h, 1Ah      ; 7A8Bh + 'H' 1A
        db   92h, 7Bh, 20h, 18h      ; 7B92h + ' ' 18
        db   0D1h, 7Bh, 00h, 1Ah     ; 7BD1h + 00 1A
        db   8Bh, 7Ah, 20h, 1Ah      ; 7A8Bh + ' ' 1A
        db   0FFh, 0FFh              ; offset=0860h — end-of-table sentinel

; Level-pointer table. var_081B is initialized to 0862h and advanced by 2
; bytes each time the player starts a new level (at loc_012A). Each entry
; is a 16-bit pointer to RLE-encoded screen data for one level. 0000h
; terminates the table (game won). 27 entries + sentinel = 7 unique levels
; played in a progressive "each round adds one rung" pattern:
;   R1: [A],          R2: [B,A],        R3: [B,C,A],
;   R4: [B,C,D,A],    R5: [B,C,D,E,A],  R6: [B,C,D,E,F,A],
;   R7: [B,C,D,E,F,G]
; where A=0C40, B=0E20, C=13A0, D=1080, E=15D0, F=18D0, G=1C00.
level_table:                                    ; offset=0862h
        dw   level_A                                           ; R1: A
        dw   level_B, level_A                                  ; R2
        dw   level_B, level_C, level_A                         ; R3
        dw   level_B, level_C, level_D, level_A                ; R4
        dw   level_B, level_C, level_D, level_E, level_A       ; R5
        dw   level_B, level_C, level_D, level_E, level_F, level_A  ; R6
        dw   level_B, level_C, level_D, level_E, level_F, level_G  ; R7
        dw   0000h                                             ; sentinel: game won

; 54 bytes of zero padding up to msg_get_ready at 08D0h.     ; offset=089Ah
        db   00h, 00h, 00h, 00h, 00h, 00h
        db   00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h
        db   00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h
        db   00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h
        db   00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h
        db   00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h
        db   00h, 00h, 00h, 00h, 00h, 00h, 00h, 00h
; "приготовьтесь!" (get ready) + 5 bells, at row 24 col 48.
msg_get_ready:                                  ; offset=08D0h
        db   1Bh, "Y", 38h, 50h              ; ESC-Y row 24, col 48
        db   "prigotowxtesx!"
        db   07h, 07h, 07h, 07h, 07h         ; 5 bells
        db   0

; 14 blanks at row 24 col 48 + 5 bells — clears the "get ready" text.
msg_clear_ready:                                ; offset=08E8h
        db   1Bh, "Y", 38h, 50h              ; ESC-Y row 24, col 48
        db   "              "                 ; 14 spaces
        db   07h, 07h, 07h, 07h, 07h         ; 5 bells
        db   0

; =============================================================================
; Screen data — RLE-compressed video memory snapshots.
; =============================================================================
;
; Contains the title/menu screen followed by 7 level maps (A..G). The entry
; points are pulled from level_table; each stream is decoded by paint_screen.
;
; Decoder (see paint_screen at 015Bh):
;   destination starts at video_memory + 3*video_width + 7  (= 77C1h,
;     i.e. row 3, col 7, just below the title bar and above the status row)
;   destination runs until HL = 7FA0h (row 28, col 72), i.e. a flat
;     stretch of 2015 bytes of video memory
;
; Stream format (one byte per source position, except for the RLE escape):
;   NN (00h..0FEh) — literal: write NN to the destination and advance 1
;   FFh NN         — run: write NN zero bytes to the destination
;                   (NN ranges 00h..FFh; 0 means "skip this escape")
;
; Notes:
;   * Only runs of ZERO (blank cell) are compressed — any other byte is
;     emitted literally, even when it repeats.
;   * There is NO explicit stream terminator — the decoder stops the moment
;     HL crosses into 7FA0h. Each level stream is sized to exactly fill
;     2015 bytes of output regardless of how many source bytes it took.
;   * Typical compressed level size is ~800 bytes; title screen is ~825
;     bytes. Compression ratio ~2.5x over the raw 2015-byte playfield.
;   * Glyphs used are the RK86 character set (see info/rk86-charmap.md):
;     block-drawing 00h..1Fh, ASCII 20h..5Fh, Cyrillic 60h..7Fh.
;
; Human-readable renderings of each screen live under `levels/` and can be
; regenerated with `python3 render_screen.py --extract`.
; =============================================================================
screen_data:                                    ; offset=0900h

; --- TITLE / MENU screen ---
        db   0FFh, 55h, 4Fh, 4Fh, 4Fh, 00h, 4Fh, 4Fh, 4Fh, 4Fh, 0FFh, 02h, 4Fh, 4Fh, 4Fh, 0FFh   ; 0900h
        db   02h, 4Fh, 4Fh, 4Fh, 4Fh, 4Fh, 00h, 4Fh, 0FFh, 03h, 4Fh, 00h, 4Fh, 0FFh, 03h, 4Fh
        db   00h, 4Fh, 0FFh, 03h, 4Fh, 0FFh, 05h, 4Fh, 4Fh, 4Fh, 0FFh, 08h, 4Fh, 0FFh, 16h, 4Fh
        db   0FFh, 02h, 4Fh, 00h, 4Fh, 0FFh, 04h, 4Fh, 0FFh, 03h, 4Fh, 0FFh, 03h, 4Fh, 0FFh, 03h
        db   4Fh, 0FFh, 03h, 4Fh, 00h, 4Fh, 0FFh, 03h, 4Fh, 00h, 4Fh, 0FFh, 03h, 4Fh, 0FFh, 04h
        db   4Fh, 0FFh, 02h, 4Fh, 0FFh, 07h, 4Fh, 4Fh, 0FFh, 16h, 4Fh, 0FFh, 02h, 4Fh, 00h, 4Fh
        db   4Fh, 4Fh, 0FFh, 02h, 4Fh, 0FFh, 07h, 4Fh, 0FFh, 03h, 4Fh, 4Fh, 4Fh, 4Fh, 4Fh, 00h
        db   4Fh, 0FFh, 02h, 4Fh, 4Fh, 00h, 4Fh, 0FFh, 03h, 4Fh, 0FFh, 03h, 4Fh, 0FFh, 03h, 4Fh
        db   0FFh, 08h, 4Fh, 0FFh, 16h, 4Fh, 0FFh, 02h, 4Fh, 00h, 4Fh, 0FFh, 04h, 4Fh, 0FFh, 07h
        db   4Fh, 0FFh, 03h, 4Fh, 0FFh, 03h, 4Fh, 00h, 4Fh, 00h, 4Fh, 00h, 4Fh, 00h, 4Fh, 0FFh
        db   03h, 4Fh, 0FFh, 03h, 4Fh, 4Fh, 4Fh, 4Fh, 4Fh, 0FFh, 02h, 4Fh, 4Fh, 4Fh, 0FFh, 03h
        db   4Fh, 0FFh, 16h, 4Fh, 0FFh, 02h, 4Fh, 00h, 4Fh, 0FFh, 04h, 4Fh, 0FFh, 02h, 20h, 4Fh
        db   0FFh, 03h, 4Fh, 0FFh, 03h, 4Fh, 0FFh, 03h, 4Fh, 00h, 4Fh, 4Fh, 0FFh, 02h, 4Fh, 00h
        db   4Fh, 0FFh, 03h, 4Fh, 0FFh, 03h, 4Fh, 0FFh, 03h, 4Fh, 0FFh, 08h, 4Fh, 0FFh, 15h, 4Fh
        db   4Fh, 0FFh, 02h, 4Fh, 00h, 4Fh, 4Fh, 4Fh, 4Fh, 0FFh, 02h, 4Fh, 4Fh, 4Fh, 0FFh, 04h
        db   4Fh, 0FFh, 03h, 4Fh, 0FFh, 03h, 4Fh, 00h, 4Fh, 0FFh, 03h, 4Fh, 20h, 4Fh, 4Fh, 4Fh
        db   4Fh, 4Fh, 4Fh, 4Fh, 00h, 4Fh, 0FFh, 03h, 4Fh, 0FFh, 07h, 4Fh, 4Fh, 4Fh, 0FFh, 3Dh   ; 0A00h
        db   4Fh, 0FFh, 8Eh, 77h, 65h, 72h, 73h, 69h, 60h, 20h, 64h, 6Ch, 71h, 20h, 70h, 7Ch
        db   77h, 6Dh, 20h, 22h, 72h, 61h, 64h, 69h, 6Fh, 2Dh, 38h, 36h, 72h, 6Bh, 22h, 0FFh
        db   32h, 72h, 61h, 7Ah, 72h, 61h, 62h, 6Fh, 74h, 61h, 6Ch, 20h, 73h, 69h, 6Dh, 6Fh
        db   6Eh, 6Fh, 77h, 20h, 60h, 2Eh, 62h, 2Eh, 0FFh, 69h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 35h, 23h, 00h, 24h, 20h, 2Dh, 20h, 77h, 79h, 68h, 6Fh
        db   64h, 20h, 69h, 7Ah, 20h, 75h, 72h, 6Fh, 77h, 6Eh, 71h, 0FFh, 19h, 50h, 20h, 2Dh
        db   20h, 6Eh, 61h, 7Eh, 61h, 6Ch, 6Fh, 20h, 69h, 67h, 72h, 79h, 0FFh, 09h, 5Dh, 3Ch
        db   0FFh, 06h, 23h, 00h, 0Bh, 20h, 2Dh, 20h, 6Fh, 7Eh, 65h, 6Eh, 78h, 20h, 70h, 6Ch
        db   6Fh, 68h, 61h, 71h, 20h, 7Bh, 74h, 75h, 6Bh, 61h, 0FFh, 16h, 4Ch, 20h, 2Dh, 20h
        db   75h, 73h, 74h, 61h, 6Eh, 6Fh, 77h, 6Bh, 61h, 20h, 73h, 6Ch, 6Fh, 76h, 6Eh, 6Fh
        db   73h, 74h, 69h, 00h, 5Dh, 3Ch, 20h, 77h, 61h, 7Bh, 0FFh, 02h, 23h, 00h, 2Eh, 20h
        db   2Dh, 20h, 6Fh, 7Eh, 65h, 6Eh, 78h, 20h, 68h, 69h, 74h, 72h, 61h, 71h, 20h, 7Bh
        db   74h, 75h, 6Bh, 61h, 0FFh, 16h, 53h, 20h, 2Dh, 20h, 75h, 73h, 74h, 61h, 6Eh, 6Fh   ; 0B00h
        db   77h, 6Bh, 61h, 20h, 73h, 6Bh, 6Fh, 72h, 6Fh, 73h, 74h, 69h, 0FFh, 02h, 5Dh, 3Ch
        db   00h, 68h, 6Fh, 64h, 0FFh, 02h, 23h, 00h, 6Fh, 20h, 2Dh, 20h, 75h, 77h, 65h, 73h
        db   69h, 73h, 74h, 79h, 6Ah, 20h, 62h, 75h, 6Ch, 79h, 76h, 6Eh, 69h, 6Bh, 0FFh, 16h
        db   65h, 20h, 2Dh, 20h, 77h, 79h, 68h, 6Fh, 64h, 20h, 77h, 20h, 6Dh, 6Fh, 6Eh, 69h
        db   74h, 6Fh, 72h, 0FFh, 05h, 5Dh, 3Ch, 0FFh, 06h, 23h, 00h, 1Eh, 20h, 2Dh, 20h, 70h
        db   72h, 69h, 71h, 74h, 6Eh, 61h, 71h, 20h, 77h, 65h, 7Dh, 78h, 0FFh, 3Bh, 23h, 00h
        db   6Eh, 20h, 2Dh, 20h, 6Ch, 65h, 73h, 74h, 6Eh, 69h, 63h, 61h, 0FFh, 24h, 73h, 6Ch
        db   6Fh, 76h, 6Eh, 6Fh, 73h, 74h, 78h, 20h, 2Dh, 20h, 31h, 0FFh, 0Fh, 23h, 00h, 09h
        db   20h, 2Dh, 20h, 61h, 20h, 7Ch, 74h, 6Fh, 20h, 2Dh, 20h, 6Ch, 69h, 7Eh, 6Eh, 6Fh
        db   20h, 77h, 79h, 0FFh, 38h, 23h, 0FFh, 03h, 75h, 20h, 70h, 20h, 72h, 20h, 61h, 20h
        db   77h, 20h, 6Ch, 20h, 65h, 20h, 6Eh, 20h, 69h, 20h, 65h, 20h, 3Ah, 0FFh, 19h, 73h
        db   6Bh, 6Fh, 72h, 6Fh, 73h, 74h, 78h, 20h, 20h, 2Dh, 20h, 31h, 0FFh, 0Fh, 23h, 00h
        db   77h, 70h, 72h, 61h, 77h, 6Fh, 2Ch, 20h, 77h, 6Ch, 65h, 77h, 6Fh, 2Ch, 20h, 77h
        db   77h, 65h, 72h, 68h, 20h, 69h, 0FFh, 36h, 23h, 00h, 77h, 6Eh, 69h, 7Ah, 20h, 70h
        db   6Fh, 20h, 6Ch, 65h, 73h, 74h, 6Eh, 69h, 63h, 65h, 20h, 2Dh, 20h, 6Bh, 6Ch, 61h
        db   77h, 69h, 2Dh, 0FFh, 33h, 23h, 00h, 7Bh, 61h, 6Dh, 69h, 20h, 75h, 70h, 72h, 61h   ; 0C00h
        db   77h, 6Ch, 65h, 6Eh, 69h, 71h, 20h, 6Bh, 75h, 72h, 73h, 6Fh, 72h, 6Fh, 6Dh, 2Ch
        db   0FFh, 0Eh, 20h, 0FFh, 24h, 23h, 00h, 70h, 72h, 79h, 76h, 6Fh, 6Bh, 20h, 2Dh, 20h
        db   70h, 72h, 6Fh, 62h, 65h, 6Ch, 2Eh, 0FFh, 57h, 76h, 0Ah, 0DAh, 2Ch, 0Bh, 0CDh, 48h

; --- LEVEL A (home rung) ---
level_A:                                        ; offset=0C40h
        db   0FFh, 67h, 74h, 20h, 69h, 20h, 68h, 20h, 6Fh, 20h, 65h, 20h, 20h, 20h, 6Dh, 20h   ; 0C40h
        db   65h, 20h, 73h, 20h, 74h, 20h, 6Fh, 0FFh, 3Ch, 55h, 0FFh, 09h, 55h, 0FFh, 09h, 24h
        db   0FFh, 4Dh, 48h, 0FFh, 29h, 48h, 0FFh, 0Fh, 23h, 0FFh, 07h, 2Eh, 2Eh, 2Eh, 2Eh, 2Eh
        db   0FFh, 07h, 48h, 0FFh, 27h, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 6Eh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 28h, 48h
        db   0FFh, 11h, 48h, 0FFh, 3Bh, 48h, 0FFh, 4Dh, 48h, 0FFh, 08h, 48h, 0FFh, 05h, 2Eh, 0FFh
        db   15h, 48h, 0FFh, 24h, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 48h, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 0FFh, 04h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 0FFh, 26h
        db   1Eh, 0FFh, 08h, 48h, 0FFh, 1Bh, 48h, 0FFh, 28h, 20h, 0FFh, 08h, 20h, 0FFh, 05h, 3Dh
        db   2Dh, 48h, 2Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 0Bh, 48h, 0FFh, 28h, 48h
        db   0FFh, 24h, 48h, 0FFh, 27h, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh   ; 0D00h
        db   3Dh, 3Dh, 3Dh, 0FFh, 03h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 00h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 27h, 48h, 0FFh
        db   4Dh, 48h, 0FFh, 4Dh, 48h, 0FFh, 0Dh, 0Bh, 0FFh, 18h, 48h, 0FFh, 22h, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 04h, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 16h, 23h, 0FFh
        db   31h, 48h, 0FFh, 1Bh, 23h, 0FFh, 31h, 48h, 0FFh, 1Bh, 23h, 09h, 0FFh, 0Fh, 3Dh, 3Dh
        db   48h, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 00h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   48h, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h
        db   0FFh, 0Ch, 23h, 0FFh, 0Eh, 23h, 3Dh, 0FFh, 0Dh, 3Dh, 3Dh, 0FFh, 2Eh, 23h, 0FFh, 0Eh
        db   23h, 2Ah, 2Eh, 0FFh, 0Bh, 0Bh, 0FFh, 23h, 0Bh, 0FFh, 0Bh, 2Ah, 23h, 0FFh, 0Eh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh
        db   0Eh, 75h, 72h, 6Fh, 77h, 65h, 6Eh, 78h, 0FFh, 06h, 70h, 6Fh, 70h, 79h, 74h, 6Bh   ; 0E00h
        db   69h, 0FFh, 06h, 6Fh, 7Eh, 6Bh, 69h, 0FFh, 08h, 77h, 72h, 65h, 6Dh, 71h, 0FFh, 63h

; --- LEVEL B (first climb) ---
level_B:                                        ; offset=0E20h
        db   0FFh, 18h, 55h, 0FFh, 04h, 73h, 70h, 6Fh, 6Bh, 6Fh, 6Ah, 6Eh, 61h, 71h, 20h, 20h   ; 0E20h
        db   70h, 72h, 6Fh, 67h, 75h, 6Ch, 6Bh, 61h, 0FFh, 1Fh, 6Ch, 6Fh, 77h, 75h, 7Bh, 6Bh
        db   61h, 0FFh, 49h, 64h, 6Ch, 71h, 0FFh, 13h, 48h, 0FFh, 35h, 64h, 75h, 72h, 61h, 6Bh
        db   6Fh, 77h, 0FFh, 0Eh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 1Dh, 24h, 0FFh, 1Ah, 21h, 0FFh, 12h
        db   48h, 00h, 2Eh, 0FFh, 1Dh, 48h, 00h, 20h, 0FFh, 18h, 21h, 0FFh, 0Eh, 3Dh, 0FFh, 03h
        db   2Dh, 2Dh, 2Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 48h, 3Dh
        db   3Dh, 48h, 2Dh, 0FFh, 09h, 1Eh, 0FFh, 03h, 48h, 0FFh, 1Ah, 21h, 0FFh, 05h, 48h, 0FFh
        db   27h, 55h, 23h, 0FFh, 03h, 48h, 0FFh, 1Ah, 21h, 0FFh, 04h, 3Dh, 48h, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 19h, 21h, 0FFh, 05h
        db   6Eh, 0FFh, 47h, 56h, 0FFh, 05h, 48h, 0FFh, 0Ch, 23h, 0FFh, 40h, 48h, 0FFh, 0Ah, 1Eh
        db   00h, 23h, 0FFh, 13h, 2Eh, 00h, 2Eh, 0FFh, 07h, 48h, 0FFh, 19h, 23h, 0FFh, 07h, 3Dh
        db   48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 00h, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 0FFh, 03h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh   ; 0F00h
        db   3Dh, 00h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 0FFh, 18h, 23h, 0FFh
        db   07h, 23h, 0FFh, 2Bh, 48h, 0FFh, 02h, 23h, 00h, 23h, 0FFh, 05h, 23h, 0FFh, 0Eh, 23h
        db   00h, 0Bh, 00h, 0Bh, 00h, 2Eh, 00h, 23h, 0FFh, 13h, 23h, 0FFh, 17h, 48h, 0FFh, 02h
        db   23h, 00h, 23h, 0FFh, 05h, 23h, 0FFh, 0Eh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh
        db   00h, 00h, 48h, 0FFh, 11h, 23h, 0FFh, 0Ch, 2Eh, 0FFh, 02h, 2Eh, 0FFh, 07h, 48h, 0FFh
        db   02h, 23h, 48h, 2Eh, 00h, 2Eh, 0Bh, 2Eh, 00h, 23h, 0FFh, 17h, 3Dh, 48h, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 04h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 02h
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 3Dh, 3Dh, 3Dh
        db   3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 23h, 48h, 23h, 23h, 23h, 23h, 23h, 23h
        db   23h, 0FFh, 18h, 48h, 0FFh, 2Ch, 23h, 48h, 0FFh, 1Fh, 48h, 0FFh, 09h, 23h, 0FFh, 43h
        db   48h, 0FFh, 09h, 23h, 0Bh, 0FFh, 12h, 2Eh, 0FFh, 03h, 2Eh, 0FFh, 08h, 48h, 0FFh, 21h
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 0FFh, 03h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh
        db   03h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 0FFh, 17h, 23h, 0FFh
        db   34h, 48h, 0FFh, 09h, 23h, 0FFh, 0Eh, 23h, 0FFh, 1Ah, 0Bh, 0FFh, 19h, 48h, 0FFh, 09h
        db   23h, 0FFh, 0Eh, 23h, 0FFh, 02h, 09h, 0FFh, 0Eh, 2Ah, 0FFh, 08h, 23h, 0FFh, 0Fh, 2Ah   ; 1000h
        db   0FFh, 09h, 48h, 0FFh, 02h, 0Bh, 0FFh, 06h, 23h, 0FFh, 0Eh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 0Eh, 75h, 72h, 6Fh
        db   77h, 65h, 6Eh, 78h, 20h, 20h, 20h, 0FFh, 03h, 70h, 6Fh, 70h, 79h, 74h, 6Bh, 69h
        db   0FFh, 06h, 6Fh, 7Eh, 6Bh, 69h, 0FFh, 08h, 77h, 72h, 65h, 6Dh, 71h, 0FFh, 63h, 76h

; --- LEVEL D ---
level_D:                                        ; offset=1080h
        db   00h, 23h, 0FFh, 12h, 55h, 0FFh, 1Ch, 55h, 0FFh, 1Dh, 23h, 0FFh, 4Dh, 23h, 0FFh, 03h   ; 1080h
        db   48h, 2Eh, 2Eh, 2Eh, 2Eh, 2Eh, 48h, 0FFh, 04h, 48h, 2Eh, 2Eh, 2Eh, 2Eh, 48h, 0FFh
        db   04h, 48h, 2Eh, 2Eh, 2Eh, 2Eh, 48h, 0FFh, 04h, 23h, 00h, 2Eh, 0FFh, 04h, 2Eh, 0FFh
        db   02h, 48h, 0FFh, 02h, 2Eh, 0FFh, 1Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 2Dh, 2Dh, 2Dh, 2Dh
        db   2Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 00h, 3Dh, 3Dh, 2Dh, 2Dh
        db   2Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 1Ch, 48h
        db   0FFh, 0Ah, 48h, 0FFh, 02h, 1Eh, 0FFh, 08h, 23h, 00h, 1Eh, 00h, 1Eh, 0FFh, 0Dh, 48h
        db   0FFh, 24h, 48h, 0FFh, 0Ah, 48h, 0FFh, 0Bh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh   ; 1100h
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 05h, 48h, 0FFh, 24h, 48h, 0FFh, 07h, 23h, 0FFh, 02h
        db   48h, 0FFh, 09h, 48h, 0FFh, 02h, 77h, 65h, 73h, 65h, 6Ch, 79h, 6Ah, 0FFh, 03h, 48h
        db   0FFh, 06h, 48h, 0FFh, 05h, 2Dh, 48h, 2Dh, 2Dh, 48h, 2Dh, 0FFh, 19h, 48h, 0FFh, 07h
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 2Dh, 2Dh, 2Dh, 3Dh, 48h, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 0FFh, 06h, 48h, 0FFh, 24h
        db   48h, 0FFh, 0Ch, 48h, 0FFh, 02h, 1Eh, 0FFh, 06h, 48h, 00h, 74h, 75h, 6Eh, 6Eh, 65h
        db   6Ch, 78h, 00h, 1Eh, 48h, 0FFh, 06h, 48h, 0FFh, 24h, 48h, 0FFh, 0Bh, 3Dh, 48h, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 48h, 0FFh, 06h, 48h, 0FFh, 24h, 48h, 0FFh, 0Bh, 23h, 48h, 0FFh, 06h
        db   1Eh, 0FFh, 0Ah, 48h, 0FFh, 09h, 48h, 0FFh, 04h, 2Eh, 00h, 2Eh, 00h, 2Eh, 00h, 2Eh
        db   0FFh, 19h, 48h, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 2Eh, 00h, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 48h, 0FFh, 09h, 48h, 0FFh, 03h, 6Eh, 65h, 00h, 73h, 6Fh, 77h, 73h, 65h, 6Dh
        db   0FFh, 18h, 48h, 00h, 4Dh, 00h, 6Fh, 00h, 50h, 00h, 67h, 00h, 48h, 0FFh, 14h, 48h
        db   0FFh, 02h, 48h, 23h, 0FFh, 05h, 48h, 0FFh, 03h, 2Eh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh
        db   0Bh, 2Eh, 0FFh, 18h, 48h, 0FFh, 09h, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 1Eh, 2Dh, 3Dh   ; 1200h
        db   3Dh, 00h, 2Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h
        db   3Dh, 0FFh, 05h, 48h, 0FFh, 04h, 6Dh, 00h, 6Fh, 00h, 72h, 00h, 67h, 0FFh, 19h, 48h
        db   0FFh, 07h, 2Eh, 2Eh, 48h, 0FFh, 17h, 48h, 0FFh, 06h, 48h, 0FFh, 20h, 23h, 0FFh, 0Bh
        db   3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 2Dh, 2Dh, 3Dh, 3Dh, 3Dh, 3Dh, 2Dh, 2Dh
        db   2Dh, 2Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 05h, 48h, 0FFh
        db   20h, 23h, 0FFh, 0Dh, 48h, 0FFh, 1Ch, 1Eh, 00h, 48h, 0FFh, 20h, 23h, 2Eh, 0FFh, 02h
        db   2Eh, 0FFh, 03h, 2Eh, 0FFh, 05h, 48h, 0FFh, 0Fh, 0Bh, 0FFh, 02h, 0Bh, 0FFh, 08h, 0Bh
        db   0FFh, 02h, 48h, 0FFh, 05h, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 0FFh, 15h, 23h, 3Dh, 3Dh
        db   2Dh, 2Dh, 2Dh, 3Dh, 3Dh, 23h, 0FFh, 05h, 48h, 0FFh, 04h, 0Bh, 0FFh, 02h, 0Bh, 0FFh
        db   02h, 0Bh, 0FFh, 10h, 23h, 0FFh, 02h, 48h, 0FFh, 20h, 23h, 0FFh, 07h, 23h, 0FFh, 05h
        db   48h, 0FFh, 0Ah, 23h, 3Dh, 3Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 48h, 0FFh, 20h, 23h, 0FFh, 02h, 3Dh, 3Dh, 3Dh
        db   0FFh, 02h, 23h, 0FFh, 03h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh
        db   2Dh, 3Dh, 3Dh, 0FFh, 13h, 48h, 0FFh, 06h, 09h, 00h, 48h, 0FFh, 08h, 23h, 0FFh, 0Eh
        db   23h, 0FFh, 03h, 24h, 0FFh, 03h, 23h, 0FFh, 09h, 3Dh, 3Dh, 0FFh, 0Ch, 0Bh, 0FFh, 0Ch
        db   48h, 0FFh, 05h, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 0FFh, 06h, 23h, 0FFh, 0Eh, 23h, 2Ah   ; 1300h
        db   00h, 24h, 24h, 24h, 00h, 2Ah, 23h, 00h, 2Eh, 0Bh, 2Eh, 0FFh, 11h, 2Eh, 0Bh, 2Eh
        db   0Bh, 2Eh, 0FFh, 07h, 2Eh, 2Ah, 00h, 48h, 0FFh, 07h, 2Ah, 48h, 0FFh, 03h, 2Eh, 0Bh
        db   2Eh, 0FFh, 02h, 23h, 0FFh, 0Eh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 0Eh, 75h, 72h, 6Fh, 77h, 65h, 6Eh, 78h, 0FFh
        db   06h, 70h, 6Fh, 70h, 79h, 74h, 6Bh, 69h, 0FFh, 06h, 6Fh, 7Eh, 6Bh, 69h, 0FFh, 08h
        db   77h, 72h, 65h, 6Dh, 71h, 0FFh, 63h, 00h, 0FFh, 00h, 0FFh, 00h, 0FFh, 00h, 0FFh, 00h

; --- LEVEL C ---
level_C:                                        ; offset=13A0h
        db   00h, 23h, 0FFh, 17h, 55h, 0FFh, 02h, 70h, 6Fh, 70h, 72h, 79h, 67h, 75h, 6Eh, 7Eh   ; 13A0h
        db   69h, 6Bh, 69h, 0FFh, 02h, 55h, 0FFh, 24h, 23h, 0FFh, 32h, 24h, 0FFh, 1Ah, 23h, 0FFh
        db   02h, 09h, 0FFh, 07h, 48h, 0FFh, 25h, 2Eh, 0Bh, 0Bh, 0Bh, 2Eh, 0FFh, 18h, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 0FFh, 22h, 48h, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 48h, 0FFh, 22h, 48h, 0FFh, 23h, 48h, 0FFh, 06h, 6Eh, 0FFh, 22h
        db   48h, 0FFh, 11h, 2Eh, 0FFh, 02h, 1Eh, 0FFh, 0Bh, 2Eh, 0FFh, 02h, 48h, 0FFh, 06h, 48h
        db   0FFh, 1Fh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 05h, 3Dh, 0FFh, 04h   ; 1400h
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 04h, 3Dh, 0FFh, 05h, 3Dh, 3Dh, 3Dh, 3Dh, 48h
        db   3Dh, 3Dh, 0FFh, 04h, 6Eh, 0FFh, 1Eh, 62h, 0FFh, 09h, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 1Eh
        db   0Bh, 0Bh, 0Bh, 0Bh, 0FFh, 06h, 0Bh, 0Bh, 0Bh, 0Bh, 1Eh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh
        db   0FFh, 0Bh, 2Eh, 0FFh, 1Eh, 79h, 0FFh, 26h, 23h, 0FFh, 07h, 24h, 0FFh, 1Eh, 73h, 00h
        db   23h, 2Eh, 2Eh, 0FFh, 07h, 48h, 0FFh, 06h, 48h, 0FFh, 06h, 48h, 0FFh, 09h, 1Eh, 0FFh
        db   02h, 23h, 0FFh, 26h, 74h, 00h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   48h, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 48h
        db   2Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   2Eh, 0FFh, 21h, 72h, 0FFh, 0Bh, 48h, 0FFh, 08h, 23h, 00h, 2Eh, 00h, 1Eh, 0FFh, 02h
        db   23h, 23h, 0FFh, 30h, 79h, 0FFh, 0Bh, 48h, 0FFh, 08h, 23h, 0FFh, 05h, 48h, 0FFh, 32h
        db   6Ah, 00h, 1Eh, 0FFh, 09h, 48h, 0FFh, 08h, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 0FFh
        db   3Eh, 48h, 0FFh, 41h, 73h, 0FFh, 03h, 23h, 2Eh, 0FFh, 06h, 48h, 0FFh, 18h, 0Bh, 0FFh
        db   05h, 48h, 0FFh, 22h, 70h, 0FFh, 03h, 3Dh, 3Dh, 3Dh, 2Dh, 2Dh, 2Dh, 2Dh, 3Dh, 48h
        db   3Dh, 3Dh, 3Dh, 3Dh, 2Dh, 2Dh, 2Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 48h, 3Dh
        db   3Dh, 0FFh, 20h, 75h, 0FFh, 2Ah, 48h, 0FFh, 22h, 73h, 0FFh, 2Ah, 48h, 0FFh, 22h, 6Bh   ; 1500h
        db   0FFh, 17h, 2Eh, 0FFh, 0Ah, 48h, 0FFh, 07h, 48h, 0FFh, 1Bh, 23h, 0FFh, 0Bh, 3Dh, 48h
        db   3Dh, 0FFh, 0Fh, 3Dh, 0Bh, 3Dh, 0FFh, 09h, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 0FFh, 0Ch, 23h, 0FFh, 0Eh, 23h, 0FFh, 12h, 0Bh, 0FFh, 08h, 3Dh, 3Dh, 00h, 2Eh
        db   00h, 3Dh, 3Dh, 0FFh, 07h, 48h, 0FFh, 14h, 23h, 0FFh, 0Eh, 23h, 0FFh, 02h, 2Ah, 0FFh
        db   0Dh, 2Eh, 0Bh, 0Bh, 0Bh, 2Eh, 0FFh, 09h, 0Bh, 0FFh, 0Ah, 48h, 0FFh, 07h, 2Eh, 0Bh
        db   2Eh, 0Bh, 2Eh, 0Bh, 2Eh, 0FFh, 03h, 2Ah, 0FFh, 02h, 23h, 0FFh, 0Eh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 0Eh, 75h
        db   72h, 6Fh, 77h, 65h, 6Eh, 78h, 0FFh, 06h, 70h, 6Fh, 70h, 79h, 74h, 6Bh, 69h, 0FFh
        db   06h, 6Fh, 7Eh, 6Bh, 69h, 0FFh, 08h, 77h, 72h, 65h, 6Dh, 71h, 0FFh, 63h, 00h, 05h

; --- LEVEL E ---
level_E:                                        ; offset=15D0h
        db   00h, 70h, 6Fh, 64h, 27h, 65h, 6Dh, 0FFh, 09h, 6Fh, 74h, 64h, 79h, 68h, 0FFh, 02h   ; 15D0h
        db   77h, 0FFh, 02h, 67h, 6Fh, 72h, 61h, 68h, 0FFh, 0Eh, 6Ch, 61h, 77h, 69h, 6Eh, 79h
        db   0FFh, 0Dh, 23h, 0FFh, 0Fh, 2Bh, 0FFh, 05h, 24h, 0FFh, 21h, 1Eh, 0FFh, 02h, 21h, 0FFh
        db   02h, 55h, 00h, 21h, 0FFh, 0Dh, 23h, 0FFh, 0Fh, 2Bh, 0FFh, 05h, 48h, 0FFh, 03h, 70h   ; 1600h
        db   72h, 69h, 71h, 74h, 6Eh, 6Fh, 67h, 6Fh, 00h, 77h, 61h, 6Dh, 00h, 6Fh, 74h, 64h
        db   79h, 68h, 61h, 00h, 21h, 0FFh, 0Bh, 56h, 0FFh, 04h, 56h, 0FFh, 02h, 48h, 0FFh, 05h
        db   09h, 0FFh, 04h, 23h, 0FFh, 0Fh, 2Bh, 2Bh, 2Bh, 2Bh, 3Eh, 00h, 48h, 0FFh, 20h, 48h
        db   0FFh, 0Ah, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh
        db   15h, 48h, 0FFh, 20h, 48h, 0FFh, 0Bh, 48h, 0FFh, 20h, 48h, 48h, 48h, 48h, 48h, 48h
        db   48h, 48h, 48h, 48h, 48h, 48h, 48h, 0FFh, 04h, 2Eh, 48h, 48h, 48h, 48h, 48h, 48h
        db   48h, 48h, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 0FFh, 0Bh, 48h, 0FFh, 19h, 23h
        db   0FFh, 06h, 1Eh, 0FFh, 12h, 55h, 0FFh, 05h, 48h, 0FFh, 0Eh, 2Dh, 2Dh, 48h, 2Dh, 2Dh
        db   48h, 0FFh, 19h, 23h, 0FFh, 1Fh, 6Eh, 0FFh, 13h, 48h, 0FFh, 19h, 23h, 0FFh, 06h, 48h
        db   0FFh, 18h, 48h, 0FFh, 05h, 2Eh, 0FFh, 0Dh, 48h, 0FFh, 04h, 2Eh, 0FFh, 14h, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh
        db   3Dh, 2Dh, 2Dh, 2Dh, 3Dh, 2Dh, 2Dh, 2Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 48h, 3Dh
        db   3Dh, 3Dh, 0FFh, 10h, 48h, 0FFh, 03h, 2Dh, 3Dh, 2Dh, 0FFh, 1Ah, 48h, 0FFh, 25h, 48h
        db   0FFh, 06h, 48h, 0FFh, 20h, 48h, 0FFh, 22h, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 18h, 70h, 72h, 6Fh, 77h, 61h, 6Ch, 00h, 48h, 0FFh, 18h
        db   48h, 0FFh, 0Ch, 48h, 0FFh, 08h, 0Bh, 2Eh, 0Bh, 0FFh, 06h, 23h, 0FFh, 15h, 48h, 0FFh   ; 1700h
        db   07h, 1Eh, 2Eh, 2Eh, 0Bh, 0Bh, 0Bh, 2Eh, 00h, 2Eh, 0Bh, 2Eh, 0Bh, 2Eh, 00h, 0Bh
        db   0Bh, 00h, 48h, 23h, 3Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 0FFh, 03h, 48h, 0FFh
        db   11h, 23h, 0FFh, 11h, 21h, 0FFh, 03h, 48h, 0FFh, 06h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 0FFh, 04h, 1Eh
        db   0FFh, 07h, 48h, 0FFh, 0Ah, 48h, 0FFh, 06h, 23h, 0FFh, 11h, 21h, 0FFh, 03h, 48h, 0FFh
        db   06h, 3Dh, 3Dh, 3Dh, 00h, 3Dh, 00h, 1Eh, 3Dh, 00h, 3Dh, 0FFh, 04h, 3Dh, 3Dh, 3Dh
        db   00h, 48h, 0FFh, 04h, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh
        db   11h, 21h, 0FFh, 03h, 48h, 0FFh, 18h, 48h, 0FFh, 17h, 48h, 0FFh, 18h, 21h, 0FFh, 03h
        db   48h, 0FFh, 06h, 2Eh, 0FFh, 0Bh, 1Eh, 0FFh, 03h, 2Eh, 00h, 48h, 0FFh, 03h, 2Eh, 0FFh
        db   04h, 1Eh, 00h, 2Eh, 0FFh, 0Ch, 48h, 0FFh, 18h, 21h, 0FFh, 03h, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 2Dh, 2Dh, 2Dh, 2Dh, 48h, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh
        db   2Dh, 2Dh, 2Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh
        db   48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 18h
        db   56h, 0FFh, 31h, 2Eh, 0FFh, 18h, 23h, 0FFh, 0Eh, 3Dh, 3Dh, 2Dh, 2Dh, 2Dh, 2Dh, 0FFh
        db   03h, 2Dh, 2Dh, 2Dh, 2Dh, 3Dh, 3Dh, 0FFh, 07h, 3Dh, 3Dh, 2Dh, 2Dh, 2Dh, 2Dh, 3Dh   ; 1800h
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 09h, 23h, 0FFh, 0Eh, 23h
        db   0FFh, 11h, 1Eh, 0FFh, 07h, 1Eh, 0FFh, 0Dh, 1Eh, 00h, 1Eh, 0FFh, 05h, 1Eh, 0FFh, 0Eh
        db   23h, 0FFh, 0Eh, 23h, 0Bh, 0Bh, 0Bh, 2Ah, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0FFh, 03h, 0Bh
        db   0Bh, 00h, 0Bh, 0Bh, 23h, 0Bh, 0Bh, 0Bh, 2Ah, 0Bh, 0Bh, 0Bh, 23h, 0Bh, 0Bh, 00h
        db   0Bh, 0Bh, 2Ah, 0Bh, 2Eh, 0Bh, 0Bh, 00h, 0Bh, 23h, 0Bh, 2Ah, 0Bh, 0Bh, 0Bh, 0FFh
        db   02h, 0Bh, 2Eh, 0FFh, 07h, 23h, 00h, 0Bh, 0Bh, 0Bh, 2Ah, 0Bh, 23h, 0FFh, 0Eh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh
        db   0Eh, 75h, 72h, 6Fh, 77h, 65h, 6Eh, 78h, 0FFh, 06h, 70h, 6Fh, 70h, 79h, 74h, 6Bh
        db   69h, 0FFh, 06h, 6Fh, 7Eh, 6Bh, 69h, 0FFh, 08h, 77h, 72h, 65h, 6Dh, 71h, 0FFh, 63h

; --- LEVEL F ---
level_F:                                        ; offset=18D0h
        db   00h, 72h, 61h, 73h, 73h, 65h, 69h, 77h, 61h, 74h, 65h, 6Ch, 78h, 00h, 23h, 0FFh   ; 18D0h
        db   15h, 0Bh, 0FFh, 0Dh, 55h, 0FFh, 1Ch, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh
        db   2Dh, 2Dh, 2Dh, 3Eh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh   ; 1900h
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 75h, 73h, 6Ch, 61h, 64h
        db   61h, 0FFh, 31h, 6Eh, 6Eh, 48h, 48h, 48h, 48h, 48h, 48h, 0FFh, 10h, 73h, 65h, 72h
        db   64h, 63h, 61h, 0FFh, 30h, 48h, 48h, 48h, 2Eh, 0FFh, 04h, 48h, 48h, 48h, 0FFh, 2Dh
        db   48h, 0FFh, 06h, 0Bh, 0FFh, 0Eh, 2Eh, 0FFh, 05h, 2Eh, 0FFh, 31h, 48h, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 23h, 0FFh, 06h, 0Bh, 0FFh, 07h, 23h, 0FFh, 05h, 23h, 0Bh, 00h, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 08h, 48h, 0FFh, 1Fh, 6Eh, 0FFh, 06h, 23h, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 03h, 23h, 00h, 0Bh, 0Bh
        db   0Bh, 00h, 23h, 0FFh, 02h, 55h, 0FFh, 0Bh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 0FFh
        db   1Ch, 48h, 0FFh, 15h, 23h, 0FFh, 05h, 23h, 0FFh, 07h, 6Bh, 72h, 69h, 77h, 61h, 71h
        db   0FFh, 04h, 48h, 0FFh, 1Fh, 6Eh, 0FFh, 15h, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 0FFh
        db   02h, 23h, 00h, 24h, 0FFh, 0Ch, 48h, 0FFh, 1Fh, 48h, 0FFh, 09h, 48h, 0FFh, 0Eh, 2Eh
        db   0FFh, 05h, 23h, 00h, 6Eh, 0FFh, 04h, 64h, 6Fh, 72h, 6Fh, 67h, 61h, 0FFh, 02h, 48h
        db   0FFh, 1Ah, 0Bh, 0FFh, 04h, 6Eh, 0FFh, 07h, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh
        db   0Ah, 09h, 0FFh, 05h, 23h, 1Eh, 48h, 00h, 48h, 0FFh, 0Ah, 48h, 0FFh, 09h, 0Bh, 0FFh
        db   10h, 23h, 0FFh, 04h, 48h, 0FFh, 09h, 48h, 0FFh, 0Bh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 0FFh, 07h, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 09h   ; 1A00h
        db   23h, 0FFh, 10h, 23h, 0FFh, 04h, 6Eh, 0FFh, 09h, 48h, 0FFh, 05h, 1Eh, 23h, 0FFh, 11h
        db   48h, 0FFh, 0Fh, 48h, 0FFh, 04h, 23h, 0FFh, 10h, 23h, 0FFh, 04h, 48h, 0FFh, 09h, 48h
        db   0FFh, 05h, 1Eh, 23h, 0FFh, 0Bh, 48h, 0FFh, 05h, 48h, 0FFh, 0Ah, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 48h, 3Dh, 3Dh, 0FFh, 02h, 23h, 0FFh, 10h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh
        db   3Dh, 3Dh, 1Eh, 0FFh, 05h, 48h, 0FFh, 06h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   48h, 3Dh, 3Dh, 3Dh, 48h, 0FFh, 05h, 48h, 0FFh, 03h, 72h, 61h, 6Ah, 73h, 6Bh, 69h
        db   65h, 0FFh, 05h, 48h, 0FFh, 04h, 23h, 0FFh, 10h, 23h, 1Eh, 0FFh, 03h, 2Eh, 00h, 1Eh
        db   23h, 0FFh, 06h, 48h, 0FFh, 12h, 48h, 0FFh, 05h, 48h, 0FFh, 04h, 21h, 0FFh, 02h, 6Bh
        db   75h, 7Dh, 69h, 0FFh, 04h, 48h, 0FFh, 04h, 23h, 0FFh, 10h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   6Eh, 3Dh, 3Dh, 3Dh, 0FFh, 06h, 48h, 0FFh, 12h, 48h, 0FFh, 05h, 1Eh, 0FFh, 04h, 21h
        db   0FFh, 0Ah, 48h, 0FFh, 04h, 23h, 0FFh, 0Fh, 6Fh, 74h, 64h, 79h, 68h, 6Eh, 6Fh, 77h
        db   65h, 6Eh, 69h, 65h, 00h, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 0FFh, 03h, 3Dh, 3Dh, 3Dh
        db   0FFh, 04h, 48h, 0FFh, 05h, 1Eh, 0FFh, 0Ah, 21h, 0FFh, 0Ah, 48h, 0FFh, 04h, 23h, 0FFh
        db   13h, 64h, 75h, 7Bh, 69h, 0FFh, 07h, 2Eh, 1Eh, 2Eh, 0FFh, 0Bh, 48h, 3Dh, 3Dh, 48h
        db   3Dh, 3Dh, 0FFh, 06h, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 21h, 00h, 3Dh, 0Bh, 0Bh, 0Bh, 0Bh
        db   00h, 23h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 0Eh, 0Bh, 0FFh, 1Dh, 48h   ; 1B00h
        db   0FFh, 03h, 1Eh, 0FFh, 0Ch, 21h, 0Bh, 0FFh, 02h, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 0FFh, 11h, 23h, 0FFh, 16h, 0Bh, 0Bh, 0Bh, 0Bh, 2Eh, 2Eh, 2Eh, 48h
        db   2Dh, 3Dh, 3Dh, 3Dh, 2Dh, 3Dh, 0FFh, 08h, 0Bh, 00h, 2Bh, 2Dh, 2Dh, 3Eh, 23h, 1Eh
        db   0FFh, 06h, 1Eh, 23h, 0FFh, 02h, 23h, 0FFh, 0Eh, 23h, 0FFh, 12h, 3Dh, 3Dh, 0FFh, 02h
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 0FFh, 09h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 2Eh, 0FFh, 02h, 2Eh, 0FFh, 02h, 23h, 0FFh
        db   02h, 23h, 0FFh, 0Eh, 23h, 2Ah, 0FFh, 05h, 0Bh, 0FFh, 03h, 0Bh, 0FFh, 05h, 0Bh, 0FFh
        db   0Ch, 48h, 0FFh, 0Bh, 48h, 0FFh, 04h, 2Eh, 0FFh, 03h, 48h, 2Eh, 0FFh, 03h, 0Bh, 0FFh
        db   02h, 48h, 0Bh, 00h, 2Ah, 23h, 0FFh, 0Eh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 0Eh, 75h, 72h, 6Fh, 77h, 65h, 6Eh
        db   78h, 0FFh, 06h, 70h, 6Fh, 70h, 79h, 74h, 6Bh, 69h, 0FFh, 06h, 6Fh, 7Eh, 6Bh, 69h
        db   0FFh, 08h, 77h, 72h, 65h, 6Dh, 71h, 0FFh, 63h, 00h, 0FFh, 00h, 0FFh, 00h, 0FFh, 00h

; --- LEVEL G (for the luckiest) ---
level_G:                                        ; offset=1C00h
        db   0FFh, 05h, 72h, 00h, 65h, 00h, 7Ah, 00h, 6Fh, 00h, 6Ch, 00h, 60h, 00h, 63h, 00h   ; 1C00h
        db   69h, 00h, 71h, 0FFh, 05h, 06h, 0FFh, 03h, 75h, 72h, 6Fh, 77h, 65h, 6Eh, 78h, 00h
        db   64h, 6Ch, 71h, 00h, 73h, 61h, 6Dh, 79h, 68h, 00h, 73h, 7Eh, 61h, 73h, 74h, 6Ch
        db   69h, 77h, 79h, 68h, 0FFh, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h
        db   14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h, 14h
        db   16h, 00h, 48h, 0FFh, 0Ch, 55h, 0FFh, 40h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 0FFh, 09h, 2Eh, 2Eh, 2Eh, 0FFh, 2Dh, 23h, 0FFh, 1Dh
        db   2Eh, 2Eh, 2Eh, 0FFh, 20h, 23h, 0FFh, 02h, 09h, 0FFh, 02h, 48h, 0FFh, 06h, 23h, 1Eh
        db   0FFh, 05h, 23h, 0FFh, 16h, 2Eh, 2Eh, 2Eh, 0FFh, 02h, 48h, 0FFh, 03h, 6Dh, 0FFh, 11h
        db   77h, 00h, 73h, 00h, 65h, 0FFh, 03h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 0FFh, 06h
        db   23h, 00h, 0Bh, 0FFh, 04h, 48h, 0FFh, 08h, 1Eh, 0FFh, 03h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 48h, 0FFh, 21h, 55h, 00h, 48h
        db   0FFh, 06h, 23h, 00h, 2Eh, 00h, 0Bh, 0FFh, 02h, 23h, 0FFh, 08h, 3Dh, 3Dh, 0FFh, 0Ch
        db   1Eh, 0FFh, 04h, 48h, 0FFh, 03h, 69h, 0FFh, 12h, 64h, 00h, 6Ch, 00h, 71h, 0FFh, 08h
        db   48h, 0FFh, 06h, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 02h, 48h, 0FFh, 10h
        db   0Bh, 0Bh, 0Bh, 2Eh, 0FFh, 04h, 48h, 0FFh, 23h, 48h, 0FFh, 10h, 48h, 3Dh, 3Dh, 0FFh
        db   0Eh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 00h, 48h, 0FFh, 03h, 72h, 0FFh, 13h, 77h   ; 1D00h
        db   00h, 61h, 00h, 73h, 0FFh, 03h, 48h, 0FFh, 03h, 48h, 0FFh, 10h, 48h, 0FFh, 0Ch, 1Eh
        db   0FFh, 0Bh, 48h, 0FFh, 1Fh, 48h, 3Dh, 3Dh, 3Dh, 48h, 0FFh, 10h, 48h, 0FFh, 08h, 23h
        db   0FFh, 03h, 23h, 0FFh, 06h, 0Bh, 0FFh, 04h, 48h, 0FFh, 03h, 61h, 0FFh, 14h, 21h, 00h
        db   21h, 00h, 21h, 0FFh, 02h, 48h, 0FFh, 0Bh, 0Bh, 0Bh, 1Eh, 1Eh, 0Bh, 0Bh, 00h, 1Eh
        db   0Bh, 48h, 0FFh, 04h, 48h, 0FFh, 03h, 23h, 0FFh, 03h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 0FFh, 1Fh, 48h, 0FFh, 09h, 3Dh, 3Dh, 3Dh, 3Dh
        db   48h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 3Dh, 3Dh, 3Dh
        db   3Dh, 0FFh, 05h, 1Eh, 0FFh, 09h, 48h, 0FFh, 03h, 76h, 0FFh, 1Bh, 48h, 0FFh, 14h, 6Eh
        db   0FFh, 04h, 48h, 0FFh, 08h, 1Eh, 1Eh, 1Eh, 0FFh, 08h, 48h, 0FFh, 34h, 6Eh, 0FFh, 04h
        db   48h, 0FFh, 07h, 1Eh, 1Eh, 1Eh, 1Eh, 1Eh, 0Bh, 0Bh, 2Eh, 2Eh, 0Bh, 0Bh, 00h, 48h
        db   0FFh, 03h, 69h, 0FFh, 30h, 48h, 0FFh, 04h, 48h, 0FFh, 07h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 48h, 0FFh, 2Ah, 3Dh, 3Dh, 2Dh, 2Dh, 2Dh, 2Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 03h, 48h, 0FFh, 03h, 23h, 0FFh, 06h, 24h, 0FFh
        db   04h, 24h, 0FFh, 07h, 2Bh, 0FFh, 31h, 23h, 0FFh, 03h, 48h, 0FFh, 03h, 23h, 0FFh, 05h
        db   24h, 24h, 24h, 0FFh, 02h, 24h, 24h, 24h, 0FFh, 06h, 2Bh, 0FFh, 18h, 3Dh, 3Dh, 3Dh
        db   2Dh, 2Dh, 2Dh, 2Dh, 2Dh, 3Dh, 3Dh, 3Dh, 0FFh, 0Eh, 23h, 0FFh, 03h, 48h, 0FFh, 03h   ; 1E00h
        db   23h, 0FFh, 04h, 24h, 24h, 24h, 24h, 24h, 24h, 24h, 24h, 24h, 24h, 0FFh, 02h, 3Ch
        db   2Bh, 2Bh, 2Bh, 0FFh, 11h, 0Bh, 0FFh, 06h, 61h, 00h, 7Ah, 64h, 65h, 73h, 78h, 0FFh
        db   03h, 23h, 0FFh, 03h, 3Dh, 0FFh, 0Ah, 23h, 00h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 23h
        db   0FFh, 03h, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 07h
        db   0Bh, 0FFh, 0Eh, 23h, 0FFh, 05h, 70h, 72h, 69h, 64h, 65h, 74h, 73h, 71h, 0FFh, 03h
        db   23h, 0FFh, 03h, 24h, 0FFh, 0Bh, 0Bh, 0FFh, 03h, 1Eh, 0FFh, 19h, 23h, 0FFh, 0Eh, 23h
        db   0FFh, 03h, 70h, 6Fh, 6Bh, 61h, 72h, 71h, 7Eh, 69h, 74h, 78h, 73h, 71h, 00h, 23h
        db   0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0FFh, 03h, 24h, 00h, 0Bh, 0FFh, 06h, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 0FFh, 16h, 23h, 0FFh, 0Eh, 23h, 2Ah, 0FFh, 11h, 2Eh, 2Eh, 2Eh, 2Eh, 00h
        db   1Eh, 00h, 0Bh, 48h, 2Ah, 0Bh, 0FFh, 0Bh, 0Bh, 00h, 0Bh, 0FFh, 0Bh, 0Bh, 0Bh, 0Bh
        db   0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 23h, 0FFh, 0Eh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh
        db   3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 3Dh, 0FFh, 0Eh, 75h, 72h, 6Fh, 77h, 65h, 6Eh
        db   78h, 0FFh, 06h, 70h, 6Fh, 70h, 79h, 74h, 6Bh, 69h, 0FFh, 06h, 6Fh, 7Eh, 6Bh, 69h   ; 1F00h
        db   0FFh, 08h, 77h, 72h, 65h, 6Dh, 71h, 0FFh, 63h, 00h, 0FFh, 00h, 0FFh, 00h, 0FFh, 00h
