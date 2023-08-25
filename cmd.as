;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
TITLE	CMD - Command utility task
;
*Include config.mac

IF	CMD

	GLOBAL _CMD_Task
	GLOBAL	ReadA
	GLOBAL	ReadBC
	GLOBAL	DE_hex
	GLOBAL	Byte_C_hex
	GLOBAL	StrUC
	GLOBAL	StrCmp
	GLOBAL	Lists,Buddy
	GLOBAL	_TasksH,AllTasksH
	GLOBAL	__StopTask
	GLOBAL __GetTaskByID
	GLOBAL __FirstFromL
	GLOBAL __NextFromL
	GLOBAL __GetTotalFree
	GLOBAL __StackLeft
	GLOBAL __CON_Read,__CON_Write
	GLOBAL __Wait
	GLOBAL __Suspend
	GLOBAL __Resume
	GLOBAL __SetTaskPrio
	GLOBAL __RoundRobinON
	GLOBAL __RoundRobinOFF
	GLOBAL __MakeSem
	GLOBAL __ShutDown
	GLOBAL	IsItTask,IsItActiveTask,IsSuspended

IF	IO_COMM
	GLOBAL	_ReadHEX
	GLOBAL	_C_Hex
ENDIF

PRI_OFF		equ	6	;Priority in TCB
SEM_OFF		equ	9	;LocalSemaphore in TCB
NXPV_OFF	equ	16	;(NextTask,PrevTask)
WAITSEM_OFF	equ	20	;WaitSem

	psect	bss

SemCmd:		defs	2
buf_con:	defs	81

;
;	big buffer
;
;used for MAP: storage for blanks and *
;used for ACT: records with structure = (TCB,Pri,StackLeft)
;used for TAS: records with structure = (TCB,Pri,StackLeft,Status(=1:active,2:susp,3:waiting),Sem(if not, 0))
;used for MEM: 
;	owned blocks: records with structure = (size:0=EOL,addr,tcb)
;	free blocks: records with structure = (size:0=EOL,addr,...,addr:0=EOL)
;
Big:		defs	512	;last two bytes == 0FFH as end-of-buf marker
;
addr:		defs	4
retHEX:		defs	2

	psect	text

C_msg:		defb	0DH,0AH,'>'
C_unknown:	defb	0DH,0AH
		defm	'Unknown command!'
C_unknown_l	equ	$-C_unknown
ACT:		defm	'ACT'
TAS:		defm	'TAS'
MAP:		defm	'MAP'
MEM:		defm	'MEM'
HEX:		defm	'HEX'
EXI:		defm	'EXI'
STP:		defm	'STP'
RESUME:		defm	'RES'
PRI:		defm	'PRI'
RRB:		defm	'RRB'
SHD:		defm	'SHD'

CRLF:
C_NotSuspended:	defb	0DH,0AH
		defm	'Task is not suspended, cannot resume-it!'
C_NotSuspend_l equ $-C_NotSuspended
C_NotTask:	defb	0DH,0AH
		defm	'No such task!'
C_NotTask_l equ	$-C_NotTask
C_SyntaxErr:	defb	0DH,0AH
		defm	'Syntax error!'
C_SyntaxErr_l equ	$-C_SyntaxErr
Sep:		defb	'|'
MMtitle:	defm	'Dynamic memory map (* = allocated 10H block)'
MMtitle_l	equ	$-MMtitle
Line:		defm	'     ______________+100____________+200____________+300______________'
Line_l	equ	$-Line
C_HexReady:	defb	0DH,0AH
		defm	'Ready to read HEX file (timeout=10 sec)'
C_HexReady_l	equ	$-C_HexReady
C_HexFailAll:	defb	0DH,0AH
		defm	'Alloc failed!'
C_HexFailAll_l equ	$-C_HexFailAll
C_HexBadChk:	defb	0DH,0AH
		defm	'Bad checksum!'
C_HexBadChk_l	equ	$-C_HexBadChk
C_HexTimeOut:	defb	0DH,0AH
		defm	'TimeOut!'
C_HexTimeOut_l equ	$-C_HexTimeOut
C_HexBadFile:	defb	0DH,0AH
		defm	'Could not reach end of Hex file!'
