;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
; 	Buddy-system memory allocation routines
;
*Include config.mac
*Include leds.mac
;
DEBUG_BALLOC	equ	0	;used for internal testing
;
; Memory block structure
;
; 	defw	next 	;pointer to next block
;	defw	prev 	;pointer to prev block
;	defb	status 	;0=available, CrtID=allocated
;	defb	size	;block size : from 0(=10H) to 9(=2000H)
;	data
;
OFF_STS		equ	4
OFF_SIZE	equ	5

	psect text

MAX_SIZE	equ	9
;
LISTS_NR	equ	MAX_SIZE+1
;
AVAILABLE	equ	0
;
	GLOBAL	RET_NULL
	GLOBAL  _GetID
	GLOBAL	CleanWP
	GLOBAL	CleanRP
COND	SIO_RING
	GLOBAL	GetSIOChars
ENDC
	GLOBAL	__AddToL
	GLOBAL	__GetFromL
	GLOBAL	__RemoveFromL
	GLOBAL  _InitBMem
COND	C_LANG
	GLOBAL  _Balloc
	GLOBAL  _Bdealloc
	GLOBAL  _BallocS
	GLOBAL	_GetOwnerTask
	GLOBAL	_Extend
ENDC
	GLOBAL  __Balloc
	GLOBAL  __Bdealloc
	GLOBAL  __BallocS
	GLOBAL  _Lists
	GLOBAL  ClearGarbage
	GLOBAL	ClearAllGarbage
	GLOBAL  TestFreeMem
	GLOBAL	_GetMaxFree
	GLOBAL	__GetMaxFree
	GLOBAL	_GetTotalFree
	GLOBAL	__GetTotalFree
	GLOBAL	__GetTaskByID
	GLOBAL	__GetOwnerTask
	GLOBAL	__Extend

COND	DEBUG_BALLOC=0
	GLOBAL	Lists
	GLOBAL	L9
	GLOBAL	L0
	GLOBAL	Buddy
ENDC
;
COND	C_LANG
;
;void*	GetOwnerTask(void* block);
;	returns HL=TCB or 0 if not found
;
_GetOwnerTask:
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=block
ENDC
;	GetOwnerTask - finds the owner of an allocated block of memory
;
;	HL=block of allocated memory
;	return Z=1 & HL=0 : no TCB was found, else Z=0 & HL=TCB
;	AF,HL,DE affected
;
__GetOwnerTask:
	ld	a,l
	add	a,OFF_STS
	ld	l,a
	ld	c,(hl)
	jp	__GetTaskByID
;
;	GetTotalFree
;
;	returns HL=total amount of free memory
;
_GetTotalFree:
	push	ix
	push	af
	push	bc
	push	de
	call	__GetTotalFree
	pop	de
	pop	bc
	pop	af
	pop	ix
	ret
;
__GetTotalFree:
	di
	ld	ix,0		;IX=total
	ld	a,10		;A=counter of lists
	ld	bc,10H		;BC=size of blocks
	ld	hl,Lists
nextl:	push	af
	ld	e,(hl)
	inc	l
	ld	d,(hl)		;DE=crt list header
	inc	l
	push	hl		;pointer of lists on stack
	ex	de,hl		;HL=crt list header
	push	hl		;on stack
nextb:	ld	e,(hl)
	inc	l
	ld	d,(hl)		;DE=first
	pop	hl		;HL=header
	push	hl
	or	a
	sbc	hl,de
	jr	z,1f
	add	ix,bc
	ex	de,hl
	jr	nextb
1:	sla	c
	rl	b		;BC=BC*2
	pop	hl		;drop header
	pop	hl		;HL=pointer of lists
	pop	af		;A=counter
	dec	a
	jr	nz,nextl
	push	ix
	pop	hl		;HL=total
	ei
	ret
;
;	GetMaxFree
;
;	returns HL=largest free memory block size (0 to 9)
;	or HL=-1 if no more free memory available
;
_GetMaxFree:
	push	af
	push	bc
	push	de
	call	__GetMaxFree
	pop	de
	pop	bc
	pop	af
	ret
