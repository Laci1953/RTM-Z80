*Include config.mac

IF	Z80ALL .and. SYSSTS
;
;	Z80ALL VGA routines
;
	GLOBAL	MarkLen, DisplaySysScr, Bin2Hex, TaskCnt, CrtLocate

	psect	text
;
Cursor: defw    0               ;cursor registers
MarkLen:defs	1		;dynamic memory marks lenght
TaskCnt:defb	0		;tasks counter

MsgSys:	defz	'RTM/Z80 - System status display'
MsgSysROW	equ	0
MsgSysCOL	equ	15

MsgDyn:	defm	'Dynamic memory (8KB) - each '
	defb	' '+80H
	defz	' = a block of 16 bytes'
MsgDynROW	equ	2
MsgDynCOL	equ	3

MsgLine:
	REPT	64
	defb	'-'
	ENDM
	defb	0
MsgLineROW1	equ	3
MsgLineROW2	equ	12
MsgLineROW3	equ	20
MsgLineCOL	equ	0

MsgTasks:
	defz	'Tasks              Status'
MsgTasksROW	equ	19
MsgTasksCOL	equ	7

MsgStatus:
	defz	'Priority(hexa) Running Waiting'	
MsgStatusROW	equ	21
MsgStatusCOL	equ	7

StsROW		equ	23
PriCOL		equ	7
RunCOL		equ	22
WaitCOL		equ	30

;
;	Clear screen
;
CrtClear:
        ld      a,' '
        ld      bc,0BH          ;go to last group of 4 lines, first column
clr4lines:
        out     (c),a
        djnz    clr4lines
        dec     c               ;decrement 4 lines group #
        jp      p,clr4lines     ;if C >= 0 , repeat
        ret
;
;	Set screen cursor
;	C=row, B=col
;
CrtLocate:
        xor     a               ;init A=col index#
        srl     c               ;shift right row#
        jr      nc,1f
        add     a,64            ;if Carry then col index# += 64
1:
        srl     c               ;shift right row#
        jr      nc,2f
        add     a,128           ;if Carry then col index# += 128
2:
        add     a,b             ;add col#
        ld      b,a             ;B=col index#
        ld      (Cursor),bc     ;save cursor
        ret
;
;	Print string
;	HL=string pointer (zero terminated)
;
PrintStr:
	ld	bc,(Cursor)
nextch:	ld	a,(hl)
	or	a
	ret	z
	out	(c),a
	inc	b
	inc	hl
	jr	nextch
;
	MACRO	Message	txt,row,col
	ld	b,col
	ld	c,row
	call	CrtLocate
	ld	hl,txt
	call	PrintStr
	ENDM
;
;	Display system status initial screen
;
DisplaySysScr:
	call	CrtClear
	Message	MsgSys,MsgSysROW,MsgSysCOL
	Message	MsgDyn,MsgDynROW,MsgDynCOL
	Message	MsgLine,MsgLineROW1,MsgLineCOL
	Message	MsgTasks,MsgTasksROW,MsgTasksCOL
	Message	MsgLine,MsgLineROW2,MsgLineCOL
	Message	MsgStatus,MsgStatusROW,MsgStatusCOL
	Message	MsgLine,MsgLineROW3,MsgLineCOL
	ret
;
;------------------------------------------------------------
;	Bin2Hex
;
;	A = byte
;
;	returns DE = hexa representation of A
;		A = high nibble in hexa (ready to be stored/printed)
;------------------------------------------------------------
Bin2Hex:
	ld	e,a		;E = byte
	and	0FH		;A = low nibble
	call	nibble2hex	;D = hexa
	ld	a,e		;A = byte
	ld	e,d		;E = low nibble in hexa
	and	0F0H		;A = (high nibble, 0000)
	rrca
	rrca
	rrca
	rrca			;A = high nibble
				;falls through, will return A = D = high nibble in hexa
;
;	A = bin
;	returns A = D = hexa
;
nibble2hex:			;A = bin
	add     a,090h
        daa
        adc     a,040h
        daa			;A = hexa
	ld	d,a
	ret

ENDIF
