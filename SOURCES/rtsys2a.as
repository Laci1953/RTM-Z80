;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	RTM/Z80 Multitasking kernel - part 3/4
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
;
COND	CMD
SYS_TASKS_NR	equ	3	;Default task + CON driver + CMD handler
ENDC
COND	NOCMD
SYS_TASKS_NR	equ	2	;Default task + CON driver 
ENDC
;
MAX_TASKS_NR	equ	32	;tasks number limit

	GLOBAL	RET_NULL,EI_RET_NULL
	GLOBAL	Lists,Buddy
	GLOBAL	LastActiveTCB,TicsCount,Counter,SecondCnt,RoundRobin
	GLOBAL	SIO_WP,SIO_RP,EchoStatus
COND	SIO_RING
	GLOBAL	GetSIOChars
ENDC
COND	CMD
	GLOBAL _CMD_Task
ENDC


COND	NOSIM
	GLOBAL	SIO_buf
ENDC

COND	SIM
SIO_buf         equ     7E00H
ENDC

COND	C_LANG
	GLOBAL _StartUp,_ShutDown
	GLOBAL _GetTaskSts,_SetTaskPrio,_GetTaskPrio
	GLOBAL _RunTask,_GetCrtTask
ENDC
	GLOBAL CON_CrtIO
	GLOBAL RTC_Header,CON_Driver_IO
	GLOBAL CleanWP,CleanRP
	GLOBAL QuickSignal
	GLOBAL __InitSem,__Wait
	GLOBAL __StartUp,__ShutDown
	GLOBAL __GetTaskSts,__SetTaskPrio,__GetTaskPrio,__RunTask
	GLOBAL __Balloc,__Bdealloc,__BallocS,_InitBMem
	GLOBAL __AddToL,__RemoveFromL,__LastFromL
	GLOBAL __AddTask
	GLOBAL _RunningTask,_TasksH,AllTasksH
	GLOBAL _Reschedule,Resch_or_Res
	GLOBAl IsItTask,IsItActiveTask,IsSuspended
	GLOBAL _InitialSP,_InitInts
	GLOBAL TCB_Default,TCB_Dummy
	GLOBAL pLists,def_sp,DefSP,def_sem,DefaultStart
	GLOBAL CON_Driver_TCB,CMD_TCB,PrioMask,TasksCount,IdCnt
COND	NOSIM
	GLOBAL CleanReqB,CleanRP
COND	DEBUG
	GLOBAL tmpbuf
ENDC
ENDC

;
;	Start Up - internal
;	used to initialize system and run the specified task
;
;	BC=stack size, HL=StartAddr, E=Priority
;	return HL=task TCB or 0 if alloc failed
;
__StartUp:
	push	af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
SavePars:
;				DIG_IO
COND	DIG_IO
	SET_LEDS 1
ENDC
;				DIG_IO
	ld	(_InitialSP),sp	;save SP to return after ShutDown
				;push params
	push	hl
	push	bc
	push	de
	call	_InitInts	;init interrupts
				;interrupts are disabled now (DI)
				;set-up kernel data
;										NOSIM
COND	NOSIM
	ld	bc,CleanReqB
	ld	hl,CleanRP
	ld	(hl),c
	inc	l
	ld	(hl),b
	inc	l
	ld	(hl),c
	inc	l
	ld	(hl),b
	inc	l
	ld	a,0FFH
	ld	(hl),a
	inc	l
	ld	a,1
	ld	(hl),a
	inc	l
	ld	(hl),a
COND	DEBUG
	ld	hl,tmpbuf
	ld	a,0DH
	ld	(hl),a
	inc	hl
	ld	a,0AH
	ld	(hl),a
	ld	bc,5
	add	hl,bc
	ld	a,'!'
	ld	(hl),a