;
__GetMaxFree:
	di
	call	TestFreeMem
	ei
	ld	h,0
	ld	l,b
	ret	nz		;if Z=0, HL=largest free memory block size (0 to 9)
COND	DIG_IO
	OUT_LEDS	ERR_FULLMEM
ENDC
	ld	l,h
	dec	hl		;HL=-1
	ret
;
;	Test Free Memory
;	
;	called under DI
;	Affected regs: A,B,DE,HL
;	returns Z=0 and B=largest free memory block size (0 to 9)
;		or Z=1 if no more free memory is available
;
TestFreeMem:
	ld	b,LISTS_NR-1
	ld	hl,Lists+LISTS_NR*2-1	;HL=pointer of largest free block possible - 1
1:	ld	d,(hl)
	dec	l
	ld	e,(hl)			;DE=current list header
	dec	l
	push	hl			;save pointer of lists
	ex	de,hl			;HL=current list header
	ld	e,(hl)
	inc	l
	ld	d,(hl)			;DE=first or header
	scf				;CARRY=1
	sbc	hl,de			;HL+1 ? DE+1
	pop	hl			;restore pointer of lists
	ret	nz			;not equal, we found available memory, Z=0, B=bSize
	dec	b
	jp	p,1b
	xor	a			;Z=1, no free memory
	ret				
;
;	Clear All garbage
;	called under DI
;
;	returns Z=0 if ZERO (Shutdown marker) found in garbage requests buffer
;	  else Z=1
;
ClearAllGarbage:
	ld	hl,(CleanWP)		;any clear garbage request?
	ld	de,(CleanRP)		;compare read and write pointers
	or	a
	sbc	hl,de
	ret	z			;if equal, return Z=1
					;readP != writeP, get request
	ex	de,hl			;HL=CleanRP
	ld	c,(hl)			;C=target ID
	inc	l
	ld	(CleanRP),hl
	ld	a,c
	or	a			;Shutdown marker?
	jr	nz,1f
	inc	a			;yes
	ret				;return Z=0
1:
	ld	ix,BMEM_BASE		;IX=pointer of dynamic memory
COND	SIM
	ld	iy,BMEM_BASE+BMEM_SIZE	;IY=pointer to end of dynamic memory
ENDC
COND	NOSIM
COND	1-DYNM512
	ld	iy,0			;IY=pointer to end of dynamic memory (0FFFFH + 1)
ENDC
COND	DYNM512
	ld	iy,BMEM_BASE+BMEM_SIZE	;IY=pointer to end of dynamic memory
ENDC
ENDC
	call	ClearGarbage		;clear garbage (uses ~ 10H stack space)
	jr	ClearAllGarbage		;then keep looping
;
;	Clear garbage
;
;	called under DI
;	IX = dynamic memory address
;	IY = pointer to end of dynamic memory
;	C = target ID
;
ClearGarbage:
	push	ix		;save start of dynamic memory on stack
2:				;loop
	ld	a,(ix+OFF_STS)	;check current block
	or	a		;block free?
	jr	z,3f
				;not free, it is an allocated block
	cp	c		;on target?
	jr	nz,3f		;if not, skip-it
				;on target!
	push	bc		;save BC
;-----------------------------------------------------------------------------	
COND	DEBUG
	ld	c,(ix+OFF_SIZE)	;C=bAlloc size
ENDC
;-----------------------------------------------------------------------------	
	push	ix		
	pop	hl		;HL=block addr
	call	__Bdealloc	;dealloc block
	pop	bc		;restore BC (C=target ID)
	pop	ix		;IX=dynamic memory address
	jr	ClearGarbage	;repeat procedure... 
3:				;block is free or with another owner, skip it
	ld	a,(ix+OFF_SIZE)
	add	a,a
	ld	hl,Buddy
	add	a,l
	ld	l,a		;HL=pointer of block size
	ld	e,(hl)
	inc	l
	ld	d,(hl)		;DE=block size
				;
	add	ix,de		;IX=new pointer
	push	iy
	pop	hl		;HL=pointer to end of dynamic memory
	push	ix
	pop	de		;DE=new pointer
	or	a		;CARRY=0
	sbc	hl,de		;end of dynamic memory reached?
	jr	nz,2b		;if not reached, go check current block
				;if yes, return
	pop	ix
	ret
