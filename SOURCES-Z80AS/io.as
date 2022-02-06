;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
TITLE	Serial I/O driver for interrupt-based I/O
;
; For the device CONSOLE
;
; Each I/O driver is build as a task
; Its priority shall be higher than a normal task priority
;
*Include config.mac

;----------------------------------------------------------------------NOSIM
IF    NOSIM
;
;---------------------------------------------------------------DIG_IO
IF	DIG_IO
;
	GLOBAL	IO_LEDS
;
LED_PORT	equ	0
;
;	LED definitions - bit affected
;
RTMZ80		equ	0	;RTM/Z80 running
CLOCK		equ	1	;1 second ON/OFF
ERR_STACK	equ	2	;stack warning 
ERR_TCB		equ	3	;wrong TCB
ERR_SEM		equ	4	;wrong Semaphore
ERR_FULLMEM	equ	5	;no more free memory
ERR_ESC		equ	6	;SIO A External Status Change
ERR_SRC		equ	7	;SIO A Special Receive Condition

MACRO	OUT_LEDS	bitnr
	ld	a,(IO_LEDS)
	set	bitnr,a
	ld	(IO_LEDS),a
	out	(LED_PORT),a
ENDM

ENDIF
;---------------------------------------------------------------DIG_IO
ENDIF
;----------------------------------------------------------------------NOSIM

;
; Serial I/O driver for interrupt-based I/O
;
; For the device CONSOLE
;
; Each I/O driver is build as a task
; Its priority shall be higher than a normal task priority
;
        psect   bss

SIO_RP:         defs    2 ;SIO receive buffer read pointer
SIO_WP:         defs    2 ;SIO receive buffer write pointer
;
;       SIO receive buffer
;
IF	SIM
SIO_buf         equ     7E00H
ENDIF

IF	NOSIM

	GLOBAL	SIO_buf

;       Exception status store
;
        GLOBAL  RR0,RR1

RR0:            defs    1       ;SIO A RR0
RR1:            defs    1       ;SIO A RR1
;
ENDIF
;
CTRL_C		equ	3
CTRL_C_flag:	defs	1	;0: No CTRL_C pressed, 1: CTRL_C was pressed
;
;       Current operation
;
CON_CrtIO:      defs    1       ;initialized as IO_IDLE
;
CON_CountS:	defs	1	;number of chars not read ( for IO_RAW_READ )
;
;	Support for line editing while reading chars
;	order is critical, DO NOT MOVE THESE BYTES
ReadCnt:	defs	1	;nr. of chars read in a IO_READ op
EchoStatus:	defs	1	;handles the sequence BS-BL-BS used to erase last char
				;0:echo BACKSPACE and set-it=1
				;1:echo BLANK and set-it=2
				;2:echo BACKSPACE and set-it back = 0
;
;       Special chars
;
ENTER           equ     0DH     ;end of IO_READ op
DELETE		equ	7FH	;BACKSPACE key (ASCII code = DELETE)
BACKSPACE	equ	8	;to move back the cursor
BLANK		equ	20H
;
COUNTER_OFF     equ     4       ;semaphore counter offset
;
CON_Q_BATCH_CNT equ	5	;CON queue has a capacity of 5 I/O requests
CON_IO_REQ_LEN  equ     10      ;must be set for each driver
;
CON_IO_Request: defs    CON_IO_REQ_LEN  ;lenght must be set for each driver
OtherRequest:	defs    CON_IO_REQ_LEN
OtherSts:	defs	1		;0 : request off, >= 1 : request on 
;
OFFSET_OP               equ     1	;I/O opcode is the high byte
OFFSET_SEM              equ     2
OFFSET_BUF              equ     4
OFFSET_COUNT            equ     6
OFFSET_TASKID		equ	7
OFFSET_TIMER		equ	8
;
CON_OpCode      equ     CON_IO_Request+OFFSET_OP
CON_Sem         equ     CON_IO_Request+OFFSET_SEM
CON_Buf         equ     CON_IO_Request+OFFSET_BUF
CON_Count       equ     CON_IO_Request+OFFSET_COUNT
CON_TaskID	equ	CON_IO_Request+OFFSET_TASKID
CON_Tim		equ	CON_IO_Request+OFFSET_TIMER
;
; I/O Request structure for device CON
;
; defw OpCode
; defw IO_Sem
; defw buf
; defb count
; defb TaskID
; defw Timer
;
ID_OFF	equ	15	;ID in TCB
OFF_BS	equ	4	;Buffer addr pointer offset in queue

	psect	text

LogMsg:         defb    0dh,0ah         ;Login message
                defm    'RTM/Z80 '
		defb	'0'+V_M
		defb	'.'
		defb	'0'+V_m
LogLen	equ	$-LogMsg
;
IF	NOSIM
        GLOBAL  _CON_ESC
        GLOBAL  _CON_SRC
