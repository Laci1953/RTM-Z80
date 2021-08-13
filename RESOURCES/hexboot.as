;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	RTM/Z80 boot utility
;
;zas -j hexboot.as
;link
;link> -x -z -ptext=0E000H -os.obj hexboot.obj
;>objtohex s.obj hexboot.hex

RAM128K	equ	1	; 0 : only 64K RAM, 1 : 2 x 64K RAM available

	psect	text

;	Loaded as .HEX at 0E000H, started at 0E000H
;	Loads RTMZ80.HEX
;	asks for breakpoints, asks confirmation
;	and starts RTM/Z80 at 0040H if confirmed
;
START_RTM	equ	40H
;
;       Ports
;
SIO_A_C equ     80H
SIO_A_D equ     81H
;
LED_PORT	equ	0
;
MEMP_PORT       equ     38H
;
ROM_OUT         equ     00000001B
ROM_IN          equ     00000000B
;
LOWER_64RAM     equ     00000000B

MACRO	LOW_RAM
	ld	a,LOWER_64RAM .or. ROM_OUT
	out	(MEMP_PORT),a
ENDM

MACRO	ROM_LOW_RAM
	ld	a,LOWER_64RAM 
	out	(MEMP_PORT),a
ENDM

COND	RAM128K

UPPER_64RAM     equ     10000000B

MACRO	UP_RAM
	ld	a,UPPER_64RAM .or. ROM_OUT
	out	(MEMP_PORT),a	
ENDM

ENDC

MACRO	CharToNumber
	sub	'0'
	cp	10
        jr	c,1f
	sub	7
1:		
ENDM
;
MACRO	ReadChar
2:	in	a,(SIO_A_C)	;RR0
	rrca			;char ready?
	jr	nc,2b		;no, wait
	in	a,(SIO_A_D)	;get A=char
ENDM
;
MACRO	SkipToRec
3:	ReadChar
	cp	':'
	jr	nz,3b
ENDM
;
;       SCM API functions used
;
RESET   equ     0       ;reset
;
;       SCM API 
MACRO   SCMF	N
        ld      c,N
        rst     30H
ENDM
;
MACRO   PRINT   msg
        ld      hl,msg
        call    TypeString
ENDM
;
START:	
	di			;disable ints
	ld	sp,end_stack
				;move RTM/Z80 exit code
	ld	hl,$DFE3
	ld	de,0DFE3H
	ld	bc,5
	ldir

COND	RAM128K
				;move low - up routines fragment
	ld	hl,$DF4D
	ld	de,0DF4DH
	ld	bc,$len
	ldir
				;move low - up routines fragment to UpperRAM
	ld	ix,$DF4D
	ld	de,0DF4DH
	ld	a,$len
looptoup:
	push	af
	ld	a,(ix+0)
	ld	c,2BH		;(DE) in UpperRAM <-- A
	rst	30H
	inc	ix
	inc	de
	pop	af
	dec	a
	jr	nz,looptoup

ENDC

	LOW_RAM			;deselect ROM, select 64K LOW RAM
	xor	a
	out	(LED_PORT),a	;leds off
	PRINT	msgrdy		;print ready
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
	jr	z,setbrk
;				;checksum wrong!
	PRINT	msgbad
	jp	resetSCM
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
	jr	nz,resetSCM
	PRINT	msgboot
	jp	START_RTM	;yes, start RTM/Z80
resetSCM:			;no, reset SCM
	ROM_LOW_RAM		;ROM IN, LOWER 64K RAM
	SCMF	RESET
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
;       Type String
;
;       Print string (zero terminated)
;
;       HL=string addr
;       BC,DE not affected
;
TypeString:
        ld      a,(hl)
        or      a
        ret     z
        call	TypeChar
        inc     hl
        jr      TypeString
;
;       Byte To Nibbles
;
;       Convert byte to nibbles
;       A = Hex byte
;       returns D = Most significant nibble, E = Least significant nibble
;       registers not affected (except AF)
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
;       Converts Nibble A to ASCII
;
;       Converts Nibble (0-15) to its ASCII value ('0' to '9', or 'A' to 'F')
;
;       A=Nibble
;       returns A=ASCII value of byte (letters in uppercase)
;       registers not affected (except AF)
;
NibbleToASCII:
        cp      10              ;digit?
        jr      nc,1f
        add     a,'0'           ;it's a digit
        ret
1:      add     a,'A'-10        ;no, it's a letter (A to F)
        ret
;
;       Print a byte in A (2 hexa chars, uppercase)
;
;       A=byte
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
        ROM_LOW_RAM
        ret
;
;	up to low 4B
;
$DF7C:	UP_RAM
        ld      c,(iy+0)
        ld      b,(iy+1)
        ld      e,(iy+2)
        ld      d,(iy+3)
	ROM_LOW_RAM
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
	defs	20H		;stack
end_stack:

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