C_HexBadFile_l equ	$-C_HexBadFile
C_HexExecute:	defb	0DH,0AH
		defm	'Execute? (Y/N):'
C_HexExecute_l equ	$-C_HexExecute
C_Block:	defb	0DH,0AH
		defm	'Block of size '
C_Block_l	equ	$-C_Block
C_at_address:	defm	'H at address '
C_at_address_l equ	$-C_at_address
C_owned_by:	defm	'H owned by task with TCB '
C_owned_by_l	equ	$-C_owned_by
C_H:		defm	'H '
C_available:	defb	0DH,0AH
		defm	'Available blocks of size '
C_available_l equ	$-C_available
C_H_colon:	defm	'H :'
C_H_colon_l	equ	$-C_H_colon
C_Total_free:	defb	0DH,0AH
		defm	'Total free dynamic memory : '
C_Total_free_l equ	$-C_Total_free
C_Active:	defb	0DH,0AH
		defm	'Active tasks:'
C_Active_l	equ	$-C_Active
C_TCB:		defb	0DH,0AH
		defm	'TCB: '
C_TCB_l	equ	$-C_TCB
C_Priority:	defm	'H Priority: '
C_Priority_l	equ	$-C_Priority
C_FreeStack:	defm	'H Free Stack: '
C_FreeStack_l equ	$-C_FreeStack
C_AllTasks:	defb	0DH,0AH
		defm	'All tasks:'
C_AllTasks_l	equ	$-C_AllTasks
C_active:	defm	', running'
C_active_l	equ	$-C_active
C_suspended:	defm	', suspended'
C_suspended_l equ	$-C_suspended
C_waiting:	defm	', waiting for semaphore: '
C_waiting_l	equ	$-C_waiting

;
;	Write text
;
;	HL=pointer of text
;	C=length of text
;	IY not affected
;
WriteTxt:
	push	iy
	ld	de,(SemCmd)
	call	__CON_Write
	ld	hl,(SemCmd)
	call	__Wait
	pop	iy
	ret
;
;	check if (HL) == 0
;
CheckEOS:
	inc	hl
	inc	hl
	inc	hl
_CheckEOS:
	ld	a,(hl)
	or	a
	ret	z
	call	SyntaxErr
	pop	hl
	jp	loop

_C_MemoryMap:
	ld	hl,CRLF
	ld	c,2
	call	WriteTxt
	ld	hl,MMtitle
	ld	c,MMtitle_l
	call	WriteTxt
				;fill Big with blanks(free) or *(allocated)
	ld	ix,BMEM_BASE	;IX=pointer in dynamic mem
	ld	iy,Big		;IY=pointer in Big
	di
bigloop:
	ld	a,(ix+5)	;get block size
	ld	b,1
1:	or	a
	jr	z,3f
2:	sla	b
	dec	a
	jr	z,3f
	jr	2b
3:				;B = 1 << block size
	ld	a,(ix+4)	;get block status
	or	a
	ld	a,' '
	jr	z,4f
	ld	a,'*'
4:
	ld	(iy+0),a
	inc	iy
	djnz	4b
				;skip past block
	ld	hl,Buddy
	ld	a,(ix+5)
	add	a,a
	add	a,l
	ld	l,a
	ld	c,(hl)
	inc	l
	ld	b,(hl)		;BC=size of block
	add	ix,bc		;IX=IX+BC
IF	SIM
	ld	hl,BMEM_BASE+BMEM_SIZE
ELSE
	ld	hl,0
ENDIF
	push	ix
	pop	de		;DE=new pointer in dynamic mem
	or	a		;CARRY=0
	sbc	hl,de		;end of dynamic memory reached?
	jr	nz,bigloop	;if not reached, go check current block
	ei
				;type Big, formatted
	ld	hl,CRLF
	ld	c,2
	call	WriteTxt	;print CR,LF
	ld	hl,Line
	ld	c,Line_l
	call	WriteTxt	;print header
	ld	hl,CRLF
	ld	c,2
	call	WriteTxt	;print CR,LF

	ld	b,8		;loop counter
	ld	hl,Big		;HL=pointer in Big
	ld	de,BMEM_BASE	;DE=crt dyn mem pointer