ENDC
ENDC
;										NOSIM
	ld	a,TICS_PER_SEC
	ld	(SecondCnt),a
	ld	hl,SIO_buf
	ld	(SIO_RP),hl
	ld	(SIO_WP),hl
	xor	a
	ld	l,a
	ld	h,a
	ld	(LastActiveTCB),hl
	ld	(TicsCount),a
	ld	(Counter),hl
	ld	(Counter+2),hl
	ld	(RoundRobin),a
	ld	(EchoStatus),a
	ld	(CON_CrtIO),a
	ld	hl,TCB_Default+NXPV_OFF
	ld	(AllTasksH),hl
	ld	(AllTasksH+2),hl
	ld	hl,TCB_Default
	ld	(_TasksH),hl
	ld	(_TasksH+2),hl
	ld	hl,TCB_Dummy
	ld	(_RunningTask),hl
	ld	hl,Lists
	ld	(pLists),hl
	ld	hl,RTC_Header
	ld	(RTC_Header),hl
	ld	(RTC_Header+2),hl
	ld	hl,_TasksH
	ld	(TCB_Default),hl
	ld	(TCB_Default+2),hl
	ld	hl,TCB_Default+4
	ld	(hl),1
	inc	hl
	ld	(hl),3
	inc	hl
	ld	(hl),0
	ld	hl,def_sp
	ld	(DefSP),hl
	ld	hl,def_sem
	ld	(def_sem),hl
	ld	(def_sem+2),hl
	ld	hl,TCB_Dummy+15
	ld	(hl),1
	ld	hl,def_sem+4
COND	BDOS
	ld	(hl),1
ENDC
COND	NOBDOS
	ld	(hl),a
ENDC
	inc	hl
	ld	(hl),a
	inc	hl
	ld	(hl),1
	inc	hl
	ld	bc,AllTasksH
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	ld	(hl),a
	inc	hl
	ld	(hl),a
	inc	hl
	ld	(hl),a
	ld	hl,DefaultStart
	ld	(def_sp+12),hl
	ld	hl,BMEM_BASE	;init dynamic memory
	call	_InitBMem
				;prepare params for RunTask CON driver
	ld	e,250		;CON driver priority
	ld	hl,CON_Driver_IO;CON driver StartAddr
	ld	bc,60H		;CON driver stack size
	call	QuickRunTask	;RunTask CON driver
	ld	(CON_Driver_TCB),hl;save CON Driver TCB
				;RunTask CON driver was ok?
	pop	de
	pop	bc
	pop	hl
	jp	z,Resch_or_Res	;no, return Z=1 and HL=0 to caller
;										CMD
COND	CMD				
				;prepare params for RunTask CMD handler
	push	hl		;push params
	push	bc
	push	de
	ld	e,240		;CMD handler priority
	ld	hl,_CMD_Task	;CMD handler StartAddr
	ld	bc,60H		;CMD handler stack size
	call	QuickRunTask	;RunTask CMD handler
	ld	(CMD_TCB),hl	;save CMD handler TCB
				;RunTask CMD handler was ok?
	pop	de
	pop	bc
	pop	hl
	jp	z,Resch_or_Res	;no, return Z=1 and HL=0 to caller
ENDC
;										CMD
	ld	a,7FH
	ld	(PrioMask),a	;set new mask to filter the user task priorities
				;now RunTask with provided params
	call	QuickRunTask
	jp	Resch_or_Res	
COND	C_LANG
;	
;	Start Up System
;
;	used to initialize system and run the specified task
;
;short	StartUp(short TCB_size, void* StartAddr, short Prio);
;	AF,BC,DE,HL,IX,IY not affected
;	return HL=task TCB or 0 if alloc failed
;
OFF_TCB_SIZE	equ	14
;
_StartUp:
	push	af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	ld	hl,OFF_TCB_SIZE
	add	hl,sp		;stack=AF,BC,DE,HL,IX,IY,retaddr,params
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=TCBSize
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=task Start Addr
	inc	hl
	ld	a,(hl)		;A=Prio
	ex	de,hl		;HL=task Start Addr
	ld	e,a		;E=Prio
	jp	SavePars
;
;	Run Task 
;
;short	RunTask(short stack_size, void* StartAddr, short Prio);
;	AF,BC,DE,HL,IX,IY not affected
;	return HL=task TCB and Z=0 or HL=0 and Z=1 if alloc failed
;
_RunTask:
	push	af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	ld	hl,OFF_TCB_SIZE
	add	hl,sp		;stack=AF,BC,DE,HL,IX,IY,retaddr,params
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=stackSize
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=task Start Addr
	inc	hl
	ld	a,(hl)		;A=Prio
	ex	de,hl		;HL=task Start Addr
	ld	e,a		;E=Prio
	di
	call	QuickRunTask	;return HL=task TCB or 0 if alloc failed
	jp	Resch_or_Res	;if TCB was inserted into active tasks list, reschedule
				;else, resume current running task