ENDIF
IF	SIO_RING
	GLOBAL  GetSIOChars
ENDIF
	GLOBAL	EchoStatus
	GLOBAL	SIO_WP,SIO_RP
        GLOBAL _ReschINT
        GLOBAL  __StartTimer
        GLOBAL  ___StopTimer
IF    C_LANG
IF	IO_COMM
        GLOBAL  _Reset_RWB
        GLOBAL  _WriteB
        GLOBAL  _GetCountB
        GLOBAL  _ReadB
ENDIF
        GLOBAL  _CON_Write
        GLOBAL  _CON_Read
	GLOBAL	_CTRL_C
ENDIF
IF	IO_COMM
        GLOBAL  __WriteB
        GLOBAL  __ReadB
        GLOBAL  __GetCountB
        GLOBAL  __Reset_RWB
ENDIF
        GLOBAL  _CON_TX
        GLOBAL  _CON_RX
        GLOBAL  _Reschedule
        GLOBAL  CON_CrtIO
        GLOBAL  CON_Count
        GLOBAL  CON_IO_Wait_Sem
        GLOBAL  CON_IO_Req_Q
        GLOBAL  CON_IO_WP
        GLOBAL  CON_IO_RP
        GLOBAL  CON_IO_BS
        GLOBAL  CON_IO_BE
        GLOBAL  CON_IO_RS
        GLOBAL  CON_IO_WS
        GLOBAL  CON_Driver_IO
	GLOBAL	__CTRL_C
        GLOBAL  __CON_Write
        GLOBAL  __CON_Read
        GLOBAL  __InitSem
        GLOBAL  __InitQ
        GLOBAL  __ReadQ
	GLOBAL	__GetQSts
        GLOBAL  __Wait
        GLOBAL  __Signal
        GLOBAL QuickSignal
	GLOBAL __KillTaskIO
	GLOBAL _RunningTask
IF    DEBUG
        GLOBAL CON_Wr_Sch
ENDIF
;------------------------------------------------------------------------------------I/O Driver task
;       I/O Driver task
;
CON_Driver_IO:
        ld      hl,CON_IO_Wait_Sem
        di
        call    __InitSem       ;Init local I/O wait semaphore
        ld      hl,CON_IO_Req_Q
        ld      b,CON_IO_REQ_LEN/2 ;5 2-bytes = 10 bytes to move in batch
        ld      c,CON_Q_BATCH_CNT ;5 batches : 5 x 10 = 50; + 6 = 56, buffer of 64 will be allocated
        call    __InitQ         ;Init I/O Requests queue
	xor	a
	ld	(CTRL_C_flag),a	;reset CTRL_C flag
        ei
        ld      c,LogLen
        ld      hl,LogMsg
        ld      de,0
        call    __CON_Write     ;write login message( HL=buf, DE=Sem, C=len)
loop:                           ;Get main I/O Request
        ld      de,CON_IO_Request
        ld      bc,CON_IO_Req_Q
        call    __ReadQ
process:			;then process-it
	xor	a		;init secondary request status
	ld	(OtherSts),a
        ld      a,(CON_Count)
        or      a
        jp      z,sig		;skip I/O with len=0
                                ;I/O request stored in CON_IO_Request
        ld      a,(CON_OpCode)
        ld      (CON_CrtIO),a   ;store OpCode, start the I/O
				;what I/O operation we have?
IF	IO_COMM
        cp	IO_RAW_READ  
        jr      z,rawreadop
ENDIF
	cp	IO_READ
	jr	z,readop
                                ;it's IO_WRITE or IO_RAW_WRITE
        di
        ld      hl,(CON_Buf)    ;get first char to write
        ld      a,(hl)
        inc     hl              ;increment pointer
        ld      (CON_Buf),hl
IF    NOSIM
        out     (SIO_A_D),a     ;write-it
ELSE
        out     (1),a
ENDIF
        ld      hl,CON_Count    ;decrement count
        dec     (hl)
        ei
        jr      wait            ;wait I/O completion
;
readop:				;it's a IO_READ
	xor	a		;prepare support data for line editing while reading
	ld	(ReadCnt),a	;Init nr. of chars read in a IO_READ op
	jr	wait
;

IF	IO_COMM

rawreadop:                      ;it's a IO_RAW_READ
        di
	ld	de,(SIO_WP)	;DE=SIO buf write pointer
	ld	hl,(SIO_RP)	;HL=SIO buf read pointer
	ld	bc,(CON_Buf)	;BC=user buf pointer
loopav:				;check if other chars available
IF	NOSIM
        in      a,(SIO_A_C)     ;read RR0
        rrca                    ;char available?
        jr     	nc,nochar       ;no, continue loop
        in      a,(SIO_A_D)     ;yes, read char
ELSE
        in      a,(0)
        or      a               ;char available?
        jr	z,nochar	;no, continue loop
        in      a,(1)           ;yes, read char
