;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
TITLE	Mailbox support routines
;
*Include config.mac
;
;	Mailbox structure
;Semaphore
;	dw	firstTask
;	dw	lastTask
;	dw	counter
;ListHeader
;	dw	firstMsg
;	dw	lastMsg
;MessageSize
;	char MsgSize;	/* real size of message, without sizeof(bElement) */
;	char BallocSize;/* Balloc size */

MB_LH	equ	6	;list header offset
MB_SIZE	equ	10	;message size offset
MB_BSIZE equ	11	;BAlloc block size offset

MAX_MSG_SIZE	equ	0FFH - B_H_SIZE;max message size

	psect	text
	GLOBAL	RET_NULL,EI_RET_NULL,RET_FFFF,EI_RET_FFFF
IF	C_LANG
	GLOBAL _GetMBSts
	GLOBAL _MakeMB
	GLOBAL _DropMB
	GLOBAL _SendMail
	GLOBAL _GetMail
ENDIF
	GLOBAL __GetMBSts
	GLOBAL __MakeMB
	GLOBAL __DropMB
	GLOBAL __SendMail
	GLOBAL __GetMail

	GLOBAL __InitSem
IF	DEBUG
	GLOBAL	__FirstFromL
	GLOBAL	IsItSem
ENDIF

	GLOBAL __Balloc
	GLOBAL __Bdealloc
	GLOBAL __BallocS

	GLOBAL __InitL
	GLOBAL __AddToL
	GLOBAL __GetFromL

	GLOBAL QuickSignal
	GLOBAL __Wait
	GLOBAL _ResumeTask

	GLOBAL Resch_or_Res
	GLOBAL _Reschedule
IF	SIO_RING
	GLOBAL	GetSIOChars
ENDIF

IF	C_LANG
;
;	Create and Initialize a mailbox
;void*  MakeMB(short MessageSize);
;	on stack:
;		MessageSize
;
;	AF,BC,DE,HL,IX,IY not affected
;	returns HL not NULL if ok, 
;	else 0 if cannot allocate or wrong message size provided (zero or > MAX_MSG_SIZE)
;
IM_SIZE	equ	8
;
_MakeMB:
	push	de
	push	bc
	push	af
	ld	hl,IM_SIZE
	add	hl,sp		;stack=AF,BC,DE,retaddr,MessageSize
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=MessageSize
	call	__MakeMB
        pop     af
	pop	bc
	pop	de
        ret
ENDIF
;
;	MakeMB - internal
;
;	BC=MessageSize
;	return HL=0 : alloc failed or size > MAX_MSG_SIZE or zero, else 1
;
__MakeMB:
	di
	ld	a,b		;A=MesageSize(high)
	or	a
	jp	nz,EI_RET_NULL
	ld	a,c		;A=MesageSize(low)
	or	a
	jp	z,EI_RET_NULL		;MesageSize=0
	cp	MAX_MSG_SIZE+1
	jp	nc,EI_RET_NULL	;MesageSize>MAX_MSG_SIZE
	push	bc
	ld	c,1		;alloc 20H
	call	__Balloc
	pop	bc
	jp	z,EI_RET_NULL
	ld	a,B_H_SIZE
	add	a,l
	ld	l,a
	push	hl		;HL=MBox = MBox->Semaphore
	call	__InitSem	;InitSem(&MBox->MBSem);
	ld	a,MB_LH
	add	a,l
	ld	l,a		;HL=MBox->ListH
	call	__InitL		;InitL(&MBox->MBListH);
	ld	a,MB_SIZE-MB_LH
	add	a,l
	ld	l,a		;HL=MBox->MsgSize
	ld	a,c		;A=MesageSize(low)
	ld	(hl),a		;MBox->MsgSize=MessageSize;
	inc	l		;HL=BAlloc block size pointer
	add	a,B_H_SIZE	;A=size of block to be allocated
	ld	c,a
	ld	b,0		;BC=MsgSize
	call	__BallocS	;get BC=alloc block size
	ld	(hl),c		;MBox->BallocSize=BallocSize;
	ei
	pop	hl		;HL=MBox
	ret			;return ok (HL not NULL)
