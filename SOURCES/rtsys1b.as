;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	RTM/Z80 Multitasking kernel - part 2/4
;
*Include config.mac
*Include leds.mac

	psect	text

COUNTER_OFF	equ	4	;Sem counter offset
DLIST_H_SIZE	equ	4	;List header size
TCB_H_SIZE	equ	20H	;TCB header size
;
ALLOCSTS_OFF	equ	4	;AllocStatus in TCB
BLOCKSIZE_OFF	equ	5	;BlockSize in TCB
PRI_OFF		equ	6	;Priority in TCB
SP_OFF		equ	7	;StackPointer in TCB
SEM_OFF		equ	9	;LocalSemaphore in TCB
ID_OFF		equ	15	;ID in TCB
NXPV_OFF	equ	16	;(NextTask,PrevTask)
WAITSEM_OFF	equ	20	;WaitSem
STACKW_OFF	equ	22	;StackWarning

COND	CMD
SYS_TASKS_NR	equ	3	;Default task + CON driver + CMD handler
ENDC
COND	NOCMD
SYS_TASKS_NR	equ	2	;Default task + CON driver 
ENDC
;
MAX_TASKS_NR	equ	32	;tasks number limit

COND	CPM
	GLOBAL CON_CrtIO,_CON_TX,_CON_RX
ENDC
COND	C_LANG
	GLOBAL _Signal,_Wait
ENDC
COND	DEBUG
	GLOBAL IsItSem,tmpbuf,DE_hex,CON_Wr_Sch
ENDC
COND	SIO_RING
	GLOBAL	GetSIOChars
ENDC
	GLOBAL __Signal,__Wait,Resch_or_Res,_Reschedule,QuickSignal,_TasksH,__AddTask,_RunningTask
	GLOBAL __RemoveFromL,__FirstFromL,RETURN,RETI_RETURN,_ReschINT,_ResumeTask,__GetFromL

COND	C_LANG
;
;	Signal semaphore
;
;short	Signal(void* SemAddr);
;	AF,BC,DE,HL,IX,IY not affected
;	return HL=0 if wrong semaphore address provided, else not null
;
SigSem	equ	14
;
_Signal:
	push	af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	ld	hl,SigSem
	add	hl,sp		;stack=AF,BC,DE,HL,IX,IY,retaddr,Sem addr
	ld      a,(hl)
	inc	hl
	ld      h,(hl)
	ld	l,a		;HL=Sem list header pointer
	di
;										DEBUG
COND	DEBUG
	call	IsItSem
	jr	z,1f
;								DIG_IO
COND DIG_IO
	OUT_LEDS ERR_SEM
ENDC
;								DIG_IO
				;no, it is not a semaphore, return 0
	xor	a		;Z=1 to just resume current task
	ld	h,a
	ld	l,a		;return HL=0
	jp	Resch_or_Res
1:
ENDC
;										DEBUG
	call	QuickSignal
				;Z=0? (TCB was inserted into active tasks list?)
	jp	Resch_or_Res	;yes : reschedule, else just resume current task
ENDC
;
;	Signal semaphore internal
;
;	HL=Semaphore address
;	return CARRY=1 if wrong semaphore address provided, else CARRY=0
;
__Signal:
	di
;										DEBUG
COND	DEBUG
	call	IsItSem
	jr	z,1f
;						DIG_IO
COND DIG_IO
	OUT_LEDS ERR_SEM
ENDC
;						DIG_IO
	scf			;no, it is not a semaphore, return CARRY=1
	ei
	ret
1:
ENDC
;										DEBUG
	call	QuickSignal
	jr	nz,1f		;Z=0? (TCB was inserted into active tasks list?)
	ei			;no, just resume current task 
	ret
1:				;yes : reschedule, CARRY=0
	push	af		;save CARRY value on stack
	ld	hl,-10		;space for 5 push (HL,DE,BC,IX,IY)
	add	hl,sp
	ld	sp,hl
	jp	_Reschedule
