;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	Queue support routines
;
*Include config.mac
;
;	Queue header structure (23 bytes)
;
;dw	void** WP;	/* write pointer */
;dw	void** RP;	/* read pointer */
;dw	void* BufStart; /* buffer start addr */
;dw	void* BufEnd;	/* buffer end addr */
;db	char BallocSize;/* Balloc size */ used only if DEBUG
;dw	short BatchSize; /* number of bytes to be moved */
;struct Semaphore ReadS; /* semaphore used when reading from queue */
;struct Semaphore WriteS; /* semaphore used when writing to queue */

OFF_WP	equ	0
OFF_RP	equ	2
OFF_BS	equ	4
OFF_BE	equ	6
OFF_BALS equ	8
OFF_BSIZE equ	9
OFF_RSEM equ	11
OFF_WSEM equ	17
;
	psect	text
;
	GLOBAL	RET_NULL,EI_RET_NULL,RET_FFFF,EI_RET_FFFF
COND	C_LANG
	GLOBAL	_GetQSts
	GLOBAL	_MakeQ
	GLOBAL	_DropQ
	GLOBAL	_WriteQ
	GLOBAL	_ReadQ
ENDC
	GLOBAL	__GetQSts
	GLOBAL	__InitQ
	GLOBAL	__MakeQ
	GLOBAL	__DropQ
	GLOBAL	__WriteQ
	GLOBAL	__ReadQ

	GLOBAL __Balloc
	GLOBAL __Bdealloc
	GLOBAL __BallocS

	GLOBAL __InitSem
	GLOBAL __InitSetSem
COND	DEBUG
	GLOBAL IsItSem
ENDC
	GLOBAL QuickSignal
	GLOBAL __Wait
	GLOBAL _Reschedule
	GLOBAL Resch_or_Res
	GLOBAL _ResumeTask
COND	SIO_RING
	GLOBAL	GetSIOChars
ENDC

COND	C_LANG
;	Creates and Initialize a queue
;
;void*	MakeQ(short batch_size, short batches_count);
;	returns HL=0 if alloc fails, else HL=queue pointer
;	AF,BC,DE,HL,IX,IY not affected
;
IQ_SIZE		equ	10
;
_MakeQ:
	push	iy
	push	af
	push	bc
	push	de
	ld	hl,IQ_SIZE
	add	hl,sp			;stack=DE,BC,AF,IY,retaddr,size,count
	ld	b,(hl)			;B=size
	inc	hl
	inc	hl
	ld	c,(hl)			;C=count
	call	__MakeQ
	pop	de
	pop	bc
	pop     af
	pop	iy
        ret
ENDC
;	
;	Make Queue - internal
;
;	B=batch size (number of 2-bytes to be moved), C=batches count
;	allocates queue
;	allocates buffer
;	returns HL=queue if alloc ok, else 0
;	A,BC,DE,HL affected
;
__MakeQ:
	push	bc
	ld	c,1			;alloc 20H for queue
	di
	call	__Balloc
	pop	bc
	jr	nz,1f
	ei
	ret
1:
	ld	a,B_H_SIZE
	add	a,l
	ld	l,a			;HL=queue
	push	hl			;queue header on stack
	call	__InitQ
	pop	hl			;HL=queue
	jr	z,2f
	ei
	ret				;return HL=queue if all ok
2:
	ld	a,l			;else dealloc also queue
	sub	B_H_SIZE
	ld	l,a
COND	DEBUG
	ld	c,1
ENDC
	call	__Bdealloc
	ei				
	dec	hl			;HL=0	
	ret
;
COND	C_LANG
;
;	Drop queue (dealloc buffer)
;
;short	DropQ(struct Queue* queue);
;	returns HL=0 if it's nor a queue, else HL=1
;	AF,BC,DE,HL,IX,IY not affected
;
DQ_Q	equ	8
;
_DropQ:
	push	af
	push	bc
	push	de
	ld	hl,DQ_Q
	add	hl,sp			;stack=DE,BC,AF,retaddr,QH
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a			;HL=queue header
	call	__DropQ
	pop	de
	pop	bc
        pop     af
        ret
