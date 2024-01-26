;
; Simple monitor on UART
;
; Derived from https://github.com:fiskabollen/z80Monitor
; Ported to z80asm for icebreaker_z80 by ebrombaugh@gmail.com 01-02-24
;
;  Current address is in HL
;  Display [nnnn] bb (A)
;          nnnn is current address, bb is hex byte, A is ASCII char
;  Input:
; <space> displays current byte
; [0-9,A-F] enters current address
; <enter> increments current address (loops through FFFF)
; <backspace> decrements current address (loops through 0000)
; l lists 16 locations, update current
; d dumps a grid of memory from current until keypress
; c copies memory: requesting from, to and length
; S (capital) enters set mode: hex input fills memory until <enter> or <ESC>
; X (capital) executes from current
; h <enter> display this help
; any errors dislpays '?'",$0A,$0D
;
; Memory Map is
; 0000-3FFF	16K ROM (probably though only 4k or 8k chip)
; 4000-7FFF space for 16K of memory (ROM or RAM)
; 8000-FFFF 32K RAM


RAMTOP:		equ	$FFFF	;	RAM ends at $FFFF
TEMP:		equ RAMTOP	; 	Temporary storage byte
KDATA1:		equ TEMP-1	;	keyed input for addresses
KDATA2:		equ KDATA1-1
BUFFER:		equ	KDATA2-256	; for building strings - 256 bytes
STACK:		equ BUFFER-1	; then we have the stack
	
	org 0C000h
	
	LD SP,STACK

init:
	LD HL,0000h
	LD A, $00				; Clear GPIO out
	OUT ($00), A
	
start:
; Output the startup text
	LD DE, TEXT0
	CALL otext
	
; Output the current location [nnnn] bb (A)
display:
	CALL dispadd	; Display [nnnn]
	LD A, ' '
	CALL outchar
	CALL outchar
	LD A, (HL)
	CALL hexout
	LD A, ' '
	CALL outchar
	LD A, '('
	CALL outchar
	LD A, (HL)
	CALL outchar
	LD A, ')'
	CALL outchar
	CALL OUTCRLF
	
inloop:
	CALL inchar			; wait for input
	LD BC, 0			; C is used

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SELECT BASED ON INPUT CHAR
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	CP ' '			; <space>: display
	JP Z, display
	CP $0D			; <CR>: increment and display
	JP NZ, L1
	INC HL
	JP display
L1:	CP $08		; backspace: decrement and display
	JP NZ, L2
	DEC HL
	JP display
L2:	CP 'h'			; h: show help then display
	JP Z, start
	CP 'i'			; i: IO in
	JP Z, io_in
	CP 'O'			; O: IO out
	JP Z, io_out
	CP 'R'			; R: SPI Read
	JP Z, spi_read_test
	CP 'c'			; c: copy memory
	JP Z, copy
	CP 'd'			; d: dump until keypress
	JP Z, dump
	CP 'l'			; l: list 16 locations
	JP Z, list
	CP 'S'			; S: enter write mode (set)
	JP Z, set
	CP 'k'			; k: bulk set memory
	JP Z, bulkset
	CP 't'			; t: type ascii to memory
	JP Z, typemem
	CP 'X'			; X: execute from current
	JP Z, exec
	CP 30h			; test for hex digit
	JP C, notdig	; < $30
	CP 47h			
	JP NC, notdig	; >= $47
	CP 3Ah
	JP NC, T1		; >= $3A
	JP digit
T1:	CP 41h			; AND
	JR C, notdig	; < $41
digit:
	CALL fourcar	; <hexdigit>: address entry
	JP display
notdig:
	LD A, '?'		; no other commands, output '?'
	CALL outchar
	CALL OUTCRLF
	JP display

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SET
;;   output SET [aaaa] [nn] where nn is current contents
;;   call two character input to set (HL)
;;   increment HL
;;   repeat until <esc>
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
set:
	LD DE, SETTXT
	CALL otext
	CALL dispadd
	LD A, ' '
	CALL outchar
	
	CALL twocar		; two character input and set (HL)
	CALL OUTCRLF	; new line
	LD A, B			; B contains $FF if we aborted
	CP $FF
	JP NZ, setend	; abort - go to display
	JP display	
