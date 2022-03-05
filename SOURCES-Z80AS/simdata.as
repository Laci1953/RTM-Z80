;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	Z80SIM version - Kernel data - will be placed at 7F00H
;	Must fit into 100H !!!
;
SIO_buf         equ     7E00H

BASE_DATA	equ	7F00H
;
AllTasksH	equ	BASE_DATA	;All tasks list header
				;defw	TCB_Default+NXPV_OFF
				;defw	TCB_Default+NXPV_OFF
_TasksH		equ	BASE_DATA+4	;active tasks TCB's priority ordered list header
				;defw	TCB_Default
				;defw	TCB_Default
_RunningTask	equ	BASE_DATA+8	;current active task TCB
				;defw	TCB_Dummy
pLists		equ	BASE_DATA+0AH	;pointer of list of headers for free mem blocks
				;defw	Lists
RTC_Header	equ	BASE_DATA+0CH	;Real Time clock control blocks list header
				;defw	RTC_Header 
				;defw	RTC_Header
TCB_Default	equ	BASE_DATA+10H	;TCB of default task
;bElement header
;	defw	_TasksH	;void* next;
;	defw	_TasksH	;void* prev;
;	defb	1	;char AllocStatus; 
;	defb	3	;char BlockSize; set for a TCB with size 80H, but NOT NEEDED
;	defb	0	;char Priority=0;
DefSP		equ	BASE_DATA+17H	;defw	def_sp	;void* StackPointer;
;local semaphore
IF	BDOS
BDOS_Sem	equ	BASE_DATA+19H
ENDIF
def_sem		equ	BASE_DATA+19H
;	defw	def_sem	;void*	first;
;	defw	def_sem	;void*	last;
;	defw	0	;short	Counter;
;	defb	1	;ID=1
;	defw	AllTasksH;nextTask
;	defw	AllTasksH;prevTask
;	defw	0	;WaitSem
;	defb	0	;ROMBank
;	defb	0	;StackWarning
;	;local stack area (we need here ~ 60H bytes)
;Memory garbage cleaner requests buffer
;				;contains TCB ID(<0FFH) to clean 
;				;or 0FFH to stop cleaning and quit Default task
;	defs	20H
TCB_Dummy	equ	BASE_DATA+48H	;TCB of dummy task - discarded after first StartUp call (10H here)
		;placed here to gain some stack space for Default Task
;	defs	2	;void* next;
;	defs	2	;void* prev;
;	defs	1	;char AllocStatus; 
;	defs	1	;char BlockSize; 
;	defs	1	;char Priority;
;	defs	2	;void* StackPointer;
;			;local semaphore
;	defs	2	;void*	first;
;	defs	2	;void*	last;
;	defs	2	;short	Counter;
;	BASE_DATA+57H (TCB_Dummy+15)
;	defb	1	;ID=1 to be used at first allocs 
			;(that's why TCB_Dummy is needed !)
;	defs	2DH	;this will be the impacted area of stack (2DH here)
def_sp	equ	BASE_DATA+85H		;0EH here = TOTAL ~ 70H
;	defw	0	;IY
;	defw	0	;IX
;	defw	0	;BC
;	defw	0	;DE
;	defw	0	;HL
;	defw	0	;AF
;	BASE_DATA+91H (def_sp+12)
;	defw	DefaultStart	;Default Task start address
					;Available block list headers
L0	equ	BASE_DATA+93H	;	defw	L0	;size=0(=10H)
				;	defw	L0
L1	equ	L0+4		;	defw	L1	;size=1(=20H)
				;	defw	L1
L2	equ	L1+4		;	defw	L2	;size=2(=40H)
				;	defw	L2
L3	equ	L2+4		;	defw	L3	;size=3(=80H)
				;	defw	L3
L4	equ	L3+4		;	defw	L4	;size=4(=100H)
				;	defw	L4
L5	equ	L4+4		;	defw	L5	;size=5(=200H)
				;	defw	L5
L6	equ	L5+4		;	defw	L6	;size=6(=400H)
				;	defw	L6
L7	equ	L6+4		;	defw	L7	;size=7(=800H)
				;	defw	L7
L8	equ	L7+4		;	defw	L8	;size=8(=1000H)
				;	defw	L8
L9	equ	L8+4		;	defw	L9	;size=9(=2000H)
				;	defw	L9
Lists	equ	L9+4		;	defw	L0,L1,L2,L3,L4,L5,L6,L7,L8,L9
				;Buddy block sizes
Buddy	equ	Lists+20	;	defw	10H,20H,40H,80H,100H,200H,400H,800H,1000H,2000H
;
CON_IO_Wait_Sem	equ	Buddy+20;	defs    6	;CON Driver Local semaphore

CON_IO_Req_Q	equ	CON_IO_Wait_Sem+6	
					;CON Device driver I/O queue
CON_IO_WP	equ	CON_IO_Req_Q	;	defs	2	;write pointer
CON_IO_RP	equ	CON_IO_WP+2	;	defs	2	;read pointer
CON_IO_BS	equ	CON_IO_RP+2	;	defs	2	;buffer start
CON_IO_BE	equ	CON_IO_BS+2	;	defs	2	;buffer end
	  				;	defs	1	;balloc size
	  				;	defs	2	;batch zize (allways 8)
CON_IO_RS	equ	CON_IO_BE+2+1+2	;	defs	6	;read sem
CON_IO_WS	equ	CON_IO_RS+6	;	defs	6	;write sem
;
;	we are at BASE_DATA+256 !!!
;	do not add any other data
;
CleanReqB	equ	7D00H	;Memory garbage cleaner requests buffer
				;contains TCB ID to clean 
				;or 0 to stop cleaning and quit Default task
;
;	remaining data placed in section 'text'
;
CON_Driver_TCB:	defs	2	;CON Driver TCB

CMD_TCB:	defs	2	;CMD task TCB

_InitialSP:	defs	2	;SP of StartUp caller

; !!! the order below is critical, do not move them !!!
CleanRP:	defw	CleanReqB	;read pointer
CleanWP:	defw	CleanReqB	;write pointer
PrioMask:	defb	0FFH	;used to filter user task priorities (1 to 127)
				;will be modified to 7FH after startup !
IdCnt:		defb	1	;used to generate tasks ID
TasksCount:	defb	1	;All tasks counter
;
IF	DEBUG
tmpbuf:	defb	0DH,0AH
	defs	4
	defb	'!'
ENDIF
