;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	.HEX file loader
;
*Include config.mac

COND	IO_COMM

	GLOBAL	__MakeSem
	GLOBAL	__MakeTimer
	GLOBAL	__DropSem
	GLOBAL	__DropTimer
	GLOBAL	__Reset_RWB
	GLOBAl	__Wait
	GLOBAL	__GetCountB
	GLOBAL	__ReadB

	psect	text

COND	SIM
RawBuf1	equ	7B01H	;buffer #1 used for RawRead
RawBuf2	equ	7C01H	;buffer #2 used for RawRead
ENDC

COND	NOSIM
RawBuf1	equ	0D201H	;buffer #1 used for RawRead
RawBuf2	equ	0D301H	;buffer #2 used for RawRead
ENDC
;
;	Intel HEX loader
;
	GLOBAL	_ReadHEX

MACRO	CharToNumber
	sub	'0'
	cp	10
        jr	c,1f
	sub	7
1:		
ENDM

MACRO	CheckA_and_IncL
	or	a
	jr	z,badnews
	inc	l
	call	z,ReadBuf
ENDM

MACRO	SkipToRec
1:	ld	a,(hl)
	CheckA_and_IncL
	cp	':'
	jr	nz,1b
ENDM

MACRO	GetActiveBuf
	ld	a,(?buf)
	or	a
	jr	z,1f
	ld	hl,RawBuf2
	ld	iy,(Timer2)
	jr	2f
1:	ld	hl,RawBuf1
	ld	iy,(Timer1)
2:	
ENDM

MACRO	GetInactiveBuf
	ld	a,(?buf)
	or	a
	jr	nz,1f
	ld	hl,RawBuf2
	ld	iy,(Timer2)
	jr	2f
1:	ld	hl,RawBuf1
	ld	iy,(Timer1)
2:	
ENDM

BIGTMO	equ	2000

;
;	Reads a .HEX file from the CON(SOLE) device
;
;	Return HL=FFFF (-1) if alloc fails	
;	If 10 sec passed and nothing was read, return HL=FFFE (-2)
;	If checksum was wrong, return HL=FFFD (-3)
;	If sequence of chars unexpectedly stops before end of EOF record, return FFFC (-4) 
;	else return HL=address of loaded code
;
ALLOC_FAIL	equ	0FFFFH
TIME_OUT	equ	0FFFEH
BAD_CHECK	equ	0FFFDH
EOF_NOT_FOUND	equ	0FFFCH
;
_ReadHEX: 
	ld	(SavedSP),sp	;prepare for bad news...
	xor	a
	ld	(FirstRead),a	;mark first read
	ld	(?buf),a	;mark Buf1,Timer1 active
	call	__MakeSem
	jr	nz,1f
				;quit if alloc failed
	ld	hl,ALLOC_FAIL
	ret
1:	ld	(Sem),hl
	call	__MakeTimer
	jr	nz,2f
				;quit if alloc failed
	ld	hl,(Sem)
	call	__DropSem
	ld	hl,ALLOC_FAIL
	ret
2:	ld	(Timer1),hl
	call	__MakeTimer
	jr	nz,3f
				;quit if alloc failed
	ld	hl,(Sem)
	call	__DropSem
	ld	hl,(Timer1)
	call	__DropTimer
	ld	hl,ALLOC_FAIL
	ret
3:	ld	(Timer2),hl
				;reset Raw I/O
	call	__Reset_RWB	
	call	ReadBuf

	ld	a,(NOT_Read)
	cp	255		;any char read?
	jr	nz,go
				;no, 10 seconds passed, nothing was read
	ld	hl,TIME_OUT
	jr	reterr
go:				;first block of chars was read, HL=pointer of chars
	ld	c,0		;init checksum
	call	GetFirstRecord	;get first hex record (store Code base)
	jr	z,eof
loop:	call	GetNextRecord	;get next record
	jr	nz,loop
eof:				;EOF reached
	ld	a,c
	or	a		;checksum = 0 ?
	ld	hl,BAD_CHECK
	jr	nz,reterr
ok:	
	ld	hl,(Sem)
	call	__DropSem
	ld	hl,(Timer1)
	call	__DropTimer
	ld	hl,(Timer2)
	call	__DropTimer
	ld	hl,(Code)	;return Code base address
	ret
;
reterr:				;HL=err code
	push	hl
	ld	hl,(Sem)
	call	__DropSem
	ld	hl,(Timer1)
	call	__DropTimer
	ld	hl,(Timer2)
	call	__DropTimer
	pop	hl
	ld	sp,(SavedSP)
	ret
;
;	(Raw)Read from CON 255 bytes
;	
;	if less than 255 bytes were read, 
;	store a NULL (zero) byte after the chars read
;
;	registers AF,BC,DE not affected
;
ReadBuf:
	push	af		;save regs
	push	bc
	push	de
	ld	hl,FirstRead
	ld	a,(hl)		;is this the first read?
	or	a
	jr	z,First
				;no
	ld	hl,(Sem)	;wait for the previous read to finish
	call	__Wait
	call	__GetCountB	;A=counter of bytes NOT read
				;move 255 bytes from secondary buffer to main buffer
	jr	seenotr		;...and go see the outcome