;
;	Get Queue Status
;
;short	GetQSts(void* queue);
;	returns HL=-1 : no queue, else HL=count of batches not read yet
;
_GetQSts:
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
ENDC
__GetQSts:				;HL=queue
	di
;-----------------------------------------------------------------------------	
COND	DEBUG
	ld	a,OFF_RSEM
	add	a,l
	ld	l,a			;HL=ReadSem
	call	IsItSem
	jp	nz,EI_RET_FFFF
	ld	a,6			;skip ReadSem
	add	a,l
	ld	l,a			;HL=WriteSem
	call	IsItSem
	jp	nz,EI_RET_FFFF
	ld	a,l
	sub	OFF_WSEM
	ld	l,a			;HL=queue
ENDC
;-----------------------------------------------------------------------------	
	ld	a,OFF_RSEM+4
	add	a,l
	ld	l,a
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a			;HL=Read Sem counter
	ei
	ret
;
;	Drop queue - internal
;
;	HL=queue
;	returns HL=0 if it's nor a queue, else HL=1
;	deallocates buffer and queue
;	A,BC,DE,HL affected
;	
__DropQ:
	push	hl			;save queue on stack
	di
;-----------------------------------------------------------------------------	
COND	DEBUG
	ld	a,OFF_RSEM
	add	a,l
	ld	l,a			;HL=ReadSem
	call	IsItSem
	jr	z,1f
2:	ei
	pop	hl
	ld	hl,0
	ret
1:	ld	a,6			;skip ReadSem
	add	a,l
	ld	l,a			;HL=WriteSem
	call	IsItSem
	jp	nz,2b
	ld	a,l
	sub	OFF_WSEM
	ld	l,a			;HL=queue=WP
	ld	e,(hl)
	inc	l
	ld	d,(hl)
	inc	l
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a			;HL=RP, DE=WP
	or	a
	sbc	hl,de
	jr	nz,2b			;queue not empty, cannot drop
	pop	hl			;HL=queue
	push	hl
	ld	a,l
	add	a,OFF_BALS
	ld	l,a			;HL=pointer of alloc block size
	ld	c,(hl)			;C=alloc block size
	ld	a,l
	sub	OFF_BALS
	ld	l,a			;HL=queue
ENDC
;-----------------------------------------------------------------------------	
	ld	a,l
	add	a,OFF_BS
	ld	l,a			;HL=pointer to BufStart, CARRY=0
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl			;HL=BufStart
	ld	a,l
	sub	B_H_SIZE
	ld	l,a			;HL=bElement
	call	__Bdealloc		;deallocate buffer
	pop	hl			;HL=queue
COND	DEBUG
	ld	c,1			;20H
ENDC
	ld	a,l
	sub	B_H_SIZE
	ld	l,a			;HL=20H block to deallocate
	call	__Bdealloc		;deallocate-it, HL=1
	ei
	ret
;	
;	Init Queue - internal
;
;	called under DI
;	HL=queue header, B=batch size (number of 2-bytes to be moved), C=batches count
;	allocates buffer
;	returns Z=1 & HL=NULL if alloc fails, else Z=0 & HL not NULL
;	A,BC,DE,HL affected
;
__InitQ:
	push	hl			;queue header on stack
					;compute B * C * 2
	xor	a			;A=0, CARRY=0
	ld	h,a
	ld	l,a			;HL=accumulator=0
	ld	e,b
	ld	d,a			;DE=B
	ld	a,c			;A=C,n=0
2:	rra				;n=n+1, Cb(8-n)=0, CARRY=Cb(n-1)
	jr	nc,1f
	add	hl,de			;if Cbn=1, HL=HL+(DE**n)
1:	sla	e
	rl	d			;DE=DE*2
	or	a			;any bit left in C? (and set CARRY=0)
	jr	nz,2b
	add	hl,hl			;HL=HL*2, now HL=C*B*2=size of the buffer
	push	hl			;buffer size on stack
	ld	de,B_H_SIZE
	add	hl,de			;HL=size of memory to be allocated
	ld	a,h
	and	11000000B		;is it > 2000H ?
	jr	z,3f
					;yes,
	pop	hl			;drop buffer size
	pop	hl			;drop queue header
	jp	RET_NULL		;total size to be allocated > 2000H
					;return HL=0