;
COND	C_LANG
_BallocS:
	ld	hl,2
	add	hl,sp
	push	af
	push	bc
	ld	a,(hl)
	inc	hl
	ld	b,(hl)
	ld	c,a
	call	__BallocS
	ld	h,b
	ld	l,c
	pop	bc
	pop	af
	ret
ENDC
;	
;	BallocS
;
;	BC=memory size (must be <= 2000H)
;	Affected regs: A,BC
;	Returns BC=bElement size
;
__BallocS:
	dec	bc		;BC = memory size-1
	ld	a,b
COND	DEBUG
	and	1FH		;keep it <= 1FH
ENDC
	or	a
	jr	z,1f
				;high part != 0
	ld	bc,MAX_SIZE	;prepare bSize for 2000H
	bit	4,a
	ret	nz		;if bit#12=1 return 9 for 2000H
	dec	c		;BC=8
	bit	3,a
	ret	nz		;if bit#11=1 return 8 for 1000H
	dec	c		;BC=7
	bit	2,a
	ret	nz		;if bit#10=1 return 7 for 800H
	dec	c		;BC=6
	bit	1,a
	ret	nz		;if bit#9=1 return 6 for 400H
	dec	c		;BC=5
	ret			;else return 5 for 200H
1:	ld	a,c		;high part == 0
	ld	bc,4		;BC=4
	bit	7,a
	ret	nz		;if bit#7=1 return 4 for 100H
	dec	c		;BC=3
	bit	6,a
	ret	nz		;if bit#6=1 return 3 for 80H
	dec	c		;BC=2
	bit	5,a
	ret	nz		;if bit#5=1 return 2 for 40H
	dec	c		;BC=1
	bit	4,a		
	ret	nz		;if bit#4=1 return 1 for 20H
	dec	c		;BC=0
	ret			;else return 0 for 10H
;
;	Returns pointer to free blocks lists headers
;
_Lists: ld	hl,Lists
	ret
;
;	Initialize buddy-system memory
;	
;	called under DI
;	HL=provided buffer pointer
;	Affected regs: A,BC,DE,HL
;
_InitBMem:
	push	hl
	ld	a,10
	ld	hl,L0
	ld	de,L0
	ld	bc,4
initL:	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ex	de,hl
	add	hl,bc
	ex	de,hl
	dec	a
	jr	nz,initL
	ld	hl,Lists
	ld	de,L0
	ld	a,10
initLL:	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ex	de,hl
	add	hl,bc
	ex	de,hl
	dec	a
	jr	nz,initLL
	ld	hl,Buddy
	ld	de,10H
	ld	a,10
initB:	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ex	de,hl
	add	hl,hl
	ex	de,hl
	dec	a
	jr	nz,initB
	pop	hl
	push	hl	;HL=provided buffer address
	xor	a	;fill buffer with 0
	ld	c,20H	;2000H = 20H x 100H
4:	ld	b,0
3:	ld	(hl),a
	inc	hl
	djnz	3b
	dec	c
	jr	nz,4b
	pop	de	;DE=provided buffer address
	push	de	;keep it on stack		
	ld	hl,L9	;HL=L9 list header
COND	RSTS
	RST	24
ENDC
COND	NORSTS
	call	__AddToL;add DE=provided buffer to HL=available list
ENDC
	pop	hl	;provided buffer address
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	(hl),AVAILABLE	;set status
	inc	hl
	ld	(hl),MAX_SIZE	;set size
	ret	
COND	C_LANG
;
;	Allocate a memory block of given size
;
;	size on stack ( size <= MAX_SIZE )
;
;	returns HL=pointer to memory block if available, 
;		else 0 if wrong size or no memory available
;	AF,BC,DE,IX,IY not affected
;
_Balloc:	
	di
	exx
	push	af
	ld	hl,4
	add	hl,sp
	ld	c,(hl)
	call	__Balloc
        pop     af
        push    hl
        exx
        pop     hl      ;restore HL=value to be returned
        ei
        ret
