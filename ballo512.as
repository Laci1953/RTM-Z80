;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
TITLE	512 KB RAM Dynamic Memory support
;
*Include config.mac
;
IF	M512 .and. EXTM512

OPTIM	equ	1	;1=optimize alloc speed, 0=do not optimize
;
BANKS_CNT	equ	28	;28 banks of 16KB each are available
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
;
MAX_SIZE	equ	10	;max block = 4000H
LISTS_NR	equ	MAX_SIZE+1
AVAILABLE	equ	0
;
	GLOBAL	__Init512Banks
	GLOBAL	__alloc512
	GLOBAL	__free512
	GLOBAL	__set512bank
	GLOBAL	__Get512Free
IF	C_LANG
	GLOBAL	_alloc512
	GLOBAL	_free512
	GLOBAL	_set512bank
	GLOBAL	_Get512Free
ENDIF
	GLOBAL	__AddToL
	GLOBAL	__RemoveFromL
	GLOBAL	__GetFromL
;
;	The following buffers size is 76AH
;	They are allocated in the bottom of the 8KB dynamic memory
;
;	Available block list headers
;
L0	equ	BMEM_BASE+6			;L0 bank0,L0 bank1,...L0 bank27
L1	equ	L0 + 4*BANKS_CNT
L2	equ	L1 + 4*BANKS_CNT
L3	equ	L2 + 4*BANKS_CNT
L4	equ	L3 + 4*BANKS_CNT
L5	equ	L4 + 4*BANKS_CNT
L6	equ	L5 + 4*BANKS_CNT
L7	equ	L6 + 4*BANKS_CNT
L8	equ	L7 + 4*BANKS_CNT
L9	equ	L8 + 4*BANKS_CNT
L10	equ	L9 + 4*BANKS_CNT
;
Lists	equ	L10 + 4*BANKS_CNT	;bank0(L0,L1,...L10),bank1(L0+4,L1+4,...L10+4)... 
;
Buddy	equ	Lists + LISTS_NR*2*BANKS_CNT
;
IF	OPTIM
;	Maximum Available
;	contains (Size+1) if available, or zero if unavailable
;
MaxAv	equ	Buddy + LISTS_NR*2	;defs	BANKS_CNT
ENDIF

	psect	text

IF	C_LANG
;
;	short Get512Free(void);
;
;	returns HL=total amount of free 512MB memory in KB
;
_Get512Free:
__Get512Free:
	push	ix
	push	iy
	call	__GetTotalFree
	pop	iy
	pop	ix
	ret
ENDIF
;
;	__GetTotalFree
;
;	returns HL=total amount of free 512MB memory in KB
;
__GetTotalFree:
	ld	iy,0		;IY=grand total
	ld	bc,BANKS_CNT	;B = CARRY = 0, C = banks counter
bigloop:
	ld	ix,0		;IX=crt bank total
	push	bc		;save BC
	ld	a,BANKS_CNT
	sub	c		;A=crt bank (0,1...)
	add	a,32+4
	out	(7BH),a		;select physical RAM bank number A in logical bank 2 (8000-C000)
	sub	32+4		;A=crt bank (0,1...)
	ld	de,LISTS_NR*2	;DE=LISTS_NR*2
				;compute HL=Lists+(crt.bank)*(LISTS_NR*2)
	ld	hl,Lists
1:	or	a
	jr	z,2f
	add	hl,de
	dec	a
	jr	1b
2:
	ld	a,LISTS_NR	;A=counter of lists
	ld	bc,10H		;BC=size of blocks
nextl:	push	af
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=crt list header
	inc	hl
	push	hl		;pointer of lists on stack
	ex	de,hl		;HL=crt list header
	push	hl		;on stack
nextb:	ld	e,(hl)
	inc	hl
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
				;done with crt bank
	pop	bc		;B = CARRY, C = banks counter
	push	ix
	pop	de		;DE=crt bank total
	add	iy,de		;add to grand total		
	jr	nc,2f
	inc	b		;increment carry if needed
