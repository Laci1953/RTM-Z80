;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	at link, use -ptext=0/0,fcoo=0FC00H/,data/,bss=0D000H/
;
;	!!! boot.obj must be the last .obj in the link command line !!!
;
*Include config.mac
*Include romram.mac
*Include leds.mac

;-------------------------------------------------------------------------------------------ROM
COND	ROM

;	(E)EPROM boot utility
;
;	called with JP from address 0000H

	GLOBAL	boot

MACRO	CharToNumber
	sub	'0'
	cp	10
        jr	c,1f
	sub	7
1:		
ENDM

MACRO	ReadChar
2:	in	a,(SIO_A_C)	;RR0
	rrca			;char ready?
	jr	nc,2b		;no, wait
	in	a,(SIO_A_D)	;get A=char
ENDM

MACRO	SkipToRec
3:	ReadChar
	cp	':'
	jr	nz,3b
ENDM

MACRO   PRINT   msg
        ld      hl,msg
        call    TypeString
ENDM

;----------------------------------------------------------------------------- fcoo
	psect	fcoo

$FC00:
;
;	Move RTMZ80 from ROM to LOW RAM (13H)
;		and continue boot
;	on entry: LOW RAM is selected, ROM is IN
;	en exit: LOW_RAM is selected, ROM is OUT
;	IX = source offset in EEPROM
;	A = # of 100H to move
;
MoveRTMZ80:			;at 0FC00H
	ld	iy,0		;dest
loopr:	push	af
	call	Move100H
	pop	af
	dec	a
	jr	nz,loopr
	ROM_OUT
	jp	boot_rtmz80
;
;	Move Watson from ROM to LOW RAM
;		and continue boot
;	on entry: LOW RAM is selected, ROM is IN
;	en exit: LOW_RAM is selected, ROM is OUT
;
MoveWatson:			;at 0FC13H
	ld	ix,6800H	;source
	ld	iy,0E000H	;dest
	ld	a,18H		;1800H to move
loopw:	push	af
	call	Move100H
	pop	af
	dec	a
	jr	nz,loopw
	ROM_OUT
	jp	0E000H		;boot Watson
;
;	Move from ROM to LOW RAM 100H bytes
;
;	LOW RAM is selected (also on exit)
;	ROM is IN (also on exit)
;
;	IX=source, IY=Destination
;	returns IX=IX+100H,IY=IY+100H 
;
Move100H:			;at 0FC26H
	ld	a,21		;21 x 12 = 252, + 4 = 256 (100H)
lloop21:			;move 252 bytes
	ld	c,(ix+0)
	ld	b,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	l,(ix+4)
	ld	h,(ix+5)
	exx
	ld	c,(ix+6)
	ld	b,(ix+7)
	ld	e,(ix+8)
	ld	d,(ix+9)
	ld	l,(ix+10)
	ld	h,(ix+11)
	exx
	ex	af,af'
	ROM_OUT
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
	ROM_IN
	ex	af,af'
	dec	a
	jr	nz,lloop21
				;move 4 bytes
	ld	c,(ix+0)
	ld	b,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ROM_OUT
	ld	(iy+0),c
	ld	(iy+1),b
	ld	(iy+2),e
	ld	(iy+3),d
	ld	bc,4
	add	iy,bc
	add	ix,bc
	ROM_IN
	ret
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
;      Byte To Nibbles
;
;      Convert byte to nibbles
;      A = Hex byte
;      returns D = Most significant nibble, E = Least significant nibble
;      registers not affected (except AF)
;
ByteToNibbles:
        ld      e,a
        rra
        rra
        rra
        rra
        and     0FH
        ld      d,a
        ld      a,e
        and     0FH
        ld      e,a
        ret
;
;      Converts Nibble A to ASCII
;
;      Converts Nibble (0-15) to its ASCII value ('0' to '9', or 'A' to 'F')
;
;      A=Nibble
;      returns A=ASCII value of byte (letters in uppercase)
;      registers not affected (except AF)
;
NibbleToASCII:
        cp      10              ;digit?
        jr      nc,1f
        add     a,'0'           ;it's a digit
        ret
