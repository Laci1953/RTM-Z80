;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	RTM/Z80 Multitasking kernel - part 2/2
;
*Include config.mac

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


COND	NOCPM
	GLOBAL	SIO_buf
ENDC

COND	CPM
SIO_buf         equ     7E00H
ENDC

COND	C_LANG
	GLOBAL _StartUp,_ShutDown
	GLOBAL _GetTaskSts,_SetTaskPrio,_GetTaskPrio
	GLOBAL _RunTask,_StopTask,_GetCrtTask,_IncTaskStack,_StackLeft
	GLOBAL _Suspend,_Resume
ENDC
	GLOBAL CON_CrtIO
	GLOBAL RTC_Header,CON_Driver_IO
	GLOBAL CleanWP,CleanRP
	GLOBAL QuickSignal
	GLOBAL __InitSem,__Wait
	GLOBAL __StartUp,__ShutDown
	GLOBAL __GetTaskSts,__SetTaskPrio,__GetTaskPrio,__RunTask,__StopTask,__IncTaskStack
	GLOBAL ShutDownLoop
	GLOBAL __Suspend,__Resume
	GLOBAL __GetCrtTask,__StackLeft
	GLOBAL __Balloc,__Bdealloc,__BallocS,_InitBMem
	GLOBAL __AddToL,__RemoveFromL,__LastFromL
	GLOBAL __AddTask
	GLOBAL _RunningTask,_TasksH,AllTasksH,_GetTasksH,_GetAllTasksH
	GLOBAL _Reschedule,Resch_or_Res,_ResumeTask,QuickStopTask
	GLOBAl IsItTask,IsItActiveTask,IsSuspended
	GLOBAL __StopTaskTimer
	GLOBAL __KillTaskIO
	GLOBAL _InitialSP,_InitInts
	GLOBAL TCB_Default,TCB_Dummy
	GLOBAL pLists,def_sp,DefSP,def_sem,DefaultStart
	GLOBAL CON_Driver_TCB,CMD_TCB,PrioMask,TasksCount,IdCnt
COND	NOCPM
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
	PUSH_ALL_REGS
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
;										NOCPM
COND	NOCPM
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
;										NOCPM
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
	xor	a
	ld	(hl),a
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
	ld	(hl),0
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0
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
	PUSH_ALL_REGS
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
	PUSH_ALL_REGS
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
	PUSH_ALL_REGS
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
	PUSH_ALL_REGS
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
COND	C_LANG
;
;	Increase Stack Size for current task
;
;short	IncTaskStack(short NewSize);
;	returns HL=0 if cannot alloc or new size < old size, else not NULL
;
CHG_S_OFF	equ	8
;
_IncTaskStack:
	push	af
	push	bc
	push	de
	ld	hl,CHG_S_OFF
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=new size
	call	__IncTaskStack
	pop	de
	pop	bc
	pop	af
	ret
ENDC
;
;	Increase Stack Size - internal
;	BC=new size
;	returns HL=0 if cannot alloc or new size < old size, else not NULL
;
__IncTaskStack:
	ld	hl,TCB_H_SIZE
	add	hl,bc
	ld	b,h
	ld	c,l
	push	bc		;BC=new TCB size, on stack
	call	__BallocS	;get C=bAlloc size
	ld	hl,(_RunningTask)
	ld	a,BLOCKSIZE_OFF
	add	a,l
	ld	l,a
	ld	a,(hl)		;A=old bSize
	cp	c
	jr	nc,1f		;if less than old size, return NULL
	push	af		;A=old bSize, on stack
	di
	call	__Balloc
	jr	nz,2f
	ei
	pop	af
1:	pop	bc
	ld	hl,0		;cannot alloc, return NULL
	ret
2:	pop	af		;A=old bSize
	push	hl		;new TCB on stack
	push	af		;old bSize on stack
	ld	bc,(_RunningTask);BC=old TCB
	ld	a,PRI_OFF
	add	a,c
	ld	c,a		;BC=pointer of old Prio
	ld	a,PRI_OFF
	add	a,l
	ld	l,a		;HL=pointer of new Prio
	ld	a,(bc)
	ld	(hl),a		;new Prio=old Prio
	inc	l		;HL=pointer of new SP
	ex	de,hl
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	hl,0
	add	hl,sp
	ex	de,hl		;DE=new SP
	ld	(hl),e
	inc	l
	ld	(hl),d		;new SP is saved
	inc	l		;HL=pointer of new LocalSem
	ld	d,h
	ld	e,l
	ld	(hl),e		;Init new LocalSem
	inc	l
	ld	(hl),d
	inc	l
	ld	(hl),e
	inc	l
	ld	(hl),d
	inc	l
	ld	(hl),0
	inc	l
	ld	(hl),0
	inc	l		;HL=pointer of new ID
	ld	a,ID_OFF-PRI_OFF
	add	a,c
	ld	c,a		;BC=pointer of old ID
	ld	a,(bc)
	ld	(hl),a		;new ID = old ID
	ld	a,WAITSEM_OFF-ID_OFF
	add	a,l
	ld	l,a		;HL=pointer of new WaitSem
	xor	a
	ld	(hl),a		;Init new WaitSem
	inc	l
	ld	(hl),a
	inc	l		;HL=pointer of new StackWarning
	ld	(hl),a		;Init new StackWarning
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	hl,(_RunningTask);remove old TCB from active tasks list
COND	RSTS
	RST	32