ENDIF
	ld	(de),a		;store char in SIO buffer
	inc	e		;increment write pointer
nochar:
                                ;check for chars stored in SIO receive buffer
        ld      a,e		;A=low write pointer
        cp      l               ;equal to L=low read pointer?
        jr      z,allstored
	ld      a,(hl)          ;no, get A=next char from SIO receive buffer
        inc     l               ;increment read pointer
        ld      (bc),a		;store A=char
        inc     bc              ;increment pointer in buf
	ld	a,(CON_Count)
        dec     a		;decrement counter
	ld	(CON_Count),a
        jr      nz,loopav       ;if not zero, continue checking
                                ;read operation ended
	ld	(SIO_WP),de
	ld	(SIO_RP),hl
	xor	a
        ld      (CON_CrtIO),a   ;set current I/O to idle (IO_IDLE=0)
	ld	(CON_CountS),a
        ld      hl,(CON_Tim)    ;stop the timer
        call    ___StopTimer
        ei
        jr      sig	        ;signal user semaphore
allstored:			;no more chars in SIO receive buffer, go wait
	ld	(SIO_WP),de
	ld	(SIO_RP),hl
	ld	(CON_Buf),bc
        ei

ENDIF

wait:				;before waiting completion of the main I/O request
				;try to read another I/O request
	ld	hl,CON_IO_Req_Q
	call	__GetQSts	;get number of batches still remaining
	ld	a,l
	ld	(OtherSts),a	;save number of batches still remaining
	or	a		;batches to be read?
	jr	z,nothing	;no, go process main I/O request
        ld      de,OtherRequest	;yes,
        ld      bc,CON_IO_Req_Q
        call    __ReadQ         ;get other I/O Request
nothing:			;then wait main I/O request completion
        ld      hl,CON_IO_Wait_Sem
        call    __Wait

IF	IO_COMM
				;check crt I/O op
	ld	a,(CON_CrtIO)
	cp	IO_RAW_READ
	jr	nz,sig
				;its a IO_RAW_READ, terminated by time-out
				;check SIO buffer
	di
	ld	de,(SIO_WP)	;DE=SIO buf write pointer
	ld	hl,(SIO_RP)	;HL=SIO buf read pointer
	ld	bc,(CON_Buf)	;BC=user buf pointer
looptmo:			;check if other chars available
IF	NOSIM
        in      a,(SIO_A_C)     ;read RR0
        rrca                    ;char available?
        jr     	nc,nochtmo      ;no, continue loop
        in      a,(SIO_A_D)     ;yes, read char
ELSE
        in      a,(0)
        or      a               ;char available?
        jr	z,nochtmo	;no, continue loop
        in      a,(1)           ;yes, read char
ENDIF
	ld	(de),a		;store char in SIO buffer
	inc	e		;increment write pointer
nochtmo:
        ld      a,e		;A=low write pointer
        cp      l               ;equal to L=low read pointer?
        jr      z,empty
	ld      a,(hl)          ;no, get A=next char from SIO receive buffer
        inc     l               ;increment read pointer
        ld      (bc),a		;store A=char
        inc     bc              ;increment pointer in buf
	ld	a,(CON_Count)
        dec     a		;decrement counter
	ld	(CON_Count),a
        jr      nz,looptmo      ;if not zero, continue checking
empty:
	ld	(SIO_WP),de
	ld	(SIO_RP),hl
	xor	a
        ld      (CON_CrtIO),a   ;set current I/O to idle (IO_IDLE=0)
	ei
	ld	a,(CON_Count)
	ld	(CON_CountS),a	;save counter

ENDIF

sig:				;I/O request specified a semaphore?
	ld      hl,(CON_Sem)
        ld      a,l
        or      h
        jr      z,checkOther	;no, skip signal
        call    __Signal        ;yes, signal requested semaphore
checkOther:			;have we another I/O request loaded ?
	ld	a,(OtherSts)
	or	a
	jp	z,loop		;no, go read main I/O request
				;yes, move-it to the I/O main request
	ld	hl,OtherRequest
	ld	de,CON_IO_Request
	ld	bc,CON_IO_REQ_LEN
	ldir
        jp      process		;then go process main I/O request
;
;------------------------------------------------------------------------------------I/O Driver task
;
;	Kill Task I/O op
;	called under disabled interrupts
;
;	C=TaskID
;	returns Z=1 : must reschedule, Z=0 : do not reschedule
;
__KillTaskIO:
	ld	hl,OtherRequest	;check first OtherRequest
	call	__KillReqIO
				;then ckeck CON I/O queue
	ld	hl,CON_IO_Req_Q+OFF_BS ;HL=pointer to queue buffer pointer
	ld	e,(hl)
	inc	l
	ld	d,(hl)
	ex	de,hl		;HL=CON IO queue buffer addr
	ld	b,CON_Q_BATCH_CNT ;queue capacity