2:
	dec	c
	jp	nz,bigloop

	push	iy
	pop	de
				;rotate (B,D) right 2 times
	srl	b
	rr	d
	srl	b
	rr	d

	ld	h,b
	ld	l,d
	ret
;
IF	C_LANG
;
;	Set Bank
;
;void	set512bank(char bank);
;
_set512bank:
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
ENDIF
;
;	__set512bank
;
;	A=bank
;
__set512bank:
	out	(7BH),a
	ret
;
;	Initialize buddy-system memory for 512 KB RAM banks
;	
;	called under DI
;	Affected regs: A,BC,DE,HL,IY
;
__Init512Banks:
				;init list headers for each bank
	ld	bc,BANKS_CNT * LISTS_NR	;total lists counter
	ld	hl,L0		;HL=first list header
initL:	
	ld	d,h		;DE=HL
	ld	e,l
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jr	nz,initL
				;init lists pointers for each bank
	ld	iy,Lists
	ld	a,BANKS_CNT
	ld	bc,4 * BANKS_CNT;delta for list headers
	ld	de,0		;offset in lists headers
initLHB:			;for each bank
	push	af
	ld	hl,L0
	add	hl,de
	ld	a,LISTS_NR
initLH:				
	ld	(iy+0),l
	ld	(iy+1),h
	inc	iy
	inc	iy
	add	hl,bc
	dec	a
	jr	nz,initLH
				;next bank
	inc	de		;increment offset in list headers
	inc	de
	inc	de
	inc	de	
	pop	af
	dec	a
	jr	nz,initLHB
				;init Buddy
	ld	hl,Buddy
	ld	de,10H
	ld	a,LISTS_NR
initBDY:ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ex	de,hl
	add	hl,hl
	ex	de,hl
	dec	a
	jr	nz,initBDY
				;fill each bank with 0
;	ld	a,BANKS_CNT
;filll:
;	push	af
;	add	a,32+3
;	out	(7BH),a		;select physical RAM bank number A in logical bank 3 (C000-FFFF)
;	ld	hl,Buf16K
;	xor	a
;	ld	c,40H		;4000H = 40H x 100H
;4:	ld	b,0
;3:	ld	(hl),a
;	inc	hl
;	djnz	3b
;	dec	c
;	jr	nz,4b
				;next bank
;	pop	af
;	dec	a
;	jr	nz,filll
				;init L10 list headers for each bank
	ld	b,BANKS_CNT
	xor	a
	ld	hl,L10		;HL=L10 lists header
initL10:
	push	af
	push	bc
	push	hl
	add	a,32+4
	out	(7BH),a		;select physical RAM bank number A in logical bank 3 (C000-FFFF)
	ld	de,Buf16K
	call	__AddToL	;add DE to HL header
	ld	hl,Buf16K+OFF_STS;HL=pointer of block status
	ld	(hl),AVAILABLE	;set block status = free
	inc	hl		;HL=pointer of block size
	ld	(hl),MAX_SIZE	;set size = 16KB
				;next bank
	pop	hl
	pop	bc
	pop	af
	inc	hl		;next header
	inc	hl
	inc	hl
	inc	hl
	inc	a		;next bank
	djnz	initL10
IF	OPTIM
				;init MaxAv vector
	ld	b,BANKS_CNT
	ld	hl,MaxAv
	ld	a,MAX_SIZE+1
loopav:	ld	(hl),a
	inc	hl
	djnz	loopav
ENDIF
	ret	
