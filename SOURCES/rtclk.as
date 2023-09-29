;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
TITLE       Real Time Clock support routines
;
*Include config.mac
*Include leds.mac
;
;       Real Time Clock Control Block structure (10 bytes)
;
;  struct ListElement link;
;  short Counter;
;  struct Semaphore* pSem;
;  short CounterCopy;			0=NO Repeat
;
OFF_CNT         equ     4
OFF_PSEM        equ     6
OFF_CNTCOPY	equ	8
;
        psect   bss
;
IF	PS2
;
	GLOBAL	PS2Tbl, PS2_WP, PS2_RP, fPS2Rel, fShift, fCtrl, fCapLock, fPS2Buf, fNumKey
;
fPS2Rel:	defs 1		;flag indicates PS2 key released
fShift: 	defs 1		;flag for PS2 SHIFT key
fCtrl:  	defs 1		;flag for PS2 CTRL key
fCapLock:       defs 1		;flag for PS2 CapLock key
bPS2:   	defs 1		;PS2 keyboard input buffer
fPS2Buf:        defs 1		;flag for PS2 keyboard buffer, 0=no data, 1= data present
fNumKey:        defs 1		;flag for Num Keypad
;
PS2_RP:		defs	2
PS2_WP:		defs	2
;
ENDIF
;
LastActiveTCB:  defs	2
TicsCount:      defs    1
;
Signals:	defs	1		;1 if Signals done, 0 else
;
;       Order is critical - do not change-it
;
Counter:        defs    4               ;incremented at each 5ms
SecondCnt:      defs	1               ;1 second = 200 * 5ms
RoundRobin:     defs    1		;1 if YES, 0 if NO
;
PRI_OFF         EQU     6       ;relative offset of Priority in TCB

	psect	text

	GLOBAL Counter
	GLOBAL	RET_NULL,EI_RET_NULL,RET_FFFF,EI_RET_FFFF
IF	SIO_RING
	GLOBAL GetSIOChars
ENDIF
	GLOBAL LastActiveTCB,TicsCount,Counter,SecondCnt,RoundRobin
        GLOBAL RETI_RETURN
        GLOBAL _ReschINT
	GLOBAL _Reschedule
IF    DIG_IO
        GLOBAL  TestFreeMem
ENDIF
	GLOBAL	__Balloc
	GLOBAL	__Bdealloc
        GLOBAL  RTC_Header
IF	C_LANG
	GLOBAL _RoundRobinON
	GLOBAL _RoundRobinOFF
	GLOBAL _GetTimerSts
	GLOBAL _MakeTimer
	GLOBAL _DropTimer
        GLOBAL _StartTimer
        GLOBAL _StopTimer
        GLOBAL _GetTicks
ENDIF
	GLOBAL __RoundRobinON
	GLOBAL __RoundRobinOFF
	GLOBAL __GetTimerSts
	GLOBAL __MakeTimer
	GLOBAL __DropTimer
        GLOBAL __StartTimer
        GLOBAL __StopTimer,___StopTimer
        GLOBAL __AddToL
        GLOBAL __FirstFromL
        GLOBAL __NextFromL
        GLOBAL __RemoveFromL
        GLOBAL __RotateL
        GLOBAL __IsInL
        GLOBAL _TasksH
        GLOBAL QuickSignal
        GLOBAL _Reschedule
        GLOBAL _RTC_Int
        GLOBAL _RunningTask
        GLOBAL __GetTicks
	GLOBAL __StopTaskTimer
IF	DEBUG
	GLOBAL	IsItSem
ENDIF
IF	SYSSTS
NXPV_OFF	equ	16	;(NextTask,PrevTask)
	GLOBAL	CountTicks
	GLOBAL	__StartSampling, __StopSampling
IF	C_LANG
	GLOBAL	_StartSampling, _StopSampling
ENDIF
ENDIF
;IF    NOSIM 
;IF	1-M512
;        GLOBAL Snapshot
;ENDIF
;ENDIF

IF	SYSSTS
;
;	Start sampling
;
IF	C_LANG
;
;void	StartSampling(void);
;
_StartSampling:
ENDIF
;
__StartSampling:
	ld	a,1			;start/resume counting
	ld	(CountTicks),a
					;set TicksCount=0 for each task
	ld	hl,AllTasksH
	call	__FirstFromL
