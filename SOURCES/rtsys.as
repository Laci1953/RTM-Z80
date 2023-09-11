;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	RTM/Z80 Multitasking kernel
;
	TITLE	RTM/Z80 core routines
;
*Include config.mac
*Include leds.mac
IF	EXTM512
*Include romram.mac
ENDIF

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
ROMBANK_OFF	equ	22	;ROMBank : not zero if task stored in 512KB EPROM
STACKW_OFF	equ	23	;StackWarning
;
IF	CMD
SYS_TASKS_NR	equ	3	;Default task + CON driver + CMD handler
ELSE
SYS_TASKS_NR	equ	2	;Default task + CON driver 
ENDIF
;
MAX_TASKS_NR	equ	32	;tasks number limit

LED_PORT	equ	0
ERR_SEM		equ	4	;wrong Semaphore

;----------------------------------------------------------------------------------NOSIM
IF	NOSIM

	psect	zero

CODE_BASE:			;at 0000H
IF	ROM
IF	BOOT_CODE
	GLOBAL	boot
	jp	boot		;ROM boot
	defw	__FirstFromL	;used to re-make "jp __FirstFromL" at 0
	defs	3
ELSE
	jp	__FirstFromL
	defw	__FirstFromL
	defs	3
ENDIF
ELSE	;NOROM
;0000H	RST	0
	jp	__FirstFromL
	defs	5
ENDIF	;ROM

;0008H	RST	8
	jp	__LastFromL
	defs	5
;0010H	RST	16
	jp	__NextFromL
	defs	5
;0018H	RST	24	
	jp	__AddToL
	defs	5
;0020H	RST	32
	jp	__RemoveFromL
	defs	5
;0028H	RST	40
	jp	__GetFromL
	defs	5
;0030H	RST	48
	jp	__InsertInL
	defs	5
;0038H	RST	56
IF	WATSON .and. NOM512
	jp	Breakpoint
	defs	5
ELSE
	defs	8
ENDIF

;0040H	SYSTEM START ADDRESS IS HERE
;
;	under DISABLE interrupts
;	if RAM128K then LOW 64K RAM is already selected 
;	if M512 then ROM & RAM banks are already selected
;
	ld	sp,STARTUP_SP	;set a temporary SP
	call	_main		;Start user code
STOP:				;RTM/Z80 was shutdown or breakpoint was reached
IF	M512 .or. Z80ALL
	jp	$
ELSE
	jp	RTM_EXIT
ENDIF
;
IF	WATSON .and. NOM512
;
;	Breakpoint was reached
;	The following registers are stored at 0DFE8H:
;	AF,BC,DE,HL,AF',BC',DE',HL',IX,IY,SP,PC
;	
Breakpoint:
	di
	ex	(sp),hl
	dec	hl			;PC decremented to RST addr
	ld	(_PC),hl		;breakpoint PC stored at 0DFFEH
	ld	hl,0
	add	hl,sp
	ld	(_PC-2),hl		;SP stored at 0DFFCH
	ex	(sp),hl
	ld	sp,_PC-2
	push	iy
	push	ix
	exx
	ex	af,af'
	push	hl
	push	de
	push	bc
	push	af
	exx
	ex	af,af'
	push	hl
	push	de
	push	bc
	push	af
	ld	sp,TCB_Dummy		;move SP to a neutral area
	call	StopHardware		;shutdown the hardware interrupt sources
	call	Snapshot		;take a snapshot
	jr	STOP			;stop and return to SCM
;
ENDIF	;WATSON .and. NOM512
;
;	Forced exit from an interrupt, quitting RTM/Z80
;	called under DI
;
RETI_RETURN:
	call	StopHardware	;shutdown the hardware interrupt sources
	ld	sp,(_InitialSP)	;restore initial SP
	POP_REGS
	reti			;Interrupts remain DISABLED
;
;	Init Interrupts
;
_InitInts:
	di				;disable interrupts
;
IF	KIO
        ld      a,0F9H          ;mux=SIO,reset SIO,CTC,PIO,Daisy chain write enable, SIO-CTC-PIO
        out     (KIO_CMD),a
                                ;wait KIO to reset
        ld      b,0
        djnz    $
ENDIF
;
;	Real Time Clock
;
;CTC_0, CTC_1, CTC_3
;
	ld	a,00000011B	;disable int,timer,prescale=16,don't care,
 				;don't care,no time constant follows,reset,control
	out 	(CTC_0),a	;CTC_0 is on hold now
	out 	(CTC_1),a	;CTC_1 is on hold now
	out 	(CTC_3),a	;CTC_3 is on hold now
;
;CTC_2	Real Time Clock
;
	ld	a,10110111B	;enable ints,timer,prescale=256,positive edge,
				;dont care,const follows,reset,control
	out	(CTC_2),a
IF	Z80ALL
	ld	a,246		;25.125 MHz / 256 / 246 ==> ~400Hz = ~2.5ms interrupt period
ELSE
	ld	a,144		;7.3728 MHz / 256 / 144 ==> 200Hz = 5ms interrupt period
ENDIF
	out	(CTC_2),a
;
;CTC interrupt vector
;
	ld	a,00000000B	;adr7 to adr3=0,vector ==> INT level 2
	out	(CTC_0),a	;set vector
;
;	SIO (async)
;
;	Init SIO
;
	ld	hl,SIO_A_TAB
	ld	c,SIO_A_C	;SIO_A
	ld	b,SIO_A_END-SIO_A_TAB
	otir			
				;HL=SIO_B_TAB
	ld	c,SIO_B_C	;SIO_B
	ld	b,SIO_B_END-SIO_B_TAB
	otir
;
IF	LPT
;
;	PIO
;
        ld      a,00001111B             ;PIO B mode=output
        out     (PIO_B_C),a
					;PIO A mode=control
	ld	hl,PIO_A_TAB
	ld	c,PIO_A_C
	ld	b,PIO_A_END-PIO_A_TAB
	otir
ENDIF
;
;	Interrupt mode
;
;	setup IM 2 
;
	im	2
	ld	a,INT_TAB/100H
	ld	i,a
	ret			;DI still ON