;	
;	allocS
;
;	BC=memory size (must be <= 4000H)
;	Affected regs: A,BC
;	Returns BC=bElement size
;
__allocS:
	dec	bc		;bc = memory size-1
	ld	a,b
	and	3FH		;keep it <= 3FH
	or	a
	jr	z,1f
				;high part != 0
	ld	bc,MAX_SIZE	;prepare bSize for 4000H
	bit	5,a
	ret	nz		;if bit#13=1 return 10 for 4000H
	dec	c		;BC=9
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
IF	C_LANG
;
;char*	alloc512(short size, char* BankPointer)
;
;	BankPointer = pointer to a byte where the RAM bank counter (0...31) will be stored
;	Size = number of bytes to be allocated
;
;	returns:
;
;	Pointer of memory (NOT NULL) if allocation done, and bank number stored in BankPointer
;	NULL if allocation failed
;
_alloc512:
	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=size in bytes
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=target bank pointer
;
ENDIF
;
;	__alloc512
;
;	BC=size, DE=pointer of bank
;
;	returns HL=Pointer of memory (NOT NULL) if allocation done, and bank number stored in BankPointer
;	NULL if allocation failed
;
__alloc512:
	inc	bc		;add 6 to size
	inc	bc
	inc	bc
	inc	bc
	inc	bc
	inc	bc
	push	de		;target bank pointer on stack
	call	__allocS	;C=bSize
	ld	b,BANKS_CNT	;B=banks counter
IF	OPTIM
	ld	hl,MaxAv	;HL=MaxAv vector
ENDIF
loop:
IF	OPTIM
				;compare bSize ? MaxAv[bank]
	ld	a,c
	cp	(hl)		;bSize ? MaxAv[bank]
	jr	c,try		;if < , try to allocate in this bank
	jr	toobig		;if >= , it's too big, try to allocate in the next bank
try:
ENDIF
	ld	a,BANKS_CNT
	sub	b		;try to allocate in this bank (A=bank nr)
	add	a,32+4 		;select physical RAM bank number A in logical bank 2 (8000-C000)
	out	(7BH),a
IF	OPTIM
	push	hl		;save MaxAv
ENDIF
	push	bc		;B=banks counter, C=bSize on stack
	sub	32+4		;A=current bank nr. (0,1,...27)
	call	__alloc		;try to alloc
	jr	nz,alloc_ok
				;local alloc failed
	pop	bc		;B=banks counter, C=bSize
IF	OPTIM
	pop	hl		;HL=MaxAv
	ld	(hl),c		;store failed bSize
toobig:
	inc	hl		;increment MaxAv pointer
ENDIF	
	djnz	loop
				;global alloc failed
	pop	de		;drop target bank pointer
	ld	hl,0		;return NULL
	ret
;
alloc_ok:			;HL=allocated block
	pop	bc		;B=banks counter
IF	OPTIM
	pop	de		;drop MaxAv
ENDIF
	pop	de		;DE=target bank pointer
	ld	a,BANKS_CNT
	sub	b		;A=current bank nr.
	add	a,32+4		;A=physical RAM bank number
	ld	(de),a		;store target bank
	ret			;return HL=allocated block
;
IF	C_LANG
;
;void	free512(char* Buf, char Bank);
;
;	Buf = pointer of memory to be deallocated 
;	Bank = physical RAM bank counter (36...63)
;
_free512:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=Buf
	inc	hl
	ld	a,(hl)		;A=physical RAM bank counter (36...63)
;
ENDIF
;
;	__free512
;
;	DE=buf, A=bank
;
__free512:
IF	OPTIM
	ld	hl,MaxAv	;HL=MaxAv vector
	ld	b,0
	ld	c,a
	add	hl,bc
	ld	(hl),MAX_SIZE+1	;set availability at full range...first alloc will settle-it
ENDIF
	out	(7BH),a		;select physical RAM bank number A in logical bank 2 (8000-C000)
	ex	de,hl		;HL=Buf
	sub	32+4		;A=current bank nr. (0,1,...27)
