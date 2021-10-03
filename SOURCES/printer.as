;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	Parallel Printer I/O support
;
*Include config.mac
;
COND	NOSIM .and. LPT

	GLOBAL	LPT_Sem,LPT_Timer,LPT_TimerSem
	GLOBAL	__LPT_Print
	GLOBAL	__Wait,__Signal,__StartTimer
	GLOBAL	B_X_C_TO_HL,HL_DIV_DE
COND	C_LANG
	GLOBAL	_LPT_Print
ENDC

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
;BIT2 (IN)
Select		equ	2		;PIN 13
SelectMask	equ	00000100B
;BIT3 (IN)
pError		equ	3		;PIN 12
pErrorMask	equ	00001000B	
;
T_OTIR: defb    0,nStrobeMask
;
;	Print to Parallel Printer
;
COND	C_LANG
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
ENDC
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
	
	pop	de		;E=len
	pop	iy		;IY=buf
	push	de		;len on stack

        ld      c,PIO_A_D       ;prepare OTIR
        ld      hl,T_OTIR+2

	di			;NO INTERRUPTS ALLOWED DURING PRINT
				;print chars
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; WARNING - THIS WAS TESTED ON THE EPSON LX 350 PARALLEL PRINTER
; TIMINGS ARE CRITICAL, DO NOT MODIFY THIS LOOP
;
loop:	
        dec     hl              ;prepare OTIR
        dec     hl
        ld      b,2

WaitNotBusy:
        in      a,(PIO_A_D)
        rra
        jp      c,WaitNotBusy

        ld      a,(iy+0)
        out     (PIO_B_D),a

        nop                     ;4
        nop                     ;4
        nop                     ;4

        otir                    ;strobe low, stobe high

        inc     iy
        dec     e
        jp      nz,loop
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  
	ei			;printing done, now enable interrupts
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
;
ENDC