loopw:
	push	bc
	push	de
	push	hl
	ld	hl,addr
	call	DE_hex		;store crt dyn mem pointer in addr as 4 hex digits
	ld	hl,addr
	ld	c,4
	call	WriteTxt	;print crt dyn mem pointer as hex 4 digits
	ld	hl,Sep
	ld	c,1
	call	WriteTxt	;print '|'
	pop	hl
	push	hl
	ld	c,64
	call	WriteTxt	;print 64 chars from Big
	ld	hl,Sep
	ld	c,1
	call	WriteTxt	;print '|'
	ld	hl,CRLF
	ld	c,2
	call	WriteTxt	;print CR,LF
	pop	hl
	pop	de
	ld	bc,64		;add 64 to pointer in Big
	add	hl,bc
	ex	de,hl
	ld	bc,400H		;add 400H to crt dyn mem pointer
	add	hl,bc
	ex	de,hl
	pop	bc
	djnz	loopw		;loop
	ld	hl,Line
	ld	c,Line_l
	jp	WriteTxt	;print header & return
;
_C_MemorySts:
	ld	ix,BMEM_BASE	;IX=pointer in dynamic mem
	ld	iy,Big		;IY=pointer in Big
	di
				;fill Big with owned block records
loopsts:
	ld	a,(ix+5)	;A=bSize
	add	a,a
	ld	hl,Buddy
	add	a,l
	ld	l,a
	ld	c,(hl)
	inc	l
	ld	b,(hl)		;BC=block size
	ld	a,(ix+4)	;A=block status or owner ID
	or	a
	jr	z,nxtblk	;if free, just skip-it
	push	ix		;block is allocated
	pop	de		;DE=block addr
	ld	(iy+0),c	;store size
	ld	(iy+1),b
	ld	(iy+2),e	;store addr
	ld	(iy+3),d
	push	bc		;block size on stack
	ld	c,a		;C=owner ID
	call	__GetTaskByID	;HL=owner TCB
	ld	(iy+4),l	;store tcb
	ld	(iy+5),h
	ld	a,(iy+6)	;check end-of-buffer mark
	and	(iy+7)
	cp	0FFH
	ld	bc,6		;increment records pointer
	add	iy,bc		;Z not affected
	pop	bc		;BC=block size
	jr	z,quitb		;end-of-buffer reached, quit filling
nxtblk:
	add	ix,bc		;IX=next block or end-of-dynamic-memory
IF	SIM
	ld	hl,BMEM_BASE+BMEM_SIZE
ELSE
	ld	hl,0
ENDIF
	push	ix
	pop	de		;DE=new pointer in dynamic mem
	or	a		;CARRY=0
	sbc	hl,de		;end of dynamic memory reached?
	jr	nz,loopsts	;if not reached, go check current block
quitb:
	xor	a
	ld	(iy+0),a	;store EOL
	ld	(iy+1),a
	ei
				;write owned records
	ld	iy,Big		;IY=pointer in Big
loopstsw:
	ld	e,(iy+0)
	ld	d,(iy+1)	;DE=size or EOL
	ld	a,e
	or	d
	jr	z,avail		;EOL reached, go check available blocks
	push	de		;size on stack
	ld	hl,C_Block
	ld	c,C_Block_l
	call	WriteTxt
	pop	de		;DE=block size
	ld	hl,addr
	call	DE_hex		;block size stored at addr in hex
	ld	hl,addr
	ld	c,4
	call	WriteTxt
	ld	hl,C_at_address
	ld	c,C_at_address_l
	call	WriteTxt
	ld	e,(iy+2)
	ld	d,(iy+3)	;DE=block addr
	ld	hl,addr
	call	DE_hex		;block addr stored at addr in hex
	ld	hl,addr
	ld	c,4
	call	WriteTxt
	ld	hl,C_owned_by
	ld	c,C_owned_by_l
	call	WriteTxt
	ld	e,(iy+4)
	ld	d,(iy+5)	;DE=tcb
	ld	hl,addr
	call	DE_hex		;tcb stored at addr in hex
	ld	hl,addr
	ld	c,4
	call	WriteTxt
	ld	hl,C_H
	ld	c,1
	call	WriteTxt
	ld	bc,6		;increment records pointer
	add	iy,bc
	jr	loopstsw