ENDC
COND	NORSTS
	call	__RemoveFromL
ENDC
				;HL is still = old TCB
				;remove old TCB from all tasks list
	ld	a,NXPV_OFF
	add	a,l
	ld	l,a		;HL=pointer of old (nextTask,prevTask)
COND	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDC
COND	RSTS
	RST	32
ENDC
COND	NORSTS
	call	__RemoveFromL
ENDC
COND	SIO_RING
	call	GetSIOChars
ENDC
	pop	af
	pop	bc		;BC=new TCB
	push	bc		;back on stack
	push	af
	ld	hl,_TasksH
	call	__AddTask	;insert new TCB into active tasks list, HL=new TCB
	ld	a,NXPV_OFF
	add	a,l
	ld	l,a		;HL=pointer of new (nextTask, PrevTask)
	ex	de,hl		;DE=pointer of new (nextTask, PrevTask)
	ld	hl,AllTasksH	;HL=Pointer to Header of all tasks list
COND	RSTS
	RST	24
ENDC
COND	NORSTS
	call	__AddToL	;Add DE=task to HL=all tasks list
ENDC
COND	DEBUG
	pop	af		;A=old TCB bSize
	push	af		;back on stack
	ld	c,a		;C=old TCB bSize
ENDC
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	hl,(_RunningTask);HL=old TCB
	call	__Bdealloc	;deallocate old TCB
	pop	af		;A=old TCB bSize
	add	a,a		
	ld	hl,Buddy
	add	a,l
	ld	l,a
	ld	c,(hl)
	inc	l
	ld	b,(hl)		;BC=old TCB size
	ld	hl,(_RunningTask);HL=old TCB
	add	hl,bc		;HL=end of old TCB
	ex	de,hl		;DE=end of old TCB
	pop	hl		;HL=new TCB
	ld	(_RunningTask),hl;set new TCB as the current running task
	ld	h,d		;compute size of used stack
	ld	l,e		;HL=DE=end of old TCB
	or	a		;CARRY=0
	sbc	hl,sp		;HL=size of used stack + (new TCB size, still on stack)
	dec	hl		;remove size of 1 push
	dec	hl	
	ex	(sp),hl		;HL=new TCB size, size of used stack on stack
	ld	b,h
	ld	c,l		;BC=new TCB size
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	hl,(_RunningTask);HL=new TCB
	add	hl,bc		;HL=end of new TCB
	ex	de,hl		;DE=end of new TCB, HL=end of old TCB
	pop	bc		;BC=size of used stack
	push	bc		;back on stack
	push	de		;end of new TCB on stack
	dec	hl
	dec	de		;do (*DE-- = *HL--) while (BC--)
	lddr			;move content of stack from the old TCB to the new TCB
	pop	hl		;HL=end of new TCB
	pop	bc		;BC=size of used stack
	or	a		;CARRY=0
	sbc	hl,bc		;HL=pointer of begin of stack in new TCB
	ld	sp,hl		;set new SP
	ei
	ret
;	
;	Suspend - internal
;
__Suspend:
	ld	hl,(_RunningTask)
	ld	a,SEM_OFF
	add	a,l
	ld	l,a		;HL=pointer to task local semaphore
	jp	__Wait		;Wait(local semaphore)
;
COND	C_LANG
;
;	Suspend current task
;
;void	Suspend(void);
;	AF,BC,DE,HL,IX,IY not affected
;
_Suspend:
	PUSH_ALL_REGS
	call	__Suspend
	POP_ALL_REGS
	ret