killiol:push	hl
	call	__KillReqIO
	pop	hl
	ld	de,CON_IO_REQ_LEN
	add	hl,de
	djnz	killiol
IF	SIO_RING
	call	GetSIOChars
ENDIF
	ld	a,(CON_TaskID)	;now check crt I/O op
	cp	c
	ret	nz		;return if task is not the owner
				;task started crt I/O, must stop-it
	ld	hl,CON_Sem	;erase semaphore
	xor	a
	ld	(hl),a
	inc	hl
	ld	(hl),a
	ld	(CON_Count),a	;set I/O op counter=0
	ld	(EchoStatus),a	;force quit echo processing
	ld	a,(CON_CrtIO)
	or	a
	jr	nz,1f
	inc	a		;set Z=0
	ret			;return if crt I/O == IO_IDLE
1:
	and	IO_WRITE .or. IO_RAW_WRITE
	ret	nz		;if write I/O op, let the next interrupt terminate the I/O op
	ld	(CON_CrtIO),a	;else set crt IO = IDLE
	ld	hl,CON_IO_Wait_Sem ;and signal CON driver for terminated I/O
	call	QuickSignal
	xor	a		;Z=1
	ret
;
;	Kill I/O request for given TaskID
;	called under disabled interrupts
;
;	HL=I/O Request addr
;	C=TaskID
;	BC not affected
;
__KillReqIO:
	ld	de,OFFSET_TASKID
	add	hl,de
	ld	a,c
	cp	(hl)		;TaskID == I/O req TaskID ?
	ret	nz
				;yes, must drop-it
	dec	hl		;HL=Count pointer
	xor	a
	ld	(hl),a		;set Count=0 to skip it
	ld	de,OFFSET_COUNT-OFFSET_SEM
	sbc	hl,de		;HL=Sem pointer
	ld	(hl),a		;set Sem=0
	inc	hl
	ld	(hl),a
	ret
;									C_LANG
IF    C_LANG
;
;	CTRL_C
;
;short CTRL_C(void);
;
;	returns HL=0,A=0 : no CTRL_C was pressed, HL=1,A=1 : CTRL_C was pressed
;
_CTRL_C:
	xor	a
	ld	h,a

ENDIF

__CTRL_C:
	ld	a,(CTRL_C_flag)
	ld	l,a
IF	SIM
        in      a,(0)
        or      a               ;char available?
        jr	z,1f
        in      a,(1)           ;yes, read char
	cp	CTRL_C
	jr	nz,1f
	ld	l,1
1:
ENDIF

	xor	a
	ld	(CTRL_C_flag),a
	ld	a,l
	ret

IF	C_LANG
;
;       CON_Read
;
;void CON_Read(void* buf, char len, Semaphore* S);
;       AF,BC,DE,HL,IX,IY not affected
;
OFF_BUF equ     14
;
_CON_Read:
	ld	a,IO_READ	;A=I/O opcode
_CON_IO:
	push	af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
onstack:			;stack=AF,BC,DE,HL,IX,IY,retaddr,buf,len,S(,Timer)
        ld	ix,OFF_BUF
	add	ix,sp
	ld	l,(ix+0)
	ld	h,(ix+1)	;HL=Buf
	ld	c,(ix+2)	;C=Len
	ld	e,(ix+6)
	ld	d,(ix+7)	;DE=Timer
	push	de
	pop	iy		;IY=Timer
	ld	e,(ix+4)
	ld	d,(ix+5)	;DE=Sem
        call    ReqOnStack      ;call internal I/O routine, A=I/O opcode
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	pop	af
        ret
;
;       CON_Write
;
;void CON_Write(void* buf, short len, Semaphore* S);
;       AF,BC,DE,HL,IX,IY not affected
;
_CON_Write:
        ld      a,IO_WRITE	;A=I/O opcode
        jr      _CON_IO
;
;       Write_B
;
;void Write_B(void* buf, short len, Semaphore* S);
;       AF,BC,DE,HL,IX,IY not affected
;
_WriteB:
        ld	a,IO_RAW_WRITE	;A=I/O opcode
        jr      _CON_IO
;
ENDIF
;									C_LANG
;       CON_Read internal
;
;       HL=buf, DE=Sem, C=len, IY=timer
;
__CON_Read:
        ld      a,IO_READ       ;A=I/O opcode
ReqOnStack:                     ;build I/O request on stack
	ld	ix,(_RunningTask)
	ld	b,(ix+ID_OFF)	;B=TaskID
	push	iy		;timer
        push    bc              ;len,TaskID
        push    hl              ;buf
        push    de              ;sem
        push    af              ;OpCode on stack
        ld      hl,0
        add     hl,sp           ;HL=pointer to I/O request
        push    hl              ;pointer to I/O request on stack
        ld      hl,CON_IO_WS    ;HL=console queue write semaphore
        call    __Wait          ;wait write sem
        pop     hl              ;HL=pointer to I/O request
	di
        ld      de,(CON_IO_WP)  ;DE=console queue write pointer
        ld      bc,CON_IO_REQ_LEN;batch size = 10
        ldir                    ;(DE) <-BC bytes- (HL), DE=write pointer+BC
