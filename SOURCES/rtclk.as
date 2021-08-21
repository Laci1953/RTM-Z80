;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;       Real Time Clock support routines
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
LastActiveTCB:  defs	2
TicsCount:      defs    1
;
Signals:	defs	1		;1 if Signals done, 0 else
;
;       Order is critical - do not change-it
;
Counter:        defs    4               ;incremented at each 5ms, used for rand seed
SecondCnt:      defs	1               ;1 second = 200 * 5ms
RoundRobin:     defs    1		;1 if YES, 0 if NO
;
PRI_OFF         EQU     6       ;relative offset of Priority in TCB

	psect	text

	GLOBAL Counter
	GLOBAL	RET_NULL,EI_RET_NULL,RET_FFFF,EI_RET_FFFF
COND	SIO_RING
	GLOBAL GetSIOChars
ENDC
	GLOBAL LastActiveTCB,TicsCount,Counter,SecondCnt,RoundRobin
        GLOBAL RETI_RETURN
        GLOBAL _ReschINT
	GLOBAL _Reschedule
COND    DIG_IO
        GLOBAL  TestFreeMem
ENDC
	GLOBAL	__Balloc
	GLOBAL	__Bdealloc
        GLOBAL  RTC_Header
COND	C_LANG
	GLOBAL _RoundRobinON
	GLOBAL _RoundRobinOFF
	GLOBAL _GetTimerSts
	GLOBAL _MakeTimer
	GLOBAL _DropTimer
        GLOBAL _StartTimer
        GLOBAL _StopTimer
        GLOBAL _GetTicks
ENDC
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
COND	DEBUG
	GLOBAL	IsItSem
ENDC
COND    NOCPM 
COND	DIG_IO .and. WATSON
        GLOBAL Snapshot
ENDC
ENDC
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
        PUSH_ALL_REGS
	di
	xor	a
	ld	(RoundRobin),a
	jp	_Reschedule
;
;       Get Ticks
;
;       return (DE=low,HL=high)=Ticks
;
COND	C_LANG
_GetTicks:
ENDC
__GetTicks:
        ld      de,(Counter)
	ld	hl,(Counter+2)
        ret
COND	C_LANG
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
ENDC
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
COND	C_LANG
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
ENDC
__GetTimerSts:			;HL=Timer
	di
COND	DEBUG
	push	hl
        ld      b,h
        ld      c,l             ;BC=Timer
        ld      hl,RTC_Header   ;HL=list header
        call    __IsInL
	pop     hl
	jp	nz,EI_RET_FFFF
ENDC
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
COND    DEBUG
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
ENDC
;------------------------------------------------------------------DEBUG
	ld	a,l
	sub	B_H_SIZE
	ld	l,a			;HL=10H block to deallocate

	call	__Bdealloc		;deallocate-it
	ei
	ret
;
COND	C_LANG
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
ENDC
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
COND    DEBUG
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
ENDC
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
COND	SIO_RING
	call	GetSIOChars
ENDC
        ld      hl,RTC_Header   ;HL=list header
COND    RSTS
        RST     24
ENDC
COND    NORSTS
        call    __AddToL        ;Add to HL=list header, new elem=DE
ENDC
        ei
	ret			;HL=RTClkCB

COND	C_LANG
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
ENDC
;
;       Stop Timer - internal
;
;       HL = Timer
;
__StopTimer:
;------------------------------------------------------------------DEBUG
COND    DEBUG
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
ENDC
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
COND    RSTS
        RST     32
ENDC
COND    NORSTS
        call    __RemoveFromL
ENDC
COND	SIO_RING
	jp	GetSIOChars
ENDC
COND	NOSIO_RING
	ret
ENDC
;
;	Stop Task's Timers
;
;	called under disabled interrupts
;	C=Task ID
;
__StopTaskTimer:
        ld      hl,RTC_Header   ;HL=List header
COND	NORSTS
	call	__FirstFromL
ENDC
COND	RSTS
	RST	0
ENDC
        ret     z
loopstp:
        push    hl              ;HL=crt RTClkCB on stack
        ld      de,RTC_Header   ;DE=List header
COND    RSTS
        RST     16
ENDC
COND    NORSTS
        call    __NextFromL     ;get next from list
ENDC
COND	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDC
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
COND    RSTS
        RST     32
ENDC
COND    NORSTS
        call    __RemoveFromL   ;remove crt RTClkCB
ENDC
	pop	bc 
COND	SIO_RING
	call	GetSIOChars
ENDC
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
        xor	a               ;Init Signals marker
	ld	(Signals),a	;0 = no Signals ! 
COND	SIO_RING
	call	GetSIOChars
ENDC
        ld      hl,Counter      ;increment 32bits ticks counter
				;byte 1
        inc     (hl)
        inc     hl
COND	DIG_IO
        jr      nz,1f
ENDC
COND	NODIG_IO
	jr	nz,timers
ENDC
				;byte 2
	inc	(hl)
	inc	hl
COND	DIG_IO
        jr      nz,2f
ENDC
COND	NODIG_IO
	jr	nz,timers
ENDC
				;byte 3
	inc	(hl)
	inc	hl
COND	DIG_IO
        jr      nz,3f
ENDC
COND	NODIG_IO
	jr	nz,timers
ENDC
				;byte 4
	inc	(hl)
COND	DIG_IO
	inc	hl
        jr      4f
ENDC
;---------------------------------------------------------------------------DIG_IO
COND    DIG_IO
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
;COND    DEBUG 
;COND	TRIGGERS
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
;ENDC
;ENDC
;-----------------------------------------------------------DEBUG
;-----------------------------------------------------------NOCPM
;COND    NOCPM
;COND	TRIGGERS .and. WATSON
;        TEST_TRIGGER    SNAPSHOT
;        jr      z,timers
;                                ;takes a snapshot
;        call    Snapshot        ;move all LOW_RAM to UP_RAM
;        jp      RETI_RETURN     ;and shutdown
;ENDC
;ENDC
;-----------------------------------------------------------NOCPM
ENDC
;---------------------------------------------------------------------------DIG_IO
timers:
COND	SIO_RING
	call	GetSIOChars
ENDC
				;process Timer requests
        ld      hl,RTC_Header   ;HL=List header
COND	NORSTS
	call	__FirstFromL
ENDC
COND	RSTS
	RST	0
ENDC
				;HL=first RTClkCB
        jr      z,roundrobin
loop:                           ;HL=crt RTClkCB
                                ;not null...
        push    hl              ;HL=crt RTClkCB on stack
        ld      de,RTC_Header   ;DE=List header
COND    RSTS
        RST     16
ENDC
COND    NORSTS
        call    __NextFromL     ;get next from list
ENDC
COND	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDC
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
COND	SIO_RING
	call	GetSIOChars
ENDC
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
COND	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDC
COND    RSTS
        RST     32
ENDC
COND    NORSTS
        call    __RemoveFromL   ;remove crt RTClkCB
ENDC
next:   
COND	SIO_RING
	call	GetSIOChars
ENDC
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
COND	SIO_RING
	call	GetSIOChars
ENDC
        ld      hl,_TasksH      ;HL=active tasks list header
        call    __RotateL       ;L=1 if round-robin move done, else 0
check:
	ld	a,(Signals)
        or      l               ;Signals or round-robin move done ?
        jr      z,return
	push    ix
        push    iy
        jp      _ReschINT       ;if Signals were made or round-robin move done
return:                         ;else, just return
        pop     bc              ;restore regs
        pop     de
        pop     hl
        pop     af
        ei
        reti
