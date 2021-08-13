*Include config.mac
*Include apiasm.mac
;
;	7,3728	: 130 micros = 1 alloc / 1 dealloc
;
	GLOBAL _main,_xrnd,_xrndseed

	psect text

rnd3:
	call	_xrnd
	ld	a,l
	and	3
	ld	c,a
	ret
;
_main:	
	ld	bc,60H
	ld	hl,Task
	ld	e,2
	call	__StartUp
COND	NOCPM
	ret
ENDC
COND	CPM
	ld	c,0
	jp	5
ENDC	
;
Task:	
	call	__MakeSem
	ld	(W),hl
	call	__MakeSem
	ld	(S),hl
	call	__MakeTimer
	ld	(Timer),hl
	ld	de,(S)
	ld	bc,1
	xor	a
	call	__StartTimer
	ld	hl,(S)
	call	__Wait
	call	_xrndseed
	call	__GetTicks
	ld	(T_start),de
loop2:				;50000 x (10 alloc + 10 dealloc)
	call	rnd3
	call	__Balloc
	ld	(p0),hl
	call	rnd3
	call	__Balloc
	ld	(p1),hl
	call	rnd3
	call	__Balloc
	ld	(p2),hl
	call	rnd3
	call	__Balloc
	ld	(p3),hl
	call	rnd3
	call	__Balloc
	ld	(p4),hl
	call	rnd3
	call	__Balloc
	ld	(p5),hl
	call	rnd3
	call	__Balloc
	ld	(p6),hl
	call	rnd3
	call	__Balloc
	ld	(p7),hl
	call	rnd3
	call	__Balloc
	ld	(p8),hl
	call	rnd3
	call	__Balloc
	ld	(p9),hl

	ld	hl,(p0)
	call	__Bdealloc
	ld	hl,(p1)
	call	__Bdealloc
	ld	hl,(p2)
	call	__Bdealloc
	ld	hl,(p3)
	call	__Bdealloc
	ld	hl,(p4)
	call	__Bdealloc
	ld	hl,(p5)
	call	__Bdealloc
	ld	hl,(p6)
	call	__Bdealloc
	ld	hl,(p7)
	call	__Bdealloc
	ld	hl,(p8)
	call	__Bdealloc
	ld	hl,(p9)
	call	__Bdealloc

	ld	hl,(Cnt)
	dec	hl
	ld	(Cnt),hl
	ld	a,l
	or	h
	jp	nz,loop2

	call	__GetTicks
	ex	de,hl
	or	a
	ld	de,(T_start)
	sbc	hl,de
	ld	(Delta),hl
				;write Delta!
	ex	de,hl
	ld	hl,delta
	call	StoreDE
	ld	hl,tx1
	call	type_str
	call	__ShutDown
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

W:	defs	2
S:	defs	2
Timer:	defs	2
Delta:	defs	2
p0:	defs	2
p1:	defs	2
p2:	defs	2
p3:	defs	2
p4:	defs	2
p5:	defs	2
p6:	defs	2
p7:	defs	2
p8:	defs	2
p9:	defs	2
T_start:defs	2
Cnt:	defw	50000
tx1:	defb	0dh,0ah	
	defm	'Delta='
delta:	defs	4
	defb	'H'
	defb	0