;
;	Deallocate a memory block of given size
;
;	on stack:
;		size ( size <= MAX_SIZE )
;		memory block addr
;
;	returns HL=1 if ok, 
;		else 0 if wrong address or size or memory block is not allocated
;	AF,BC,DE,IX,IY not affected
;
_Bdealloc:	
	di
	exx
	push	af
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)			;DE=addr
	inc	hl
	ld	c,(hl)			;C=size
	ex	de,hl			;HL=addr
	call	__Bdealloc
        pop     af
        push    hl
        exx
        pop     hl      ;restore HL=value to be returned
        ei
        ret
ENDC
;
;	Allocate a memory block of given size
;
;	called under DI
;	C=size ( size <= MAX_SIZE )
;	returns Z=0 and HL=pointer to memory block if available, 
;		else Z=1 and HL=0 if wrong size or no memory available
;	Local variables: DE = Element, BC on stack (B=Size, C=CrtSize)
;	Affected regs: A,BC,DE,HL
;	IX,IY not affected
;
__Balloc:
;CrtSize=Size
	ld	b,c		;CrtSize=Size
;-----------------------------------------------------------------------------	
COND	DEBUG
	ld	a,c		;A=size
	cp	MAX_SIZE+1
	jr	c,3f	
	xor	a		;Z=1
	ld	h,a
	ld	l,a		;size > MAX_SIZE
	ret			;return Z=1 & HL=0