IF	SIO_RING
	call	GetSIOChars
ENDIF
        ld      hl,(CON_IO_BE)  ;HL=console queue buffer end
        or      a               ;CARRY=0
        sbc     hl,de
        jr      nz,2f           ;if write pointer at end of buffer...
        ld      de,(CON_IO_BS)  ;then set it again on start of buffer
2:      ld      (CON_IO_WP),de
	ei
        ld      hl,CON_IO_RS    ;HL=console queue read sem addr
        call    __Signal        ;signal read sem
        ld	hl,10           ;drop I/O request from stack
        add	hl,sp
	ld	sp,hl
        ret
;
;       CON_Write internal
;
;       HL=buf, DE=Sem, BC=len
;
__CON_Write:
        ld      a,IO_WRITE      ;A=I/O opcode
        jr      ReqOnStack
;
;       Write_B internal
;
;       HL=buf, DE=Sem, BC=len, IY=Timer
;
__WriteB:
        ld      a,IO_RAW_WRITE  ;A=I/O opcode
        jr      ReqOnStack
;
;-----------------------------------------------------------------DEBUG
IF    DEBUG
;
;       CON_Write from scheduler
;
;       called under interrupts disabled
;       DE=pointer to msg, C=message size
;
;       if (console queue write sem counter > 0), put the write request into the queue,
;          return Z=0 and HL=CON Driver TCB
;       else do nothing...sorry! and return Z=1
;
CON_Wr_Sch:
        ld      hl,CON_IO_WS+COUNTER_OFF
        ld      a,(hl)          ;A=console queue write sem counter
        or      a               ;zero?
        ret     z               ;yes, sorry, cannot write...
        dec     (hl)            ;decrement console queue write sem counter
                                ;build I/O request on stack
	push	bc		;dummy timer
        push    bc              ;msg len
        push    de              ;msg
        ld      de,0
        push    de              ;sem=0
        inc     d               ;D=1=IO_WRITE
        push    de              ;OpCode on stack
        ld      hl,0
        add     hl,sp           ;HL=pointer of I/O request, CARRY=0
        ld      de,(CON_IO_WP)  ;DE=console queue write pointer
        ld      bc,CON_IO_REQ_LEN;batch size = 10
        ldir                    ;(DE) <-BC bytes- (HL), DE=write pointer+BC
        ld      hl,(CON_IO_BE)  ;HL=console queue buffer end
        sbc     hl,de
        jr      nz,2f           ;if write pointer at end of buffer...
        ld      de,(CON_IO_BS)  ;then set it again on start of buffer
2:      ld      (CON_IO_WP),de
        ld      hl,CON_IO_RS    ;HL=console queue read sem addr
        call    QuickSignal     ;Signal-it, HL and Z returned
	ld	ix,10		;drop I/O request from stack
	add	ix,sp
 	ld	sp,ix
        ret
ENDIF
;-----------------------------------------------------------------DEBUG
;-----------------------------------------------------------------IO_COMM
IF	IO_COMM

;       Reset read / write bytes
;
;void Reset_RWB(void);
;       AF,BC,DE,HL,IX,IY not affected
;
;       Resets internal SIO receive buffer & error code
;
IF    C_LANG
_Reset_RWB:
ENDIF
__Reset_RWB:
        push    hl
        di
        ld      hl,SIO_buf
        ld      (SIO_RP),hl
        ld      (SIO_WP),hl
IF	NOSIM
	xor	a
	ld	(RR1),a
ENDIF
        ei
        pop     hl
        ret
IF    C_LANG
;
;       ReadB
;
;void ReadB(void* buf, char len, Semaphore* S, void*Timer, short TimeOut);
;       AF,BC,DE,HL,IX,IY not affected
;
;       Initiate raw data reading,
;       use of semaphore is mandatory
;       executes StartTimer(Timer, CON_IO_Wait_Sem, TimeOut, 0)
;
OFF_TIM	equ     20
;
_ReadB:
	push	af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
        ld      hl,OFF_TIM
        add     hl,sp           ;stack=AF,BC,DE,HL,IX,IY,retaddr,buf,len,S,Timer,TimeOut
        ld      e,(hl)
        inc     hl
        ld      d,(hl)          ;DE=Timer
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=Timeout
	ld	hl,CON_IO_Wait_Sem;HL=I/O Driver semaphore
	ex	de,hl		;DE=I/O Driver semaphore, HL=Timer
        xor     a               ;A=0 (no repeat)
        call    __StartTimer    ;start Timer
        ld      a,IO_RAW_READ   ;A=I/O opcode
        jp      onstack         ;go get buf,len,S,Timer and launch I/O