First:	
	ld	(hl),1		;erase FirstRead flag
	ld	c,0FFH		;try to read 255 chars

	GetActiveBuf

	ld	de,(Sem)
	ld	ix,BIGTMO	;2000 x 5ms = 10 sec timeout for the first read op
	call	__ReadB		;read from CON (SIO)
	ld	hl,(Sem)
	call	__Wait
	call	__GetCountB	;A=counter of bytes NOT read
seenotr:ld	(NOT_Read),a	;save counter of bytes NOT read
	or	a		
	jr	z,allread	;if 0 NOT read (all 255 bytes were read), return
				;else (zero or not all chars were read)
				;this was the last read
	ld	b,a		;save counter of bytes NOT read
	GetActiveBuf
	ld	a,b		;A=counter of bytes NOT read

	push	hl
	neg			;ex: 1 NOT read ==> FFH
	ld	l,a		;HL=pointer after the block that was read
	ld	(hl),0		;store a NULL after the block
	pop	hl		;HL=pointer of chars read (if any...)
	pop	de
	pop	bc
	pop	af
	ret
allread:
				;start again a read command in the not active buffer
	GetInactiveBuf

	ld	c,0FFH
	ld	de,(Sem)
	ld	ix,20		;100 ms timeout for the next read ops
	call	__ReadB	
				;then return HL=active buf
	GetActiveBuf	

	ld	a,(?buf)	;then switch bufs
	xor	1
	ld	(?buf),a

	pop	de
	pop	bc
	pop	af
	ret
;
;	Get Byte
;
;	HL=pointer of 2 ASCII hex chars
;	C=checksum
;	returns A=byte, HL incremented by 2, Checksum updated
;	registers not affected (except AF)
;
GetByte:
COND	SIM
	GLOBAL	CON_CrtIO,CON_Count,_CON_RX
	ld	a,(CON_CrtIO)
	cp	IO_RAW_READ
	jr	nz,nothing
	ld	a,(CON_Count)
	or	a
	jr	z,nothing
	call	_CON_RX
nothing:
ENDC
	push	de
	ld	a,(hl)		;hi nibble
	CheckA_and_IncL
	CharToNumber
	rlca
	rlca
	rlca
	rlca
	ld	e,a
	ld	a,(hl)		;low nibble
	CheckA_and_IncL
	CharToNumber
	or	e
	ld	e,a		;save in E
	add	a,c		;add to checksum
	ld	c,a		;save checksum
	ld	a,e		;restore from E
	pop	de
	ret
;
;	Get First Record
;
;	HL=pointer in the HEX file
;	C=current checksum
;
;	returns C=checksum updated, 
;	record data stored,
;	saves Code base address
;	HL incremented at end-of-record (after "checksum")
;	Z=1 if end-of-file, else Z=0
;
GetFirstRecord:
	SkipToRec		;we are now past the ':'
	call	GetByte		;A=len
	ld	b,a		;B=len
	call	GetByte		;addr hi
	ld	d,a		;D=addr hi
	call	GetByte		;addr low
	ld	e,a		;E=addr low
	ld	(Code),de	;save Code base address
	call	GetByte		;record type
	push	af		;on stack
	ld	a,b
	or	a		;len zero?
	jr	z,2f		;if yes, go get the record checksum
1:				;no, get the data
	call	GetByte		;data
	ld	(de),a		;store at addr
	inc	de		;increment addr
	djnz	1b		;loop until B=0
2:				;get record checksum byte
	call	GetByte		;checksum byte
	pop	af		;record type
	cp	1		;Z=1 if EOF
	ret
;
;
badnews:			;a NULL char was found in the stream of chars
				;before reaching EOF record end
	di
	ld	hl,(Sem)
	call	__DropSem
	ld	hl,EOF_NOT_FOUND
	ld	sp,(SavedSP)
	ret
;
;	Get Next Record
;
;	HL=pointer in the HEX file
;	C=current checksum
;
;	returns C=checksum updated, 
;	record data stored,
;	HL incremented at end-of-record (after "checksum")
;	Z=1 if end-of-file, else Z=0
;
GetNextRecord:
	SkipToRec		;we are now past the ':'
	call	GetByte		;A=len
	ld	b,a		;B=len
	call	GetByte		;addr hi
	ld	d,a		;D=addr hi
	call	GetByte		;addr low
	ld	e,a		;E=addr low
	call	GetByte		;record type
	push	af		;on stack
	ld	a,b
	or	a		;len zero?
	jr	z,2f		;if yes, go get the record checksum
1:				;no, get the data
	call	GetByte		;data
	ld	(de),a		;store at addr
	inc	de		;increment addr
	djnz	1b		;loop until B=0
2:				;get record checksum byte
	call	GetByte		;checksum byte
	pop	af		;record type
	cp	1		;Z=1 if EOF
	ret

	psect	bss

Timer1:	defs	2
Timer2:	defs	2
FirstRead:defs	1		;set to 1 after the first read
Sem:	defs	2		;used at I/O
Buf:	defs	2		;allocated 400H pointer
?buf:	defs	1		;buffer used for read , 0:Buf1, 1:Buf2
NOT_Read:defs	1		;counter of bytes NOT read after a RawRead(255)
Code:	defs	2		;address of loaded code
SavedSP:defs	2

ENDC
