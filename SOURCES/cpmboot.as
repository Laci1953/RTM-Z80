;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	CPM RTM/Z80 app boot utility
;
;	Based on
; **********************************************************************
; **  Compact Flash CP/M Boot Loader            by Stephen C Cousins  **
; **********************************************************************
;
; Based on code by Grant Searle. 
; http://searle.hostei.com/grant/index.html
;

SET_BRK		equ	0	; 1 : set breakpoint (if any, ONLY for SC108 & Z80ALL)
SETUP_UP_RAM	equ	1	; 0 : do NOT setup upper 64K RAM, 
				; 1 : DO setup upper 64K RAM (ONLY for SC108 & Z80ALL)
Z80ALL		equ	0	; 0 : SC108, 1 : Z80ALL

SC108		equ	1-Z80ALL

	psect	boot

IF	SETUP_UP_RAM

IF	SC108

MEMP_PORT       equ     38H
;
ROM_OUT         equ     00000001B
ROM_IN          equ     00000000B
;
LOWER_64RAM     equ     00000000B
UPPER_64RAM     equ     10000000B

MACRO	SET_ROM_OUT
	ld	a,LOWER_64RAM .or. ROM_OUT
	out	(MEMP_PORT),a
ENDM

MACRO	SET_ROM_IN
	ld	a,LOWER_64RAM .or. ROM_IN
	out	(MEMP_PORT),a
ENDM

MACRO	UP_RAM
	ld	a,UPPER_64RAM .or. ROM_OUT
	out	(MEMP_PORT),a
ENDM

MACRO	LOW_RAM
	ld	a,LOWER_64RAM .or. ROM_OUT
	out	(MEMP_PORT),a
ENDM

ENDIF	;SC108

IF	Z80ALL

COPY_3_TO_2	equ	0DFB5H
COPY_2_TO_3	equ	0DFC9H

BANK_PORT	equ	1FH

ENDIF

ENDIF	;SETUP_UP_RAM

start:
	di			;disable ints
	ld	sp,0FFFFH
	ld	hl,100H		;move boot code from (100H - 300H) to 0E300H
	ld	de,0E300H
	ld	bc,200H
	ldir
	jp	0E300H+(begin-start)

begin:

IF	SET_BRK

	ld	hl,80H
	ld	a,(hl)
	inc	hl
	inc	hl
	cp	5
	jp	nz,nobrk
				;get hi byte
	ld	a,(hl)		;get hi nibble
	inc	hl
	call	IsHex
	jr	c,nobrk
	call	CharToNumber
	rlca
	rlca
	rlca
	rlca
	ld	e,a
	ld	a,(hl)		;get low nibble
	inc	hl
	call	IsHex
	jr	c,nobrk
	call	CharToNumber
	or	e
	ld	b,a
				;get low byte
	ld	a,(hl)		;get hi nibble
	inc	hl
	call	IsHex
	jr	c,nobrk
	call	CharToNumber
	rlca
	rlca
	rlca
	rlca
	ld	e,a
	ld	a,(hl)		;get low nibble
	call	IsHex
	jr	c,nobrk
	call	CharToNumber
	or	e
	ld	c,a		;BC=breakpoint
	jr	pushbc
nobrk:	ld	bc,0
pushbc:	push	bc

ENDIF	;SET_BRK

	ld	hl,300H		;move app code from (300H - 0E300H) to 0H
	ld	de,0
	ld	bc,0E000H
	ldir

IF	SET_BRK

	pop	bc
	ld	a,b
	or	c		;breakpoint to be set?
	jr	z,noset
	ld	a,0FFH		;yes, store a RST 56
	ld	(bc),a
noset:

ENDIF	;SET_BRK

IF	SETUP_UP_RAM

IF	SC108
				;move RTM/Z80 exit code
	ld	hl,$DFE3
	ld	de,0DFE3H
	ld	bc,5
	ldir
				;move low - up routines fragment
	ld	hl,$DF4D
	ld	de,0DF4DH
	ld	bc,$len
	ldir

	SET_ROM_IN

	call	get_ltoup_scm
	push	hl
	pop	iy		;IY=SCM function to move A --> UpperRAM in (DE)
				;move low - up routines fragment to UpperRAM
	ld	ix,$DF4D
	ld	de,0DF4DH
	ld	a,$len
looptoup:
	push	af
	ld	a,(ix+0)
				;(DE) in UpperRAM <-- A
	ld	hl,retadr
	push	hl
	jp	(iy)
retadr:	inc	ix
	inc	de
	pop	af
	dec	a
	jr	nz,looptoup

	SET_ROM_OUT

ENDIF	;SC108

IF	Z80ALL

	ld	hl,$DFB5
	ld	de,COPY_3_TO_2
	ld	bc,$len
	ldir

ENDIF	;Z80ALL

ENDIF	;SETUP_UP_RAM

	jp	40H		;boot RTM/Z80 