ENDIF
;
;       ReadB internal
;
;       HL=buf, DE=Sem, C=len, IX=TimeOut, IY=Timer
;
__ReadB:
        push    de
        push    hl
        push    bc
        push    ix              ;copy IX to...
        pop     bc              ;BC=TimeOut
	ld	de,CON_IO_Wait_Sem;DE=I/O Driver semaphore
	push	iy
	pop	hl		;HL=Timer
        xor     a               ;A=0 (no repeat)
        call    __StartTimer    ;setup timer
        pop     bc              ;C=len
        pop     hl              ;HL=buf
        pop     de              ;DE=sem
	ld	a,IO_RAW_READ	;A=I/O opcode, IY=Timer
        jp      ReqOnStack
IF    C_LANG
;
;       GetCountB
;
;short  GetCountB(void);
;
;       Returns L=nr. of chars NOT read, H = error code
;
_GetCountB:
        call    __GetCountB
        ld      l,a
        ret
ENDIF
;
;       GetCountB - internal
;
;       Returns A=nr. of chars NOT read, H=error code
;
;       Usage:
;               ld      hl,Sem
;               call    __InitSem
;               ex      de,hl           ;DE=Sem
;               ld      hl,Buf
;               ld      c,CHAR_COUNT
;               ld      ix,2            ;timeout 10 ms
;               call    __ReadB
;               ld      hl,Sem
;               call    __Wait
;               call    __GetCountB
;               or      a               ;check # NOT read
;
__GetCountB:
IF	NOSIM
	ld	a,(RR1)		;error code
	ld	h,a		;in H
ENDIF
        ld      a,(CON_CountS)  ;return counter of NOT read chars
        ret
;
ENDIF
;-----------------------------------------------------------------IO_COMM

;       Hardware interrupt handlers
;
;       SIO_A transmit buffer empty
;
_CON_TX:
IF    SIM
        di
ENDIF
        push    af              ;save only AF
        ld      a,(CON_CrtIO)   ;check current I/O op
        and     IO_WRITE .or. IO_RAW_WRITE        ;is it a write?
        jr      nz,write
                                ;no, this must be an echo char for IO_Read
	ld	a,(EchoStatus)
	or	a		;are we processing a BACKSPACE?
	jr	z,resettx
				;yes, check the current echo step
	dec	a
	jr	nz,2f
				;it was echo step 1
	ld	a,BLANK		;write a BLANK
IF    NOSIM
        out     (SIO_A_D),a    
ELSE
        out     (1),a
ENDIF
	ld	a,2
	ld	(EchoStatus),a	;set echo step 2
	jr	rettx
2:				;it was echo step 2
	ld	a,BACKSPACE	;write a backspace
IF    NOSIM
        out     (SIO_A_D),a    
ELSE
        out     (1),a
ENDIF
	xor	a
	ld	(EchoStatus),a	;set echo step 0 (quit BACKSPACE processing)
	jr	rettx
;
resettx:
IF    NOSIM
        ld      a,00101000B     ;RR0 Reset Transmitter Interrupt Pending
        out     (SIO_A_C),a
ENDIF
rettx:
        pop     af              ;restore AF
IF    NOSIM
        ei
        reti
ELSE
        ei
        ret
ENDIF
write:                          ;it's a write
        ld      a,(CON_Count)   ;A=counter
        or      a               ;is zero?
        jr      z,endwrite
                                ;no, continue writing
        dec     a               ;first, decrement counter
        ld      (CON_Count),a
        push    hl              ;save also HL
                                ;then write next char
        ld      hl,(CON_Buf)    ;get next char
        ld      a,(hl)
        inc     hl              ;increment pointer
        ld      (CON_Buf),hl
IF    NOSIM
        out     (SIO_A_D),a     ;write-it
ELSE
        out     (1),a
ENDIF
        pop     hl              ;restore AF,HL
        pop     af
IF    NOSIM
        ei
        reti
ELSE
        ei
        ret
ENDIF
endwrite:                       ;no more chars to write
IF    NOSIM
        ld      a,00101000B     ;RR0 Reset Transmitter Interrupt Pending
        out     (SIO_A_C),a
ENDIF
        push    hl              ;prepare stack
        push    de
        push    bc
        push    ix
        push    iy
	xor     a
        ld      (CON_CrtIO),a   ;set IO_IDLE
        ld      hl,CON_IO_Wait_Sem
        call    QuickSignal     ;Signal local I/O completion
IF    NOSIM
        jp      _ReschINT       ;then reschedule
ELSE
        jp      _Reschedule
ENDIF
;
;       SIO_A receive character available
;
_CON_RX:
IF    SIM
        di