ENDC
;
;	Run Task - internal
;
;	BC=stack size, HL=StartAddr, E=Priority
;	return HL=task TCB or 0 if alloc failed
;
__RunTask:
	di
	call	QuickRunTask	;HL returned
	jr	nz,1f		;Z=0? (TCB was inserted into active tasks list?)
	ei			;no, just resume current task 
	ret
1:				;yes : reschedule
	push	af		;prepare stack
	push	hl		;keep HL=return value on stack
	ld	hl,-8		;space for 4 push
	add	hl,sp
	ld	sp,hl
	jp	_Reschedule
;
;	Run Task without reschedule
;
;	called under DI
;	BC=stack size, HL=StartAddr, E=Priority
;	return (HL=task TCB and Z=0) or (HL=0 and Z=1) if alloc failed or too many tasks
;
QuickRunTask:
	ld	a,(TasksCount)	;check tasks counter
	cp	MAX_TASKS_NR
	jr	c,1f
0:	xor	a		;Z=1
	ld	h,a
	ld	l,a		;max nr reached, return HL=0
	ret
1:				;check ID counter
	ld	a,(IdCnt)
	cp	0FFH
	jr	z,0b		;too many runs & stops, cannot reuse ID's !!!
				;mask the priority
	ld	a,(PrioMask)
	and	e		;for user tasks, 1 <= prio <=127 !
	jr	nz,2f
	inc	a
2:	ld	e,a		;E=Prio filtered
				;save params
	push	de		;E=Prio
	push	hl		;HL=StartAddr
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	hl,TCB_H_SIZE	;create TCB (add +20H to stack size)
	add	hl,bc
	ld	b,h
	ld	c,l
	push	bc		;BC=TCB size, on stack
	call	__BallocS	;get BC=bAlloc size
	call	__Balloc	;returned HL=TCB
	jr	nz,3f
				;Z=1, alloc failed, return HL=0
	pop	de		;drop params from stack
	pop	de
	pop	de
	ret			;HL=0
3:				;HL=TCB
	ld	d,h
	ld	e,l		;DE=TCB
COND	SIO_RING
	call	GetSIOChars
ENDC
	pop	hl		;HL=TCB Size
	add	hl,de		;HL=TCB+TCB Size, CARRY=0
	pop	bc		;BC=StartAddr
	dec	hl
	ld	(hl),b
	dec	hl
	ld	(hl),c		;task start address is at end of stack, ready for RET
	ld	bc,12
	sbc	hl,bc		;HL=stack pointer to be set as SP
	ex	de,hl		;HL=TCB, DE=stack pointer to be set as SP
	pop	bc		;C=Prio
	push	hl		;TCB on stack
	ld	a,PRI_OFF
	add	a,l
	ld	l,a		;HL=pointer to task priority
	ld	(hl),c		;save task priority in TCB
	inc	l		;HL=pointer of task SP
	ld	(hl),e		;set the SP
	inc	l
	ld	(hl),d
	inc	l		;HL=pointer to local semaphore
COND	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDC
	call	__InitSem
	ld	a,6		;skip Semaphore area
	add	a,l
	ld	l,a		;HL=pointer to TCB ID
	ld	de,IdCnt
	ex	de,hl		;HL=ID & Tasks counter pointer, DE=pointer to TCB ID
	inc	(hl)		;increment ID counter
	ld	a,(hl)		;A=new task's ID
	inc	hl
	inc	(hl)		;increment TasksCount
	ex	de,hl		;HL=pointer to TCB ID
	ld	(hl),a		;save TCB ID
	inc	l		;HL=pointer of (nextTask, PrevTask)
	ex	de,hl		;DE=pointer of (nextTask, PrevTask)
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	hl,AllTasksH	;HL=Pointer to Header of all tasks list
COND	RSTS
	RST	24
ENDC
COND	NORSTS
	call	__AddToL	;Add DE=task to HL=all tasks list