1:
	push	hl
	ld	bc,TICS_OFF - NXPV_OFF
	add	hl,bc
	xor	a
	ld	(hl),a
	inc	hl
	ld	(hl),a
	inc	hl
	ld	(hl),a
	inc	hl
	ld	(hl),a
	pop	hl
	ld	de,AllTasksH
	call	__NextFromL
	jr	nz,1b
	ret
;	
;
;	Stop sampling
;
IF	C_LANG
;
;void	StopSampling(void);
;
_StopSampling:
ENDIF
;
__StopSampling:
	xor	a			;stop counting
	ld	(CountTicks),a
	ret
;	
ENDIF
;
;	Set/reset round robin
;
_RoundRobinON:
__RoundRobinON:
	ld	a,1
	ld	(RoundRobin),a
	ret
;
_RoundRobinOFF:
__RoundRobinOFF:
	PUSH_REGS
	di
	xor	a
	ld	(RoundRobin),a
	jp	_Reschedule
;
;       Get Ticks
;
;       return (DE=low,HL=high)=Ticks
;
IF	C_LANG
_GetTicks:
ENDIF
__GetTicks:
        ld      de,(Counter)
	ld	hl,(Counter+2)
        ret
IF	C_LANG
;
;	Make Timer
;
;void* MakeTimer(void);
;	returns HL=0 if alloc fails, else HL=timer
;	AF,BC,DE,HL,IX,IY not affected
;
_MakeTimer:
	push	af
	push	bc
	push	de
	call	__MakeTimer
	pop	de
	pop	bc
	pop     af
        ret
ENDIF
;
;	Make Timer - internal
;	
;	returns Z=0 & HL=Timer or Z=1 & HL=NULL if alloc fails
;	A,BC,DE,HL affected
;
__MakeTimer:
	ld	c,0			;alloc 10H
	di
	call	__Balloc
	ei
	ret	z			;return HL=0 if alloc fails
	ld	a,B_H_SIZE
	add	a,l
	ld	l,a			;HL=Timer		
	ret
;
IF	C_LANG
;
;	Drop Timer
;short  DropTimer(RTClkCB* Timer);
;
;	returns HL=0 if Timer is active, else HL=not NULL
;	AF,BC,DE,HL,IX,IY not affected
;
D_T	equ	8
;
_DropTimer:
	push	af
	push	bc
	push	de
	ld	hl,D_T
	add	hl,sp			;stack=DE,BC,AF,retaddr,Timer
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a			;HL=Timer
	call	__DropTimer
	pop	de
	pop	bc
        pop     af
        ret
;
;	GetTimer Status
;short	GetTimerSts(void* Timer);
;	returns HL=-1 : no timer, else HL=ticks counter
;
_GetTimerSts:
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
ENDIF
__GetTimerSts:			;HL=Timer
	di
IF	DEBUG
	push	hl
        ld      b,h
        ld      c,l             ;BC=Timer
        ld      hl,RTC_Header   ;HL=list header
        call    __IsInL
	pop     hl
	jp	nz,EI_RET_FFFF
ENDIF
	ld	a,4
	add	a,l
	ld	l,a		;HL=pointer of ticks counter
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a
	ei
	ret			;return HL=Ticks counter
;
;	DropTimer - internal
;
;	HL = Timer
;	returns HL=0 if Timer is active, else HL=not NULL
;	deallocates timer
;
__DropTimer:
	di
;------------------------------------------------------------------DEBUG
IF    DEBUG
	push	bc
	push	de
	push	hl
        ld      b,h
        ld      c,l             ;BC=Timer
        ld      hl,RTC_Header   ;HL=list header
        call    __IsInL
	pop     hl
        pop     de
	pop	bc
	jp	z,EI_RET_NULL	;it is in the list, must be stopped before dropping
	ld	c,0			;10H
ENDIF
;------------------------------------------------------------------DEBUG
	ld	a,l
	sub	B_H_SIZE
	ld	l,a			;HL=10H block to deallocate

	call	__Bdealloc		;deallocate-it
	ei
	ret
