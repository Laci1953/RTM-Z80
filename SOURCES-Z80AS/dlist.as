;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
TITLE Double linked list routines
;
*Include config.mac
;
; List header structure:
; Head: DEFW    First
;       DEFW    Last
;
; An empty list has First = Last = Head
;
; List element structure:
; Elem: DEFW    Next
;       DEFW    Prev
;       data
;
        psect text

;public API
        GLOBAL __InitL
        GLOBAL __AddToL
        GLOBAL __RemoveFromL
        GLOBAL __FirstFromL
        GLOBAL __LastFromL
        GLOBAL __NextFromL
	GLOBAL __InsertInL
	GLOBAL __GetFromL
	GLOBAL __RotateL
	GLOBAL __AddTask
	GLOBAL __IsInL
;
	GLOBAL	RET_NULL,EI_RET_NULL,RET_FFFF,EI_RET_FFFF
IF	SIO_RING
	GLOBAL	GetSIOChars
ENDIF
;
;	public error returns
;
EI_RET_NULL:
	ei
RET_NULL:
	ld	hl,0
	ret
EI_RET_FFFF:
	ei
RET_FFFF:
	ld	hl,0FFFFH
	ret
;
;	__InitL
;
;	must be called under interrupts DISABLED
;	HL=ListHeader, returned
;	affected regs: HL,DE
;	A,BC,IX,IY not affected
;
__InitL:
	ld      e,l
        ld      d,h
        ld      (hl),e
        inc     l
        ld      (hl),d          ;First=Header
        inc     l
        ld      (hl),e
        inc     l
        ld      (hl),d          ;Last=Header
        ex      de,hl           ;return HL=ListHeader
	ret
;
;	__AddToL
;
;	must be called under interrupts DISABLED
;	HL=list header, DE=new
;	return HL=new
;	affected regs: A,BC,DE,HL
;	IX,IY not affected
;
__AddToL:
        ld      a,l
        ld      (de),a
        inc     e
        ld      a,h
        ld      (de),a
        dec     e              ;New.Next=ListHeader
        inc     l
        inc     l
        ld      c,(hl)
        ld      (hl),e
        inc     l
        ld      b,(hl)
        ld      (hl),d          ;BC=Last, ListHeader.Last=New
        ld      a,e
        ld      (bc),a
        inc     c
        ld      a,d
        ld      (bc),a
        dec     c              ;Last.Next=New
IF	SIO_RING
	call	GetSIOChars
ENDIF
        ld      l,e
        ld      h,d             ;return HL=New
        inc     e
        inc     e
        ld      a,c
        ld      (de),a
        inc     e
        ld      a,b
        ld      (de),a          ;New.Prev=Last
	ret
;
;	__FirstFromL
;
;	must be called under interrupts DISABLED
;	HL=list header
;	returns (HL=first and Z=0) or (HL=0 and Z=1 and CARRY=0)
;	affected regs: DE,HL
;	A,BC,IX,IY not affected
;
__FirstFromL:
        ld      e,(hl)
        inc     l
        ld      d,(hl)
        dec     l		;DE=First, HL=ListHeader
				;compare HL ? DE 
	or	a		;CARRY=0
	sbc	hl,de
	ret	z		;List empty, return 0
	ex	de,hl		;HL=First
	ret
;
;	__LastFromL
;
;	must be called under interrupts DISABLED
;	HL=list header
;	returns (HL=last and Z=0) or (HL=0 and Z=1)
;	affected regs: DE,HL
;	A,BC,IX,IY not affected
;	
__LastFromL:
        inc     l
        inc     l
        ld      e,(hl)
        inc     l
        ld      d,(hl)
        dec     l
        dec     l
        dec     l		;DE=Last, HL=ListHeader
				;compare HL ? DE 
	or	a		;CARRY=0
	sbc	hl,de
	ret	z		;List empty, return 0
	ex	de,hl		;HL=Last
	ret
;
;	__NextFromL
;
;	must be called under interrupts DISABLED
;	DE=list header, HL=crt el
;       returns (HL=next after crt and Z=0) or (HL=0 and Z=1 if end-of-list)
;	affected regs: A,DE,HL
;	BC,IX,IY not affected
;
__NextFromL:
        ld      a,(hl)
        inc     l
        ld      h,(hl)
        ld      l,a             ;HL=CrtElement.Next
	ex	de,hl		;DE=CrtElement.Next,HL=list header
	or	a		;CARRY=0
	sbc	hl,de
	ret	z		;End-Of-List, return 0
	ex	de,hl		;HL=CrtElement.Next
	ret