;
;	Signal semaphore without reschedule
;
;	called under DI
;	HL=Semaphore address
;	returns CARRY=0
;	returns Z=0 and A!=0 and HL=TCB inserted into active tasks list, 
;	or Z=1 and A=0 and HL not NULL if only counter was incremented
;
QuickSignal:
	push	hl
COND	RSTS
	RST	40
ENDC
COND	NORSTS
	call	__GetFromL
ENDC
	pop	de		;DE = Sem list header pointer, Z=0 & HL=first TCB or Z=1 & HL=0
	jr	z,1f
	push	hl		;HL=TCB
	ld	a,WAITSEM_OFF
	add	a,l
	ld	l,a		;HL=pointer to WaitSem
	xor	a
	ld	(hl),a		;Set WaitSem=0
	inc	l
	ld	(hl),a
	pop	bc		;BC=TCB
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	hl,_TasksH	;HL=Active tasks list header
	jp	__AddTask	;insert TCB into active tasks list, return HL=TCB & Z=0 & CARRY=0
1:				;list was empty, so only increment sem counter
	ex	de,hl		;HL=Sem list header pointer
	ld	a,COUNTER_OFF
	add	a,l
	ld	l,a		;HL=Sem counter pointer, increment counter
	inc	(hl)		;inc low counter
	jr	nz,2f
	inc	l		;if (low counter) == 0, increment also high counter
	inc	(hl)
2:	xor	a		;Z=1 & CARRY=0
	ret			;HL not NULL
COND	C_LANG
;
;	Wait Semaphore
;
;short	Wait(void* SemAddr);
;	AF,BC,DE,HL,IX,IY not affected
;	return HL=0 if wrong semaphore address provided, else not null
;
WaitSem	equ	14
;
_Wait:
	push	af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
COND	CPM
lwait1:	ld	a,(CON_CrtIO)
	cp	IO_IDLE
	jr	z,nowait1
COND	IO_COMM
	cp	IO_RAW_READ
	jr	z,nowait1
ENDC
	cp	IO_WRITE
	jr	nz,isread1
	call	_CON_TX
	jr	lwait1
isread1:call	_CON_RX
	call	_CON_TX
	call	_CON_TX
	call	_CON_TX
	jr	lwait1
nowait1:
ENDC	
	ld	hl,WaitSem
	add	hl,sp		;stack=AF,BC,DE,HL,IX,IY,retaddr,Sem addr
	ld      a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=Sem list header pointer
	di
;										DEBUG
COND	DEBUG
	call	IsItSem
	jr	z,1f
;									DIG_IO
COND DIG_IO
	OUT_LEDS ERR_SEM
ENDC
;									DIG_IO
				;no, it is not a semaphore, return 0
	xor	a		;Z=1 to just resume current task
	ld	h,a
	ld	l,a		;return HL=0
	jp	Resch_or_Res
1:
ENDC
;										DEBUG
	call	QuickWait
				;Z=0? (TCB was inserted into sem list?)
	jp	Resch_or_Res	;yes : reschedule, else just resume current task
ENDC
;
;	Wait Semaphore - internal
;
;	HL=SemAddr
;	return CARRY=1 if wrong semaphore address provided, else CARRY=0
;
__Wait:
COND	CPM
lwait:	ld	a,(CON_CrtIO)
	cp	IO_IDLE
	jr	z,nowait
COND	IO_COMM
	cp	IO_RAW_READ
	jr	z,nowait
ENDC
	cp	IO_WRITE
	jr	nz,isread
	call	_CON_TX
	jr	lwait
isread:	call	_CON_RX
	call	_CON_TX
	call	_CON_TX
	call	_CON_TX
	jr	lwait
nowait:
ENDC	
	di
;										DEBUG
COND	DEBUG
	call	IsItSem
	jr	z,1f
;									DIG_IO
COND DIG_IO
	OUT_LEDS ERR_SEM
ENDC
;									DIG_IO
	scf			;no, it is not a semaphore, return CARRY=1
	ei
	ret