;
IF	C_LANG
;
;	Start Timer
;
;void*  StartTimer(RTClkCB* Timer, struct Semaphore* pSem, short Ticks, char Repeat);
;       return HL=0 if Timer already started, else HL=Timer
;	AF,BC,DE,HL,IX,IY not affected
;
InRep	equ	14
;
_StartTimer:
	push	af
	push	bc
	push	de
	ld	hl,InRep
	add	hl,sp			;stack=DE,BC,AF,retaddr,Timer,pSem,Ticks,Repeat
	ld	a,(hl)			;A=Repeat
	push	af			;on stack
	dec	hl
	ld	b,(hl)
	dec	hl
	ld	c,(hl)			;BC=Ticks
	dec	hl
	ld	d,(hl)
	dec	hl
	ld	e,(hl)			;DE=pSem
	dec	hl
	ld	a,(hl)
	dec	hl
	ld	l,(hl)
	ld	h,a			;HL=Timer
	pop	af			;A=Repeat
	call	__StartTimer
	pop	de
	pop	bc
	pop     af
        ret
ENDIF
;
;       Start Timer - internal
;
;       HL = Timer, DE=Sem, BC=Ticks, A=Repeat (0=NO)
;       return HL=0 if Timer already started, else HL=Timer
;
__StartTimer:
	push	af
	di
;------------------------------------------------------------------DEBUG
IF    DEBUG
	push	bc
	push	de
	push	hl
        ld      b,h
        ld      c,l             ;BC=Timer
        ld      hl,RTC_Header   ;HL=list header
        call    __IsInL
	pop     hl
        pop     de
	pop	bc
        jr      nz,1f
        ei                      ;it is already in the list
	pop	af
        ld      hl,0
        ret
1:
ENDIF
;------------------------------------------------------------------DEBUG
        ld      a,OFF_CNT
	add	a,l
	ld	l,a		;HL=pointer to RTClkCB Counter
        ld      (hl),c
        inc     l
        ld      (hl),b          ;Counter saved
        inc     l               ;HL=pointer to RTClkCB pSem
        ld      (hl),e
        inc     l
        ld      (hl),d          ;pSem Saved
	inc	l
	pop	af		;A=Repeat flag
	or	a		;repeat?
	jr	nz,2f		;yes, save Counter in CounterCopy
	ld	b,a
	ld	c,a		;no, set CounterCopy=0
2:	ld	(hl),c		
	inc	l
	ld	(hl),b
	ld	a,l
	sub	OFF_CNTCOPY+1
	ld	l,a		;HL=Timer
	ex	de,hl		;DE=Timer
IF	SIO_RING
	call	GetSIOChars
ENDIF
        ld      hl,RTC_Header   ;HL=list header
IF    RSTS
        RST     24
ELSE
        call    __AddToL        ;Add to HL=list header, new elem=DE
ENDIF
        ei
	ret			;HL=RTClkCB

IF	C_LANG
;
;       Stop Timer
;
;short StopTimer(struct RTClkCB* Timer);
;       return HL=0 if Timer not started, else not null
;       AF,BC,DE,HL,IX,IY not affected
;
StpTimer        equ     8
;
_StopTimer:
        push    af
	push	bc
	push	de
        ld      hl,StpTimer
        add     hl,sp           ;IX=SP,stack=DE,BC,AF,retaddr,Timer
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=RTClkCB
	di
        call    __StopTimer
	ei
	pop	de
	pop	bc
        pop     af
        ret
ENDIF
;
;       Stop Timer - internal
;
;       HL = Timer
;
__StopTimer:
;------------------------------------------------------------------DEBUG
IF    DEBUG
	push	bc
	push	de
	push	hl
	ld	a,OFF_PSEM
	add	a,l
	ld	l,a
	ld	e,(hl)
	inc	l
	ld	d,(hl)
	ex	de,hl
	di
	call	IsItSem
	ei
	pop     hl
        pop     de
	pop	bc
	jp	nz,RET_NULL
ENDIF
;------------------------------------------------------------------DEBUG
                                ;check if started
        push    hl
        ld      b,h
        ld      c,l             ;BC=Timer
        ld      hl,RTC_Header   ;HL=list header
        di
	call    __IsInL
        pop     hl
	jp	nz,EI_RET_NULL	;it is not started
	call	___StopTimer
	ei
	ret