setend:
	INC HL			; else next address and loops
	JP set
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; EXECUTE
;;    execute from HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
exec:
	LD DE, EXTXT	; confirmation text
	CALL otext
	CALL dispadd
	CALL OUTCRLF
	
	CALL inchar
	CP $0D			; <ret> we continue, else abort
	JP NZ, xabort	
	PUSH HL
	RET
xabort:
	JP display
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; LIST - LIST 16 LOCATIONS, SETTING HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
list:
	LD C, $FF		; Use C=$FF to do one cycle of dump

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DUMP - dump memory from current location until keypress
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
dump:
	LD A, H
	CALL hexout
	LD A, L
	CALL hexout
	
	LD A, ' '
	CALL outchar
	CALL outchar

	LD B, 16
	LD IX, BUFFER		; Build string of ASCII values at TEMP
loop16:	
	LD A, (HL)
	CALL hexout
	LD (IX+0), '.'		; set it to dot and we'll overwrite if it's displayable
	CP 20h				; displayable is >$19 and <$7f
	JP M, skip
	CP 7Fh
	JP P, skip
	LD (IX+0), A			; replace with the ASCII code otherwise
skip:
	LD A, ' '
	CALL outchar
	INC HL
	INC IX
	DEC B
	LD A, 0
	CP B
	JP NZ, loop16
	
	; Output the 8 ASCII chars at BUFFER
	; Add a $80 on the end and use otext routine
	LD A, 80h
	LD (BUFFER+16), A
	LD DE, BUFFER
	CALL otext
	CALL OUTCRLF
	
	LD A, C				; check if we were only doing one line
	CP $FF
	JP Z, display		; C was $FF so stop at one cycle
	
	CALL chkchar		; check if a key was pressed
	CP $FF
	JP NZ, display		; a keypress: abort
	
	JP dump
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; COPY from, to, length (all in hex)
;;    use BUFFER to store 'to' and 'from'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
copy:
	PUSH HL
	PUSH DE
	PUSH BC
	LD DE, CPTXT1	; Copy: From
	CALL otext
	
	LD A, $30		; start fourcar with [0000]
	CALL fourcar
	LD (BUFFER), HL
	LD DE, CPTXT2	; To:
	CALL otext
	LD A, $30		; start fourcar with [0000]
	CALL fourcar
	LD (BUFFER+2), HL
	LD DE, CPTXT3	; Length:
	CALL otext
	LD A, $30		; start fourcar with [0000]
	CALL fourcar
;	LD BC, HL		; set up for eLDIR - this instr is not legal for orig z80
	LD B, H		; set up for eLDIR
	LD C, L		; set up for eLDIR
	LD DE, (BUFFER+2)
	LD HL, (BUFFER)
	CALL eLDIR
	
	LD DE, DONETXT	; Done
	CALL otext
	POP BC
	POP DE
	POP HL
	JP display

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Four hex digit rotating input starting with contents of A
;;   exits on <ret> or <esc>
;;   HL contains the address input on return
;;   or HL remains unchanged on abort
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
fourcar:
		PUSH AF
		PUSH BC
;		LD BC, HL		; save original HL - illegal opcode
		LD B, H		; save original HL
		LD C, L		; save original HL
		; First set HL to [000(digit)] to display
		CALL ATOHEX
		LD L, A
		LD H, 00h
		LD (KDATA2), A	; start with the digit we were given
		LD A, 0
		LD (KDATA1), A
		; Output [nnnn] then one backspace
		CALL dispadd
		LD A, $08
		CALL outchar