3:					;A=0
	push	bc			;B=batch size, C=batches count on stack
	ld	b,h
	ld	c,l			;BC=total size to be allocated
	call	__BallocS
;------------------------------------------------------------------
COND	DEBUG
	push	bc			;bSize on stack
ENDC
;------------------------------------------------------------------
	call	__Balloc
	jr	nz,4f		
;------------------------------------------------------------------
COND	DEBUG
	pop	bc			;drop bSize
ENDC
;------------------------------------------------------------------
	pop	bc			;drop batch size and batches count
	pop	bc			;drop buffer size
	pop	bc			;drop queue header
	ret				;return 0 if alloc failed
4:					;HL=allocated block
	ld	a,B_H_SIZE
	add	a,l
	ld	l,a			;HL=buffer
;------------------------------------------------------------------
COND	DEBUG
	pop	de			;E=bSize
	ld	a,e			;A=bSize
ENDC
;------------------------------------------------------------------
	pop	bc			;B=batch size, C=batches count
	pop	de			;DE=buffer size
	ex	(sp),hl			;HL=queue header,buffer on stack
;------------------------------------------------------------------
COND	DEBUG
	push	bc
	ld	bc,OFF_BALS
	add	hl,bc
	ld	(hl),a			;set bSize
	sbc	hl,bc
	pop	bc
ENDC
;------------------------------------------------------------------
	push	de			;buffer size on stack
	push	bc			;B=batch size, C=batches count on stack
	ld	c,b			;C=batch size
	ld	b,0			
	sla	c
	rl	b			;BC=BC*2=count of bytes to be moved
	ld	a,OFF_BSIZE
	add	a,l
	ld	l,a			;HL=pointer of queue.BatchSize
	ld	(hl),c
	inc	l
	ld	(hl),b			;saved count of bytes to be moved
	inc	l			;HL=pointer of Read Semaphore
	call	__InitSem		;init Read semaphore
	ld	a,6			;skip Read semaphore
	add	a,l
	ld	l,a			;HL=pointer of queue Write semaphore
	pop	bc			;C=batches count
	ld	b,0
	call	__InitSetSem		;init and set Write semaphore counter
	ld	a,l
	sub	OFF_WSEM
	ld	l,a			;HL=queue
	pop	bc			;BC=buffer size
	pop	de			;DE=buffer
	ld	(hl),e
	inc	l
	ld	(hl),d			;WP
	inc	l
	ld	(hl),e
	inc	l
	ld	(hl),d			;RP
	inc	l
	ld	(hl),e
	inc	l
	ld	(hl),d			;BufStart
	inc	l
	ex	de,hl			;HL=buffer,DE=queue pointer
	add	hl,bc			;HL=buffer+buffer size=buffer end
	ex	de,hl			;HL=queue pointer, DE=buffer end
	ld	(hl),e
	inc	l
	ld	(hl),d			;BufEnd
	ret				;Z=0 & HL not NULL
;
COND	C_LANG
;
;       Write to queue
;
;short  WriteQ(struct Queue* queue, void* info);
;	returns HL=0 if parameter provided is not a real queue, else not NULL 
;       AF,BC,DE,HL,IX,IY not affected
;
WQ_Q    equ     14
;
_WriteQ:
	push	af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
        ld      hl,WQ_Q
        add     hl,sp                   ;stack=AF,BC,DE,HL,IX,IY,retaddr,queue,info
        ld      c,(hl)
	inc	hl
        ld      b,(hl)		        ;BC=queue header
	inc	hl
        ld      e,(hl)
	inc	hl
        ld      d,(hl)		        ;DE=info pointer
;-----------------------------------------------------------------------------	
COND	DEBUG
	push	bc
	push	de
	ld	h,b
	ld	l,c
	ld	a,OFF_RSEM
	add	a,l
	ld	l,a			;HL=ReadSem
	di
	call	IsItSem
	ei
	jr	z,1f
2:	pop	de
	pop	bc
	jp	RET_NULL		;return HL=0
1:	ld	a,6			;skip ReadSem
	add	a,l
	ld	l,a
	di				;HL=WriteSem
	call	IsItSem
	ei
	jr	nz,2b
	pop	de
	pop	bc