;
IF	C_LANG
;
;	Drop Mailbox
;
;short	DropMB(void* MBAddr)
;	AF,BC,DE,HL,IX,IY not affected
;	returns HL=0 if not a mailbox, else 1
;
DropMaddr	equ	8
;
_DropMB:
	push	af
	push	bc
	push	de
	ld	hl,DropMaddr
	add	hl,sp		;stack=AF,BC,DE,retaddr,MB addr
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=MB Sem pointer
	call	__DropMB
	pop	de
	pop	bc
	pop     af
	ret
;
;	Get Mailbox Status
;short	GetMBSts(void* MBox);
;	returns HL=-1 : no malibox, else HL=counter of mails not yet read
;
_GetMBSts:
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
ENDIF
__GetMBSts:			;HL=Mbox
	di
IF	DEBUG
	call	IsItSem
	jp	nz,EI_RET_FFFF	;no, it is no a semaphore, return -1
ENDIF
	ld	a,4
	add	a,l
	ld	l,a		;HL=pointer of sem counter
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a
	ei
	ret			;return sem counter
;
;
;	Internal Drop Mailbox 
;
;	HL=MB addr
;	returns HL=0 if not a Mailbox, else 1
;	Affected regs: A,BC,DE,HL,IY
;	IX not affected
;
__DropMB:
	di
;										DEBUG
IF	DEBUG
	call	IsItSem
	jp	nz,EI_RET_NULL	;no, it is no a semaphore, return 0
	push	hl
	ld	a,6
	add	a,l
	ld	l,a		;HL=pointer of list header
IF	NORSTS
	call	__FirstFromL
ELSE
	RST	0
ENDIF
	pop	hl
	jp	nz,EI_RET_NULL	;if list not empty, cannot drop mailbox
	ld	c,1		;20H
ENDIF
;										DEBUG
	ld	a,l
	sub	B_H_SIZE
	ld	l,a	
	call	__Bdealloc	;deallocate-it, HL=1
	ei
	ret
IF	C_LANG
;
;	Send Mail
;short	SendMail(struct MailBox* MBox, void* Msg)
;	on stack:
;		Msg addr
;		MailBox addr
;
;	AF,BC,DE,HL,IX,IY not affected
;	returns not NULL if ok, else 0 if could not allocate
;	 or parameter provided is not a real mailbox
;
SM_MB	equ	14
;
_SendMail:
	PUSH_REGS
	ld	hl,SM_MB
	add	hl,sp		;IX=SP,stack=AF,BC,DE,HL,IX,IY,retaddr,MBox,Msg
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=MBox
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=Msg
	ex	de,hl		;HL=MBox, DE=Msg (source)
	di
;										DEBUG
IF	DEBUG
	push	de
	call	IsItSem
	pop	de
	jr	z,1f
	POP_REGS
	jp	EI_RET_NULL			;return HL=0
1:
ENDIF
;										DEBUG
	call	QuickSendMail
	jp	Resch_or_Res
ENDIF
;
;	SendMail - internal
;
;	HL=MBox, DE=Msg
;	returns HL not NULL if ok, else HL=0 if could not allocate
;	 or parameter provided is not a real mailbox
;
__SendMail:
	di
;										DEBUG
IF	DEBUG
	push	de
	call	IsItSem
	pop	de
	jp	nz,EI_RET_NULL
ENDIF
;										DEBUG
	call	QuickSendMail
	jr	nz,1f		;Z=0?
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
;	QuickSendMail
;
;	called under DI
;	HL=MBox, DE=Msg
;	returns Z=1 and HL=0 : just resume task , 
;	else Z=0 and HL not null: reschedule
;
QuickSendMail:
	push	hl		;HL=MBox on stack
	push	de		;DE=Msg on stack
	ld	a,MB_SIZE
	add	a,l
	ld	l,a		;HL=MBox->MsgSize
	ld	e,(hl)
	ld	d,0		;DE=MsgSize
	push	de		;MsgSize on stack
	inc	l		;HL=MBox->BallocSize
	ld	c,(hl)		;C=BallocSize
	call	__Balloc	;allocate block with size=BC, HL returned
	jr	nz,1f
				;alloc failed
	pop	bc		;drop MsgSize
	pop	bc		;drop MSG
	pop	bc		;drop MBox
	ret			;could not alloc, return Z=1 & HL=0
