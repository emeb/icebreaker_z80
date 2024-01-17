;
; spi.asm - SPI interfaces for the Z80
; 01-08-24 E. Brombaugh
;

; SPI IP registers
SPI0_BASE:	equ		$10		; IO Offset of SPI0 IP core 
SPICR0:		equ		$08		; Control reg 0
SPICR1:		equ		$09		; Control reg 1
SPICR2:		equ		$0a		; Control reg 2
SPIBR:		equ		$0b		; Baud rate reg
SPISR:		equ		$0c		; Status reg
SPITXDR:	equ		$0d		; TX data reg (r/w)
SPIRXDR:	equ		$0e		; RX data reg (ro)
SPICSR:		equ		$0f		; Chip Select reg

; Flash commands
FLASH_WRPG:	equ		$02		; write page
FLASH_READ:	equ		$03		; read data
FLASH_RSR1:	equ		$05		; read status reg 1
FLASH_RSR2:	equ		$35		; read status reg 2
FLASH_RSR3:	equ		$15		; read status reg 3
FLASH_WSR1:	equ		$01		; write status reg 1
FLASH_WSR2:	equ		$31		; write status reg 2
FLASH_WSR3:	equ		$11		; write status reg 3
FLASH_WEN:	equ		$06		; write enable
FLASH_EB32:	equ		$52		; erase block 32k
FLASH_GBUL:	equ		$98		; global unlock
FLASH_WKUP:	equ		$AB		; wakeup
FLASH_ERST:	equ		$66		; enable reset
FLASH_RST:	equ		$99		; reset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize SPI peripheral
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_init:
	LD	HL, spi_init_tab	; get start of table
si_lp:
	LD	A, (HL)				; get relative reg
	CP	$0					; end of table?
	JP	Z, si_done
	ADD	A, SPI0_BASE		; compute absolute reg addr
	LD	C, A
	INC	HL
	LD	A, (HL)				; get data
	OUT	(C), A				; write to device
	INC HL
	JP	si_lp				; next iter
si_done:
;	CALL spi_flash_init		; init flash chip
	RET
	
; zero-terminated table of reg/data pairs for init of SPI periph
spi_init_tab:
	db	SPICR0,	$ff		; max delay counts on all auto CS timing
	db	SPICR1,	$84		; enable spi, disable scsni(undocumented!)
	db	SPICR2,	$c0		; master, hold cs low while busy
	db	SPIBR,	$02		; divide clk by 3 for spi clk
	db	SPICSR,	$0f		; all CS outs high
	db	0				; end of table

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; wait for spi tx
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_tx_wait:
	IN	A, (SPI0_BASE+SPISR)	; get tx status on first pass
	AND	$10					; test trdy
	JP	Z, spi_tx_wait		; loop until ready
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; wait for spi rx
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

spi_rx_wait:
	IN	A, (SPI0_BASE+SPISR)	; get rx status		
	AND $08					; test rrdy
	JP	Z, spi_rx_wait		; loop until ready
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; spi send routine - single byte, with CS
;; data in A
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_tx_byte:
	EX	AF, AF'
	LD	A, $fe				; lower cs0
	OUT	(SPI0_BASE+SPICSR), A
	CALL spi_tx_wait		; wait for tx ready
	EX	AF, AF'
	OUT	(SPI0_BASE+SPITXDR), A	; send tx
	CALL spi_rx_wait		; wait for rx ready
	LD	A, $ff				; raise cs0
	OUT (SPI0_BASE+SPICSR), A
	RET			

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; spi flash init - wakeup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_flash_init:
	LD	A, FLASH_WKUP			; Wake up
	CALL spi_tx_byte
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; send header - used for read, write and erase
;; expects cmd in A, addr in C:HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_flash_hdr:
	EX	AF, AF'
;	CALL spi_tx_wait			; wait for tx ready
	EX	AF, AF'
	OUT (SPI0_BASE+SPITXDR), A	; send cmd
	CALL spi_rx_wait			; wait for tx ready
	LD	A, L
	OUT (SPI0_BASE+SPITXDR), A	; send low addr
	CALL spi_rx_wait			; wait for tx ready
	LD	A, H
	OUT (SPI0_BASE+SPITXDR), A	; send mid addr
	CALL spi_rx_wait			; wait for tx ready
	LD	A, C
	OUT (SPI0_BASE+SPITXDR), A	; send high addr
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; spi flash read - 64kB max
;; dest addr in IX
;; count in DE
;; source addr in C:HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_flash_read:
	LD	A, $fe					; lower cs0
	OUT	(SPI0_BASE+SPICSR), A
			
	LD	A, FLASH_READ			; send header w/ read cmd + source addr
	CALL spi_flash_hdr
			
	CALL spi_rx_wait			; wait for tx ready
	IN	A, (SPI0_BASE+SPIRXDR)	; dummy reads to clear RX
	IN	A, (SPI0_BASE+SPIRXDR)
			
sfr_rdm:
	LD	A, $00
	OUT (SPI0_BASE+SPITXDR), A	; send dummy data
	CALL spi_rx_wait			; wait for rx ready
	IN	A, (SPI0_BASE+SPIRXDR)	; get rx
	LD	(IX+0),	A				; save rx byte
	INC	IX						; next dest
	DEC	DE						; dec count
	LD	A, E
	OR	D
	JP	NZ, sfr_rdm				; loop if not zero
	LD	A, $ff					; raise cs0
	OUT (SPI0_BASE+SPICSR), A
	RET