1:
ENDC
;										DEBUG
	call	QuickWait
	jr	nz,1f		;Z=0? (TCB was inserted into semaphore list?)
	ei			;no, just resume current task 
	ret
1:				;yes : reschedule
	push	af		;save CARRY value on stack
	ld	hl,-10		;space for 5 push (HL,DE,BC,IX,IY)
	add	hl,sp
	ld	sp,hl
	jr	_Reschedule
;
;	Wait semaphore without reschedule
;
;	called under DI
;	HL=Semaphore address
;	returns CARRY=0
;	returns Z=0 and HL=TCB inserted into semaphore list, 
;	or Z=1 and HL not NULL if only counter was decremented
;
QuickWait:
	ld	a,COUNTER_OFF+1
	add	a,l
	ld	l,a		;HL=Sem counter pointer+1
	ld	a,(hl)		;A=counter high
	dec	l		;HL=Sem counter pointer
	or	(hl)		;counter is zero?
	jr	z,2f
				;not zero, decrement-it
	ld	a,(hl)		;A=low part before decrementing
	dec	(hl)		;decrement low part
	or	a		;if low part = 0 before being decremented...
	jr	nz,1f
	inc	l		;...decrement also high part
	dec	(hl)
1:
	xor	a		;Z=1, CARRY=0
	ret			;HL not NULL
2:				;counter was 0, so...
				;CARRY=0
	ld	a,l
	sub	COUNTER_OFF
	ld	l,a		;HL=SemAddr
	ex	de,hl		;DE=SemAddr
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	hl,(_RunningTask)
	push	hl		;HL=current active task TCB on stack
				;store SemAddr stored to WaitSem
	ld	a,WAITSEM_OFF
	add	a,l
	ld	l,a		;HL=pointer to WaitSem
	ld	(hl),e
	inc	l
	ld	(hl),d		;SemAddr stored to WaitSem
COND	SIO_RING
	call	GetSIOChars
ENDC
	ex	de,hl		;HL=SemAddr
	ex	(sp),hl		;HL=TCB, SemAddr on stack
COND	RSTS
	RST	32
ENDC
COND	NORSTS
	call	__RemoveFromL	;remove current active task TCB from active tasks list
ENDC
	ld	b,h		;returned HL=TCB
	ld	c,l		;BC=active task TCB
COND	SIO_RING
	call	GetSIOChars
ENDC
	pop	hl		;HL=SemAddr
	jp	__AddTask	;add crt task to semaphore's list,
				; return HL=current task and Z=0 and CARRY=0
;
_Reschedule:
;
;	called with JP !!!
;	DI already called, must exit with EI called
;	on stack: IY,IX,BC,DE,HL,AF,Return address
;
;	Prepare current task stack to resume later,
;	then give control to first TCB from active tasks list
;
COND	SIO_RING
	call	GetSIOChars
ENDC
				;prepare current task stack to resume later
	ld	hl,0		;save SP to current TCB
	add	hl,sp
	ex	de,hl		;DE = current SP 
	ld	hl,(_RunningTask)
	ld	a,SP_OFF	;save SP of the running task	
	add	a,l
	ld	l,a		;HL= pointer to Running Task's StackPointer
	ld	(hl),e
	inc	l
	ld	(hl),d		;SP is saved
				;now give control to first TCB from active tasks list
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	hl,_TasksH
COND	NORSTS
	call	__FirstFromL
ENDC
COND	RSTS
	RST	0
ENDC
				;returns HL=first active TCB
	jp	z,RETURN	;if HL NULL, return to the caller of the StartUp
				;if HL not NULL, go set new current active task
COND	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDC
	ld	(_RunningTask),hl;save current TCB
	ld	d,h
	ld	e,l		;DE=crt TCB
	ld	a,SP_OFF
	add	a,l
	ld	l,a		;HL = pointer to current task SP, CARRY=0
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a		;HL = current task SP
	ld	sp,hl		;SP is restored