;
;	__RemoveFromL
;
;	must be called under interrupts DISABLED
;	HL=elem to be removed
;	Returns HL=Element
;	affected regs: A,BC,DE,HL
;	IX,IY not affected
;
__RemoveFromL:
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
        ld      e,(hl)
        inc     l
        ld      d,(hl)
        inc     l              ;DE=Next
        ld      c,(hl)
        inc     l
        ld      b,(hl)          ;BC=Prev
        ld      a,e
        ld      (bc),a
        inc     c
        ld      a,d
        ld      (bc),a          ;Prev.Next=Next
        dec     c
        inc     e
        inc     e
        ld      a,c
        ld      (de),a
        inc     e
        ld      a,b
        ld      (de),a          ;Next.Prev=Prev
	dec	l
	dec	l
	dec	l		;HL=element
	ret
;
;	__InsertInL
;
;	must be called under interrupts DISABLED
;	HL=crt elem, BC=new elem
;	returns HL=new elem
;	affected regs: A,BC,DE,HL
;	IX,IY not affected
;
__InsertInL:
	inc	l
	inc	l
	ld	e,(hl)
	ld	(hl),c
	inc	l
	ld	d,(hl)		;DE=PrevElement
	ld	(hl),b		;CrtElement.prev=NewElement
	dec	l
	dec	l
	dec	l
	ld	a,c
	ld	(de),a
	inc	e
	ld	a,b
	ld	(de),a		;PrevElement.next=NewElement
	dec	e
	ld	a,l
	ld	(bc),a
	inc	c
	ld	a,h
	ld	(bc),a		;NewElement.next=CrtElement
	inc	c
	ld	a,e
	ld	(bc),a
	inc	c
	ld	a,d
	ld	(bc),a		;NewElement.prev=PrevElement
	dec	c
	dec	c
	dec	c
	ld	h,b
	ld	l,c		;HL=NewElement
	ret
;
;	__GetFromL
;
;	must be called under interrupts DISABLED
;	HL=list header
;	returns (HL=elem and Z=0) or (HL=0 and Z=1 if list empty)
;	affected regs: A,BC,DE,HL
;	IX,IY not affected
;
__GetFromL:
        ld      e,(hl)
        inc     l
        ld      d,(hl)
        dec     l		;DE=First, HL=ListHeader
				;compare HL ? DE 
	or	a		;CARRY=0
	sbc	hl,de
        ret	z	        ;list empty, return HL=0
IF	SIO_RING
	call	GetSIOChars
ENDIF
	ex	de,hl		;HL will be returned after removing element from list
        ld      e,(hl)		;Remove HL=Element
        inc     l
        ld      d,(hl)
        inc     l              ;DE=Next
        ld      c,(hl)
        inc     l
        ld      b,(hl)          ;BC=Prev
        ld      a,e
        ld      (bc),a
        inc     c
        ld      a,d
        ld      (bc),a          ;Prev.Next=Next
        dec     c
        inc     e
        inc     e
        ld      a,c
        ld      (de),a
        inc     e
        ld      a,b
        ld      (de),a          ;Next.Prev=Prev
	dec	l
	dec	l
	dec	l		;HL=element to be returned
	or	h		;Z=0
	ret
;
;	__RotateL
;
;	must be called under interrupts DISABLED
;	HL=list header
;	returns (HL=0 and Z=1 if list empty or has 1 element), else (HL=1 and Z=0)
;	affected regs: A,BC,DE,HL
;	IX,IY not affected
;
__RotateL:
	push	hl		;list header on stack
IF	NORSTS
	call	__FirstFromL
ELSE
	RST	0
ENDIF
	pop	de		;HL=First, DE=List Header
	ret	z		;List empty, return 0
	push	de		;list header on stack
	push	hl		;first on stack
	ex	de,hl		;HL=List Header
IF	RSTS
	RST	8
ELSE
	call	__LastFromL
ENDIF
	pop	de		;DE=First, HL=Last
        			;compare HL ? DE
	or	a		;CARRY=0
	sbc	hl,de
        jr  	nz,3f
	pop	bc		;drop list header
	ret			;List contains only 1 element, return 0
3:				;list contains at least 2 elements
	pop	hl		;HL=list header
	push	hl		;list header on stack
IF	RSTS
	RST	40
ELSE
	call	__GetFromL	;Get first element and remove-it
ENDIF
	ex	de,hl		;DE=removed elem
	pop	hl		;HL=list header
IF	RSTS
	RST	24
ELSE
	call	__AddToL	;Add removed element as last one
ENDIF
	ld	hl,1		;return 1
	or	l		;Z=0
	ret
;
;	AddTask
;
;	Inserts new task into tasks list, according to its priority (highest first)
;
PRI_OFF	EQU	6		;relative offset of Priority in TCB
;
;	must be called under interrupts DISABLED
;	HL=list header, BC=NewTaskTCB
;	return HL=NewTaskTCB and Z=0 and CARRY=0
;	affected regs: A,BC,DE,HL
;	IX,IY not affected
;
__AddTask:
	push	hl		;list header on stack