ENDC
;-----------------------------------------------------------------------------	
	ld	h,b
	ld	a,OFF_WSEM
	add	a,c
	ld	l,a			;HL=pointer to Write Semaphore
	push	bc
	push	de
	call	__Wait			;Wait Write Semaphore
	pop	de
	pop	bc
	di
	call	wq
					;Z=0? (TCB was inserted into active tasks list?)
	jp	Resch_or_Res		;yes : reschedule, else just resume current task
ENDC
;
;	WriteQ - internal
;
;	BC=queue, DE=pointer to data
;
__WriteQ:
;-----------------------------------------------------------------------------	
COND	DEBUG
	push	bc
	push	de
	ld	h,b
	ld	l,c
	ld	a,OFF_RSEM
	add	a,l
	ld	l,a			;HL=ReadSem
	di
	call	IsItSem
	ei
	jr	z,1f
2:	pop	de
	pop	bc
	jp	RET_NULL		;return HL=0
1:	ld	a,6			;skip ReadSem
	add	a,l
	ld	l,a
	di				;HL=WriteSem
	call	IsItSem
	ei
	jr	nz,2b
	pop	de
	pop	bc
ENDC
;-----------------------------------------------------------------------------	
	ld	h,b
	ld	a,OFF_WSEM
	add	a,c
	ld	l,a			;HL=pointer to Write Semaphore
	push	bc
	push	de
	call	__Wait			;Wait Write Semaphore
	pop	de
	pop	bc
	di
	call	wq
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
;	wq - internal
;
;	called under DI
;	BC=queue, DE=pointer to data
;	returns Z=0 to reschedule, 
;	or Z=1 to return to current task
;
wq:
	ld	h,b
	ld	a,OFF_BSIZE
	add	a,c
	ld	l,a			;HL=pointer to batch size
	push	bc			;save queue
	ld	c,(hl)
	inc	l
	ld	b,(hl)			;BC=batch size
	pop	hl			;HL=queue
	push	hl			;queue on stack
					;HL=queue=pointer to WP
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a			;HL=write pointer
					;store info
	ex	de,hl			;HL=pointer to data, DE=write pointer
	push	hl
COND	SIO_RING
	call	GetSIOChars
ENDC
	pop	hl
	ldir				;(DE) <-BC bytes- (HL), DE=write pointer+BC
	pop	bc			;restore queue
COND	SIO_RING
	call	GetSIOChars
ENDC
					;check if end-of-buffer reached
	ld	h,b
	ld	a,OFF_BE
	add	a,c
	ld	l,a			;HL=pointer of BufEnd, CARRY=0
	ld	a,(hl)
	inc	l
	ld	h,(hl)			
	ld	l,a			;HL=buffer end
					;CARRY=0
	sbc	hl,de
	jr	nz,2f			;if write pointer at end of buffer...
					;then set it again on start of buffer
	ld	h,b
	ld	a,OFF_BS
	add	a,c
	ld	l,a			;HL=pointer of BufStart
	ld	e,(hl)
	inc	l
	ld	d,(hl)			;DE=BufStart
2:					;save write pointer
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	h,b
	ld	l,c			;HL=queue header=pointer of WP
	ld	(hl),e
	inc	l
	ld	(hl),d			;new WP saved
					;Signal Read Semaphore
	ld	h,b
	ld	a,OFF_RSEM
	add	a,c
	ld	l,a			;HL=Read semaphore pointer
	jp	QuickSignal		;Signal without reschedule
;
COND	C_LANG
;
;       Read from queue
;
;short  ReadQ(struct Queue* queue, void* buf);
;       AF,BC,DE,HL,IX,IY not affected
;       return HL = 0 if parameter provided is not a real queue, else not NULL
;
RQ_Q    equ     14
;
_ReadQ:
	push	af
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
        ld      hl,RQ_Q
        add     hl,sp                   ;stack=AF,BC,DE,HL,IX,IY,retaddr,queue
        ld      c,(hl)
	inc	hl
        ld      b,(hl)           	;BC=queue header
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)			;DE=buf
;-----------------------------------------------------------------------------	
COND	DEBUG
	push	bc
	push	de
	ld	h,b
	ld	l,c
	ld	a,OFF_RSEM
	add	a,l
	ld	l,a			;HL=ReadSem
	di
	call	IsItSem
	ei
	jr	z,1f