IF	SET_BRK
;
;	CharToNumber
;	A --> A
;
CharToNumber:
	sub	'0'
	cp	10
        ret	c
	sub	7
	ret
;
;       Is Hex A
;
;       Is character hexadecimal?
;
;       A = ASCII character
;       if character is hexadecimal (0 to 9, A to F)
;               returns CARRY=0 , A converted to uppercase
;       else
;               returns CARRY=1
;       registers not affected (except AF)
;
IsHex:
        cp      '0'             ;Less than '0'?
        ret     c               ;Yes, so return NOT hex
        cp      '9'+1           ;Less than or equal to '9'?
        ccf
        ret     nc              ;Yes, so numeric
        call    UpperCase
        cp      'A'             ;Less than 'A'
        ret     c               ;Yes, so return NOT hex
        cp      'F'+1           ;Less than or equal to 'F'?
        ccf
        ret
;
;       Converts A to Upper Case
;
;       A=char to be converted to uppercase
;       returns A
;       registers not affected (except AF)
;
UpperCase:
        cp      'a'
        ret     c
        cp      'z'+1
        ret     nc
        sub     'a'-'A'
        ret
;
ENDIF	;SET_BRK

IF	SETUP_UP_RAM

IF	SC108
;
;	The following code must be moved to Lower & Upper RAM at 
;
;	up to low 6W
;
$DF4D:  UP_RAM
        ld      c,(iy+0)
        ld      b,(iy+1)
        ld      e,(iy+2)
        ld      d,(iy+3)
        ld      l,(iy+4)
        ld      h,(iy+5)
        exx
        ld      c,(iy+6)
        ld      b,(iy+7)
        ld      e,(iy+8)
        ld      d,(iy+9)
        ld      l,(iy+10)
        ld      h,(iy+11)
        exx
        LOW_RAM
        ret
;
;	up to low 4B
;
$DF7C:	UP_RAM
        ld      c,(iy+0)
        ld      b,(iy+1)
        ld      e,(iy+2)
        ld      d,(iy+3)
	LOW_RAM
	ret
;
;	low to up 6W
;
$DF91:	UP_RAM
	ld	(iy+0),c
	ld	(iy+1),b
	ld	(iy+2),e
	ld	(iy+3),d
	ld	(iy+4),l
	ld	(iy+5),h
	exx
	ld	(iy+6),c
	ld	(iy+7),b
	ld	(iy+8),e
	ld	(iy+9),d
	ld	(iy+10),l
	ld	(iy+11),h
	ld	bc,12
	add	iy,bc
	add	ix,bc
	exx
	LOW_RAM
	ret
;	
;	low to up 4B
;
$DFC7:	UP_RAM
	ld	(iy+0),c
	ld	(iy+1),b
	ld	(iy+2),e
	ld	(iy+3),d
	ld	bc,4
	add	iy,bc
	add	ix,bc
	LOW_RAM
	ret
$len	equ	$-$DF4D
;
;	The following code (5 bytes) must be moved to Lower RAM at 0DFE3H
;
$DFE3:	xor	a
	out	(38H),a
	ld	c,a
	rst	30H
;
;	returns	HL=LTOUP_SCM
;
get_ltoup_scm:
	ld	hl,69H
searchjp:
	ld	a,(hl)
	cp	0c3H
	jr	z,jpfound
	inc	hl
	jr	searchjp
jpfound:
	ld	b,6
searchj7thjp:
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	cp	0c3H
	jr	nz,searchjp
	djnz	searchj7thjp
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	ld	bc,2bH
	add	hl,bc
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	ret

ENDIF	;SC108

IF	Z80ALL

$DFB5:
;
;	PC = 0DFB5H
;
;	code in bank 3
;	current banks are 0 & 3
;	returns at (IY)
;	at return, current banks are 0 & 3
;
copy_3_to_2:
	ld	hl,8000H	;from
	ld	de,0		;to
	ld	bc,8000H	;count
	ld	a,2		;select bank #2
	out	(BANK_PORT),a
	ldir
	xor	a		;select bank #0
	out	(BANK_PORT),a
	jp	(iy)		;return
;
;	PC = 0DFC9H
;
;	current banks are 0 & 3
;	returns at (IY)
;	at return, current banks are 0 & 3
;
copy_2_to_3:
	ld	a,2		;select bank #2
	out	(BANK_PORT),a
				;move 0100-5F00 to 8100-DF00
	ld	hl,0100H	;from
	ld	de,8100H	;to
	ld	bc,5E00H	;count
	ldir
				;move 6000-8000 to E000-FFFF
	ld	hl,6000H	;from
	ld	de,0E000H	;to
	ld	bc,2000H	;count
	ldir

	xor	a		;select bank #0
	out	(BANK_PORT),a
	jp	(iy)		;return
;
;	PC = 0DFE8H
;
$len	equ	$-$DFB5

ENDIF	;Z80ALL

ENDIF	;SETUP_UP_RAM
;
;	memory pad used to fill the space till 300H
;
	defs	200H - ($ - start)
;