3:
ENDC
;-----------------------------------------------------------------------------	
5:	
;do {
;  Element=FirstFromL(Lists[Lists[CrtSize])
				;
	push	bc		;B=Size, C=CrtSize on stack
	ld	a,c
	add	a,a
	add	a,a		;A=CrtSize*4
	ld	hl,L0
	add	a,l
	ld	l,a		;HL=CrtL=Lists[CrtSize]
COND	RSTS
	RST	40
ENDC
COND	RSTS=0
	call	__GetFromL	;HL=GetFromL(CrtL)
ENDC
	jr	z,7f
				;
;  if (Element) {
				;HL=Element
	ld	d,h
	ld	e,l		;save DE=Element
;    Element->Status=ALLOCATED
	ld	a,OFF_STS
	add	a,l
	ld	l,a		;HL=&El.Status
	call	_GetID		;A=Crt TCB ID, CARRY=0
	ld	(hl),a		;ALLOCATED
				;
	pop	bc		;B=Size, C=CrtSize
	inc	l		;HL=&El.Size
;    Element->Size=Size
	ld	(hl),b		;set ElSize = Size
	ld	a,c
;    if ( CrtSize == Size)
	cp	b	
;      return Element
	jr	nz,6f
	ex	de,hl		;HL=Element
	inc	a		;Z=0
	ret			;return HL=Element
6:	
;    do {
;      CrtSize--
	dec	c		;decrement CrtSize
				;
	push	bc		;B=Size, C=CrtSize back on stack
				;
;      ElementBuddy = Element XOR Buddy_XOR_Mask
	ld	a,c
	add	a,a		;A=CrtSize*2
	ld	hl,Buddy
	add	a,l
	ld	l,a		;HL=pointer to Buddy_XOR_mask
	push	de		;DE=Element on stack
	ld	a,e
	xor	(hl)
	ld	e,a
	inc	l
	ld	a,d
	xor	(hl)
	ld	d,a		;DE = ElementBuddy = Element XOR Buddy_XOR_Mask
;      CrtL=Lists[CrtSize]
	ld	hl,L0		;C is still = CrtSize
	ld	a,c
	add	a,a
	add	a,a		;A=CrtSize*4
	add	a,l
	ld	l,a		;HL=CrtL=Lists[CrtSize]
;      AddToL(CrtL, ElementBuddy)
COND	RSTS
	RST	24
ENDC
COND	NORSTS
	call	__AddToL	;AddToL(HL=CrtL, DE=ElementBuddy)
ENDC
				;returned HL=ElementBuddy
	pop	de		;DE=Element
;      ElementBuddy->Status=AVAILABLE
	ld	a,OFF_STS
	add	a,l
	ld	l,a
	ld	(hl),AVAILABLE	
;      ElementBuddy->Size=CrtSize
				;
	pop	bc		;B=Size, C=CrtSize
				;
	inc	l
	ld	a,c
	ld	(hl),a		;set ElBuddy Size = CrtSize	
;    while (--CrtSize != Size)
	cp	b
	jr	nz,6b
;
COND	SIO_RING
	call	GetSIOChars	;check pending SIO inputs
ENDC
	or	d		;Z=0
	ex	de,hl		;HL=Element
	ret			;return HL=Element	
;
;   end if (Element) }
7:	
;}
;while (CrtSize++ < MAX_SIZE)
	pop	bc		;B=Size, C=CrtSize
	inc	c		;++CrtSize
	ld	a,c
	cp	MAX_SIZE+1
	jr	nz,5b
;
COND	SIO_RING
	call	GetSIOChars	;check pending SIO inputs
ENDC
	xor	a		;Z=1, no available memory
	ld	h,a
	ld	l,a
	ret			;return HL=0	
;
;	Deallocate a memory block of given size
;
;	called under DI
;	C=size ( size <= MAX_SIZE ) : only when DEBUG=1
;	HL=memory block addr
;	returns HL=1 if ok, 
;		else 0 if wrong address or size or memory block is not allocated
;	Local variables : DE = Element, C=CrtSize
;	Affected regs: A,BC,DE,HL
;	IX,IY not affected
;
__Bdealloc:
;-----------------------------------------------------------------------------	
COND	DEBUG
	push	bc		;size on stack
	push	hl		;block addr on stack
	ld	de,BMEM_BASE
	or	a		;CARRY=0
	sbc	hl,de
	pop	de		;DE=block addr
	jr	c,9f		;return 0 if address < BMEM_BASE
				;CARRY=0
COND	SIM
	ld	hl,BMEM_BASE+BMEM_SIZE
	sbc	hl,de
	jr	c,9f		;return 0 if address > BMEM_BASE+BMEM_SIZE
ENDC
	ld	a,c
	add	a,a		;A=CrtSize*2
	ld	hl,Buddy
	add	a,l
	ld	l,a
	ld	c,(hl)
	inc	l
	ld	b,(hl)		;BC=size of memory block to be deallocated
	dec	bc		;BC=safety mask (AND-ed with address shall be = 0)
				;DE=block address
	ld	a,d
	and	b
	jr	nz,9f		;return 0 if wrong address provided
	ld	a,e
	and	c
	jr	nz,9f		;return 0 if wrong address provided
;Element=Addr
	ld	h,d
	ld	l,e		;HL=DE=ElementAddr
	ld	a,OFF_STS
	add	a,l
	ld	l,a
	ld	a,(hl)		;A=Element->Status
	or	a		;ALLOCATED?
	jr	nz,8f
9:	
	pop	bc		;drop Size
10:	
	ld	hl,0
	ret			;return 0 
8:	
	inc	l
	ld	a,(hl)		;A=Element->Size
	pop	bc		;C=Size
	cp	c
	jr	nz,10b		;return 0 if Element->Size != Size
ENDC
;-----------------------------------------------------------------------------
COND	NODEBUG
	ld	d,h
	ld	e,l		;DE=HL=Element
	ld	a,OFF_SIZE
	add	a,l
	ld	l,a
	ld	c,(hl)		;C=CrtSize=Size
ENDC
;-----------------------------------------------------------------------------	
	ld	b,0		;B=0
;CrtSize=Size
;while (CrtSize < MAX_SIZE) {
10:	
	push	de		;DE=Element on stack
	ld	a,c		;A=CrtSize
	cp	MAX_SIZE
	jr	z,11f		;quit while loop when CrtSize == MAX_SIZE
				;
;  ElementBuddy = Element XOR Buddy_XOR_Mask
	ld	a,c
	add	a,a		;A=CrtSize*2
	ld	hl,Buddy
	add	a,l
	ld	l,a		;HL=pointer to Buddy_XOR_mask
	ld	a,e
	xor	(hl)
	ld	e,a
	inc	l
	ld	a,d
	xor	(hl)
	ld	d,a		;DE = ElementBuddy = Element XOR Buddy_XOR_Mask
	ex	de,hl		;HL=ElementBuddy
	ld	a,OFF_STS
	add	a,l
	ld	l,a
	ld	a,(hl)		;A=BuddyStatus
	or	a		;is AVAILABLE ?
	jr	nz,11f		;break if ElementBuddy->Status != AVAILABLE
	inc	l
	ld	a,(hl)		;A=BuddySize
	cp	c		;is BuddySize == CrtSize ?
	jr	nz,11f		;break if ElementBuddy->Size != CrtSize
				;CARRY=0
	ld	a,l
	sub	OFF_SIZE
	ld	l,a		;HL=ElementBuddy
;  RemoveFromL(ElementBuddy)
	push	bc		;save CrtSize
COND	RSTS
	RST	32
ENDC
COND	NORSTS
	call	__RemoveFromL	;HL is still = ElementBuddy
ENDC
	pop	bc		;restore CrtSize
	ex	de,hl		;DE=ElementBuddy
	pop	hl		;HL=Element
				;must set Element = min (Element,Buddy)
;  if (ElementBuddy < Element)
				;compare DE(buddy) ? HL(element)
	ld	a,d
	cp	h
	jr	c,12f
				;buddy high (D) >= element high (H)
	ld	a,e
	cp	l
	jr	c,12f
				;buddy low (E) >= element low (L)
				;buddy (DE) >= HL (element)...
;    then Element = ElementBuddy
	ex	de,hl		;so set DE (element) = HL
12:
	inc	c		;C=CrtSize++
	jr	10b
				;
;} end while (CrtSize < MAX_SIZE)
11:
	pop	de		;DE=Element
	ld	h,d
	ld	l,e		;HL=DE=Element
	inc	l
	inc	l
	inc	l
	inc	l
;Element->Status=AVAILABLE
	ld	(hl),AVAILABLE	
	inc	l
;Element->Size = CrtSize;
	ld	(hl),c		;set Element Size=CrtSize
	ld	a,c
	add	a,a
	add	a,a		;A=CrtSize*4
	ld	hl,L0
	add	a,l
	ld	l,a		;HL=CrtL=Lists[CrtSize]
;CrtL=Lists[CrtSize]
;AddToL(CrtL, Element);
COND	RSTS
	RST	24
ENDC
COND	NORSTS
	call	__AddToL	;Add DE=Element to HL=CrtL
ENDC
COND	SIO_RING
	call	GetSIOChars	;check pending SIO inputs
ENDC
	ld	hl,1
	ret			;return 1
;
COND	C_LANG
;
;	Extend - extends size of allocated block, conserving its contents
;
;void* Extend(void* block);
;
;	HL=block to be extended
;	returns HL=extended block
;	 or NULL if no more dynamic memory or wrong block addr
;
_Extend:
	push	af
	ld	hl,4
	add	hl,sp
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	bc
	push	de
	di
	call	__Extend
	ei
	pop	de
	pop	bc
	pop	af
	ret
ENDC
;
;	Extend - internal
;
;	called under DISABLED interrupts
; 
;	HL=block to be extended
;	returns Z=0 & HL=extended block 
;	 or Z=1 & HL=NULL if no more dynamic memory or wrong block addr
;	affects AF,BC,DE,HL
;
__Extend:
COND	DEBUG
	push	hl		;block addr on stack
	ld	de,BMEM_BASE
	or	a		;CARRY=0
	sbc	hl,de
	pop	de		;DE=block addr
	jr	nc,1f
9:	xor	a		;Z=1
	jp	RET_NULL	;return 0 if address < BMEM_BASE
1:				;CARRY=0
COND	SIM
	ld	hl,BMEM_BASE+BMEM_SIZE
	sbc	hl,de
	jr	c,9b
ENDC
	ld	a,OFF_SIZE
	add	a,e
	ld	e,a
	ld	a,(de)		;A=size of block
	add	a,a		;A=size*2
	ld	hl,Buddy
	add	a,l
	ld	l,a
	ld	c,(hl)
	inc	l
	ld	b,(hl)		;BC=size of memory block
	ld	a,e
	sub	OFF_SIZE
	ld	e,a		;DE=block address
	dec	bc		;BC=safety mask (AND-ed with address shall be = 0)
	ld	a,d
	and	b
	jr	nz,9b
	ld	a,e
	and	c
	jr	nz,9b
	ld	h,d
	ld	l,e		;HL=DE=block addr
	ld	a,OFF_STS
	add	a,e
	ld	e,a
	ld	a,(de)		;A=block status
	or	a		;free?
	jp	z,RET_NULL	;if yes, return 0 (wrong block addr)
ENDC
	ld	a,OFF_SIZE
	add	a,l
	ld	l,a
	ld	a,(hl)		;A=bSize
	cp	8
	jr	c,1f
	xor	a		;Z=1
	jp	RET_NULL	;if block size >= 1000H, cannot extend
1:
	inc	a		;increment bSize
	ld	c,a		;C=bSize to be allocated
	ld	a,l
	sub	OFF_SIZE
	ld	l,a		;HL=old block addr
	push	hl		;on stack
COND	SIO_RING
	call	GetSIOChars	;check pending SIO inputs
ENDC
	call	__Balloc
	jr	z,nomem		;return 0 if cannot alloc
	push	hl		;new block on stack
	ex	de,hl		;DE=new block
	ld	a,OFF_SIZE
	add	a,e
	ld	e,a
	ld	a,(de)
	inc	e		;DE=new block data pointer
	dec	a		;A=old block bSize
	add	a,a
	ld	hl,Buddy
	add	a,l
	ld	l,a
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a		;HL=old block size
	ld	bc,B_H_SIZE
	or	a		;CARRY=0
	sbc	hl,bc
	ld	b,h
	ld	c,l		;BC=old block data size
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	add	a,B_H_SIZE
	ld	l,a		;HL=old block data pointer
	ldir			;move data from old to new block
COND	SIO_RING
	call	GetSIOChars	;check pending SIO inputs
ENDC
	pop	de		;DE=new block
	pop	hl		;HL=old block
	push	de		;new block on stack
COND	DEBUG
	ld	a,OFF_SIZE
	add	a,l
	ld	l,a
	ld	c,(hl)		;C=old block bSize
	sub	OFF_SIZE
	ld	l,a		;HL=old block
ENDC
	call	__Bdealloc	;dealloc old block
	pop	hl		;HL=new block
	ld	a,l
	or	h		;Z=0
	ret
nomem:	
	pop	hl
	jp	RET_NULL
;
;	FOR DEBUG: use with tballoc.c -------------------------
;
COND	DEBUG_BALLOC
CleanRP:
CleanWP:
;
_GetID:	ld	a,1
__GetTaskByID:
	ret
;
GetSIOChars:
	ld	hl,1234		;just to affect HL
	ld	a,89		;and A
	ret
;
BASE_DATA	equ	7F00H

; Available block list headers
;
L0	equ	BASE_DATA
	;defw	L0	;size=0(=10H)
	;defw	L0
L1	equ	BASE_DATA+4	
	;defw	L1	;size=1(=20H)
	;defw	L1
L2	equ	BASE_DATA+8	
	;defw	L2	;size=2(=40H)
	;defw	L2
L3	equ	BASE_DATA+12	
	;defw	L3	;size=3(=80H)
	;defw	L3
L4	equ	BASE_DATA+16	
	;defw	L4	;size=4(=100H)
	;defw	L4
L5	equ	BASE_DATA+20	
	;defw	L5	;size=5(=200H)
	;defw	L5
L6	equ	BASE_DATA+24
	;defw	L6	;size=6(=400H)
	;defw	L6
L7	equ	BASE_DATA+28	
	;defw	L7	;size=7(=800H)
	;defw	L7
L8	equ	BASE_DATA+32	
	;defw	L8	;size=8(=1000H)
	;defw	L8
L9	equ	BASE_DATA+36	
	;defw	L9	;size=9(=2000H)
	;defw	L9
;
Lists	equ	BASE_DATA+40	
	;defw	L0,L1,L2,L3,L4,L5,L6,L7,L8,L9
;
; Buddy block sizes
;
Buddy	equ	BASE_DATA+60	
;	defw	10H,20H,40H,80H,100H,200H,400H,800H,1000H,2000H

ENDC
;
;	FOR DEBUG --------------------------------------
;