1:				;HL=bElement allocated
	pop	bc		;BC=MsgSize
	push	hl		;save on stack HL=bElement allocated
	ld	a,B_H_SIZE
	add	a,l
	ld	l,a		;HL=bElement.data pointer = destination
	ex	de,hl		;DE=bElement.data pointer = destination
	pop	hl		;HL=bElement allocated
	ex	(sp),hl		;HL=Msg=source, bElement allocated on stack
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
	ldir			;memcpy(DE=destination, HL=source, BC=MsgSize)
IF	SIO_RING
	call	GetSIOChars
ENDIF
	pop	de		;DE=bElement allocated
	pop	hl		;HL=MBox
	push	hl		;keep MBox on stack
	ld	a,MB_LH
	add	a,l
	ld	l,a		;HL=MBox->ListH
IF	RSTS
	RST	24
ELSE
	call	__AddToL	;AddToL(HL=&MBox->MBListH, DE=bElement);
ENDIF
	pop	hl		;HL=MBox=MBox->MBSem
	jp	QuickSignal	;Signal(&MBox->MBSem);
IF	C_LANG
;
;	Get Mail
;short	GetMail(struct MailBox* MBox, void* Buffer)
;	returns HL=0 if not a mailbox, else 1
;	on stack:
;		Buffer addr
;		MailBox addr
;	AF,BC,DE,HL,IX,IY not affected
;
GM_MB	equ	14
;
_GetMail:
	PUSH_REGS
	ld	hl,GM_MB
	add	hl,sp		;stack=AF,BC,DE,HL,IX,IY,retaddr,MBox,Buffer
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=MBox
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=Buffer
	ex	de,hl		;HL=MBox=MBox->Sem, DE=Buffer (destination)
;										DEBUG
IF	DEBUG
	push	de
	call	IsItSem
	pop	de
	jr	z,1f
	POP_REGS
	jp	RET_NULL
1:
ENDIF
;										DEBUG
	call	QuickGetMail
	POP_REGS
	ret
ENDIF
;
;	GetMail - internal
;	HL=Mbox, DE=buffer
;	returns HL=0 if not a mailbox, else 1
;
__GetMail:
;										DEBUG
IF	DEBUG
	push	de
	call	IsItSem
	pop	de
	jp	nz,RET_NULL
ENDIF
;										DEBUG
;
;	QuickGetMail
;
;	HL=Mbox, DE=buffer
;
QuickGetMail:
				;HL=MBox=MBox->Sem
	push	hl		;on stack
	push	de
	call	__Wait		;Wait(&MBox->MBSem);
	pop	de
	pop	hl		;HL=MBox
	di
;-----------------------------------------------------------------------------	
IF	DEBUG
	push	hl		;keep MBox on stack
ENDIF
;-----------------------------------------------------------------------------	
	ld	a,MB_SIZE
	add	a,l
	ld	l,a		;HL=MBox->MsgSize, CARRY=0
	ld	c,(hl)
	ld	b,0		;BC=MsgSize
	push	bc		;MsgSize on stack
				;CARRY=0
	ld	a,l
	sub	4
	ld	l,a		;HL=MBox->ListH
	push	de		;buffer on stack
IF	RSTS
	RST	40
ELSE
	call	__GetFromL	;GetFromL(HL=&MBox->MBListH);
ENDIF
				;HL=bElement returned
	pop	de		;DE=buffer
	ld	a,B_H_SIZE
	add	a,l
	ld	l,a		;HL=bElement.data pointer (source), CARRY=0
	pop	bc		;BC=MsgSize
	push	hl		;keep bElement.data pointer on stack
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
	ldir			;memcpy(DE=destination, HL=source, BC=MsgSize)
IF	SIO_RING
	call	GetSIOChars
ENDIF
	pop	hl		;HL=bElement.data pointer
	ld	a,l
	sub	B_H_SIZE
	ld	l,a		;HL=bElement
;-----------------------------------------------------------------------------	
IF	DEBUG
	ex	de,hl		;DE=bElement
	pop	hl		;HL=MBox
	ld	a,MB_BSIZE
	add	a,l
	ld	l,a
	ld	c,(hl)		;C=BallocSize
	ex	de,hl		;HL=bElement
ENDIF
;-----------------------------------------------------------------------------	
	call	__Bdealloc	;dealloc HL=bElement,BC=bSize
	ei
	ret
;