;
;	Stop Hardware devices
;
;	called under DI
;	reset all hardware devices, kill all possible interrupts
;	HL not affected
;
StopHardware:
;
;	stop CTC_2
;
	ld	a,00000011B	;disable int,timer,prescale=16,don't care,
 				;don't care,no time constant follows,reset,control
	out (CTC_2),a 		;CTC_2 is on hold now
;
;	stop SIO
;
	ld	a,00011000B		;A WR0 Channel reset
	out	(SIO_A_C),a
	ld	a,00011000B		;B WR0 Channel reset
	out	(SIO_B_C),a
IF	DIG_IO
	xor	a			;RTM/Z80 stopped
	out	(LED_PORT),a
ENDIF
	ret
;
;	Only to execute RETI, when this is needed
;	May be used to track the "unwanted" interrupts
IntRet:	 
	ei
	reti
;
;	Default task
;
DefaultStart:
	di
	call	ClearAllGarbage		;clean all garbage
	ei
	nop		
	jr	z,DefaultStart		;if shutdown marker found...
	di				;DISABLE Interrupts	
RETURN:					;return to the caller of StartUp
	call	StopHardware		;shutdown the hardware interrupt sources
IF	WATSON .and. NOM512
	call	Snapshot		;move LOW_RAM to UP_RAM
ENDIF
	ld	hl,0
	ld	(_PC),hl		;set recorded PC=0 (system was shutdown)
	ld	sp,(_InitialSP)		;restore initial SP
	POP_REGS
	ret				;Interrupts still DISABLED
;
;	memory pad used to fill the space till 100H
;
	defs	100H - ($ - CODE_BASE)
;
INT_TAB equ 100H
;
;	must be placed at an address multiple of 100H
;
INTERRUPTS:
	defw	IntRet;+00H
	defw	IntRet;+02H
	defw	_RTC_Int	;+04H	CTC_2 Real Time Clock (5 ms)
	defw	IntRet;+06H
IF	LPT
	defw	_PIO_INT	;+08H	PIO A (LPT ACK HIGH-->LOW)
ELSE
	defw	IntRet;+08H
ENDIF
	defw	IntRet;+0AH
	defw	IntRet;+0CH
	defw	IntRet;+0EH
	defw	IntRet;+10H	SIO_B transmit buffer empty		-inactive
	defw	IntRet;+12H	SIO_B external/status change		-inactive
	defw	IntRet;+14H	SIO_B receive character available	-inactive
	defw	IntRet;+16H	SIO_B special receive condition		-inactive
	defw	_CON_TX		;+18H	SIO_A transmit buffer empty
	defw	_CON_ESC	;+1AH	SIO_A external/status change
	defw	_CON_RX		;+1CH	SIO_A receive character available
	defw	_CON_SRC	;+1EH	SIO_A special receive condition

	psect	ram

;	UNINITIALIZED DATA - at multiple of 100H
;
CleanReqB:	defs	100H	;Memory garbage cleaner requests buffer
				;contains TCB ID to clean 
				;or 0 to stop cleaning and quit Default task
SIO_buf:	defs	100H	;SIO receive buffer
;
		defs	200H	;HEX loader buffers
;
;	For SC108 - Tasks related data - placed at BSS base + 400H
;
;	WATSON POINTERS					
AllTasksH:	defs	2	;TCB_Default+NXPV_OFF	;All tasks list header
		defs	2	;TCB_Default+NXPV_OFF
_TasksH:	defs	2	;TCB_Default	;active tasks TCB's priority ordered list header
		defs	2	;TCB_Default
_RunningTask:	defs	2	;TCB_Dummy	;current active task TCB
pLists:		defs	2	;Lists		;pointer of list of headers for free mem blocks
RTC_Header:	defs	2	;RTC_Header	;Real Time clock control blocks list header
		defs	2	;RTC_Header
;	END OF POINTERS
;
TCB_Default:			;TCB of default task
	;bElement header
	defs	2	;_TasksH	;void* next;
	defs	2	;_TasksH	;void* prev;
	defs	1	;1	;char AllocStatus; 
	defs	1	;3	;char BlockSize; set for a TCB with size 80H, but NOT NEEDED
	defs	1	;0	;char Priority=0;
DefSP:	defs	2	;def_sp	;void* StackPointer;
	;local semaphore
IF	BDOS
BDOS_Sem:
ENDIF
def_sem:defs	2	;def_sem	;void*	first;
	defs	2	;def_sem	;void*	last;
	defs	2	;0	;short	Counter;
	defs	1	;1	;ID=1
	defs	2	;AllTasksH;nextTask
	defs	2	;AllTasksH;prevTask
	defs	2	;0	;WaitSem
	defs	1	;0	;ROMBank
	defs	1	;0	;StackWarning
			;local stack area (we need here ~ 60H bytes)
	defs	20H