2:	pop	de
	pop	bc
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	pop	af
	jp	RET_NULL		;return HL=0
1:	ld	a,6			;skip ReadSem
	add	a,l
	ld	l,a			;HL=WriteSem
	di
	call	IsItSem
	ei
	jr	nz,2b
	pop	de
	pop	bc
ENDC
;-----------------------------------------------------------------------------	
	ld	h,b
	ld	a,OFF_RSEM
	add	a,c
	ld	l,a			;HL=Read semaphore pointer
	push	bc
	push	de
	call	__Wait			;wait Read semaphore
	pop	de
	pop	bc
	di
	call	rq
					;Z=0? (TCB was inserted into active tasks list?)
	jp	Resch_or_Res		;yes : reschedule, else just resume current task
;
ENDC
;
;	ReadQ - internal
;	BC=queue, DE=pointer to buffer
;
__ReadQ:
;-----------------------------------------------------------------------------	
COND	DEBUG
	push	bc
	push	de
	ld	h,b
	ld	l,c
	ld	a,OFF_RSEM
	add	a,l
	ld	l,a			;HL=ReadSem
	di
	call	IsItSem
	ei
	jr	z,1f
2:	pop	de
	pop	bc
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	pop	af
	jp	RET_NULL		;return HL=0
1:	ld	a,6			;skip ReadSem
	add	a,l
	ld	l,a			;HL=WriteSem
	di
	call	IsItSem
	ei
	jr	nz,2b
	pop	de
	pop	bc
ENDC
;-----------------------------------------------------------------------------	
	ld	h,b
	ld	a,OFF_RSEM
	add	a,c
	ld	l,a			;HL=Read semaphore pointer
	push	bc
	push	de
	call	__Wait			;wait Read semaphore
	pop	de
	pop	bc
	di
	call	rq
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
;	rq - internal
;
;	called under DI
;	BC=queue, DE=pointer to buffer
;	returns Z=0 to reschedule, 
;	or Z=1 to return to current task
;
rq:
	ld	h,b
	ld	a,OFF_BSIZE
	add	a,c
	ld	l,a			;HL=pointer to batch size
	push	bc			;save queue
	ld	c,(hl)
	inc	l
	ld	b,(hl)			;BC=batch size
	pop	hl			;HL=queue
	push	hl			;queue on stack
	inc	l
	inc	l			;HL=pointer to RP
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a			;HL=Read Pointer
	push	hl
COND	SIO_RING
	call	GetSIOChars
ENDC
	pop	hl	
	ldir				;(DE) <-BC bytes- (HL), HL=read pointer+BC
	pop	bc			;restore queue
	ex	de,hl			;DE=read pointer+8
COND	SIO_RING
	call	GetSIOChars
ENDC
					;check if end-of-buffer reached
	ld	h,b
	ld	a,OFF_BE
	add	a,c
	ld	l,a			;HL=pointer of BufEnd, CARRY=0
	ld	a,(hl)
	inc	l
	ld	h,(hl)			
	ld	l,a			;HL=buffer end
					;CARRY=0
	sbc	hl,de
	jr	nz,2f			;if read pointer at end of buffer...
					;then set it again on start of buffer
	ld	h,b
	ld	a,OFF_BS
	add	a,c
	ld	l,a			;HL=pointer of BufStart
	ld	e,(hl)
	inc	l
	ld	d,(hl)			;DE=BufStart
2:					;save read pointer
COND	SIO_RING
	call	GetSIOChars
ENDC
	ld	h,b
	ld	a,OFF_RP
	add	a,c
	ld	l,a			;HL=pointer of RP
	ld	(hl),e
	inc	l
	ld	(hl),d			;new RP saved
					;Signal Write Semaphore
	ld	h,b
	ld	a,OFF_WSEM
	add	a,c
	ld	l,a			;HL=Write semaphore pointer
	jp	QuickSignal		;Signal without reschedule
;
