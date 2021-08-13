;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	Utility routines
;
*Include config.mac

	psect	text

	GLOBAL	__IsInL
	GLOBAL	IsItTask,IsItActiveTask,IsSuspended
	GLOBAL	AllTasksH,_TasksH

SEM_OFF		equ	9	;LocalSemaphore in TCB
NXPV_OFF	equ	16	;(NextTask,PrevTask)
WAITSEM_OFF	equ	20	;WaitSem

;
;	Is it a task?
;
;	called under DI
;	BC=TCB to be checked
;	returns Z=1 if it's a task, else Z=0 if it's NOT a task
;	HL not affected
;
IsItTask:
	push	hl
	ld	a,NXPV_OFF	;adjust BC=BC+NXPV_OFF
	add	a,c
	ld	c,a		;BC is to be searched
	ld	hl,AllTasksH	;in all tasks list
	call	__IsInL
	pop	hl
	ret
;
;	Is it an active task?
;
;	called under DI
;	BC=TCB to be checked
;	returns Z=1 if it's an active task, else Z=0 if it's NOT an active task
;	HL, BC not affected
;
IsItActiveTask:
	push	hl
	ld	hl,_TasksH	;search in active tasks list
	call	__IsInL
	pop	hl
	ret
;
;	Is the task suspended
;
;	called under DI
;	BC=TCB (it is a task waiting a semaphore)
;	returns Z=1 if suspended, else Z=0
;	HL,BC not affected
;	AF,DE affected
;
IsSuspended:
	push	hl		;save HL
	ld	h,b
	ld	l,c		;HL=TCB
	ld	a,WAITSEM_OFF
	add	a,l
	ld	l,a
	ld	e,(hl)
	inc	l
	ld	d,(hl)		;DE=semaphore waited by the task
	ld	h,b
	ld	l,c		;HL=TCB
	ld	a,SEM_OFF
	add	a,l		;CARRY=0
	ld	l,a		;HL=addr of task local semaphore, CARRY=0
	sbc	hl,de		;HL ? DE
	pop	hl
	ret			;Z=1 : suspended, Z=0 : not suspended

COND	DEBUG

	GLOBAL	IsItSem
;
;	IsItSemaphore ?
;
;	called under DI
;	HL=semaphore address
;	returns Z=1 if it is a semaphore, else Z=0
;	HL not affected
;
IsItSem:
	push	hl
	ld	c,(hl)
	inc	l
	ld	b,(hl)		;BC=first in sem list
	scf			;CARRY=1
	sbc	hl,bc		;is it equal to sem?
	pop	hl
	ret	z		;yes, it's a semaphore
	jr	IsItTask	;else, is it a task? 	

ENDC

COND	DEBUG .or. CMD

	GLOBAL	DE_hex
	GLOBAL	Byte_C_hex

;
;	(HL++) = Ascii(A)
;
A_hex:
	cp	0AH
	jr	c,1f
			;A to F
	add	a,'A'-0AH
2:
	ld	(hl),a
	inc	hl
	ret
1:			;0 to 9
	add	a,'0'
	jr	2b
;
;	(HL++) = Ascii(high(C))
;	(HL++) = Ascii(low(C))
;
Byte_C_hex:
	ld	a,c
	srl	a
	srl	a
	srl	a
	srl	a
	call	A_hex
	ld	a,c
	and	0FH
	jr	A_hex
;
;	sprintf((HL), "%X", DE) 
;	DE not affected
;
DE_hex:
	ld	c,d
	call	Byte_C_hex
	ld	c,e
	jr	Byte_C_hex
ENDC

COND	CMD
	
	GLOBAL	UpperC
	GLOBAL	StrUC
	GLOBAL	StrCmp
	GLOBAL	ReadA
	GLOBAL	ReadBC
;
;       Converts A to Upper Case
;
;       A=char to be converted to uppercase
;       returns A
;       registers not affected (except AF)
;
UpperC:
        cp      'a'
        ret     c
        cp      'z'+1
        ret     nc
        sub     'a'-'A'
        ret
;
;	Converts a string to Upper Case
;
;	HL=string addr
;
StrUC:	
	ld	a,(hl)
	or	a
	ret	z
	call	UpperC
	ld	(hl),a
	inc	hl
	jr	StrUC
;
;	Compare strings
;
;	HL,DE = strings (second is 3 chars long)
;	returns Z=1 : equal, else Z=0
;
StrCmp:
	ld	a,(de)
	cp	(hl)
	ret	nz
	inc	hl
	inc	de
	ld	a,(de)
	cp	(hl)
	ret	nz
	inc	hl
	inc	de
	ld	a,(de)
	cp	(hl)
	ret
;
;       Read Byte in A
;
;       HL=pointer of chars (2 hexa chars)
;
;       returns CARRY=0, A=byte, increment HL=HL+2
;		or CARRY=1 if not hex digits
;       registers not affected (except AF)
;
ReadA:
        push    bc
        ld      a,(hl)          ;1'st char
        cp      0DH
        jr      z,SyntaxErr
        call    CharToNumber    ;...as number, A = the high half
        jr	c,SyntaxErr
        sla     a
        sla     a
        sla     a
        sla     a
        ld      c,a             ;store in C high half
        inc     hl
        ld      a,(hl)          ;2'nd char
        cp      0DH
        jp      z,SyntaxErr
        call    CharToNumber    ;...as number, A = the low half
        jr	c,SyntaxErr
        or      c               ;merge A with high half from C, CARRY=0
        pop     bc
        inc     hl
        ret
SyntaxErr:
	scf			;CARRY=1
	pop	bc
	ret
;
;       Read Word in BC
;
;       HL=pointer of chars (4 hexa chars, followed by a <0DH>)
;       returns returns CARRY=0, BC=word, increment HL=HL+4
;		or CARRY=1 if not hex digits
;       registers not affected (except AF)
;
ReadBC:
        call    ReadA           ;read first 2 chars
	ret	c
        ld      b,a             ;in B
        call    ReadA           ;read last 2 chars
	ret	c
        ld      c,a             ;in C
        ret			;CARRY=0
;
;       Is Hex A
;
;       Is character hexadecimal?
;
;       A = ASCII character (uppercase)
;       if character is hexadecimal (0 to 9, A to F)
;               returns CARRY=0 
;       else
;               returns CARRY=1
;       registers not affected (except AF)
;
IsHex:
        cp      '0'             ;Less than '0'?
        ret     c               ;Yes, so return NOT hex
        cp      '9'+1           ;Less than or equal to '9'?
        ccf
        ret     nc              ;Yes, so numeric
        cp      'A'             ;Less than 'A'
        ret     c               ;Yes, so return NOT hex
        cp      'F'+1           ;Less than or equal to 'F'?
        ccf
        ret
;
;	Converts ASCII to number
;	A= ASCII char
;	returns CARRY=0 & A=number, or CARRY=1 if char not a hexa digit
;
CharToNumber:
	call	IsHex
	ret	c
	sub	'0'
	cp	10
	jr	nc,1f
	ccf			;CARRY=0
	ret
1:
	sub	7
	ret
;
ENDC