ENDC
;
;	Quick Resume - internal
;
;	Check conditions for Resume and do Signal(localSem) without reschedule
;	called under DI
;	HL=TCB
;	return Z=1 if it is ok 
;	else Z=0 if it is not a task or the task is active (not suspended) - only when DEBUG
;
QuickResume:
COND	DEBUG
	ld	b,h		;check if it is a real task
	ld	c,l
	call	IsItTask	;returns Z=1 if YES
	ret	nz
				;check if it is an active task
	ld	b,h
	ld	c,l
	call	IsItActiveTask	;returns Z=1 if YES
	jr	nz,3f
	ld	a,l		;it is an active task (NOT suspended)
	or	h		;Z=0		
	ret			;return Z=0
3:
	ld	b,h
	ld	c,l
	call	IsSuspended
	ret	nz		;it waits NOT for local semaphore (NOT suspended)
				;TCB valid (task was suspended)
ENDC
;										DEBUG
	ld	a,SEM_OFF
	add	a,l
	ld	l,a		;HL=pointer to task local semaphore
	call	QuickSignal
	xor	a		;Z=1, HL not NULL
	ret
;
;	Resume - internal
;
;	HL = TCB
;	return CARRY=0 if ok, else CARRY=1 if it is not a task or the task is not suspended
;
__Resume:
	di
	call	QuickResume
	jr	nz,1f
	or	a		;CARRY=0
	push	af		;keep CARRY on stack
	ld	hl,-10		;space for 5 push (HL,DE,BC,IX,IY)
	add	hl,sp
	ld	sp,hl
	jp	_Reschedule
1:
	scf			;CARRY=1
	ei
	ret
;
COND	C_LANG
;
;	Resume task
;
;short	Resume(struct TaskCB* taskTCB);
;	AF,BC,DE,HL,IX,IY not affected
;	return HL=1 if ok, else 0 if it is not a task or the task is not suspended
;
ResTCB	equ	14
;
_Resume:
	PUSH_ALL_REGS
	ld	hl,ResTCB
	add	hl,sp		;stack=AF,BC,DE,HL,IX,IY,retaddr,TCB
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=TCB
	di
	call	QuickResume
	ex	de,hl		;store HL as return value on stack
	ld	hl,8
	add	hl,sp		;Z not affected
	ld	(hl),e
	inc	hl		;Z not affected
	ld	(hl),d
	jp	z,_Reschedule
	jp	_ResumeTask
;
;	Stop task
;	
;short	StopTask(void* taskTCB);
;	AF,BC,DE,HL,IX,IY not affected
;	returns HL=0 if it is not a task or it is the Default task, else not null (success)
;
StopTCB	equ	14
;
_StopTask:
	PUSH_ALL_REGS
	ld	hl,StopTCB
	add	hl,sp		;stack=AF,BC,DE,HL,IX,IY,retaddr,TCB
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=TCB
	di
	call	QuickStopTask
	jr	z,StopCheck	;if not the current active task was stopped,
				;just resume current task
	ex	de,hl		;DE=to be returned
	ld	hl,8
	add	hl,sp
	ld	(hl),e		;store returned value on stack
	inc	hl
	ld	(hl),d
	jp	_ResumeTask
ENDC
;
;	StopTask - internal
;
;	HL=TCB
;	returns HL=0 if it is not a task, else not null (success)
;
__StopTask:
	di
	call	QuickStopTask
	jr	z,StopCheck	;if not the current active task was stopped,
	ei			;just resume current task
	ret
;
StopCheck:			;the current active task was stopped
	ld	a,(TasksCount)	;check how many tasks left?
	cp	SYS_TASKS_NR
	jp	nz,_Reschedule	;there are other user tasks remaining, go reschedule
	jr	ShutDownLoop	;only the system tasks remain, go shutdown	
;
;	Quick Stop Task
;
;	Stop task without reschedule
;	called under DI
;	HL=Task TCB
;
;	if (TCB is not a task) 
;		return HL=0, Z=0 
;	else if (TCB is the current active task)
;		return Z=1
;	else
;		return HL=1, Z=0
; 
QuickStopTask:
;										DEBUG
COND	DEBUG
	push	hl
	ld	bc,TCB_Default
	or	a
	sbc	hl,bc
	pop	hl
	jp	z,RET_NULL	;Default task cannot be stopped!
	ld	b,h
	ld	c,l
	call	IsItTask	;BC is a task TCB ?
	jr	z,1f		;if not, return Z=0, HL=0
COND DIG_IO
	OUT_LEDS ERR_TCB
ENDC
	jp	RET_NULL
1:
ENDC
;										DEBUG
	push	hl		;HL=TCB on stack
COND	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDC
COND	RSTS
	RST	32
ENDC
COND	NORSTS
	call	__RemoveFromL	;remove from active tasks list or waiting for semaphore list
ENDC
				;HL is still = TCB
	ld	a,NXPV_OFF
	add	a,l
	ld	l,a		;HL=pointer of (nextTask,prevTask)
