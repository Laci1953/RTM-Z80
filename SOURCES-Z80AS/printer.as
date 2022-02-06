;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
TITLE	Parallel Printer I/O support
;
*Include config.mac
;
IF	NOSIM .and. LPT

	GLOBAL	LPT_Sem,LPT_Timer,LPT_TimerSem
	GLOBAL	__LPT_Print
	GLOBAL	__Wait,__Signal,__StartTimer
	GLOBAL	B_X_C_TO_HL,HL_DIV_DE
IF	C_LANG
	GLOBAL	_LPT_Print
ENDIF

	psect	text

;PIO B (output)
;
;DATA1...DATA8 PINS:2 to 9
;
;PIO A (input/output)                   MALE CABLE PINS
;BIT0 (IN)
BUSY            equ     0               ;PIN 11
BUSYMask        equ     00000001B
;BIT1 (OUT)
nStrobe         equ     1               ;PIN 1
nStrobeMask     equ     00000010B
;BIT2 (OUT)
nAutoFd         equ     2               ;PIN 14
nAutoFdMask     equ     00000100B
;BIT3 (IN)
Select		equ	3		;PIN 13
SelectMask	equ	00001000B
;BIT4 (IN)
pError		equ	4		;PIN 12
pErrorMask	equ	00010000B	
;BIT7 (IN)
nAck            equ     7               ;PIN 7
nAckMask        equ     10000000B
;
;	Print to Parallel Printer
;
IF	C_LANG
;
;	short	LPT_Print(char* buf, short len);
;	returns 0=OK, 1=OFF LINE, 2=PAPER OUT, 3=PRINTER ERROR
_LPT_Print:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=buf
	inc	hl
	ld	c,(hl)		;C=len
ENDIF
;
;	DE=buf, C=len
;	returns HL: 0=OK, 1=OFF LINE, 2=PAPER OUT, 3=PRINTER ERROR
;
__LPT_Print:
;	in	a,(PIO_A_D)
;	bit	BUSY,a
;	jr	z,notbusy
;	ld	hl,3		;Printer error
;notbusy:
;	bit	pError,a
;	jr	z,paperok
;	ld	hl,2		;Paper out
;	ret
;paperok:
;	bit	Select,a
;	jr	nz,isonline
;	ld	hl,1		;Off line
;	ret
;isonline:
	push	de
	push	bc

	ld	hl,LPT_Sem	;wait free printer 
	call	__Wait
	
	pop	bc		;C=len
	pop	hl		;HL=buf
	push	bc		;len on stack

        ld      d,0
        ld      e,nStrobeMask

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; WARNING - THIS WAS TESTED ON THE EPSON LX 350 PARALLEL PRINTER
; TIMINGS ARE CRITICAL, DO NOT MODIFY THIS CODE

loop:
	di

WaitNotBusy:
        in      a,(PIO_A_D)
        rra
        jr      c,WaitNotBusy

        ld      a,(hl)
        out     (PIO_B_D),a
				;wait
        nop
        nop
                                ;strobe low
        ld      a,d
        out     (PIO_A_D),a
				;wait
        inc     hl		;increment pointer
                                ;strobe high
        ld      a,e
        out     (PIO_A_D),a

	ei

        dec	c		;decrement counter
	jr	nz,loop

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

				;wait ((LEN*TICS_PER_SEC)/LPT_CH_P_S)+1 tics
	pop	bc		;C=len
	ld	b,TICS_PER_SEC
	call	B_X_C_TO_HL	;HL=C(len) * B(TICS_PER_SEC)
	ld	de,LPT_CH_P_S	;chars per sec for EPSON LX 350
	call	HL_DIV_DE	;HL=HL/LPT_CH_P_S
	inc	hl		;+1
	push	hl		;tics on stack
	ld	hl,LPT_Timer
	ld	de,LPT_TimerSem
	pop	bc		;BC=tics
	xor	a		;no repeat
	call	__StartTimer

	ld	hl,LPT_TimerSem	;wait tics #
	call	__Wait

	ld	hl,LPT_Sem	;signal printer free
	call	__Signal

	ld	hl,0		;success
	ret

ENDIF
