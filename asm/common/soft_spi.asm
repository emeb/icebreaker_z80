;
; soft_spi.asm - soft core SPI interfaces for the Z80
; 01-11-24 E. Brombaugh
;

; Soft SPI registers
SPI0_BASE:	equ		$10		; IO Offset of SPI0 IP core 
SR:			equ		$00		; Status reg
DR:			equ		$01		; Data reg

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
;; Initialize SPI peripheral (not really needed except for flash)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_init:
;	CALL spi_flash_init		; init flash chip
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; wait for spi tx empty
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_tx_wait:
	IN	A, (SPI0_BASE+SR)	; get tx status
	AND	$02					; test txe
	JP	Z, spi_tx_wait		; loop until ready
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; wait for spi rx full
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

spi_rx_wait:
	IN	A, (SPI0_BASE+SR)	; get rx status		
	AND $04					; test rxf
	JP	Z, spi_rx_wait		; loop until ready
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; spi send routine - single byte, with CS
;; data in A
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_tx_byte:
	EX	AF, AF'
	LD	A, $00				; lower cs0
	OUT	(SPI0_BASE+SR), A
	CALL spi_tx_wait		; wait for tx ready
	EX	AF, AF'
	OUT	(SPI0_BASE+DR), A	; send tx
	CALL spi_rx_wait		; wait for rx ready
	LD	A, $01				; raise cs0
	OUT (SPI0_BASE+SR), A
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
	CALL spi_tx_wait			; wait for tx ready
	EX	AF, AF'
	OUT (SPI0_BASE+DR), A		; send cmd
	CALL spi_tx_wait			; wait for tx ready
	LD	A, C
	OUT (SPI0_BASE+DR), A		; send low addr
	CALL spi_tx_wait			; wait for tx ready
	LD	A, H
	OUT (SPI0_BASE+DR), A		; send mid addr
	CALL spi_tx_wait			; wait for tx ready
	LD	A, L
	OUT (SPI0_BASE+DR), A		; send high addr
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; spi flash read - 64kB max
;; dest addr in IX
;; count in DE
;; source addr in C:HL
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_flash_read:
	LD	A, $00					; lower cs0
	OUT	(SPI0_BASE+SR), A
			
	LD	A, FLASH_READ			; send header w/ read cmd + source addr
	CALL spi_flash_hdr
			
	CALL spi_tx_wait			; wait for tx ready
	IN	A, (SPI0_BASE+DR)		; dummy read to clear RX
			
sfr_rdm:
	LD	A, $00
	OUT (SPI0_BASE+DR), A		; send dummy data
	CALL spi_rx_wait			; wait for rx ready
	IN	A, (SPI0_BASE+DR)		; get rx
	LD	(IX+0),	A				; save rx byte
	INC	IX						; next dest
	DEC	DE						; dec count
	LD	A, E
	OR	D
	JP	NZ, sfr_rdm				; loop if not zero
	LD	A, $01					; raise cs0
	OUT (SPI0_BASE+SR), A
	RET