;
;	called under DISABLED interrupts
;
___StopTimer:
IF    RSTS
        RST     32
ELSE
        call    __RemoveFromL
ENDIF
IF	SIO_RING
	jp	GetSIOChars
ELSE
	ret
ENDIF
;
;	Stop Task's Timers
;
;	called under disabled interrupts
;	C=Task ID
;
__StopTaskTimer:
        ld      hl,RTC_Header   ;HL=List header
IF	NORSTS
	call	__FirstFromL
ELSE
	RST	0
ENDIF
        ret     z
loopstp:
        push    hl              ;HL=crt RTClkCB on stack
        ld      de,RTC_Header   ;DE=List header
IF    RSTS
        RST     16
ELSE
        call    __NextFromL     ;get next from list
ENDIF
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
                                ;HL=next RTClkCB
        ex      (sp),hl         ;HL=crt RTClkCB, next RTClkCB on stack
	dec	l
	dec	l		;HL=pointer of block owner
	ld	a,c		;block ID == TaskID ?
	cp	(hl)
	jr	nz,nextstp
	inc	l		;yes, remove-it
	inc	l
	push	bc
IF    RSTS
        RST     32
ELSE
        call    __RemoveFromL   ;remove crt RTClkCB
ENDIF
	pop	bc 
IF	SIO_RING
	call	GetSIOChars
ENDIF
nextstp:
	pop     hl              ;HL=next RTClkCB
        ld      a,l
        or      h               ;if not NULL
        jr      nz,loopstp      ;keep looping...
	ret
;
;       Real Time Clock Hardware Interrupt
;
_RTC_Int:
        push    af              ;save regs
        push    hl
        push    de
        push    bc
;
IF	SIM
;
        in      a,(0)
        or      a               ;char available?
        jr	z,nochar	;no, continue 
        in      a,(1)           ;yes, read char
	ld	hl,(SIO_WP)	;and store-it in the SIO ring
	ld	(hl),a
	inc	l
	ld	(SIO_WP),hl
nochar:
;
ENDIF
;
IF	PS2
;
	call	constPS2
	or	a		;key hit?
	jr	z,skip
	call	cinPS2		;yes, read-it
	ld	hl,(PS2_WP)	;and store-it
	ld	(hl),a
	inc	l
	ld	(PS2_WP),hl
skip:
;
ENDIF
;
IF	SYSSTS
	ld	a,(CountTicks)	;if sampling active...
	or	a
	jr	z,1f
	AddTick			;increment ticks count for the running task
1:
ENDIF
;
        xor	a               ;Init Signals marker
	ld	(Signals),a	;0 = no Signals ! 
IF	SIO_RING
	call	GetSIOChars
ENDIF
        ld      hl,Counter      ;increment 32bits ticks counter
				;byte 1
        inc     (hl)
        inc     hl
IF	DIG_IO
        jr      nz,1f
ELSE
	jr	nz,timers
ENDIF
				;byte 2
	inc	(hl)
	inc	hl
IF	DIG_IO
        jr      nz,2f
ELSE
	jr	nz,timers
ENDIF
				;byte 3
	inc	(hl)
	inc	hl
IF	DIG_IO
        jr      nz,3f
ELSE
	jr	nz,timers
ENDIF
				;byte 4
	inc	(hl)
IF	DIG_IO
	inc	hl
        jr      4f
ENDIF
;---------------------------------------------------------------------------DIG_IO
IF    DIG_IO
1:	inc	hl
2:	inc	hl
3:	inc	hl
4:        		        ;HL=pointer of SecondCnt
        dec     (hl)            ;decrement "second" counter
        jp      nz,timers
                                ;1 Second tick, toggle "clock" led
        TOGGLE_LEDS     CLOCK

        ld      (hl),TICS_PER_SEC ;load back "second" counter