avail:				;walk through available blocks lists
	ld	b,10		;lists counter
	ld	hl,Lists	;pointer of lists headers
	ld	e,(hl)
	inc	l
	ld	d,(hl)
	ex	de,hl		;HL = first header
	ld	de,10H		;block size
	ld	iy,Big		;IY=pointer in Big
	di
				;fill Big with free block records (no overflow check !!!)
loopfree:
	push	bc		;lists counter on stack
	push	de		;block size on stack
	push	hl		;lists header on stack
IF	NORSTS
	call	__FirstFromL
ELSE
	RST	0
ENDIF
	jr	z,nxtl
				;HL=crt block
	pop	de
	pop	bc		;BC=block size
	push	bc
	push	de
	ld	(iy+0),c	;store size
	ld	(iy+1),b
	inc	iy
	inc	iy
nxtaddr:
	ld	(iy+0),l	;store addr
	ld	(iy+1),h
	inc	iy
	inc	iy	
	pop	de		;DE=crt header, HL=crt block
	push	de		;crt header back on stack
IF	RSTS
	RST	16
ELSE
	call	__NextFromL
ENDIF
				;HL=next block or NULL
	jr	nz,nxtaddr
	ld	(iy+0),l	;store addr EOL (HL=0)
	ld	(iy+1),h
	inc	iy
	inc	iy
nxtl:	
	pop	hl		;HL=header
	ld	a,4		;go to nex header
	add	a,l
	ld	l,a
	pop	de		;DE=block size
	sla	e
	rl	d		;DE=DE*2
	pop	bc
	djnz	loopfree
	xor	a
	ld	(iy+0),a	;store size EOL
	ld	(iy+1),a
	ei
				;write free blocks
	ld	iy,Big		;IY=pointer in Big
loopfreew:
	ld	e,(iy+0)
	ld	d,(iy+1)	;DE=size or EOL
	ld	a,e
	or	d
	jr	z,wrtot
	inc	iy
	inc	iy
	push	de		;size on stack
	ld	hl,C_available
	ld	c,C_available_l
	call	WriteTxt
	pop	de		;DE=size
	ld	hl,addr
	call	DE_hex
	ld	hl,addr		;write size
	ld	c,4
	call	WriteTxt
	ld	hl,C_H_colon
	ld	c,C_H_colon_l
	call	WriteTxt
loopaddrw:
	ld	e,(iy+0)
	ld	d,(iy+1)	;DE=addr or addr EOL
	inc	iy
	inc	iy
	ld	a,e
	or	d
	jr	z,loopfreew
	ld	hl,addr
	call	DE_hex
	ld	hl,addr		;write addr
	ld	c,4
	call	WriteTxt
	ld	hl,Line		;Line starts with blanks
	ld	c,1
	call	WriteTxt	;write a blank
	jr	loopaddrw
wrtot:				;write total free dyn mem
	ld	hl,C_Total_free
	ld	c,C_Total_free_l
	call	WriteTxt
	call	__GetTotalFree	;DE=total free dyn mem
	ex	de,hl
	ld	hl,addr
	call	DE_hex
	ld	hl,addr
	ld	c,4
	call	WriteTxt
	ld	hl,C_H
	ld	c,1
	jp	WriteTxt
;
_C_TasksSts:
	ld	hl,C_Active
	ld	c,C_Active_l
	call	WriteTxt
	ld	hl,_TasksH
	ld	iy,Big
	di
IF	NORSTS
	call	__FirstFromL
ELSE
	RST	0
ENDIF
loopact:
	push	hl		;TCB on stack
	ld	(iy+0),l
	ld	(iy+1),h
	ld	a,PRI_OFF
	add	a,l
	ld	l,a
	ld	c,(hl)		;C=priority
	ld	(iy+2),c
	sub	PRI_OFF
	ld	l,a
	ex	de,hl		;DE=TCB
	call	__StackLeft
	ld	(iy+3),l
	ld	(iy+4),h
	ld	bc,5
	add	iy,bc
	pop	hl		;HL=crt TCB
	ld	de,_TasksH