ENDIF
        push    af              ;save AF
IF    SIM
        in      a,(0)
        or      a               ;char available?
        jr      nz,1f
        pop     af		;no, just return
        ei
        ret
1:
ENDIF
        ld      a,(CON_CrtIO)   ;check current I/O OpCode
IF	IO_COMM
	cp	IO_RAW_READ	
	jp	z,rawrd		;it's IO_RAW_READ
ENDIF
	cp	IO_READ
	jr	z,read		;it's IO_READ
	cp	IO_WRITE
	jp	nz,idleorw	;it's IO_IDLE or IO_RAW_WRITE
				;it's IO_WRITE, ignore char
IF    NOSIM
        in      a,(SIO_A_D)     ;get A=char
ELSE
        in      a,(1)           ;get A=char
ENDIF
	cp	CTRL_C
	jp	nz,retrxa
	ld	a,1
	ld	(CTRL_C_flag),a	;set CTRL_C flag
	jp	retrxa		;return from int
;										IO_READ
read:                         	;it's a read
IF    NOSIM
        in      a,(SIO_A_D)     ;get A=char
ELSE
        in      a,(1)           ;get A=char
ENDIF
        push    hl              ;save HL
	cp	ENTER
	jr	nz,noCR
                                ;terminate read if ENTER
        xor     a               ;force read end
        jr      storecnt
noCR:
	ld	hl,ReadCnt	;set HL=pointer of nr. of read chars
IF	SIM
	cp	DELETE
ELSE
	cp	BACKSPACE
ENDIF
	jr	z,backspace
	cp	BLANK
	jr	c,retrxh	;ignore all "special" chars
				;echo back char
	inc	(hl)		;increment nr. of read chars
IF    NOSIM
        out     (SIO_A_D),a     ;echo back char
ELSE
        out     (1),a
ENDIF
                                ;store A=char
        ld      hl,(CON_Buf)
        ld      (hl),a
        inc     hl              ;increment pointer
        ld      (CON_Buf),hl
        ld      a,(CON_Count)   ;A=counter
        dec     a               ;decrement counter
storecnt:
        ld      (CON_Count),a
        jr      z,endread	;if zero, read is ended
retrxh:
	pop     hl              ;restore HL
retrxa:
        pop     af              ;restore AF
IF    NOSIM
        ei
        reti
ELSE
        ei
        ret
ENDIF
endread:
        ld      hl,(CON_Buf)
        ld      (hl),a          ;store a zero at the buffer end
        push    de
        push    bc
        push    ix
        push    iy
	xor     a
        ld      (CON_CrtIO),a   ;set IO_IDLE
        ld      hl,CON_IO_Wait_Sem
        call    QuickSignal     ;Signal local I/O completion
IF    NOSIM
        jp      _ReschINT       ;then reschedule
ELSE
        jp      _Reschedule
ENDIF
backspace:			;it's a BACKSPACE
	ld	a,(hl)		;check nr. of chars read
	or	a
	jr	z,retrxh	;if it's the first char, ignore-it
				;it's not the first char
	dec	(hl)		;decrement nr. of chars read
	inc	hl		;HL=EchoStatus pointer
	ld	a,1
	ld	(hl),a		;prepare for echo
	ld	hl,(CON_Buf)
	dec	hl		;decrement pointer
	ld	(CON_Buf),hl
	ld	hl,CON_Count
	inc	(hl)		;increment counter
	ld	a,BACKSPACE
IF    NOSIM
        out     (SIO_A_D),a     ;echo back BACKSPACE
ELSE
        out     (1),a
ENDIF
	jr	retrxh
;-------------------------------------------------------------------------------IO_COMM
IF	IO_COMM
;										IO_RAW_READ
rawrd:  			;it's a raw read
IF    NOSIM
        in      a,(SIO_A_D)     ;get A=char
ELSE
        in      a,(1)           ;get A=char
ENDIF
        push    hl              ;save HL
	push	de		;save DE
	push	bc		;save BC
	ld	de,(SIO_WP)	;DE=SIO buf write pointer
	ld	hl,(SIO_RP)	;HL=SIO buf read pointer
	ld	bc,(CON_Buf)	;BC=user buf pointer
        ld      (de),a		;store char to SIO buf
        inc     e               ;increment pointer in buf
rlp:				;check if other char available
IF	NOSIM
        in      a,(SIO_A_C)     ;read RR0
        rrca                    ;char available?
        jr     	nc,noch       	;no, continue loop
        in      a,(SIO_A_D)     ;yes, read char
ELSE
        in      a,(0)
        or      a               ;char available?
        jr	z,noch		;no, continue loop
        in      a,(1)           ;yes, read char
ENDIF
	ld	(de),a		;store char in SIO buffer
	inc	e		;increment write pointer