;
;	Deallocate a memory block of given size
;
;	called under DI
;	HL=memory block addr
;	A=current bank nr. (0,1,...27)
;	Local variables : DE = Element, 
;			C=CrtSize, 
;			IY=Lists[crt.bank],
;	Affected regs: A,BC,DE,HL,IY
;	IX not affected
;
__dealloc:
	ld	bc,-6
	add	hl,bc		;decrement HL by -6
				;compute IY=Lists+(crt.bank)*(LISTS_NR*2)
				;A=current bank nr. (0,1,...27)
	ld	de,LISTS_NR*2	;DE=LISTS_NR*2
	ld	iy,Lists
	ld	b,5		;how many times to shift A
2:
	rra			;shift right A
	jr	nc,1f
	add	iy,de
1:
	sla	e		;DE=DE*2
	rl	d
	djnz	2b
				;IY=Lists+(crt.bank)*(LISTS_NR*2)
	ld	d,h
	ld	e,l		;DE=HL=Element
	ld	a,OFF_SIZE
	add	a,l
	ld	l,a
	ld	c,(hl)		;C=CrtSize=Size
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
	call	__RemoveFromL	;HL is still = ElementBuddy
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
	add	a,a		;A=CrtSize*2
	push	iy
	pop	hl		;HL=Lists+(crt.bank)*(LISTS_NR*2)		
	ld	b,0
	ld	c,a
	add	hl,bc		;HL=Lists+(crt.bank)*(LISTS_NR*2)+(CrtSize*2)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=CrtL=Lists[CrtSize]
;CrtL=Lists[CrtSize]
;AddToL(CrtL, Element);
	jp	__AddToL	;Add DE=Element to HL=CrtL 
;
;	Allocate a memory block of given size
;
;	called under DI
;	A=current bank nr. (0,1,...27)
;	returns Z=0 and HL=pointer to memory block if available, 
;		else Z=1 if no memory available
;	Local variables: DE = Element, 
;			BC on stack (B=Size, C=CrtSize), 
;			IY=Lists[crt.bank],
;	Affected regs: A,BC,DE,HL
;	IX not affected
;
__alloc:
				;compute IY=Lists+(crt.bank)*(LISTS_NR*2)
				;A=current bank nr. (0,1,...27)
	ld	de,LISTS_NR*2	;DE=LISTS_NR*2
	ld	iy,Lists
	ld	b,5		;how many times to shift A
2:
	rra			;shift right A
	jr	nc,1f
	add	iy,de
1:
	sla	e		;DE=DE*2
	rl	d
	djnz	2b
				;IY=Lists+(crt.bank)*(LISTS_NR*2)
;CrtSize=Size
	ld	b,c		;CrtSize=Size
5:	
;do {
;  Element=FirstFromL(Lists[Lists[CrtSize])
				;
	push	bc		;B=Size, C=CrtSize on stack
	ld	a,c
	add	a,a		;A=CrtSize*2
	push	iy
	pop	hl		;HL=Lists+(crt.bank)*(LISTS_NR*2)		
	ld	d,0
	ld	e,a
	add	hl,de		;HL=Lists+(crt.bank)*(LISTS_NR*2)+(CrtSize*2)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=CrtL=Lists[CrtSize]
	call	__GetFromL	;HL=GetFromL(CrtL)
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
	ld	a,0FFH
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
	ld	bc,6
	add	hl,bc		;+6
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
	ld	a,c		;C=CrtSize
	add	a,a		;A=CrtSize*2
	push	iy
	pop	hl		;HL=Lists+(crt.bank)*(LISTS_NR*2)		
	ld	b,0
	ld	c,a
	add	hl,bc		;HL=Lists+(crt.bank)*(LISTS_NR*2)+(CrtSize*2)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a		;HL=CrtL=Lists[CrtSize]
;      AddToL(CrtL, ElementBuddy)
	call	__AddToL	;AddToL(HL=CrtL, DE=ElementBuddy)
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
	inc	a		;Z=0
	ex	de,hl		;HL=Element
	ld	bc,6
	add	hl,bc		;+6
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
;				;alloc failed
	xor	a		;Z=1, no available memory
	ret	
;
ENDIF

