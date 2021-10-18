;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	Based on
; **********************************************************************
; **  Compact Flash CP/M Boot Loader            by Stephen C Cousins  **
; **********************************************************************

; Based on code by Grant Searle. 
; http://searle.hostei.com/grant/index.html
;
;	CP/M boot for RC2014 (512KB.ROM + 512KB.RAM) & (32KB.ROM+128KB.RAM) memory modules
;
;for SC108 and MM
;
;link>
; -ptext=40H/07F00H
;
;for M512
;
;link>
; -ptext=40H/4040H
;

	psect	text

M512		equ	1	;1=512KB.ROM + 512KB.RAM, else 0=32KB.ROM+128KB.RAM
LARGE_TPA	equ	1	;1=BDOS starts at DA00H, 0=BDOS starts at D000H
				;set it to 1 ONLY for 64MB CFs
KIO		equ	0	;1=KIO's SIO, 0=SC110's SIO

;---------------------------------------------------------------512KB.ROM + 512KB.RAM
COND	M512

;	512KB ports & macros

P_BASE		equ	78H
P_ENABLE_B	equ	7CH

ROM_B		equ	0
RAM_B		equ	32

MACRO	SETROM	LOGICAL_B,PHYSICAL_B
	ld	a,PHYSICAL_B
	out	(P_BASE+LOGICAL_B),a
ENDM

MACRO	SETRAM	LOGICAL_B,PHYSICAL_B
	ld	a,PHYSICAL_B + 32
	out	(P_BASE+LOGICAL_B),a
ENDM

MACRO	ENABLE_B
	ld	a,1
	out	(P_ENABLE_B),a
ENDM

MACRO	DISABLE_B
	xor	a
	out	(P_ENABLE_B),a
ENDM

ENDC
;---------------------------------------------------------------512KB.ROM + 512KB.RAM

;---------------------------------------------------------------32KB.ROM + 128KB.RAM
COND	1-M512

MM_RAM_P	equ	30H

MM_UP_RAM	equ	1
MM_LOW_RAM	equ	0

MACRO	LOW_RAM
	ld	a,MM_LOW_RAM
	out	(MM_RAM_P),a
ENDM

MACRO	UP_RAM
	ld	a,MM_UP_RAM
	out	(MM_RAM_P),a
ENDM

MM_ROM_P	equ	38H

MM_ROM_IN	equ	0
MM_ROM_OUT	equ	1

MACRO	ROM_IN
	ld	a,MM_ROM_IN
	out	(MM_ROM_P),a
ENDM

MACRO	ROM_OUT
	ld	a,MM_ROM_OUT
	out	(MM_ROM_P),a
ENDM

ENDC
;---------------------------------------------------------------32KB.ROM + 128KB.RAM

; 	CF data
;
; CF registers
CF_DATA     EQU 10H
CF_FEATURES EQU 11H
CF_ERROR    EQU 11H
CF_SECCOUNT EQU 12H
CF_SECTOR   EQU 13H
CF_CYL_LOW  EQU 14H
CF_CYL_HI   EQU 15H
CF_HEAD     EQU 16H
CF_STATUS   EQU 17H
CF_COMMAND  EQU 17H
CF_LBA0     EQU 13H
CF_LBA1     EQU 14H
CF_LBA2     EQU 15H
CF_LBA3     EQU 16H

;CF Features
CF_8BIT     EQU 1
CF_NOCACHE  EQU 082H
;CF Commands
CF_RD_SEC EQU 020H
CF_WR_SEC EQU 030H
CF_SET_FEAT EQU  0EFH

;       SIO Ports

COND	KIO
SIO_A_D      EQU 88H
SIO_A_C      EQU 89H
SIO_B_D      EQU 8AH
SIO_B_C      EQU 8BH
ENDC

COND	1-KIO
SIO_A_D      EQU 81H
SIO_A_C      EQU 80H
SIO_B_D      EQU 83H
SIO_B_C      EQU 82H
ENDC

COND	LARGE_TPA
BIOS	equ	0F000H
ENDC

COND	1-LARGE_TPA
BIOS	equ	0E600H
ENDC

IOBYTE	equ	3

;	Called from RTM/Z80 boot at BASE + 0040H

start:

	di			;disable ints
COND	1-M512
	LOW_RAM			;select lower 64KB RAM bank
ENDC
	ld	sp,0D000H	;SP at 0D000H,just below the CP/M space

	xor	a
	out	(0),a		;LEDS OFF (if any...)

				;init SIO
	ld	hl,SIO_Data
	ld	c,SIO_A_C
	ld	b,SIO_len
	otir
				;test if CF present
        CALL Wait               ;Wait for compact flash to be ready
	ld	a,5
	out	(CF_SECCOUNT),a
	in	a,(CF_SECCOUNT)
	cp	5
	jr	z,cf_present
				;CF not found, print error message
	ld	hl,msg_cf_notfound
	call	TypeString
	jp	$		;and freeze