1:      add     a,'A'-10        ;no, it's a letter (A to F)
        ret
;
;      Print a byte in A (2 hexa chars, uppercase)
;
;      A=byte
;	BC,DE,HL not affected
;
TypeA:
	push	de
        call    ByteToNibbles   ;High Nibble = D, Low Nibble = E
        ld      a,d
        call    NibbleToASCII            
        call	TypeChar	;type High Nibble to console
        ld      a,e
        call    NibbleToASCII
        call	TypeChar	;type Low Nibble to console
	pop	de
        ret
;
;	Get Byte
;
;	Get 2 ASCII hex chars 
;	C=Checksum
;
;	returns A=byte, C=Checksum updated
;	E affected, HL not affected
;
GetByte:
	ReadChar		;get hi nibble
	CharToNumber
	rlca
	rlca
	rlca
	rlca
	ld	e,a
	ReadChar		;get low nibble
	CharToNumber
	or	e
	ld	e,a		;save to E
	add	a,c		;add to checksum
	ld	c,a		;save checksum
	ld	a,e		;restore from E
	ret
;
;      Is Hex A
;
;      Is character hexadecimal?
;
;      A = ASCII character
;      if character is hexadecimal (0 to 9, A to F)
;              returns CARRY=0 , A converted to uppercase
;      else
;              returns CARRY=1
;      registers not affected (except AF)
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
;      Converts A to Upper Case
;
;      A=char to be converted to uppercase
;      returns A
;      registers not affected (except AF)
;
UpperCase:
        cp      'a'
        ret     c
        cp      'z'+1
        ret     nc
        sub     'a'-'A'
        ret
;
;	Loads RTM/Z80 app as .HEX file
;	returns Z=1 if checksum OK, else Z=0
;
LoadHEX:
	xor	a
	ld	c,a		;init C=checksum
loop:	SkipToRec		;we are now past the ':'
	call	GetByte		;A=len
	ld	b,a		;B=len
	call	GetByte		;A=addr hi
	ld	h,a		;H=addr hi
	call	GetByte		;A=addr low
	ld	l,a		;L=addr low
	call	GetByte		;A=record type
	ld	d,a		;D=record type
	ld	a,b
	or	a		;len zero?
	jr	z,getchck	;if yes, go get the record checksum
getdata:			;no, get the data
	call	GetByte		;A=data
	ld	(hl),a		;store at addr
	inc	hl		;increment addr
	djnz	getdata		;loop until B=0
getchck:			;get record checksum byte
	call	GetByte		;get and update checksum
	ld	a,d		;record type
	cp	1		;Z=1 if EOF
	jr	nz,loop
	ld	a,c		;checksum ok?
	or	a
	ret
;
;	Boot RTM/Z80
;
boot_rtmz80:
	PRINT	msgrdy		;print ready
	call	LoadHEX
	jr	z,setbrk
;				;checksum wrong!
	PRINT	msgbad
RESET:	ROM_IN
	jp	0		;reset
;
setbrk:				;ask for breakpoints
	PRINT	msgbrk
				;get hi byte
1:	ReadChar		;get hi nibble
	cp	0DH		;skip CR, if any
	jr	z,1b
	call	TypeChar
	cp	'.'		
	jr	z,ask		;if '.' ask to boot
	call	IsHex
	jr	c,setbrk
	CharToNumber
	rlca
	rlca
	rlca
	rlca
	ld	e,a
	ReadChar		;get low nibble
	call	TypeChar
	call	IsHex
	jr	c,setbrk
	CharToNumber
	or	e
	ld	b,a
				;get low byte
	ReadChar		;get hi nibble
	call	TypeChar
	call	IsHex
	jr	c,setbrk
	CharToNumber
	rlca
	rlca
	rlca
	rlca
	ld	e,a
	ReadChar		;get low nibble
	call	TypeChar
	call	IsHex
	jr	c,setbrk
	CharToNumber
	or	e
	ld	c,a		;BC=breakpoint
	ld	a,0FFH		;yes, store a RST 56
	ld	(bc),a
	PRINT	msgset
	jp	setbrk