IF	NORSTS
	call	__FirstFromL
ELSE
	RST	0
ENDIF
				;HL=CrtTask=first task TCB
	jr	z,1f		
3:				;while (CrtTask)
	ex	de,hl		;DE=CrtTask
	ld	h,d
	ld	a,PRI_OFF
	add	a,e
	ld	l,a		;HL=DE+PRI_OFF=pointer to CrtTask priority
	ld	a,(hl)		;A=CrtTask priority
	ld	hl,PRI_OFF	;BC=NewTask
	add	hl,bc		;HL=pointer to NewTask priority
	cp	(hl)		;CrtTask.Prio ? NewTask.Prio
	jr	nc,2f
				;CrtTask.Prio < NewTask.Prio, so...
IF	SIO_RING
	call	GetSIOChars
ENDIF
	pop	hl		;drop list header
	ex	de,hl		;HL=CrtTask
				;Insert BC=NewTask before HL=CrtTask
IF	RSTS
	RST	48
ELSE
	call	__InsertInL
ENDIF
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
	or	h		;HL=NewTask & Z=0 & CARRY=0
	ret
2:				;CrtTask.Prio >= NewTask.Prio
				;DE=CrtTask, BC=newTask
IF	SIO_RING
	call	GetSIOChars
ENDIF
	pop	hl		;HL=list header
	push	hl		;keep it on stack
	ex	de,hl		;HL=CrtTask, DE=list header
IF	RSTS
	RST	16
ELSE
	call	__NextFromL
ENDIF
				;HL=CrtTask=next task TCB
	jr	nz,3b		;end while
1:
IF	SIO_RING
	call	GetSIOChars
ENDIF
	pop	hl		;HL=list header
	ld	d,b
	ld	e,c		;DE=new task
				;Add DE=NewTask to end of tasks list
IF	RSTS
	RST	24
ELSE
	call	__AddToL
ENDIF
IF	SIO_RING
	ex	de,hl
	call	GetSIOChars
	ex	de,hl
ENDIF
	or	h		;HL=NewTask & Z=0 & CARRY=0
	ret			
;
;	IsInL
;
;	Is element in the given list ?
;
;	must be called under interrupts DISABLED
;	HL=list header, BC=element
;	returns Z = 1 if element is in the list, Z = 0 if NOT
;	affected regs: A,DE,HL
;	BC not affected
;
__IsInL:
	ld	e,(hl)
	inc	l
	ld	d,(hl)
	dec	l		;DE=next,HL=header
3:	ld	a,h		;compare next ? header
	cp	d
	jr	nz,1f
	ld	a,l
	cp	e
	jr	nz,1f
				;equal, so element is not in the list, return Z=0
	or	h		;Z=0
	ret
1:				;not equal
	ld	a,d		;compare next ? element
	cp	b
	jr	nz,2f
	ld	a,e
	cp	c
	ret	z		;equal, so element was found
2:	push	hl		;not equal, so get the next one
	ex	de,hl		
	ld	e,(hl)
	inc	l
	ld	d,(hl)		;DE=next.next
	pop	hl		
	jr	3b		;loop
;
IF	DEBUG
;
;	Is it a List ?
;
;	must be called under interrupts DISABLED
;	HL=list header
;
;	If it's a list,
;		return Z=1
;	else
;		return Z=0
;	HL not affected
;
__IsItList:
	ld	e,(hl)
	inc	l
	ld	d,(hl)		;DE=first
	inc	l
	ld	c,(hl)
	inc	l
	ld	b,(hl)		;BC=last
	dec	l
	dec	l
	dec	l		;HL=header
	ld	a,h		;compare first ? header
	cp	d
	jr	nz,1f
	ld	a,l
	cp	e
	jr	nz,1f
				;equal
				;BC=last,HL=header
	ld	a,h		;compare last ? header
	cp	b
	ret	nz		;not equal, return Z=0
	ld	a,l
	cp	c
	ret			;if equal, it's a list, return Z=1,
				;else, it's not a list, return Z=0
1:				;HL=header,DE=first,BC=last
	inc	e
	inc	e
	ld	a,(de)		;A=low(first.prev)
	cp	l		;compare with low(header)
	ret	nz		;if not equal, it's not a list, return Z=0
	inc	e
	ld	a,(de)		;A=high(first.prev)
	cp	h		;compare with high(header)
	ret	nz		;if not equal, it's not a list, return Z=0
				;first.prev equal to header, 
				;let's check if last.next = header
	ld	a,(bc)		;A=low(last.next)
	cp	l		;compare with low(header)
	ret	nz		;if not equal, it's not a list, return Z=0
	inc	c
	ld	a,(bc)		;A=high(last.next)
	cp	h		;compare with high(header)
	ret			;if not equal, it's not a list, return Z=0
				;else, it's a list, return Z=1
;
ENDIF