fcloop:
		; Output 4 backspaces
		LD A, $08
		CALL outchar
		CALL outchar
		CALL outchar
		CALL outchar
		
		CALL inchar
		CP $0D			; <return>: end
		JP Z, fcend
		CP $1B		; <escape>: abort
		JP NZ, fccont
;		LD HL, BC		; Abort - restore old value - illegal opcode
		LD H, B		; Abort - restore old value
		LD L, C		; Abort - restore old value
		JP fcabort
fccont:	CALL ATOHEX
		LD HL, KDATA2
		RLD
		LD HL, KDATA1
		RLD
		LD A, (KDATA1)
		CALL hexout
		LD A, (KDATA2)
		CALL hexout
		JP fcloop
		
fcend:	LD HL, (KDATA2)		;Loads L then H
fcabort:
		CALL OUTCRLF
		POP BC
		POP AF
		RET	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TWO CHARACTER ROLLING INPUT ROUTINE, exits on <esc> or <ret>
;;   sets (HL) to A and returns
;;   on <esc> set (HL) to original value, write FF to A and return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
twocar:
		PUSH HL
		; Output [00] then one backspace
		LD A, '['
		CALL outchar
		LD A, '0'
		CALL outchar
		CALL outchar
		LD A, ']'
		CALL outchar
		LD A, $08
		CALL outchar
		LD B, (HL)		; save the old contents for <esc>
		LD HL, KDATA1
		LD (HL), 0
tcloop:
		; Output 2 backspaces
		LD A, $08
		CALL outchar
		CALL outchar

		CALL inchar
		CP $0D
		JP Z, tcend
		CP $1B
		JP Z, tcabort
		
		CALL ATOHEX
		RLD
		LD A, (HL)
		CALL hexout
		JP tcloop
		
tcabort:
		LD A, B		; <esc>: so restore A
		LD (KDATA1), A
		LD B, $FF	; Use $FF in B to indicate an abort
tcend:	POP HL
		LD A, (KDATA1)
		LD (HL), A	; set (HL) to KDATA1
		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;; Display '[aaaa]' - address of HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
dispadd:
		LD A, '['
		CALL outchar
		LD A, H
		CALL hexout
		LD A, L
		CALL hexout
		LD A, ']'
		CALL outchar
		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
; OUTPUT VALUE OF A IN HEX ONE NYBBLE AT A TIME
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
hexout:	PUSH BC
		PUSH AF
		LD B, A
		; Upper nybble
		SRL A
		SRL A
		SRL A
		SRL A
		CALL TOHEX
		CALL outchar
		
		; Lower nybble
		LD A, B
		AND 0FH
		CALL TOHEX
		CALL outchar
		
		POP AF
		POP BC
		RET
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
; TRANSLATE value in lower A TO 2 HEX CHAR CODES FOR DISPLAY
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
TOHEX:
		PUSH HL
		PUSH DE
		LD D, 0
		LD E, A
		LD HL, DATA
		ADD HL, DE
		LD A, (HL)
		POP DE
		POP HL
		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 	ASCII char code for 0-9,A-F in A to single hex digit
;;    subtract $30, if result > 9 then subtract $7 more
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ATOHEX:
		SUB $30
		CP 10
		RET M		; If result negative it was 0-9 so we're done
		SUB $7		; otherwise, subtract $7 more to get to $0A-$0F
		RET		

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; eLDIR - LDIR but with confirmed writes
;;   HL=from, DE=to, BC=length
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
eLDIR:
		PUSH AF
ldlp:	LD A, B			; test BC for zero first
		OR C			; stupid z80 doesn't flag after DEC xy
		JP Z, ldend
		LD A, (HL)
		PUSH HL
;		LD HL, DE		; illegal opcode
		LD H, D
		LD L, E
		CALL CONFWR		; uses HL
		POP HL
		INC HL
		INC DE
		DEC BC
		JP ldlp
ldend:	POP AF
		RET		
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CONFWR - Write to address with confirm, returns when complete
;;          used for writign to EEPROM
;;  This will hang the computer if write does not succeed
;; byte to write is in A
;; address to write is HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CONFWR:
		PUSH BC
		LD B, A
		LD (HL), A		; write the byte