ENDC
				;HL=pointer of (nextTask, PrevTask)
	ld	a,DLIST_H_SIZE	;skip (nextTask, PrevTask)
	add	a,l
	ld	l,a		;HL=pointer to WaitSem, CARRY=0
	xor	a
	ld	(hl),a
	inc	l
	ld	(hl),a		;WaitSem=0
	inc	l		;HL=pointer to StackWarning
	ld	(hl),a		;StackWarning=0
	pop	bc		;BC=TCB to be inserted into active tasks list
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	hl,_TasksH	;HL=Active tasks list header
	jp	__AddTask	;insert BC=TCB into active tasks list, HL=TCB returned, Z=0
;
;	Get Task Priority
;
;short GetTaskPrio(void* TCB);
;	returns HL=prio, or HL=-1 if not a real task
;
GET_PRI_TCB	equ	8
;
_GetTaskPrio:
	push	af		;save some regs
	push	de		
	push	bc
	ld	hl,GET_PRI_TCB
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=TCB
	call	__GetTaskPrio	;HL=prio or -1
	pop	bc
	pop	de
	pop	af
	ret
;
;	Get Task Priority - internal
;	BC=TCB
;	returns HL=prio, or HL=-1 if not a real task
;
__GetTaskPrio:
COND	DEBUG
	push	bc		;TCB on stack
	call	IsItTask	;BC is a task TCB ?
	pop	bc		;BC=TCB
	jr	z,1f
COND DIG_IO
	OUT_LEDS ERR_TCB
ENDC
	ld	hl,-1		;no, return -1
	ret
1:
ENDC
	ld	a,c
	add	a,PRI_OFF
	ld	c,a		;BC=pointer of prio in TCB
	ld	a,(bc)		
	ld	l,a
	ld	h,0		;HL=prio
	ret
;
;	Set Task Priority
;
;short	SetTaskPrio(void* TCB, short Prio);
;	returns HL=0 if not a real task or Prio > 127 or TCB=DefaultTask, else not NULL
;
SET_PRI_TCB	equ	14
;
_SetTaskPrio:
	push	af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	ld	hl,SET_PRI_TCB
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=TCB
	inc	hl
	ld	e,(hl)		;E=Prio
	jr	setpri
;
;	Set Task Priority - internal
;	BC=TCB, E=Prio
;
__SetTaskPrio:
	push	af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
setpri:	
	di
COND	DEBUG
	ld	a,e		;check pri < 128 ?
	cp	128
	jr	nc,3f		;no, return 0
				;yes, pri < 128
	ld	hl,TCB_Default
	or	a
	sbc	hl,bc
	jr	z,3f		;cannot change prio of DefaultTask
	push	de		;prio on stack
	push	bc		;TCB on stack
	call	IsItTask	;BC is a task TCB ?
	pop	bc		;BC=TCB
	pop	de		;E=Prio
	jr	z,1f		;no, return 0
COND DIG_IO
	OUT_LEDS ERR_TCB
ENDC
3:	
	xor	a		;Z=1
	ld	h,a
	ld	l,a		;HL=0
	jp	Resch_or_Res	;Z=1, resume crt task & return HL=0
1:				;yes, TCB is ok
ENDC
	ld	a,c
	add	a,PRI_OFF	;Z=0
	ld	c,a		;BC=pointer of prio in TCB
	ld	a,e		;A=prio
	ld	(bc),a		;set prio
	ld	hl,1
	jp	Resch_or_Res	;Z=0, return HL=1 & reschedule
;
;	Get Task Status
;
;short	GetTaskSts(void* TCB)
;	returns HL=0 : no task, HL=1 : active, HL=2 : waiting, HL=3 : suspended
;
COND	C_LANG
_GetTaskSts:
	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
ENDC
;
;	Get Task Status - internal
;
__GetTaskSts:			;BC=TCB
	di
	push	bc
	call	IsItTask
	pop	bc
	ld	hl,0
	jr	z,1f
	ei
	ret			;0 = no task
1:	inc	hl
	call	IsItActiveTask
	ei
	ret	z		;1 = active
	inc	hl
	call	IsSuspended
	ret	nz		;2 = waiting
	inc	hl
	ret			;3 = suspended
;
