;
; rom.asm - rom code for the z80 system test
; 12-26-2023 E. Brombaugh
;

org $0000

;
; Start - init stack ptr
;
		ld sp, $0fff

;
; test SPI IO
;
;		in a, ($13)
;		in a, ($12)
;		in a, ($11)
;		in a, ($10)
;		out ($10), a

;
; boot message
;
		ld hl, msg0
		call cstr_out

;
; IO test
;
;		ld a, $00
loop:
;		out ($00), a
;		call acia_out
;		call delay
;		ld b, 0
;dlp:
;		djnz dlp
;		inc a
;		call acia_in
;		call acia_out
		in a, ($02)
		and $03
		ld c, a
		ld a, b
		and $FC
		or c
		out ($00), a
		
		in a, ($02)
		and $01
		jp Z, skip_ser
		in a, ($03)
		out ($03), a
		
skip_ser:		
		inc b
		jp loop

;
; C string (null terminated) output to ACIA
; string ptr in HL, A, A' trashed
;
cstr_out:
		ld a, (hl)
		and a
		jp Z, cstr_done
		call acia_out
		inc hl
		jp cstr_out
cstr_done:
		ret
		
;
; single char output to ACIA
; data in A, A' is trashed
; waits for TXE before sending, returns immediately after
;
acia_out:
		EX AF,AF'
tx_wait:
		in a, ($02)
		and $02
		jp Z, tx_wait
		EX AF,AF'
		out ($03), a
		ret

;
; single char input from ACIA
; returns immediately with char in A. Z flag indicates if char is valid
;
acia_in:
		in a, ($02)
rx_wait:
		and $01
		jp Z, rx_wait
		in a, ($03)
rx_skip:
		ret
	
;
; strings
;
msg0:
	defm "\n\rice40 Z80\n\r"
	defb 0

;
; delay
;
delay:
		ld b, 0
dloop:
		djnz dloop
		ret
end