;									DEBUG
COND DEBUG
				;CARRY=0
	ld	bc,50H
	sbc	hl,bc		;HL(SP)=HL(SP)-50H
				;DE=crt TCB
	sbc	hl,de
	jr	nc,_ResumeTask
				;stack space < 50H (!!! this means < 34H safe space !!!)
;							DIG_IO
COND DIG_IO
	OUT_LEDS ERR_STACK
ENDC
;							DIG_IO
	ld	hl,STACKW_OFF
	add	hl,de		;HL=pointer of StackWarning
	ld	a,(hl)
	cp	0FFH		;already set?
	jr	z,_ResumeTask	;if yes, just resume task
	ld	(hl),0FFH	;no, set-it
				;check if left stack space too low...
	ld	hl,0
	add	hl,sp		;HL=SP
	ld	bc,30H
	sbc	hl,bc		;HL(SP)=HL(SP)-30H
				;DE=crt TCB
	sbc	hl,de
	jr	c,_ResumeTask	;if left stack < 30H (safe < 14H), cannot write !!!
				;30H <= left stack space <= 50H ( 14H <= safe space <= 34H )
				;Write CR,LF,<hex TCB>,! on the CPM console
	ld	hl,tmpbuf+2
	call	DE_hex		;stores Ascii(DE) in tmpbuf+2
	ld	de,tmpbuf	;msg
	ld	c,7
	call	CON_Wr_Sch	;write msg to console (uses 12H stack space)
	jr	z,_ResumeTask	;if Z=1, just resume task
	ld	(_RunningTask),hl;else set HL=CON Driver TCB as running task
	ld	a,SP_OFF
	add	a,l
	ld	l,a		;HL = pointer to current task SP, CARRY=0
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a		;HL = current task SP
	ld	sp,hl		;SP is restored
ENDC
;									DEBUG
;	called under DI
;
_ResumeTask:			;enters with di called
COND	SIO_RING
	call	GetSIOChars
ENDC
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	pop	af
	ei
	ret
;
;	Reschedule or Resume
;
;	called with JP under DI
;	store HL as returned value stack
;	if Z=1, resume current task
;	else (Z=0) reschedule
;
Resch_or_Res:
	ex	de,hl		;store HL as return value on stack
	ld	hl,8
	add	hl,sp		;Z not affected
	ld	(hl),e
	inc	hl		;Z not affected
	ld	(hl),d
	jp	nz,_Reschedule	;Z=0 , reschedule
	jr	_ResumeTask	;Z=1 , resume current running task
;
;	_ReschINT - called from interrupts
;
;	called with JP from an interrupt under DI
;	on stack: AF,BC,DE,HL,IX,IY,Return address
;	Prepare current task stack to resume later,
;	then give control to first TCB from active tasks list
;
_ReschINT:
COND	SIO_RING
	call	GetSIOChars
ENDC
				;prepare current task stack to resume later
	ld	hl,0		;save SP to current TCB
	add	hl,sp
	ex	de,hl		;DE = current SP 
	ld	hl,(_RunningTask)
	ld	a,SP_OFF	;save SP of the running task
	add	a,l
	ld	l,a		;HL= pointer to Running Task's StackPointer
	ld	(hl),e
	inc	l
	ld	(hl),d		;SP is saved
				;now give control to first TCB from active tasks list
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	hl,_TasksH
COND	NORSTS
	call	__FirstFromL
ENDC
COND	RSTS
	RST	0
ENDC
				;returns HL=first active TCB
	jp	z,RETI_RETURN	;if HL NULL, return to the caller of the StartUp
				;if HL not NULL, set HL as new current active task
COND	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDC
	ld	(_RunningTask),hl;save current TCB
	ld	a,SP_OFF
	add	a,l
	ld	l,a		;HL = pointer to current task SP
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a		;HL = current task SP
	ld	sp,hl		;SP is restored
COND	SIO_RING
	call	GetSIOChars
ENDC
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	pop	af
	ei
	reti
