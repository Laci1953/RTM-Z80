;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	RTM/Z80 Multitasking kernel - part 4/4
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

COND	DEBUG
	GLOBAL IsItTask,IsItActiveTask,IsSuspended,TCB_Default
ENDC
COND	SIO_RING
	GLOBAL GetSIOChars
ENDC
COND	C_LANG
	GLOBAL _IncTaskStack,_Suspend,_Resume,_StopTask,_ShutDown,_GetCrtTask,_StackLeft
ENDC
	GLOBAL __IncTaskStack,__BallocS,_RunningTask,__Balloc,__RemoveFromL,_TasksH,__LastFromL
	GLOBAL __AddTask,AllTasksH,__AddToL,__Bdealloc,Buddy,__Suspend,__Wait,__ShutDown
	GLOBAL QuickSignal,__Resume,_Reschedule,__StopTask,_ResumeTask,TasksCount
	GLOBAL RET_NULL,CleanWP,DefSP,__GetCrtTask,_GetTasksH,_GetAllTasksH,__StackLeft
	GLOBAL ShutDownLoop,QuickStopTask
	GLOBAL __StopTaskTimer
	GLOBAL __KillTaskIO

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
