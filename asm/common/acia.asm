;
; acia.asm - ACIA serial interfaces for the Z80 monitor
; 01-08-24 E. Brombaugh
;

; registers
ACIA_PORT:	equ $03	; The UART's data buffer for in/out
ACIA_LSR:	equ	$02	; Line Status Register (used for transmitter empty bit)
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Wait until UART has a byte, store it in A
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
inchar:
		IN A, (ACIA_LSR)	; read LSR
		BIT 0, A			; bit 1 is RXF
		JP Z, inchar
		IN A, (ACIA_PORT)
		RET
		
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; If UART has a byte, store it in A else return $FF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
chkchar:
		IN A, (ACIA_LSR)
		BIT 0, A			; bit 1 is set when data present
		JP NZ, gotchar
		LD A, $FF
		RET
gotchar:
		IN A, (ACIA_PORT)
		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Output the byte in A to UART, wait until transmitted
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
outchar:
		PUSH AF
		OUT (ACIA_PORT), A
; wait until transmitted
oloop:	
		IN A, (ACIA_LSR)	; read LSR
		BIT 1, A	; bit 0 is transmitter empty
		JP Z, oloop
		POP AF
		RET
	