IF	RSTS
	RST	16
ELSE
	call	__NextFromL
ENDIF
	jp	nz,loopact
	ld	(iy+0),l	;store EOL=NULL
	ld	(iy+1),h
	ei
				;write tasks info
	ld	iy,Big		
loopactw:
	ld	e,(iy+0)
	ld	d,(iy+1)	;DE=TCB
	ld	a,e
	or	d
	ret	z
	push	de
	ld	hl,C_TCB
	ld	c,C_TCB_l
	call	WriteTxt
	pop	de
	ld	hl,addr
	call	DE_hex
	ld	hl,addr
	ld	c,4
	call	WriteTxt
	ld	hl,C_Priority
	ld	c,C_Priority_l
	call	WriteTxt
	ld	hl,addr
	ld	c,(iy+2)	;C=pri
	call	Byte_C_hex
	ld	hl,addr
	ld	c,2
	call	WriteTxt
	ld	hl,C_FreeStack
	ld	c,C_FreeStack_l
	call	WriteTxt
	ld	e,(iy+3)
	ld	d,(iy+4)	;DE=stack left
	ld	hl,addr
	call	DE_hex
	ld	hl,addr
	ld	c,4
	call	WriteTxt
	ld	hl,C_H
	ld	c,1
	call	WriteTxt
	ld	bc,5
	add	iy,bc
	jr	loopactw
;
_C_AllTasksSts:
	ld	hl,C_AllTasks
	ld	c,C_AllTasks_l
	call	WriteTxt
	ld	hl,AllTasksH
	ld	iy,Big
	di
IF	NORSTS
	call	__FirstFromL
ELSE
	RST	0
ENDIF
loopall:
	ld	a,l
	sub	NXPV_OFF
	ld	l,a
	push	hl		;TCB on stack
	ld	(iy+0),l
	ld	(iy+1),h
	ld	a,PRI_OFF
	add	a,l
	ld	l,a
	ld	c,(hl)		;C=priority
	ld	(iy+2),c
	sub	PRI_OFF
	ld	l,a
	ex	de,hl		;DE=TCB
	call	__StackLeft
	ld	(iy+3),l
	ld	(iy+4),h
	pop	hl		;HL=TCB
	push	hl
	ld	a,WAITSEM_OFF
	add	a,l
	ld	l,a
	ld	e,(hl)
	inc	l
	ld	d,(hl)
	ld	a,d
	or	e
	jr	nz,notact
				;it's active
	inc	a		;A=1
	ld	(iy+5),a
	jr	appsem
notact:	
	pop	hl		;HL=TCB
	push	hl
	ld	a,SEM_OFF
	add	a,l		;CARRY=0
	ld	l,a
	sbc	hl,de
	jr	z,susp
				;it's waiting for sem DE
	ld	a,3
	ld	(iy+5),a
	jr	appsem
susp:				;it's suspended
	ld	a,2
	ld	(iy+5),a
appsem:
	ld	(iy+6),e	;store sem (if any)
	ld	(iy+7),d
	ld	bc,8
	add	iy,bc
	pop	hl		;HL=crt TCB
	ld	a,NXPV_OFF
	add	a,l
	ld	l,a
	ld	de,AllTasksH
IF	RSTS
	RST	16
ELSE
	call	__NextFromL
ENDIF
	jp	nz,loopall
	ld	(iy+0),l	;store EOL=NULL
	ld	(iy+1),h
	ei
				;write tasks info
	ld	iy,Big	