COND	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDC
COND	RSTS
	RST	32
ENDC
COND	NORSTS
	call	__RemoveFromL	;remove from all tasks list
ENDC
COND	SIO_RING
	call	GetSIOChars
ENDC
	pop	hl		;HL=TCB
	push	hl		;on stack
;										DEBUG
COND	DEBUG
	ld	a,BLOCKSIZE_OFF
	add	a,l
	ld	l,a		;HL=pointer of block size
	ld	c,(hl)		;C=TCB block size
	pop	hl		;HL=TCB
	push	hl		;keep it on stack
ENDC
;										DEBUG	
	call	__Bdealloc	;deallocate HL=task TCB, BC=block size
	pop	bc		;BC=TCB
				;store TCB ID as "clean request"
	ld	a,ID_OFF
	add	a,c
	ld	c,a		;BC=pointer to TCB ID, CARRY=0
	ld	a,(bc)		;A=TCB ID			
	ld	hl,(CleanWP)
	ld	(hl),a		
	inc	l
	ld	(CleanWP),hl		
	ld	hl,TasksCount	;decrement counter of tasks
	dec	(hl)		
	push	bc
	ld	c,a		;C=TCB ID
	call	__StopTaskTimer
	call	__KillTaskIO	;returns Z=1 if reschedule needed
	pop	bc
	jr	z,retZ		;if Z=1, force reschedule
				;else check if it is the current active task
	ld	a,c
	sub	ID_OFF		;CARRY=0
	ld	c,a		;BC=TCB
	ld	hl,(_RunningTask)
	sbc	hl,bc		;Z=1 if it was the current active task, else Z=0
retZ:
	ld	hl,1		;return HL=1
	ret
;
;	Shut down the system
;
__ShutDown:
COND	C_LANG
_ShutDown:
ENDC
	di
ShutDownLoop:			;loop
	ld	a,(TasksCount)
	cp	1		;only Default task remaining?
	jr	z,2f
				;no, there are still other tasks remaining...
	ld	hl,AllTasksH	;HL=all tasks list header
COND	RSTS
	RST	8
ENDC
COND	NORSTS
	call	__LastFromL	;HL=Get last task
ENDC
	ld	a,l
	sub	NXPV_OFF
	ld	l,a		;HL=TCB
	call	QuickStopTask	;Stop-it
	jr	ShutDownLoop	;and keep looping...
2:				;yes, only Default Task remains
	ld	hl,(CleanWP)
	ld	(hl),0		;store ZERO = cleaner quit command
	inc	l
	ld	(CleanWP),hl
				;
	ld	sp,(DefSP)	;restore Default task SP
	jp	_ResumeTask 	;resume Default task
;
;	Get current active task
;	return HL=Current active task TCB
;
__GetCrtTask:
COND	C_LANG
_GetCrtTask:
ENDC
	ld	hl,(_RunningTask)
	ret
;
;	Get active tasks list header
;
_GetTasksH:
	ld	hl,_TasksH
	ret
;
;	Get all tasks list header
;
_GetAllTasksH:
	ld	hl,AllTasksH
	ret
;
;	Get task available stack space
;
;short	StackLeft(void* tcb);
;
;	returns task available stack space
;
_StackLeft:
	ld	hl,2
	add	hl,sp		;HL points to TCB, CARRY=0
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=TCB
;
;	StackLeft - internal
;
;	DE=TCB
;	returns HL=task available stack space
;
__StackLeft:
	ld	hl,TCB_Default	;is this the Default Task?
	sbc	hl,de
	jr	nz,1f
				;yes, it's the Default Task, we calculate remaining stack
				;as *(DefaultTaskTCB.SP) - (DefaultTaskTCB+STACKW_OFF+1)
	ld	hl,SP_OFF
	add	hl,de		;HL=pointer to DefaultTask SP
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=DefaultTask SP
	sbc	hl,de		;HL=DefaultTask SP - DefaultTaskTCB
	ld	bc,STACKW_OFF+1
	sbc	hl,bc		;HL=DefaultTask SP - DefaultTaskTCB - STACKW_OFF+1
	ret			;return HL=available stack space
1:				;it's not the Default Task, try to locate the deepest "push"...
	ld	hl,STACKW_OFF+1	;...by finding the first not "empty" byte in the stack area ...
	add	hl,de		;...(dynamic memory was initialized to zero at start-up)
	ex	de,hl		;DE=pointer of first available stack byte
	ld	hl,0		;HL=counter of "empty" bytes on the stack
2:	ld	a,(de)
	or	a
	ret	nz		;found-it, return HL=available stack space
	inc	de
	inc	hl
	jr	2b