TCB_Dummy:	;TCB of dummy task - discarded after first StartUp call (10H here)
		;placed here to gain some stack space for Default Task
	defs	2	;void* next;
	defs	2	;void* prev;
	defs	1	;char AllocStatus; 
	defs	1	;char BlockSize; 
	defs	1	;char Priority;
	defs	2	;void* StackPointer;
			;local semaphore
	defs	2	;void*	first;
	defs	2	;void*	last;
	defs	2	;short	Counter;
	defs	1	;1	;ID=1 to be used at first allocs 
			;(that's why TCB_Dummy is needed !)
	defs	2DH	;this will be the impacted area of stack (2DH here)
def_sp:			;0EH here = TOTAL ~ 70H
	defs	2	;IY
	defs	2	;IX
	defs	2	;BC
	defs	2	;DE
	defs	2	;HL
	defs	2	;AF
	defs	2	;DefaultStart	;Default Task start address
;
			;Available block list headers
L0:	defs	4
L1:	defs	4
L2:	defs	4
L3:	defs	4
L4:	defs	4
L5:	defs	4
L6:	defs	4
L7:	defs	4
L8:	defs	4
L9:	defs	4
;
Lists:	defs	20
;
Buddy:	defs	20
;
CON_IO_Wait_Sem:defs    6	;CON Driver Local semaphore
;
CON_IO_Req_Q:			;CON Device driver I/O queue
;
CON_IO_WP:defs	2	;write pointer
CON_IO_RP:defs	2	;read pointer
CON_IO_BS:defs	2	;buffer start
CON_IO_BE:defs	2	;buffer end
	  defs	1	;balloc size
	  defs	2	;batch size (allways 10)
CON_IO_RS:defs	6	;read sem
CON_IO_WS:defs	6	;write sem
;
;	we are at BSS base + 500H
;
CON_Driver_TCB:	defs	2	;CON Driver TCB
;
CMD_TCB:	defs	2	;CMD task TCB
;
_InitialSP:	defs	2	;SP of StartUp caller
;
IF	LPT
LPT_Sem:	defs	6	;Line printer semaphore
LPT_Timer:	defs	10	;Line printer timer
LPT_TimerSem:	defs	6	;Line printer timer semaphore
ENDIF
;
IF	DIG_IO
IO_LEDS:defs	1	;LEDs
ENDIF
;
; !!! the order below is critical, do not move them !!!
CleanRP:defs	2	;CleanReqB	;read pointer
CleanWP:defs	2	;CleanReqB	;write pointer
PrioMask:defs	1	;0FFH	;used to filter user task priorities (1 to 127)
				;will be modified to 7FH after startup !
IdCnt:	defs	1	;1	;used to generate tasks ID
TasksCount:defs	1	;1	;All tasks counter

IF	DEBUG
tmpbuf:	defs	7	;0DH,0AH,4 blanks,!
ENDIF

ELSE	;--------------------------------------------------------------------------SIM

	psect	text

*Include simdata.as

ENDIF
;----------------------------------------------------------------------------------NOSIM

	psect	text

	GLOBAL __GetTaskSts,__SetTaskPrio,__GetTaskPrio,__RunTask
	GLOBAL __Suspend,__Resume,__StopTask
	GLOBAL __StartUp,__ShutDown,__BallocS,_InitBMem
	GLOBAL	RET_NULL,EI_RET_NULL,EI_RET_FFFF
	GLOBAL	Lists,L9,L0,Buddy
	GLOBAL	CON_IO_Wait_Sem,CON_IO_Req_Q,CON_IO_WP,CON_IO_RP,CON_Driver_IO
	GLOBAL	CON_IO_BS,CON_IO_BE,CON_IO_RS,CON_IO_WS
	GLOBAL	RETURN,RETI_RETURN
	GLOBAL	__GetCrtTask,__StackLeft,_GetTasksH,_GetAllTasksH
	GLOBAL ShutDownLoop,QuickStopTask
	GLOBAL __StopTaskTimer
	GLOBAL __KillTaskIO
;----------------------------------------------------------------------------------NOSIM
IF	NOSIM

IF	LPT
	GLOBAL	LPT_Sem,LPT_Timer,LPT_TimerSem,_PIO_INT
ENDIF

IF	WATSON .and. NOM512
	GLOBAL  Snapshot
ENDIF

IF	NOROM
	GLOBAL	_main
ENDIF

IF	DIG_IO
	GLOBAL	IO_LEDS
ENDIF

	GLOBAL	_CON_ESC,_CON_SRC
	GLOBAL	SIO_buf

ENDIF
;--------------------------------------------------------------------------------NOSIM
IF	C_LANG
	GLOBAL _GetHost
	GLOBAL _GetSemSts,_MakeSem,_DropSem,_Wait,_ResetSem,_Signal
	GLOBAL _GetTaskByID
	GLOBAL _StartUp,_ShutDown
	GLOBAL _GetTaskSts,_SetTaskPrio,_GetTaskPrio
	GLOBAL _RunTask,_GetCrtTask
	GLOBAL _IncTaskStack,_Suspend,_Resume,_StopTask,_ShutDown,_GetCrtTask,_StackLeft
ENDIF
	GLOBAL IsItTask,IsItActiveTask,IsSuspended
	GLOBAL	SIO_WP,SIO_RP,EchoStatus
	GLOBAL	LastActiveTCB,TicsCount,Counter,SecondCnt,RoundRobin
	GLOBAL	RET_NULL,EI_RET_NULL
	GLOBAL CON_CrtIO,CON_Count,_CON_TX,_CON_RX
	GLOBAL RTC_Header
	GLOBAL CleanWP,CleanRP,ClearAllGarbage
	GLOBAL __GetSemSts,__MakeSem,__DropSem,__InitSem,__InitSetSem,__Wait,__ResetSem
	GLOBAL __Signal,Resch_or_Res,_Reschedule,QuickSignal
	GLOBAL RETURN,RETI_RETURN,_ReschINT,_ResumeTask
	GLOBAL __GetHost
	GLOBAL __Balloc,__Bdealloc
	GLOBAL __InitL,__AddToL,__RemoveFromL,__FirstFromL,__LastFromL,__NextFromL
	GLOBAL __InsertInL,__GetFromL,__AddTask,__IncTaskStack
	GLOBAL _RunningTask,_TasksH,AllTasksH
	GLOBAL _GetID,__GetTaskByID
	GLOBAL _RTC_Int
IF	DEBUG
	GLOBAL IsItSem,tmpbuf,DE_hex,CON_Wr_Sch
ENDIF
	GLOBAL _InitialSP,_InitInts
	GLOBAL TCB_Default,TCB_Dummy
	GLOBAL pLists,def_sp,DefSP,def_sem,DefaultStart
	GLOBAL CON_Driver_TCB,CMD_TCB,PrioMask,TasksCount,IdCnt
IF	NOSIM
	GLOBAL CleanReqB
ENDIF
IF	BDOS
	GLOBAL BDOS_Sem
ENDIF
IF	SIO_RING
	GLOBAL	GetSIOChars
ENDIF
IF	CMD
	GLOBAL _CMD_Task
ENDIF
IF	SIM
SIO_buf         equ     7E00H
ENDIF
IF	EXTM512
	GLOBAL __RunTask512
IF	C_LANG
	GLOBAL _RunTask512
ENDIF
	GLOBAL __Init512Banks
ENDIF

;----------------------------------------------------------------------------------SIM
IF	SIM
;
;	Default task
;
DefaultStart:
	ld	a,(CON_CrtIO)		;check current CON I/O opcode
	cp	IO_RAW_READ
	jr	nz,nothing		;if not IO_RAW_READ, nothing to simulate
	ld	a,(CON_Count)
	or	a
	jr	z,nothing		;if I/O counter zero, nothing to simulate
	call	_CON_RX			;if IO_RAW_READ, go to RX interrupt, no echo, uses 14H stack space
nothing:
	di
	call	ClearAllGarbage		;clean all garbage
	ei
	nop		
	jr	z,DefaultStart		;if shutdown marker found...
	di				;DISABLE Interrupts	
RETURN:					;return to the caller of StartUp
	call	StopHardware		;shutdown the hardware interrupt sources
	ld	sp,(_InitialSP)		;restore initial SP
	POP_REGS
	ret				;Interrupts still DISABLED
;
_InitInts:
	di				;disable interrupts
IF	Z80SIM_CHECK
	ld	hl,0FB11H		;check for Udo!
	ld	a,(hl)
	cp	'U'
	jr	nz,notz80sim
	inc	hl
	ld	a,(hl)
	cp	'd'
	jr	nz,notz80sim
	inc	hl
	ld	a,(hl)
	cp	'o'
	jr	z,z80sim
notz80sim:				;NOT in Z80SIM
	ld	hl,msgNotZ80SIM		;write err msg
loopq:	
	ld	a,(hl)
	or	a
	jr	z,rebootcpm
	ld	e,a
	ld	c,2
	push	hl
	call	5
	pop	hl
	inc	hl
	jr	loopq
rebootcpm:
	ld	c,0
	call	5
msgNotZ80SIM:
	defb	0dh,0ah
	defm	'Must be executed under Z80SIM, quitting!'
	defb	0
z80sim:
ENDIF	;Z80SIM_CHECK			
	ld	a,0C3H			;valid ONLY for Z80SIM
	ld	(38H),a			;RTC int at RST 38H
	ld	hl,_RTC_Int
	ld	(39H),hl
	ld	a,1			;start RTC ints
	out	(27),a
	im	1
	ret
;
StopHardware:
					;valid ONLY for Z80SIM
	xor	a			;stop RTC ints
	out	(27),a
	ret
;
;	Forced exit from an interrupt, quitting RTM/Z80
;	called under DI
;
RETI_RETURN:
	call	StopHardware	;shutdown the hardware interrupt sources
	ld	sp,(_InitialSP)	;restore initial SP
	POP_REGS
	reti			;Interrupts remain DISABLED
;
ELSE	;--------------------------------------------------------------------------NOSIM

SIO_A_TAB:
	defb	00011000B	;WR0 Channel reset
	defb	00010100B	;Wr0 Pointer R4 + reset ex st int
IF	Z80ALL
        defb    01000100B       ;Wr4 /16, async mode, 1 stop bit, no parity
ELSE
	defb	11000100B	;Wr4 /64, async mode, 1 stop bit, no parity
ENDIF
	defb	00000011B	;WR0 Pointer R3
	defb	11100001B	;WR3 8 bit, Auto enables, Receive enable
	defb	00000101B	;WR0 Pointer R5
	defb	11101010B	;WR5 DTR, 8 bit, Transmit enable, RTS
	defb	00010001B	;WR0 Pointer R1 + reset ex st int
	defb	00011010B	;WR1 interrupt on all RX characters, TX Int enable
SIO_A_END:			;parity error is not a Special Receive condition

SIO_B_TAB:
	defb	00011000B	;WR0 Channel reset
	defb	00000010B	;WR0 Pointer R2
	defb	00010000B	;WR2 interrupt address = 10H
	defb	00010100B	;Wr0 Pointer R4 + reset ex st int
IF	Z80ALL
        defb    01000100B       ;Wr4 /16, async mode, 1 stop bit, no parity
ELSE
	defb	11000100B	;Wr4 /64, async mode, 1 stop bit, no parity
ENDIF
	defb	00000011B	;WR0 Pointer R3
	defb	11000000B	;WR3 8 bit
	defb	00000101B	;WR0 Pointer R5
	defb	01100000B	;WR5 8 bit
	defb	00010001B	;WR0 Pointer R1 + reset ex st int
	defb	00000100B	;WR1 no INTS on channel B, status affects INT vector
SIO_B_END:			;INTs: BTX,BE/SC,BRX,BSRC,ATX,AE/SC,ARX,ASRC
;

IF	LPT
PIO_A_TAB:
	defb	11001111B	;mode=control
	defb	00000011B	;bit 0 & 1 = inputs, bit 2 to 7 = outputs
				;BIT 0 = BUSY
				;BIT 1 = ACK
				;BIT 2 = STROBE
	defb	00001000B	;interrupt vector offset at 8H
	defb	10010111B	;interrupt control word: enable int, OR, LOW, mask follows
	defb	11111101B	;INT only for BIT 1 (ACK)
PIO_A_END:
ENDIF

ENDIF
;----------------------------------------------------------------------------------SIM

;
;	Get Current TCB ID
;
;	returns A=TCB_ID
;	HL,DE,IX,IY not affected
;	A, BC affected
;
_GetID:
	ld	bc,(_RunningTask)
	ld	a,ID_OFF
	add	a,c
	ld	c,a
	ld	a,(bc)		;A=TCB ID
	ret
;
;	Get Host 
;
;	returns HL=0 : Z80SIM , HL=1 : RC2014
;
IF	C_LANG
_GetHost:
ENDIF
__GetHost:
IF	SIM
	ld	hl,0
ELSE
IF	Z80ALL
	ld	hl,2
ELSE
	ld	hl,1
ENDIF
ENDIF
	ret
;
IF	C_LANG
;
;	GetTaskByID
;
;short	GetTaskByID(short id);
;	returns HL=TCB or 0 if not found
;
_GetTaskByID:
	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	call	__GetTaskByID
	ret	nz
	jp	RET_NULL
ENDIF
;
;	Search task with ID=C
;	return Z=1 & HL=0 : no TCB was found, else Z=0 & HL=TCB
;	AF,HL,DE affected
;
__GetTaskByID:
        ld      hl,AllTasksH
	ld	d,h
	ld	e,l		;DE=tasks header
NxT:  	ld      a,(hl)		;get next in list
        inc     l
        ld      h,(hl)          
	ld	l,a		;HL=TCB+NXPV_OFF
	push	hl
	or	a		;CARRY=0
        sbc     hl,de
	pop	hl
        ret	z	        ;if next=header, return Z=1
	dec	l		;HL=ID pointer
	ld	a,(hl)		;A=Crt ID
	inc	l		;HL=TCB+NXPV_OFF
	cp	c		;equal to target ID?
	jr	nz,NxT
	ld	a,l
	sub	NXPV_OFF
	ld	l,a
	or	h		;HL=TCB, Z=0
	ret
;
;	Get Sem Status
;short	GetSemSts(void* S)
;	returns HL=-1 : no sem, else HL=sem counter
IF	C_LANG
_GetSemSts:
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
ENDIF
__GetSemSts:			;HL=Sem
	di
IF	DEBUG
	call	IsItSem
	jp	nz,EI_RET_FFFF
ENDIF
	ld	a,l
	add	a,COUNTER_OFF
	ld	l,a
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a
	ei
	ret			;HL=counter
;	
IF	C_LANG
;
;	Create semaphore
;
;void*	MakeSem(void);
;	AF,BC,DE,HL,IX,IY not affected
;	returns HL = SemAddr or NULL if alloc failed
;
_MakeSem:
	push	af
	push	bc
	push	de
	call	__MakeSem
	pop	de
	pop	bc
	pop     af
	ret
;
;	Reset Semaphore
;
;void*	ResetSem(void* Semaphore)
;	returns HL=0 if task is waiting for semaphore, else not NULL
;
_ResetSem:
	push	af
	push	bc
	push	de
	ld	hl,8
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	__ResetSem
	pop	de
	pop	bc
	pop	af
	ret
ENDIF
;
;	Create semaphore - internal
;
;	return Z=0 & HL=SemAddr or Z=1 & HL=0 if alloc failed
;	affects A,BC,DE,HL
;
__MakeSem:
	ld	c,0		;alloc 10H
	di
	call	__Balloc
	jr	z,1f		;if alloc failed, return 0
				;HL=block addr
	ld	a,B_H_SIZE
	add	a,l
	ld	l,a		;HL=sem addr=list header addr	
	call	__InitSem
1:	ei
	ret
;
;	Initialize semaphore - internal
;
;	called under DI
;	HL=SemAddr
;	return HL=SemAddr
;	does not affect BC
;
__InitSem:
	call	__InitL
	ld	a,COUNTER_OFF
	add	a,l
	ld	l,a		;HL=Sem counter pointer
	xor	a		;A=0
	ld	(hl),a		;Sem counter = 0
setcnth:inc	l
	ld	(hl),a
	ld	a,l
	sub	COUNTER_OFF+1	;Z=0 if called from MakeSem !!!
	ld	l,a		;HL=SemAddr
	ret
;
;	Initialize semaphore and set its counter - internal
;
;	called under DI
;	HL=SemAddr, C=counter
;	return HL=SemAddr
;	does not affect BC
;
__InitSetSem:
	call	__InitL
	ld	a,COUNTER_OFF
	add	a,l
	ld	l,a		;HL=Sem counter pointer
	ld	(hl),c		;Set Sem counter
	xor	a
	jr	setcnth
;
;	Reset Semaphore - internal
;
;	HL = semaphore
;	returns HL=0 if task is waiting for semaphore, else not NULL
;
__ResetSem:
	di
IF	DEBUG
	push	hl
	ld	c,(hl)
	inc	l
	ld	b,(hl)		;BC=first in sem list
	scf			;CARRY=1
	sbc	hl,bc		;is it equal to sem?
	pop	hl
	jr	z,1f		;yes, it's a semaphore
;								DIG_IO
IF DIG_IO
	ld	a,(IO_LEDS)
	set	ERR_SEM,a
	ld	(IO_LEDS),a
	out	(LED_PORT),a
ENDIF
;								DIG_IO
	jp	EI_RET_NULL	;task is waiting for semaphore, return 0
1:
ENDIF	;DEBUG
	call	__InitSem
	ei
	ret
;
IF	C_LANG
;
;	Drop Semaphore
;
;short	DropSem(void* SemAddr)
;	AF,BC,DE,HL,IX,IY not affected
;	returns HL=0 if not a semaphore, else 1
;
DropSaddr	equ	8
;
_DropSem:
	push	de
	push	bc
	push	af
	ld	hl,DropSaddr
	add	hl,sp		;stack=AF,BC,DE,retaddr,Sem addr
	ld      a,(hl)
	inc	hl
	ld      h,(hl)
	ld	l,a		;HL=Sem list header pointer
	call	__DropSem
	pop     af
	pop	bc
	pop	de
	ret
ENDIF
;
;	Internal Drop Semaphore 
;
;	HL=Sem addr
;	returns HL=0 if not a semaphore or task is waiting for semaphore, else 1
;	Affected regs: A,BC,DE,HL
;	IX,IY not affected
;
__DropSem:
	di
;										DEBUG
IF	DEBUG
	call	IsItSem
	jr	z,1f
;								DIG_IO
IF DIG_IO
	ld	a,(IO_LEDS)
	set	ERR_SEM,a
	ld	(IO_LEDS),a
	out	(LED_PORT),a
ENDIF
;								DIG_IO
	jp	EI_RET_NULL	;no, it is no a semaphore, return 0
1:
	push	hl
IF	NORSTS
	call	__FirstFromL
ELSE
	RST	0
ENDIF
	pop	hl
	jp	nz,EI_RET_NULL	;if task list not empty, cannot drop semaphore
	ld	c,0		;10H
ENDIF	;DEBUG
;										DEBUG
	ld	a,l
	sub	B_H_SIZE
	ld	l,a		;HL=10H block addr
	call	__Bdealloc	;deallocate-it
	ei
	ret
;
IF	C_LANG
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
	PUSH_REGS
	ld	hl,SigSem
	add	hl,sp		;stack=AF,BC,DE,HL,IX,IY,retaddr,Sem addr
	ld      a,(hl)
	inc	hl
	ld      h,(hl)
	ld	l,a		;HL=Sem list header pointer
	di
;										DEBUG
IF	DEBUG
	call	IsItSem
	jr	z,1f
;								DIG_IO
IF DIG_IO
	OUT_LEDS ERR_SEM
ENDIF
;								DIG_IO
				;no, it is not a semaphore, return 0
	xor	a		;Z=1 to just resume current task
	ld	h,a
	ld	l,a		;return HL=0
	jp	Resch_or_Res
1:
ENDIF
;										DEBUG
	call	QuickSignal
				;Z=0? (TCB was inserted into active tasks list?)
	jp	Resch_or_Res	;yes : reschedule, else just resume current task
ENDIF
;
;	Signal semaphore internal
;
;	HL=Semaphore address
;	return CARRY=1 if wrong semaphore address provided, else CARRY=0
;
__Signal:
	di
;										DEBUG
IF	DEBUG
	call	IsItSem
	jr	z,1f
;						DIG_IO
IF DIG_IO
	OUT_LEDS ERR_SEM
ENDIF
;						DIG_IO
	scf			;no, it is not a semaphore, return CARRY=1
	ei
	ret
1:
ENDIF
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
IF	RSTS
	RST	40
ELSE
	call	__GetFromL
ENDIF
	pop	de		;DE = Sem list header pointer, Z=0 & HL=first TCB or Z=1 & HL=0
	jr	z,1f

IF	SYSSTS
	OffWait
ENDIF

	push	hl		;HL=TCB
	ld	a,WAITSEM_OFF
	add	a,l
	ld	l,a		;HL=pointer to WaitSem
	xor	a
	ld	(hl),a		;Set WaitSem=0
	inc	l
	ld	(hl),a
	pop	bc		;BC=TCB
IF	SIO_RING
	call	GetSIOChars
ENDIF
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
IF	C_LANG
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
	PUSH_REGS
IF	SIM
lwait1:	ld	a,(CON_CrtIO)
	cp	IO_IDLE
	jr	z,nowait1
IF	IO_COMM
	cp	IO_RAW_READ
	jr	z,nowait1
ENDIF
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
ENDIF	
	ld	hl,WaitSem
	add	hl,sp		;stack=AF,BC,DE,HL,IX,IY,retaddr,Sem addr
	ld      a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=Sem list header pointer
	di
;										DEBUG
IF	DEBUG
	call	IsItSem
	jr	z,1f
;									DIG_IO
IF DIG_IO
	OUT_LEDS ERR_SEM
ENDIF
;									DIG_IO
				;no, it is not a semaphore, return 0
	xor	a		;Z=1 to just resume current task
	ld	h,a
	ld	l,a		;return HL=0
	jp	Resch_or_Res
1:
ENDIF
;										DEBUG
	call	QuickWait
				;Z=0? (TCB was inserted into sem list?)
	jp	Resch_or_Res	;yes : reschedule, else just resume current task
ENDIF
;
;	Wait Semaphore - internal
;
;	HL=SemAddr
;	return CARRY=1 if wrong semaphore address provided, else CARRY=0
;
__Wait:
IF	SIM
lwait:	ld	a,(CON_CrtIO)
	cp	IO_IDLE
	jr	z,nowait
IF	IO_COMM
	cp	IO_RAW_READ
	jr	z,nowait
ENDIF
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
ENDIF	
	di
;										DEBUG
IF	DEBUG
	call	IsItSem
	jr	z,1f
;									DIG_IO
IF DIG_IO
	OUT_LEDS ERR_SEM
ENDIF
;									DIG_IO
	scf			;no, it is not a semaphore, return CARRY=1
	ei
	ret
1:
ENDIF
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
IF	SIO_RING
	call	GetSIOChars
ENDIF
	ld	hl,(_RunningTask)
	push	hl		;HL=current active task TCB on stack
				;store SemAddr stored to WaitSem
	ld	a,WAITSEM_OFF
	add	a,l
	ld	l,a		;HL=pointer to WaitSem
	ld	(hl),e
	inc	l
	ld	(hl),d		;SemAddr stored to WaitSem
IF	SIO_RING
	call	GetSIOChars
ENDIF
	ex	de,hl		;HL=SemAddr
	ex	(sp),hl		;HL=TCB, SemAddr on stack

IF	SYSSTS
	OnWait
ENDIF

IF	RSTS
	RST	32
ELSE
	call	__RemoveFromL	;remove current active task TCB from active tasks list
ENDIF
	ld	b,h		;returned HL=TCB
	ld	c,l		;BC=active task TCB
IF	SIO_RING
	call	GetSIOChars
ENDIF
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
IF	SIO_RING
	call	GetSIOChars
ENDIF
				;prepare current task stack to resume later
	ld	hl,0		;save SP to current TCB
	add	hl,sp
	ex	de,hl		;DE = current SP 
	ld	hl,(_RunningTask)

IF	SYSSTS
	OffRun
ENDIF

	ld	a,SP_OFF	;save SP of the running task	
	add	a,l
	ld	l,a		;HL= pointer to Running Task's StackPointer
	ld	(hl),e
	inc	l
	ld	(hl),d		;SP is saved
				;now give control to first TCB from active tasks list
IF	SIO_RING
	call	GetSIOChars
ENDIF
	ld	hl,_TasksH
IF	NORSTS
	call	__FirstFromL
ELSE
	RST	0
ENDIF
				;returns HL=first active TCB
	jp	z,RETURN	;if HL NULL, return to the caller of the StartUp
				;if HL not NULL, go set new current active task
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
	ld	(_RunningTask),hl;save current TCB

IF	SYSSTS
	OnRun
ENDIF

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
IF DEBUG
				;CARRY=0
	ld	bc,50H
	sbc	hl,bc		;HL(SP)=HL(SP)-50H
				;DE=crt TCB
	sbc	hl,de
	jr	nc,_ResumeTask
				;stack space < 50H (!!! this means < 34H safe space !!!)
;							DIG_IO
IF DIG_IO
	OUT_LEDS ERR_STACK
ENDIF
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
ENDIF
;									DEBUG
;	called under DI
;
_ResumeTask:			;enters with di called
IF	SIO_RING
	call	GetSIOChars
ENDIF
IF	EXTM512
	ld	hl,(_RunningTask)
	ld	a,l
	add	ROMBANK_OFF
	ld	l,a
	ld	a,(hl)		;0 or ROMBank
	or	a
	jr	z,notROMtask	;if not zero...
	out	(P_BASE+1),a	;set ROMBank at 4000H
notROMtask:
ENDIF
	POP_REGS
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
IF	SIO_RING
	call	GetSIOChars
ENDIF
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
IF	SIO_RING
	call	GetSIOChars
ENDIF
	ld	hl,_TasksH
IF	NORSTS
	call	__FirstFromL
ELSE
	RST	0
ENDIF
				;returns HL=first active TCB
	jp	z,RETI_RETURN	;if HL NULL, return to the caller of the StartUp
				;if HL not NULL, set HL as new current active task
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
	ld	(_RunningTask),hl;save current TCB
	ld	a,SP_OFF
	add	a,l
	ld	l,a		;HL = pointer to current task SP
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a		;HL = current task SP
	ld	sp,hl		;SP is restored
IF	SIO_RING
	call	GetSIOChars
ENDIF
	POP_REGS
	ei
	reti
;
;	Start Up - internal
;	used to initialize system and run the specified task
;
;	BC=stack size, HL=StartAddr, E=Priority
;	return HL=task TCB or 0 if alloc failed
;
__StartUp:
	PUSH_REGS
SavePars:
;				DIG_IO
IF	DIG_IO
	SET_LEDS 1
ENDIF
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
IF	NOSIM
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
IF	LPT
	ld	hl,LPT_Sem
	ld	(LPT_Sem),hl
	ld	(LPT_Sem+2),hl
	ld	hl,LPT_TimerSem
	ld	(LPT_TimerSem),hl
	ld	(LPT_TimerSem+2),hl
	ld	hl,0
	ld	(LPT_TimerSem+4),hl
	inc	hl
	ld	(LPT_Sem+4),hl
ENDIF
IF	DEBUG
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
ENDIF
ENDIF
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
IF	BDOS
	ld	(hl),1
ELSE
	ld	(hl),a
ENDIF
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
IF	EXTM512
	ld	c,7		;alloc 800H for 512KB dynamic memory data structures
	call	__Balloc
	call	__Init512Banks	;init 512KB dynamic memory data structures
ENDIF

IF	SYSSTS
	call	DisplaySysScr
	ld	bc,TCB_Default
	AddTask
ENDIF
				;prepare params for RunTask CON driver
	ld	de,250		;E=CON driver priority,D=0(RAM resident)
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
IF	CMD				
				;prepare params for RunTask CMD handler
	push	hl		;push params
	push	bc
	push	de
	ld	de,240		;E=CMD handler priority,D=0(RAM resident)
	ld	hl,_CMD_Task	;CMD handler StartAddr
	ld	bc,60H		;CMD handler stack size
	call	QuickRunTask	;RunTask CMD handler
	ld	(CMD_TCB),hl	;save CMD handler TCB
				;RunTask CMD handler was ok?
	pop	de
	pop	bc
	pop	hl
	jp	z,Resch_or_Res	;no, return Z=1 and HL=0 to caller
ENDIF
;										CMD
	ld	a,7FH
	ld	(PrioMask),a	;set new mask to filter the user task priorities
				;now RunTask with provided params
	ld	d,0		;RAM resident
	call	QuickRunTask
	jp	Resch_or_Res
;	
IF	C_LANG
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
	PUSH_REGS
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
	PUSH_REGS
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
	ld	d,0		;RAM resident
	call	QuickRunTask	;return HL=task TCB or 0 if alloc failed
	jp	Resch_or_Res	;if TCB was inserted into active tasks list, reschedule
				;else, resume current running task
ENDIF
;
IF	EXTM512 .and. C_LANG
;
;	Run Task 512
;
;short	RunTask512(short stack_size, void* StartAddr, short Prio, short ROMBank);
;	AF,BC,DE,HL,IX,IY not affected
;	return HL=task TCB and Z=0 or HL=0 and Z=1 if alloc failed
;
_RunTask512:
	PUSH_REGS
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
	inc	hl
	inc	hl
	ld	h,(hl)		;H=ROMBank
	ex	de,hl		;HL=task Start Addr, D=ROMBank
	ld	e,a		;E=Prio
	di
	call	QuickRunTask	;return HL=task TCB or 0 if alloc failed
	jp	Resch_or_Res	;if TCB was inserted into active tasks list, reschedule
				;else, resume current running task
ENDIF
;
;	Run Task - internal
;
;	BC=stack size, HL=StartAddr, E=Priority
;	return HL=task TCB or 0 if alloc failed
;
__RunTask:
	ld	d,0		;ROMBank=0 (task is resident in RAM)
IF	EXTM512
__RunTask512:			;D=ROMBank
ENDIF
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
;	BC=stack size, HL=StartAddr, E=Priority(, D=ROMBank if EXTM512)
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
	push	de		;E=Prio(, D=ROMBank if EXTM512)
	push	hl		;HL=StartAddr
IF	SIO_RING
	call	GetSIOChars
ENDIF
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
IF	SIO_RING
	call	GetSIOChars
ENDIF
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
	pop	bc		;C=Prio(, B=ROMBank if EXTM512)
	push	hl		;TCB on stack
IF	EXTM512
	ld	a,ROMBANK_OFF
	add	a,l
	ld	l,a		;HL=pointer to ROMBank
	ld	(hl),b		;save ROMBank in TCB
	pop	hl		;HL=TCB
	push	hl		;TCB on stack
ENDIF
	ld	a,PRI_OFF
	add	a,l
	ld	l,a		;HL=pointer to task priority
	ld	(hl),c		;save task priority in TCB
	inc	l		;HL=pointer of task SP
	ld	(hl),e		;set the SP
	inc	l
	ld	(hl),d
	inc	l		;HL=pointer to local semaphore
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
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
IF	SIO_RING
	call	GetSIOChars
ENDIF
	ld	hl,AllTasksH	;HL=Pointer to Header of all tasks list
IF	RSTS
	RST	24
ELSE
	call	__AddToL	;Add DE=task to HL=all tasks list
ENDIF
				;HL=pointer of (nextTask, PrevTask)
	ld	a,DLIST_H_SIZE	;skip (nextTask, PrevTask)
	add	a,l
	ld	l,a		;HL=pointer to WaitSem, CARRY=0
	xor	a
	ld	(hl),a
	inc	l
	ld	(hl),a		;WaitSem=0
	inc	l		;HL=pointer to ROMBank
	inc	l		;HL=pointer to StackWarning
	ld	(hl),a		;StackWarning=0
	pop	bc		;BC=TCB to be inserted into active tasks list
IF	SIO_RING
	call	GetSIOChars
ENDIF

IF	SYSSTS
	AddTask
ENDIF

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
IF	DEBUG
	push	bc		;TCB on stack
	call	IsItTask	;BC is a task TCB ?
	pop	bc		;BC=TCB
	jr	z,1f
IF DIG_IO
	OUT_LEDS ERR_TCB
ENDIF
	ld	hl,-1		;no, return -1
	ret
1:
ENDIF
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
	PUSH_REGS
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
	PUSH_REGS
setpri:	
	di
IF	DEBUG
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
IF DIG_IO
	OUT_LEDS ERR_TCB
ENDIF
3:	
	xor	a		;Z=1
	ld	h,a
	ld	l,a		;HL=0
	jp	Resch_or_Res	;Z=1, resume crt task & return HL=0
1:				;yes, TCB is ok
ENDIF
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
IF	C_LANG
_GetTaskSts:
	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
ENDIF
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
IF	C_LANG
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
ENDIF
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
IF	EXTM512
	push	hl		;new TCB on stack
	ld	a,ROMBANK_OFF
	add	a,c
	ld	c,a		;BC=pointer of old ROMBank
	ld	a,ROMBANK_OFF
	add	a,l
	ld	l,a		;HL=pointer of new ROMBank
	ld	a,(bc)
	ld	(hl),a		;new ROMBank=old ROMBank
	pop	hl		;HL=new TCB
	ld	bc,(_RunningTask);BC=old TCB
ENDIF
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
IF	SIO_RING
	call	GetSIOChars
ENDIF
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
	inc	l		;HL=pointer of new ROMBank
	inc	l		;HL=pointer of new StackWarning
	ld	(hl),a		;Init new StackWarning
IF	SIO_RING
	call	GetSIOChars
ENDIF
	ld	hl,(_RunningTask);remove old TCB from active tasks list
IF	RSTS
	RST	32
ELSE
	call	__RemoveFromL
ENDIF
				;HL is still = old TCB
				;remove old TCB from all tasks list
	ld	a,NXPV_OFF
	add	a,l
	ld	l,a		;HL=pointer of old (nextTask,prevTask)
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
IF	RSTS
	RST	32
ELSE
	call	__RemoveFromL
ENDIF
IF	SIO_RING
	call	GetSIOChars
ENDIF
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
IF	RSTS
	RST	24
ELSE
	call	__AddToL	;Add DE=task to HL=all tasks list
ENDIF
IF	DEBUG
	pop	af		;A=old TCB bSize
	push	af		;back on stack
	ld	c,a		;C=old TCB bSize
ENDIF
IF	SIO_RING
	call	GetSIOChars
ENDIF
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
IF	SIO_RING
	call	GetSIOChars
ENDIF
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
IF	C_LANG
;
;	Suspend current task
;
;void	Suspend(void);
;	AF,BC,DE,HL,IX,IY not affected
;
_Suspend:
	PUSH_REGS
	call	__Suspend
	POP_REGS
	ret
ENDIF
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
IF	DEBUG
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
ENDIF
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
IF	C_LANG
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
	PUSH_REGS
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
	PUSH_REGS
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
ENDIF
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
IF	DEBUG
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
IF DIG_IO
	OUT_LEDS ERR_TCB
ENDIF
	jp	RET_NULL
1:
ENDIF
;										DEBUG
	push	hl		;HL=TCB on stack
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
IF	RSTS
	RST	32
ELSE
	call	__RemoveFromL	;remove from active tasks list or waiting for semaphore list
ENDIF
				;HL is still = TCB
	ld	a,NXPV_OFF
	add	a,l
	ld	l,a		;HL=pointer of (nextTask,prevTask)
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
IF	RSTS
	RST	32
ELSE
	call	__RemoveFromL	;remove from all tasks list
ENDIF
IF	SIO_RING
	call	GetSIOChars
ENDIF
	pop	hl		;HL=TCB
	push	hl		;on stack
;										DEBUG
IF	DEBUG
	ld	a,BLOCKSIZE_OFF
	add	a,l
	ld	l,a		;HL=pointer of block size
	ld	c,(hl)		;C=TCB block size
	pop	hl		;HL=TCB
	push	hl		;keep it on stack
ENDIF
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
IF	C_LANG
_ShutDown:
ENDIF
	di
ShutDownLoop:			;loop
	ld	a,(TasksCount)
	cp	1		;only Default task remaining?
	jr	z,2f
				;no, there are still other tasks remaining...
	ld	hl,AllTasksH	;HL=all tasks list header
IF	RSTS
	RST	8
ELSE
	call	__LastFromL	;HL=Get last task
ENDIF
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
IF	C_LANG
_GetCrtTask:
ENDIF
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
;