loopallw:	
	ld	e,(iy+0)
	ld	d,(iy+1)	;DE=TCB
	ld	a,e
	or	d
	ret	z
	push	de
	ld	hl,C_TCB
	ld	c,C_TCB_l
	call	WriteTxt
	pop	de
	ld	hl,addr
	call	DE_hex
	ld	hl,addr
	ld	c,4
	call	WriteTxt
	ld	hl,C_Priority
	ld	c,C_Priority_l
	call	WriteTxt
	ld	hl,addr
	ld	c,(iy+2)	;C=pri
	call	Byte_C_hex
	ld	hl,addr
	ld	c,2
	call	WriteTxt
	ld	hl,C_FreeStack
	ld	c,C_FreeStack_l
	call	WriteTxt
	ld	e,(iy+3)
	ld	d,(iy+4)	;DE=stack left
	ld	hl,addr
	call	DE_hex
	ld	hl,addr
	ld	c,4
	call	WriteTxt
	ld	hl,C_H
	ld	c,1
	call	WriteTxt
	ld	a,(iy+5)
	cp	1
	jr	nz,notactw
				;it's active
	ld	hl,C_active
	ld	c,C_active_l
	jr	w_inc_iy
notactw:	
	cp	3
	jr	nz,suspw
				;it's waiting
	ld	hl,C_waiting
	ld	c,C_waiting_l
	call	WriteTxt
	ld	e,(iy+6)
	ld	d,(iy+7)	;DE=sem
	ld	hl,addr
	call	DE_hex
	ld	hl,addr
	ld	c,4
	call	WriteTxt
	ld	hl,C_H
	ld	c,1
	jr	w_inc_iy
suspw:				;it's suspended
	ld	hl,C_suspended
	ld	c,C_suspended_l
w_inc_iy:
	call	WriteTxt
	ld	bc,8
	add	iy,bc
	jp	loopallw
;

IF	IO_COMM

_C_Hex:
	ld	hl,C_HexReady
	ld	c,C_HexReady_l
	call	WriteTxt
	call	_ReadHEX
	ld	a,h
	cp	0FFH
	jr	nz,ok
	ld	a,l
	cp	0FEH
	jr	z,tmo
	cp	0FDH
	jr	z,badck
	cp	0FCH
	jr	z,eofnf
				;alloc failed
	ld	hl,C_HexFailAll
	ld	c,C_HexFailAll_l
	jp	WriteTxt
tmo:				;timeout
	ld	hl,C_HexTimeOut
	ld	c,C_HexTimeOut_l
	jp	WriteTxt
badck:				;bad checksum
	ld	hl,C_HexBadChk
	ld	c,C_HexBadChk_l
	jp	WriteTxt
eofnf:				;could not reach EOF
	ld	hl,C_HexBadFile
	ld	c,C_HexBadFile_l
	jp	WriteTxt
ok:				;ok
	ld	(retHEX),hl
	ld	hl,C_HexExecute
	ld	c,C_HexExecute_l
	call	WriteTxt
	ld	hl,buf_con
	ld	c,80
	ld	de,(SemCmd)
	call	__CON_Read
	ld	hl,(SemCmd)
	call	__Wait
	ld	hl,buf_con
	call	StrUC
	ld	a,(buf_con)
	cp	'Y'		;exec?
	ret	nz		;no, just return
	ld	hl,(retHEX)
	jp	(hl)		;yes, execute loaded code (MUST end with RET !!!)
;
ENDIF

_C_Exit:
	call	__Suspend
	ret
;

_C_StopTask:
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	cp	20H
	jr	nz,SyntaxErr
	inc	hl
	call	ReadBC
	jr	c,SyntaxErr
	call	_CheckEOS
	push	bc
	call	IsItTask
	pop	bc	
	jr	z,1f
	ld	hl,C_NotTask
	ld	c,C_NotTask_l
	jp	WriteTxt
1:
	ld	h,b
	ld	l,c
	jp	__StopTask
;

_C_Resume:
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	cp	20H
	jr	nz,SyntaxErr
	inc	hl
	call	ReadBC
	jr	c,SyntaxErr
	call	_CheckEOS
	push	bc
	call	IsItTask
	pop	bc
	jr	z,1f
	ld	hl,C_NotTask
	ld	c,C_NotTask_l
	jp	WriteTxt
1:
	call	IsSuspended
	jr	z,2f
	ld	hl,C_NotSuspended
	ld	c,C_NotSuspend_l
	jp	WriteTxt
2:
	ld	h,b
	ld	l,c
	jp	__Resume