;-----------------------------------------------------------DEBUG
;IF    DEBUG 
;IF	TRIGGERS
;                                ;and test triggers...
;        TEST_TRIGGER    ROUNDROBIN
;        jr      z,1f
;                                ;set RoundRobin ON
;        inc     hl              ;HL=pointer of RoundRobin
;        ld      (hl),1
;        jr      timers
;1:
;        TEST_TRIGGER    SHUTDOWN
;        jp      nz,RETI_RETURN  ;shutdown if requested;
;
;        TEST_TRIGGER    TESTFREEMEM
;        jr      z,timers
;                                ;test free dynamic memory available
;        call    TestFreeMem     ;(Z=0 and B=bSize) or Z=1
;        jr      nz,3f
;        OUT_LEDS        ERR_STACK;no more free mem, display 1 on LED b2
;        jr      timers
;3:                              ;display largest free block size on LEDs b7-4
;        sla     b
;        sla     b
;        sla     b
;        sla     b               ;bSize on b7-4
;        set     0,b             ;add RTM/Z80 running
;        SET_LEDS        b       ;display on LEDs b7-4
;ENDIF
;ENDIF
;-----------------------------------------------------------DEBUG
;-----------------------------------------------------------NOSIM
;IF    NOSIM
;IF	TRIGGERS 
;IF	1-M512
;        TEST_TRIGGER    SNAPSHOT
;        jr      z,timers
;                                ;takes a snapshot
;        call    Snapshot        ;move all LOW_RAM to UP_RAM
;        jp      RETI_RETURN     ;and shutdown
;ENDIF
;ENDIF
;ENDIF
;-----------------------------------------------------------NOSIM
ENDIF
;---------------------------------------------------------------------------DIG_IO
timers:
IF	SIO_RING
	call	GetSIOChars
ENDIF
				;process Timer requests
        ld      hl,RTC_Header   ;HL=List header
IF	NORSTS
	call	__FirstFromL
ELSE
	RST	0
ENDIF
				;HL=first RTClkCB
        jr      z,roundrobin
loop:                           ;HL=crt RTClkCB
                                ;not null...
        push    hl              ;HL=crt RTClkCB on stack
        ld      de,RTC_Header   ;DE=List header
IF    RSTS
        RST     16
ELSE
        call    __NextFromL     ;get next from list
ENDIF
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
                                ;HL=next RTClkCB
        ex      (sp),hl         ;HL=crt RTClkCB, next RTClkCB on stack
        ld	a,OFF_CNT
	add	a,l
	ld	l,a             ;HL=pointer to crt RTClkCB counter
                                ;decrement counter
	ld	c,(hl)
	inc	l
	ld	b,(hl)
	dec	bc
	ld	(hl),b
	dec	l
	ld	(hl),c
	ld	a,b
	or	c		;counter == ZERO ?
        jr      nz,next
      			        ;yes
	inc	l
        inc     l               ;HL=pointer to crt RTClkCB pSemaphore
        ld      a,(hl)
        inc     l
        push    hl              ;HL=pointer to crt RTClkCB pSemaphore+1, on stack
        ld      h,(hl)
        ld      l,a             ;HL=pSem
        call    QuickSignal     ;Signal sem
	jr	z,1f
IF	SIO_RING
	call	GetSIOChars
ENDIF
	ld	a,1
	ld	(Signals),a	; 1 : Signals were done!
1:      pop     hl              ;HL=pointer to crt RTClkCB pSemaphore+1
	inc	l		;HL=pointer to CounterCopy
	ld	c,(hl)
	inc	l
	ld	b,(hl)		;BC=CounterCopy
	ld	a,l
	sub	OFF_CNTCOPY+1-OFF_CNT
	ld	l,a		;HL=pointer to Counter
	ld	(hl),c		;restore counter from copy
	inc	l
	ld	(hl),b
	ld	a,b		;check CounterCopy
	or	c		;zero? (no repeat)
	jr	nz,next		;no, go to next
        ld      a,l		;yes, remove crt from list
	sub	OFF_CNT+1
        ld	l,a             ;HL=crt RTClkCB
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
IF    RSTS
        RST     32
ELSE
        call    __RemoveFromL   ;remove crt RTClkCB
ENDIF
next:   
IF	SIO_RING
	call	GetSIOChars
ENDIF
	pop     hl              ;HL=next RTClkCB
        ld      a,l
        or      h               ;if not NULL
        jr      nz,loop         ;keep looping...
                                ;no (more) elements in list, CARRY=0