cf_present:
; Load CP/M
            CALL Wait           ;Wait for compact flash to be ready
            LD   A,CF_8BIT      ;Set IDE to be 8bit
            OUT  (CF_FEATURES),A  ;Store feature code
            LD   A,CF_SET_FEAT  ;Get set features command
            OUT  (CF_COMMAND),A ;Perform set features
            CALL Wait           ;Wait for compact flash to be ready
            LD   A,CF_NOCACHE   ;Set no write cache
            OUT  (CF_FEATURES),A  ;Store feature code
            LD   A,CF_SET_FEAT  ;Get set features command
            OUT  (CF_COMMAND),A ;Perform set features
            CALL Wait           ;Wait for compact flash to be ready
            LD   B,24		;Number of physical sectors
            LD   C,0            ;First sector number
            LD   HL,0D000H      ;Code from compact flash loads here
; Read sectors where one sector is 4 x 128 byte blocks = 512 bytes
ReadSects:  LD   A,C            ;Get sector number
            OUT  (CF_LBA0),A    ;Set sector number
            XOR  A              ;Set up LBA parameters...
            OUT  (CF_LBA1),A
            OUT  (CF_LBA2),A
            LD   A,0E0H
            OUT  (CF_LBA3),A
            LD   A,1            ;Get number if sectors to read
            OUT  (CF_SECCOUNT),A  ;Store sector count
            LD   A,CF_RD_SEC    ;Get read sectors command
            OUT  (CF_COMMAND),A ;Perform sector(s) read
            CALL Wait           ;Wait for compact flash to be ready
TstReady:  IN   A,(CF_STATUS)  ;Read status register
            BIT  3,A            ;Test DRQ flag
            JR   Z,TstReady    ;Low so not ready
            LD   E,4            ;1 sector = 4 x 128 byte blocks
            PUSH BC             ;Preserve sector number and count
            LD   C,CF_DATA      ;Compact flash data register
ReadBlock:  LD   B,128          ;Block size
            INIR                ;(HL)=(C), HL=HL+1, B=B-1, repeat
            DEC  E              ;Decrement block counter
            JR   NZ,ReadBlock   ;Repeat until all blocks read
            POP  BC             ;Preserve sector number and count
            INC  C              ;Increment sector number
            DJNZ ReadSects      ;Repeat for all required sectors
; CP/M now is loaded into RAM
				;move boot code to RAM addr 8000H
	ld	de,8000H	;dest
	ld	hl,bootc
	ld	bc,bootc_len
	ldir
	jp	8000H		;jump to 8000H

bootc:	
COND	M512
	SETRAM	0,3		;ROM #0 OUT, RAM #3 to 0000H
ENDC
COND	1-M512
	ROM_OUT			;32KB ROM OUT, lower RAM IN
ENDC
	ld	a,1		;init IOBYTE
	ld	(IOBYTE),a
	jp	BIOS		;jump to BIOS
bootc_len	equ	$-bootc
;
; Wait until compact flash is ready
Wait:
TBusy:   IN   A,(CF_STATUS)  ;Read status register
            BIT  7,A            ;Test Busy flag
            JR   NZ,TBusy    ;High so busy
	    IN   A,(CF_STATUS)  ;Read status register
            BIT  6,A            ;Test Ready flag
            JR   Z,TBusy     ;Low so not ready
            RET
;
;	Type A
;
TypeChar:
	push	af
2:	in	a,(SIO_A_C)	;RR0
	and	100B		;ready for TX?
	jr	z,2b		;no, wait
	pop	af
	out	(SIO_A_D),a	;type A=char
	ret
;
;      Type String
;
;      Print string (zero terminated)
;
;      HL=string addr
;      BC,DE not affected
;
TypeString:
        ld      a,(hl)
        or      a
        ret     z
        call	TypeChar
        inc     hl
        jr      TypeString
;
msg_cf_notfound:
	defb	0dh,0ah
	defm	'CF not found or defect!'
	defb	0
;
SIO_Data:
	defb	00011000B	;Wr0 Channel reset
	defb	00010100B	;Wr0 Pointer R4 + reset ex st int
	defb	11000100B	;Wr4 /64, async mode, no parity
	defb	00000011B	;Wr0 Pointer R3
	defb	11000001B	;Wr3 Receive enable, 8 bit 
	defb	00000101B	;Wr0 Pointer R5
	defb	11101010B	;Wr5 Transmit enable, 8 bit, flow ctrl
	defb	00010001B	;Wr0 Pointer R1 + reset ex st int
	defb	00000000B	;Wr1 No RX,Tx interrupts
SIO_len	equ	$-SIO_Data
	