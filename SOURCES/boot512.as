;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	Boot code for 512KB RAM/ROM module
;
;	link: -ptext=0
;
;	To be stored in the 512KB ROM at 0000H (ROM # 0)
;
;	CP/M boot will be stored at 4000H (ROM # 1)
;	26 RTM/Z80 versions will be stored starting with 8000H (ROM # 2...27), each of size 4000H
;	WATSON will be stored at 7FC00 (ROM # 31), of size 4000H
;
*Include config.mac
*Include romram.mac
*Include leds.mac

;-------------------------------------------------------------------------------------------ROM
COND	ROM
;-------------------------------------------------------------------------------------------M512
COND	M512

	psect	text

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

;
;	Bootstrap code start at 0000H
;
				;Banking disabled, 0-3 physical ROM is mapped to 0-3 logical banks 
	di			;disable ints
	SETROM	0,0		;ROM #0 to 0000-3FFF 
	SETRAM	1,0		;RAM #0 to 4000-7FFF
	SETRAM	2,1		;RAM #1 to 8000-BFFF
	SETRAM	3,2		;RAM #2 to C000-FFFF
	ENABLE_B
	ld	sp,_REGS	;SP at 0DFE8H
COND	DIG_IO
	xor	a		;all leds OFF
	out (LED_PORT),a
ENDC
				;move RTM/Z80 exit code to RAM
	ld	hl,$DFE3
	ld	de,0DFE3H
	ld	bc,5
	ldir
				;init SIO
	ld	hl,SIO_Data
	ld	c,SIO_A_C
	ld	b,SIO_len
	otir
;
	jp	select
;
	org	03EH
selrom:
	out	(78H),a		;ROM #A to 0000-3FFF
;we are now at 0040H, the start address of RTM/Z80 or Watson
;execution continues at 0040H in the selected ROM
;
watson:	ld	a,31		;ROM #31 for watson
	jr	selrom
;
cpm:	ld	a,1		;ROM #1 for CP/M
	jr	selrom
;
select:				;ask user to select an RTM/Z80 version or Watson
	PRINT	msgsel
	ReadChar
	cp	'0'
	jr	z,cpm
	cp	'1'
	jr	z,watson
	call	UpperCase
	cp	'Z'+1
	jr	nc,select
	cp	'A'
	jr	c,select
	sub	'A'-2
	push	af		;save A=2...27 : selects RTM/Z80 (Physical ROM #2...27)
				;ask for the RTM/Z80 app HEX file
askHEX:				
	PRINT	msgrdy		;print ready
	call	LoadHEX
	jr	z,setbrk
;				;checksum wrong!
	PRINT	msgbad
	jr	askHEX
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
	jp	nz,0		;if not, start again booting
	PRINT	msgboot
				;move RTM/Z80 ver #A to RAM

	SETRAM	1,3		;map RAM #3 to 4000-7FFF
				;RTM/Z80 ver #A will be stored here...

	pop	af		; A = ver # of RTM/Z80 (2=v1, 3=v2,...)
	out	(7AH),a		;map ROM #A to 8000-BFFF
				;now, RTM/Z80 ver #A is stored at 8000-BFFF
	ld	hl,8000H
	ld	de,4000H
	ld	bc,4000H
	ldir			;move (8000H --> 4000H, 4000H bytes)
				;now, RTM/Z80 ver #A is stored in RAM #3

	SETRAM	1,0		;map back RAM #0 to 4000-7FFF
	SETRAM	2,1		;map back RAM #1 to 8000-BFFF

	ld	a,35		;set RAM # 3 to be loaded at 0000H
	jp	selrom
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
;	Exit RTM/Z80
;
$DFE3:	SETROM	0,0		;ROM #0 to 0000-3FFF 
	rst	0
;
msgsel:	defb	0dh,0ah
	defm	'Type 0 to boot CP/M,'
	defb	0dh,0ah
	defm	' a...z to boot an RTM/Z80 version,'
	defb	0dh,0ah
	defm	' or 1 to start Watson:'
	defb	0dh,0ah
	defb	0
msgrdy:	defb	0dh,0ah
	defm	'Ready to read the RTM/Z80 app HEX file:'
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

ENDC
;-------------------------------------------------------------------------------------------M512
ENDC
;-------------------------------------------------------------------------------------------ROM