roundrobin:                     ;RoundRobin algorithm follows...
        ld      hl,RoundRobin   ;is RoundRobin allowed?
        bit     0,(hl)
        ld      l,0             ;initialize "round-robin move"=not done
        jr      z,check
                                ;yes, prepare round robin data
        ld      hl,(LastActiveTCB)
                                ;HL=TCB of last active task
                                ;refresh last active task
        ld      de,(_RunningTask)
        ld      (LastActiveTCB),de
                                ;DE=TCB of current active task
                                ;CARRY=0
        sbc     hl,de
        ex      de,hl           ;HL=TCB of current active task
        jr      z,3f
        ld      a,PRI_OFF       ;Last active task changed...
        add     a,l
	ld	l,a
        ld      a,(hl)          ;A=priority of the current active task
        ld      (TicsCount),a   ;set tics count = new task priority
3:
        ld      hl,TicsCount
        dec     (hl)            ;Decrement tics count
        ld      l,0             ;L=0 (no round-robin move done)
        jr      nz,check
                                ;TicsCount=0, try to rotate active task list
IF	SIO_RING
	call	GetSIOChars
ENDIF
        ld      hl,_TasksH      ;HL=active tasks list header
        call    __RotateL       ;L=1 if round-robin move done, else 0
check:
	ld	a,(Signals)
        or      l               ;Signals or round-robin move done ?
        jr      z,return
	push    ix
        push    iy
			;then regs'
	ex	af,af'
	exx
	push	af
	push	hl
	push	de
	push	bc
	exx
	ex	af,af'

        jp      _ReschINT       ;if Signals were made or round-robin move done
return:                         ;else, just return
        pop     bc              ;restore regs
        pop     de
        pop     hl
        pop     af
        ei
        reti
;
IF	PS2
;
;---------------------------------------------------------
;	Adapted from an original code written by Bill Shen
;---------------------------------------------------------

;----------------------------------------------------------------------------------------------------
;
constPS2:
				;fPS2Buf may already be set in CONST routine, 
				;but not yet processed in CONIN routine
				;release code (0xf0) and following character are not considered
				; as valid console input EXCEPT release code of Num Keypad.
        ld 	a,(fPS2Buf)	;first check data in keyboard buffer (set previously in CONST)
        and 	1
        jp 	nz,gotDat	;not necessary to process data for release code (0xF0)
				;this is because routine that set fPS2Buf already processed released code
        in 	a,(PS2Stat)	;read keyboard status
        and 	1
        ret 	z		; return with 0 if data not available
				;try another approach by creating a PS2keyboard buffer and an associated flag
				;put valid data in bPS2 and set fPS2Buf
				;expect receive routine to check fPS2Buf first to see if here are data
        ld 	a,(fPS2Rel)	;check key release flag; ignore data if flag set
				; EXCEPT when fNumKey is set
        bit 	0,a
        jr 	z,chkPS2Rel
        ld 	a,(fNumKey)	;release flag set, now check NumKey flag to decide to ignore
                        	; the next data or not
        bit 	0,a
        jr 	nz,NumKeyRelease;branch if this is data following NumKey release
				; else this is data following release code, clear release flag, check data for
				;  control, shift key release and return with Z flag set (no valid data)
        xor 	a
        ld 	(fPS2Rel),a	;clear key release flag
        push 	hl
        ld 	hl,PS2Tbl	;check for release of Shift, Caplock or Ctrl keys
        in 	a,(PS2Data)	;process data following the release code
        or 	l		;combine with index
        ld 	l,a
        ld 	a,(hl)		;get scancode
        cp 	0e1h		;Shift key released?
        jr 	nz,chkRelCtl
        xor 	a
        ld 	(fShift),a	;clear Shift flag
        jr 	ReleaseDone
chkRelCtl:
        cp 	0e2h		;Ctrl key released?
        jr 	nz,ReleaseDone
        xor 	a
        ld 	(fCtrl),a	;clear Ctrl flag
ReleaseDone:
        pop 	hl
        xor 	a		; return with 0
        ret
NumKeyRelease:
				;data following will be flag as valid data and eventually output
				; as 0x4 to mark the end of NumKeypad input
				;if release code flag, NumKey flag, and PS2Buf flag all asserted,
				;  then the release of NumKeypad input (CONIN sents 0x4 to calling application)
        ld 	a,1
        ld 	(fPS2Buf),a	;set valid data
        in 	a,(PS2Data)	;get PS2 data and store it
        ld 	(bPS2),a
        or 	a		;data is non-zero, so this will clear Z flag
        ret
