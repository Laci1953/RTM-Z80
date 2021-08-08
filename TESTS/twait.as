*Include config.mac
*Include apiasm.mac

;	Just reading a (big) .HEX file

	GLOBAL _main,_ReadHEX

	psect text

_main:	
	ld	bc,60H
	ld	hl,Task
	ld	e,10
	call	__StartUp
	ret
Task:
	call	__RoundRobinOFF
	call	__MakeSem
	ld	(W),hl
	call	_ReadHEX
	ld	a,h
	cp	0FFH
	jr	nz,ok
	ld	a,l
	cp	0FEH
	jr	z,tmo
	cp	0FDH
	jr	z,badck
	cp	0FCH
	jr	z,eofnf
	ld	hl,mallocf
prt:	call	type_str
	call	__GetCrtTask
	call	__StopTask

tmo:	ld	hl,mtmo
	jr	prt
badck:	ld	hl,mbadck
	jr	prt
eofnf:	ld	hl,meofnf
	jr	prt
ok:	ld	hl,mok
	jr	prt

;
;	Type string
;	HL=string
;
type_str:
	push	hl
	ld	bc,0
loop:	ld	a,(hl)
	or	a
	jr	z,1f
	inc	bc
	inc	hl
	jr	loop
1:	pop	hl
	ld	de,(W)
	call	__CON_Write
	ld	hl,(W)
	call	__Wait
	ret

;
;       Store Word
;
;       store DE in hexa at HL
;       DE not affected
;
StoreDE:
        push    de
        ld      a,d
        call    ByteToNibbles
        ld      a,d
        call    NibbleToASCII
        ld      (hl),a
        inc     hl
        ld      a,e
        call    NibbleToASCII
        ld      (hl),a
        inc     hl
        pop     de
        push    de
        ld      a,e
        call    ByteToNibbles
        ld      a,d
        call    NibbleToASCII
        ld      (hl),a
        inc     hl
        ld      a,e
        call    NibbleToASCII
        ld      (hl),a
        pop     de
        ret
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

mallocf:defb	0dh,0ah
	defm	'Alloc failed!'
	defb	0	
mtmo:	defb	0dh,0ah
	defm	'TimeOut!'
	defb	0	
mbadck:	defb	0dh,0ah
	defm	'Bad Checksum!'
	defb	0	
meofnf:	defb	0dh,0ah
	defm	'Could not reach EOF!'
	defb	0	
mok:	defb	0dh,0ah
	defm	'OK!'
	defb	0	
W:	defs	2