eeloop:	LD A, (HL)		; read the byte
		CP B			; the EEPROM puts inverse of the value
		JP NZ, eeloop	; while it is writing
		POP BC
		RET	
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; serial I/O
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
include '../common/acia.asm'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
; Output text pointed to by DE
;   loop through calling outchar until $80 is encountered
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
otext:
		PUSH AF
otloop:	LD A, (DE)
		CP $80			; $80 means end of text
		JP Z, otend		
		CALL outchar	; output the byte in A
		INC DE			; point to next
		JP otloop
otend:	POP AF
		RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;; OUTCRLF - output a CR and an LF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
OUTCRLF:
		PUSH AF
		LD A, $0D
		CALL outchar
		LD A, $0A
		CALL outchar
		POP AF
		RET

DATA:
		DEFB	30h	; 0
		DEFB	31h	; 1
		DEFB	32h	; 2
		DEFB	33h	; 3
		DEFB	34h	; 4
		DEFB	35h	; 5
		DEFB	36h	; 6
		DEFB	37h	; 7
		DEFB	38h	; 8
		DEFB	39h	; 9
		DEFB	41h	; A
		DEFB	42h	; B
		DEFB	43h	; C
		DEFB	44h	; D
		DEFB	45h	; E
		DEFB	46h	; F
	
TEXT0:
	DEFM	"Mon [RAM] $Revision: 1.13 $",$0A,$0D
	DEFM	"<spc>: display address",$0A,$0D
	DEFM	"[0-9A-F]: enter address (<esc> abort)",$0A,$0D
	DEFM	"<ent>: inc address, <bs>:dec address",$0A,$0D
	DEFM	"l: list+inc 16",$0A,$0D
	DEFM	"d: dump at address (any key ends)",$0A,$0D
	DEFM	"S: set at address (<ent>:set+inc <esc>:end)",$0A,$0D
	DEFM	"X: exec address (caution!)",$0A,$0D
	DEFM	"c: copy... (length=0 to abort)",$0A,$0D
	DEFM	"k: bulk set...",$0A,$0D
	DEFM	"t: type ascii to mem...",$0A,$0D
	DEFM	"i: IO in from low address",$0A,$0D
	DEFM	"O: IO out to low address",$0A,$0D
	DEFM	"R: SPI Read Test",$0A,$0D
	DEFM	"h: this help",$0A,$0D
	DEFB	$80

SETTXT:
	DEFM	"SET ",$80
	
EXTXT:
	DEFM	"exec ",$80
	
CPTXT1:
	DEFM	"copy from:",$80
CPTXT2:
	DEFM	"to:", $80
CPTXT3:
	DEFM	"length:",$80

DONETXT:
	DEFM	"Done.",$0A,$0D,$80
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Additional routines
;; April 2015
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Call address in HL
;; Works by putting 'display' on the stack
;; destroys DE
callhl:
	LD DE, EXTXT	; confirmation text
	CALL otext
	CALL dispadd
	CALL OUTCRLF
	CALL inchar
	CP $0D			; <ret> we continue, else abort
	JP NZ, xabort	; xabort jumps to display
	
	LD DE, display
	PUSH DE
	PUSH HL
	RET


;; Bulk memory set, continuous entry
;; designed to take paste from clipboard
;; of continual hex stream
;; starts from HL until <esc>
bulkset:
	PUSH DE
	LD DE, bstxt
	CALL otext
	
	; ask for address -> HL
	XOR A
	CALL fourcar
	
	LD DE, bstxt1
	CALL otext
	
bkdigit:	
	; Digit 1
	CALL inchar
	CP $1B
	JR Z, bsabort
	CALL outchar	; echo the character
	CALL ATOHEX		; convert to binary
	RLD				; move into (HL) lower nybble

	; Digit 2
	CALL inchar
	CALL outchar	; echo the character
	CALL ATOHEX		; convert to binary
	RLD				; shift (HL) and move into lower nybble
	
	INC HL
	JR 	bkdigit
	