chkPS2Rel:
				;check PS2 status for data; if not release, store data and set flag
        in 	a,(PS2Data)
        cp 	0f0h		;Is this key release?
        jp 	nz,chkSecondary	;if not release code check secondary keys (shift/ctrl/alt...)
				;if release code, ignore current data and next data
        ld 	a,1
        ld 	(fPS2Rel),a	;set the key release flag
        xor 	a           	;return with 0x0
        ld 	(fPS2Buf),a  	;clear flag for PS2 data buffer
        ret
chkSecondary:
				;The high nibble of secondary keys is $E in PS2 scan code table
        ld 	(bPS2),a	;save data, but don't set flag yet
        push 	hl
        ld 	hl,PS2Tbl
        or 	l		;PS2Tbl is page aligned so l is always 0x0
                        	;index into the PS2Tbl
        ld 	l,a		;hl is now points to the key entered
        ld 	a,(hl)		;get PS2 scan code from table
        pop 	hl
        cp 	0e1h		;check shift key
        jr 	nz,chkCtrl
				;set shift key flag
        ld 	a,1
        ld 	(fShift),a	;set shfit flag
        jr 	DoneSecKey
chkCtrl:			;check control key
        cp 	0e2h
        jr 	nz,chkCapLock
				;set CTRL flag
        ld 	a,1
        ld 	(fCtrl),a
        jr 	DoneSecKey
chkCapLock:			;check cap lock key
        cp 	0e4h
        jr 	nz,chkOtherSec
				;complement the cap lock flag
        ld 	a,(fCapLock)
        xor 	1
        ld 	(fCapLock),a
        jr 	DoneSecKey
chkOtherSec:			;ignore other secondary keys
        and 	0f0h		;look at the high nibble
        cp 	0e0h
        jr 	nz,gotDat1	;have real data to process
				;ignore other secondary keys
DoneSecKey:
        xor 	a		;return with 0
        ret
gotDat1:
        ld 	a,1		;set flag for PS2 data available
        ld 	(fPS2Buf),a
gotDat:
        or 	0ffh		; data available, return with 0ffh
        ret
;
;----------------------------------------------------------------------------------------------------
;
cinPS2:
        ld 	a,(fPS2Buf)	;first check if data available in buffer
        and 	1
        jr 	z,chkPS2Stat	;if flag not set, skip to check PS2 status reg
        xor 	a
        ld 	(fPS2Buf),a	;clear the flag
        jr 	prcPS2Data	;process PS2 data
chkPS2Stat:
        in 	a,(PS2Stat)	;read keyboard status
        and 	1
        jr 	z,cinPS2
        in 	a,(PS2Data)	;read in PS2 data and store in buffer
        ld 	(bPS2),a
				;process PS2 keyboard input that's in the keyboard buffer
				;first check the release flag, if set, clear the flag, 
				;then check whether it is shift/ctrl/caplock release.
				;If not shift/ctrl/caplock release, ignore the incoming data
				;special case is if release code flag and NumKey flag asserted,
				;then it is the release of NumKeypad input 
				;(CONIN sents 0x4 to calling application)
prcPS2Data:
        ld 	a,(fPS2Rel)	;check key release flag
        bit 	0,a
        jr 	z,PS2qa
				;check for release of NumKeypad input
        ld 	a,(fNumKey)
        bit 	0,a
        jr 	z,releaseNorm	;branch to normal release code processing
				;special case for release of NumKeypad input
				;  sents 0x4 to calling application
        xor 	a
        ld 	(fPS2Buf),a	;clear data buffer
        ld 	(fNumKey),a	;end of NumKeypad input
        ld 	(fPS2Rel),a
        inc 	a		;clear Z flag
        ld 	a,4		;return with 0x4
        ret
releaseNorm:
        xor 	a
        ld 	(fPS2Rel),a	;clear key release flag
        push 	hl
        ld 	hl,PS2Tbl	;check for release of Shift, Caplock or Ctrl keys
        ld 	a,(bPS2)	;get the release key code from the keyboard buffer
        or 	l		;combine with index
        ld 	l,a
        ld 	a,(hl)		;get scancode
        cp 	0e1h		;Shift key released?
        jr 	nz,Release2
        xor 	a
        ld 	(fShift),a	;clear Shift flag
        jp 	Release9