noch:
        ld      a,(hl)          ;get A=next char from SIO receive buffer
        inc     l               ;increment read pointer
        ld      (bc),a		;store char to user buffer
        inc     bc              ;increment pointer in buf
        ld	a,(CON_Count)	;decrement counter of NOT read bytes
        dec     a
	ld	(CON_Count),a
	jr	z,endrr
				;read op not ended
        ld      a,e		;A=low write pointer
  	cp      l               ;equal to L=low read pointer?
        jr      nz,rlp          ;if not zero, try to continue reading from SIO receive buffer
				;SIO buf empty
	ld	(SIO_WP),a	;save write pointer
	ld	(SIO_RP),a	;save read pointer
	ld	(CON_Buf),bc
	pop	bc
	pop	de
	pop     hl
        pop     af
IF    NOSIM
        ei
        reti
ELSE
        ei
        ret
ENDIF
endrr:				;read ended
	ld	(SIO_WP),de	;save write pointer
	ld	(SIO_RP),hl	;save read pointer
        push    ix
        push    iy
        ld      hl,(CON_Tim)    ;stop the timer
        call    ___StopTimer
	xor     a
        ld      (CON_CrtIO),a   ;set IO_IDLE
	ld	(CON_CountS),a	;set counter=0
        ld      hl,CON_IO_Wait_Sem
        call    QuickSignal     ;Signal local I/O completion
IF    NOSIM
        jp      _ReschINT       ;then reschedule
ELSE
        jp      _Reschedule
ENDIF

ENDIF
;-------------------------------------------------------------------------------IO_COMM
;										IO_IDLE or IO_RAW_WRITE
idleorw:
	or	a		;is it IO_IDLE ?
IF    NOSIM
        in      a,(SIO_A_D)     ;get A=char
ELSE
        in      a,(1)           ;get A=char
ENDIF
	jr	nz,1f	
				;if IO_IDLE, check for CTRL_C
	cp	CTRL_C
	jr	nz,1f
	ld	a,1		;set CTRL_C flag
	ld	(CTRL_C_flag),a
1:				;it's idle or raw write, try to store char to SIO receive buffer
	push	hl		;save HL
        ld      hl,(SIO_WP)     ;get write pointer
ilp:
        ld      (hl),a          ;store char
        inc     l               ;increment pointer
        ld      (SIO_WP),hl     ;save back pointer
				;check if another char ready
IF    NOSIM
        in      a,(SIO_A_C)     ;RR0
        rrca
        jp      nc,retrxh       ;no, return from int
ELSE
        in      a,(0)
        or      a               ;char available?
        jp      z,retrxh        ;no, return from int
ENDIF
	jr	ilp		;keep looping
;
;                                               			NOSIM
IF    NOSIM
;
;       SIO_A external/status change
;
_CON_ESC:
        push    af
        in      a,(SIO_A_C)     ;A read RR0
        ld      (RR0),a         ;store-it for reference
        ld      a,00010000B     ;A WR0 pointer R0 + reset external/status interrupts
        out     (SIO_A_C),a
IF DIG_IO
        OUT_LEDS ERR_ESC
ENDIF
        pop     af
        ei
        reti
;
;       SIO_A special receive condition
;
_CON_SRC:
        push    af
        ld      a,00000001B     ;A WR0 pointer R1
        out     (SIO_A_C),a
        in      a,(SIO_A_C)     ;A read RR1
        ld      (RR1),a         ;store-it for reference
        and     01110000B       ;Framing,Receiver overrun or Parity err?
        jr      z,1f
        in      a,(SIO_A_D)     ;remove errored Rx byte
1:      ld      a,00110000B     ;WR0 error reset
        out     (SIO_A_C),a
IF DIG_IO
        OUT_LEDS ERR_SRC
ENDIF
	pop     af
        ei
        reti
;
ENDIF
;                                               			NOSIM

;-------------------------------------------------------------------------------SIO_RING
IF	SIO_RING

;       GetSIOChars
;
;       called under interrupts DISABLED
;       If current I/O opcode is IO_IDLE or IO_RAW_READ or IO_RAW_WRITE 
;	and chars are available,
;       store them in the SIO receive buffer
;       AF,HL affected
;
GetSIOChars:
        ld      a,(CON_CrtIO)   ;check current I/O OpCode
        and     IO_READ+IO_WRITE
        ret     nz      	;if IO_READ or IO_WRITE, ignore
loopget:
        in      a,(SIO_A_C)     ;read RR0
        rrca                    ;char available?
        ret     nc              ;no, quit loop and return
        in      a,(SIO_A_D)     ;yes, read char
				;store in SIO receive buffer
        ld      hl,(SIO_WP)     ;get write pointer (multiple of 100H)
        ld      (hl),a          ;save char
        inc     l               ;increment pointer
        ld      (SIO_WP),hl     ;save back pointer
        jr      loopget

ENDIF
;-------------------------------------------------------------------------------SIO_RING
