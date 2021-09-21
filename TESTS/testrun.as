*Include config.mac
*Include apiasm.mac
;
;	Measuring starting & stopping tasks (while optionally reading a big .HEX file)
;

;
;	7,3728	: 	440 micros = Run+Stop
;
	GLOBAL _main

	psect text

_main:	
	ld	bc,60H
	ld	hl,Task2
	ld	e,2
	call	__StartUp
	ret
;
Task2:	
	call	__RoundRobinOFF
COND	IO_COMM
	ld	bc,60H
	ld	hl,TaskHEX
	ld	e,30
	call	__RunTask
ENDC
	call	__MakeSem
	ld	(W),hl
	call	__MakeSem
	ld	(S),hl
	call	__MakeSem
	ld	(X),hl

	call	__MakeTimer
	ld	(Timer),hl

	ld	de,(S)
COND	IO_COMM
	ld	bc,600		;wait 3 secs
ENDC
COND	IO_COMM=0
	ld	bc,1		;wait 5 ms
ENDC
	xor	a		;just once
	call	__StartTimer

	ld	hl,(S)
	call	__Wait

	call	__GetTicks
	ld	(T_start),de
COND	IO_COMM
	ld	de,(S)
	ld	bc,200		;1sec
	ld	a,1		;forever
	call	__StartTimer
ENDC
loop2:				;1 start + stop task /sec
COND	IO_COMM
	ld	hl,(S)
	call	__Wait
ENDC
	ld	bc,60H
	ld	hl,Task1
	ld	e,1
	call	__RunTask
	call	__StopTask

	ld	hl,(Cnt)
	dec	hl
	ld	(Cnt),hl
	ld	a,l
	or	h
	jr	nz,loop2

	call	__GetTicks
	ex	de,hl
	or	a
	ld	de,(T_start)
	sbc	hl,de
	ex	de,hl
	ld	hl,delta
	call	StoreDE
COND	IO_COMM
	ld	hl,(X)
	call	__Wait
ENDC
	ld	hl,tx1		;write Delta!
	call	type_str

	call	__GetCrtTask
	call	__StopTask

Task1:	jr	Task1

COND	IO_COMM
	GLOBAL _ReadHEX
TaskHEX:
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
	ld	hl,(X)
	call	__Signal
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
ENDC
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
W:	defs	2
S:	defs	2
X:	defs	2
Timer:	defs	2
Delta:	defs	2		;count of tics for RunTask+StopTask
T_start:defs	2
TCB1:	defs	2
COND	IO_COMM
Cnt:	defw	10		;how many RunTask+StopTask
ENDC
COND	IO_COMM=0
Cnt:	defw	250		;how many RunTask+StopTask
ENDC
tx1:	defb	0dh,0ah	
	defm	'Delta='
delta:	defs	4
	defb	'H'
	defb	0
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
