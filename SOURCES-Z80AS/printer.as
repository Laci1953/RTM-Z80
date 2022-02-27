;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
TITLE	Parallel Printer I/O support
;
*Include config.mac
;
IF	NOSIM .and. LPT

	GLOBAL	LPT_Sem,LPT_Timer,LPT_TimerSem,_PIO_INT
	GLOBAL	__LPT_Print
	GLOBAL	__Wait,__Signal,__StartTimer
	GLOBAL	B_X_C_TO_HL,HL_DIV_DE
IF	C_LANG
	GLOBAL	_LPT_Print
ENDIF

	psect	text
;
;					MALE CABLE PINS
;PIO B (output)
;
;DATA1...DATA8 				;2 to 9
;
;PIO A (control)
;                  
;BIT0 (IN) = BUSY
BUSY            equ     0               ;11
BUSYMask        equ     00000001B
;BIT1 (IN) = ACK
nAck            equ     1               ;7
nAckMask        equ     00000010B
;BIT2 (OUT) = STROBE
nStrobe         equ     2               ;1
nStrobeMask     equ     00000100B
;
;	Also, link with a Dupont wire SC103 IEI <---> SC110 IEO
;	...and link with a Dupont wire SC103 GND <---> LPT GND (any PIN from 18 to 25)
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
	push	de
	push	bc

	ld	hl,LPT_Sem	;wait free printer 
	call	__Wait
	
	ld	hl,LPT_Timer	;wait 5 ms
	ld	de,LPT_TimerSem
	ld	bc,1		;BC=tics=1
	xor	a		;no repeat
	call	__StartTimer

	ld	hl,LPT_TimerSem	;wait 1 tick
	call	__Wait

	pop	bc		;C=len
	pop	hl		;HL=buf
	push	bc		;len on stack

        ld      de,nStrobeMask	;D=0,E=4

	ld	a,e		;strobe high
	out     (PIO_A_D),a

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
; WARNING - THIS WAS TESTED ON THE EPSON LX 350 PARALLEL PRINTER
; TIMINGS ARE CRITICAL, DO NOT MODIFY THIS PART OF THE SOURCE CODE

loop:

WaitNotBusy:			;wait not BUSY
        in      a,(PIO_A_D)
        rra
        jp      c,WaitNotBusy

        ld      a,(hl)		;send char to printer
        out     (PIO_B_D),a
				;wait > 0.75 uS
        nop
        nop
                                ;strobe low
        ld      a,d
        out     (PIO_A_D),a
				;wait > 0.75 uS
        nop
	or	a		;CARRY=0
                                ;strobe high
        ld      a,e
        out     (PIO_A_D),a

	inc     hl		;increment pointer
				;wait ACK
	jp	nc,$
				;ACK done
        dec	c		;decrement counter

	jp	nz,loop

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

;
;	PIO A interrupt (at ACK 1-->0)
;
_PIO_INT:
	scf			;set CARRY=1
	ei
	reti
;

ENDIF