;

SyntaxErr:
	ld	hl,C_SyntaxErr
	ld	c,C_SyntaxErr_l
	jp	WriteTxt
;

_C_SetTaskPrio:
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	cp	20H
	jr	nz,SyntaxErr
	inc	hl
	call	ReadBC
	jr	c,SyntaxErr
	push	bc
	call	IsItTask
	pop	bc
	jr	z,1f
	ld	hl,C_NotTask
	ld	c,C_NotTask_l
	jp	WriteTxt
1:
	ld	a,(hl)
	cp	','
	jr	nz,SyntaxErr
	inc	hl
	call	ReadA
	jr	c,SyntaxErr
	ld	e,a
	call	_CheckEOS
	jp	__SetTaskPrio
;

_C_RoundRobin:
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	cp	20H
	jr	nz,SyntaxErr
	inc	hl
	ld	a,(hl)
	cp	'O'
	jr	nz,SyntaxErr
	inc	hl
	ld	a,(hl)
	cp	'N'
	jr	nz,1f
	inc	hl
	call	_CheckEOS
	jp	__RoundRobinON
1:
	cp	'F'
	jr	nz,SyntaxErr
	inc	hl
	ld	a,(hl)
	cp	'F'
	jr	nz,SyntaxErr
	inc	hl
	call	_CheckEOS
	jp	__RoundRobinOFF
;

_CMD_Task:
	call	__MakeSem
	jp	z,__Suspend	;dyn memory full, sorry, suspend!
	ld	(SemCmd),hl
loop:
	ld	hl,0FFFFH	;set end-of-buf marker
	ld	(Big+510),hl
				;write '>'
	ld	hl,C_msg
	ld	c,3
	call	WriteTxt
				;read command
	ld	hl,buf_con
	ld	c,80
	ld	de,(SemCmd)
	call	__CON_Read
	ld	hl,(SemCmd)
	call	__Wait
	ld	hl,buf_con
				;try to identify command
	push	hl
	call	StrUC		;convert string to uppercase
	pop	hl
	push	hl
	ld	de,ACT
	call	StrCmp
	pop	hl
	jr	nz,1f
	call	CheckEOS
	call	_C_TasksSts
	jp	loop
1:	push	hl
	ld	de,TAS
	call	StrCmp
	pop	hl
	jr	nz,2f
	call	CheckEOS
	call	_C_AllTasksSts
	jp	loop
2:	push	hl
	ld	de,MAP
	call	StrCmp
	pop	hl
	jr	nz,3f
	call	CheckEOS
	call	_C_MemoryMap
	jp	loop
3:	push	hl
	ld	de,MEM
	call	StrCmp
	pop	hl
	jr	nz,4f
	call	CheckEOS
	call	_C_MemorySts
	jp	loop
4:	
IF	IO_COMM
	push	hl
	ld	de,HEX
	call	StrCmp
	pop	hl
	jr	nz,5f
	call	CheckEOS
	call	_C_Hex
	jp	loop
5:
ENDIF
	push	hl
	ld	de,EXI
	call	StrCmp
	pop	hl
	jr	nz,6f
	call	CheckEOS
	call	_C_Exit
	jp	loop
6:	
	push	hl
	ld	de,STP
	call	StrCmp
	pop	hl
	jr	nz,7f
	call	_C_StopTask
	jp	loop
7:
	push	hl
	ld	de,PRI
	call	StrCmp
	pop	hl
	jr	nz,8f
	call	_C_SetTaskPrio
	jp	loop
8:
	push	hl
	ld	de,RRB
	call	StrCmp
	pop	hl
	jr	nz,9f
	call	_C_RoundRobin
	jp	loop
9:
	push	hl
	ld	de,SHD
	call	StrCmp
	pop	hl
	jr	nz,10f
	call	CheckEOS
	jp	__ShutDown
10:
	push	hl
	ld	de,RESUME
	call	StrCmp
	pop	hl
	jr	nz,11f
	call	_C_Resume
	jp	loop
11:
	ld	hl,C_unknown
	ld	c,C_unknown_l
	call	WriteTxt
	jp	loop
;

ENDIF