ask:				;ask permission to boot
	PRINT	msgcont
1:	ReadChar
	cp	0DH
	jr	z,1b
	call	TypeChar
	call	UpperCase
	cp	'Y'		;Y?
	jp	nz,RESET
	ld	hl,(3)		;restore RST 0's JP
	ld	(1),hl
	PRINT	msgboot
	jp	40H		;start RTM/Z80
;
msgsel:	defb	0dh,0ah
	defm	'Press 1,2,3,4 to boot an RTM/Z80 version, or 5 to start Watson :'
	defb	0
msgrdy:	defb	0dh,0ah
	defm	'Ready to read RTM/Z80 HEX file:'
	defb	0dh,0ah
	defb	0
msgbrk:	defb	0dh,0ah
	defm	'Breakpoint (4 hex digits, .=no more breakpoints to set):'
	defb	0
msgset:	defm	' set!'
	defb	0
msgcont:defb	0dh,0ah
	defm	'Boot? (Y/y=yes) :'
	defb	0
msgboot:defb	0dh,0ah
	defm	'Booting RTM/Z80...'
	defb	0
msgbad:	defb	0dh,0ah
	defm	'Bad checksum!'
	defb	0
;
$FC00_len	equ	$-$FC00
;
;----------------------------------------------------------------------------- fcoo
	psect	text
;
;	Bootstrap code start
;
boot:
				;ROM is IN
	di			;disable ints
	ld	sp,0FFFFH	;SP at end of RAM
	ROM_IN_LOW_RAM
COND	DIG_IO
	xor	a		;all leds OFF
	out (LED_PORT),a
ENDC
				;init SIO
	ld	hl,SIO_Data
	ld	c,SIO_A_C
	ld	b,SIO_len
	otir
				;copy psect fcoo to 0FC00H in LOW RAM
	ld	hl,psect_text_end
	ld	de,0FC00H
	ld	bc,$FC00_len
	ldir
				;move RTM/Z80 exit code to LOW RAM
	ld	hl,$DFE3
	ld	de,0DFE3H
	ld	bc,5
	ldir

COND	RAM128K
				;move low - up routines fragment to LOW RAM
	ld	hl,$DF4D
	ld	de,0DF4DH
	ld	bc,$len
	ldir

	ROM_IN_UP_RAM
				;move low - up routines fragment to UP RAM
	ld	hl,$DF4D
	ld	de,0DF4DH
	ld	bc,$len
	ldir

	ROM_IN_LOW_RAM

ENDC

sel:
	PRINT	msgsel
	ReadChar
	call	TypeChar
	cp	'1'
	jr	nz,2f
	ld	ix,0000H	;RTM/Z80 v1
	ld	a,28H
	jp	0FC00H
2:	cp	'2'
	jr	nz,3f
	ld	ix,2800H	;RTM/Z80 v2
	ld	a,15H
	jp	0FC00H
3:	cp	'3'
	jr	nz,4f
	ld	ix,3D00H	;RTM/Z80 v3
	ld	a,1CH
	jp	0FC00H
4:	cp	'4'
	jr	nz,5f
	ld	ix,5900H	;RTM/Z80 v4
	ld	a,10H
	jp	0FC00H
5:	cp	'5'
	jr	nz,sel
	jp	0FC13H		;boot Watson
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

COND	RAM128K

;-------------------------------------------------------------------------------
;	The following code must be moved to Lower & Upper RAM at 0DF4DH
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
;-------------------------------------------------------------------------------

ENDC

;
;	Exit RTM/Z80
;
$DFE3:	ROM_IN
	rst	0
;-------------------------------------------------------------------------------

psect_text_end:

ENDC
;-------------------------------------------------------------------------------------------ROM