Release2:
        cp 	0e2h		;Ctrl key released?
        jr 	nz,Release9
        xor 	a
        ld 	(fCtrl),a	;clear Ctrl flag
Release9:
        pop 	hl
        jp 	cinPS2
releaseIn:
				;input is release code
        ld 	a,1		;ignore current data
        ld 	(fPS2Rel),a	;set flag to mark next data as released key
				;if next data is normal, it will be ignored
				;if next data is shift/ctrl/caplock, the appropriate flag is cleared
        jp	cinPS2
PS2qa:
        ld 	a,(bPS2)	;get the data from the keyboard buffer
        cp 	0f0h		;key release code?
        jr 	z,releaseIn
        cp 	0e0h		;NumKeypad input?
				;set NumKey flag and process the data normally
        jr 	nz,KeyInq
        ld 	a,1
        ld 	(fNumKey),a	;set flag indicating input from Num Keypad
        ld 	a,(bPS2)	;reload keyboard buffer data
KeyInq:
				;check CapLock later to decide whether alphabet needs 
				;to be converted to upper or lower case
        push 	hl
        ld 	a,(fShift)	;get shift flag
        or	a
        ld 	hl,PS2Tbl	;assuming Z set
        jr 	z,KeyInqa
        ld 	hl,PS2Tbl+80h	;load the Shifted scancode
KeyInqa:
        ld 	a,(bPS2)	;retrieve data from keyboard buffer
        or 	l		;PS2Tbl is aligned so l is always 0x80
				;index into the PS2Tbl
        ld 	l,a		;hl is now points to the key entered
        ld 	a,(hl)
        cp 	0e1h		;if shift key, set Shift flag
        jr 	nz,KeyInq1
        ld 	a,1
        ld 	(fShift),a
        jp 	KeyInq7
KeyInq1:
        cp 	0e2h		;if Ctrl key, set Ctrl flag
        jr 	nz,KeyInq2
        ld 	a,1
        ld 	(fCtrl),a
        jp 	KeyInq7
KeyInq2:
        cp 	0e4h		;if CapLock key, complement CapLock flag
        jr 	nz,KeyInq8
        ld 	a,(fCapLock)
        xor 	1		;complement the flag value
        ld 	(fCapLock),a
KeyInq7:
				;we are not done console input, continue to look for valid key
        pop 	hl
        jp 	cinPS2
KeyInq8:
				;before returning as a normal key input, check ctrl flag
				;if ctrl flag set, return key input as ctrl-a to ctrl-z
				; for both upper and lower cases
        ld 	h,a		;temporary save
        ld 	a,(fCtrl)
        or 	a		;set flags
        ld 	a,h		;restore regA without changing flag
        jr 	z,KeyInq9
				;control key input, assuming input is a-z, A-Z
        and 	1fh		;mask off top 3 bits, it becomes ctrl-A to ctrl-Z for a-z, A-Z
KeyInq9:
				;got a real key, returning with input value
				;check caplock flag.  If set and data is alphabet, 
				;then bit 5 needs to be complemented
				;  bit 5 determines whether the alphabet character is upper or lower case
        ld 	h,a		;save for a while
        ld 	a,(fCapLock)	;if caplock, exchange upper and lower case alphabets
        or	a
        ld 	a,h		;restore keyboard input without affecting flag
        jr 	z,keyInq9a
        cp 	'z'+1
        jr 	nc,keyInq9a	;branch if data is greater than 'z', return without processing
        cp 	'a'
        jp 	nc,doCapLock	;branch if data between 'a' and 'z'
        cp 	'Z'+1
        jr 	nc,keyInq9a	;branch if data is between 'Z' and 'a', return without processing
        cp 	'A'
        jr 	c,keyInq9a	;branch if data is lesser than 'A', return without processing
doCapLock:
        xor 	00100000b	;flip bit 5
keyInq9a:
        ld 	h,0
        inc 	h		;clear Z flag
        pop 	hl
				;valid input is returned
				;  So PS2 input is returned with Z flag cleared
        ret             	;return PS2 data with Z flag cleared
;
ENDIF
;