bsabort:
	LD DE, DONETXT
	CALL otext
	POP DE
	JP	display
bstxt:
	DEFM "Bulk load to: ",$80
bstxt1:
	DEFM "Ready (<esc> to end): ",$80
	
	
;; Type ascii values to memory, <esc> exits
typemem:
	PUSH DE
	LD DE, tmtxt
	CALL otext

	; ask for address -> HL
	XOR A			; zero A as first digit of fourchar
	CALL fourcar	; set HL as per user entry

	LD DE, bstxt1
	CALL otext

tmloop:
	CALL inchar
	LD (HL), A
	INC HL
	CALL outchar
	CP $1B		; escape
	JR NZ, tmloop

;	LD HL, DE		; illegal opcode
	LD H, D
	LD L, E
	POP DE
	JP display
tmtxt:
	DEFM "Type ascii to: ",$80
	

;; Set memory range to value in A
;; From HL, length in BC
SETMEM:
	PUSH DE
	LD D, A
smloop:
	LD A, B		; Test BC for zero first
	OR C
	JR Z, smend		
	LD A, D
	CALL CONFWR
	INC HL
	DEC BC
	JR smloop
smend:	
	LD DE, DONETXT
	CALL otext
	POP DE
	JP display

;; IO input from addr in L
io_in:
	PUSH BC
	PUSH DE					; display port addr
	LD DE, io_intxt
	CALL otext
	LD A, L
	CALL hexout
	LD A, ']'
	CALL outchar
	LD A, '='
	CALL outchar
	LD C, L					; display input byte
	IN A, (C)
	CALL hexout
	CALL OUTCRLF
	POP DE
	POP BC
	JP inloop
io_intxt:
	DEFM "Port [",$80

;; IO output to addr in L - get value from inchar
io_out:
	PUSH BC					; get current port value
	LD C, L
	IN A, (C)
	LD (KDATA2), A
	PUSH DE					; display port addr
	LD DE, io_intxt
	CALL otext
	LD A, L
	CALL hexout
	LD A, ']'
	CALL outchar
	LD A, '>'
	CALL outchar
	PUSH HL					; get output byte
	LD HL, KDATA2
	CALL twocar
	LD D, (HL)
	POP HL
	LD A, B
	CP $FF
	JP Z, skpout
	LD C, L
	LD A, D
	OUT (C), A
	JP endout
skpout:
	LD A, '-'
	CALL outchar
	CALL outchar
endout:
	CALL OUTCRLF
	POP DE
	POP BC
	JP inloop
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SPI I/O
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
include '../common/soft_spi.asm'

;; test spi stuff
spi_read_test:
	LD DE, spi_txt0
	CALL otext
	CALL spi_init			; initialize spi port and flash chip
	LD DE, spi_txt1
	CALL otext
	LD A, $10				; raise output bit to signal start of flash init
	OUT ($00), A
	CALL spi_flash_init		; init flash chip
	LD DE, spi_txt2
	CALL otext
	LD A, $30				; raise output bit to signal start of read
	OUT ($00), A
	LD	C, $0A				; flash addr high byte
	LD	HL, $0000			; flash addr mid & low byte
	LD	IX, $8000			; destination address
	LD	DE, $0800			; 2k length
	CALL spi_flash_read		; load from spi to sram
	LD DE, spi_txt3
	CALL otext
	jp inloop

spi_txt0:
	DEFM "SPI Read Test...",$0D,$0A,$80
spi_txt1:
	DEFM "SPI Initialized",$0D,$0A,$80
spi_txt2:
	DEFM "Flash Initialized -",$0D,$0A,$80
spi_txt3:
	DEFM "Flash Read complete",$0D,$0A,$80

txt:	DEFM "Fin.",$0D,$0A,$80

	end