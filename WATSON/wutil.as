;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
*Include w.mac
;
        psect   text
;
        GLOBAL  wReadA
        GLOBAL  wReadBC
        GLOBAL  ReadDE
        GLOBAL  TypeBC
        GLOBAL  TypeDE
        GLOBAL  TypeHL
        GLOBAL  ByteToNibbles
        GLOBAL  NibbleToASCII
        GLOBAL  UpperCase
        GLOBAL  CharToNumber
        GLOBAL  FilterChar
        GLOBAL  IsHex
        GLOBAL  IsNumeric
        GLOBAL  IsInL
        GLOBAL  wIsItTask
        GLOBAL  wIsItActiveTask
        GLOBAL  wIsItSem
	GLOBAL	IsItQ
        GLOBAL  IsItRTClkB
        GLOBAL  IsItList
        GLOBAL  SyntaxErr
        GLOBAL  TypeA
        GLOBAL  TypeString
        GLOBAL  TasksH
        GLOBAL  ActiveTasksH
        GLOBAL  RtClockLH
        GLOBAL  msgBSandDEL
        GLOBAL  ReadLine
        GLOBAL  RtClockLH
        GLOBAL  RepeatCmd
        GLOBAL  StoreDE
	GLOBAL	GetTaskByID

COND	1-SIM
	GLOBAL	TypeChar,ReadChar
;
;	Read A from console
;
ReadChar:
	in	a,(SIO_A_C)	;RR0
	rrca			;char ready?
	jr	nc,ReadChar	;no, wait
	in	a,(SIO_A_D)	;get A=char
	ret
;
;	Type A at console
;
TypeChar:
	push	af
1:	in	a,(SIO_A_C)	;RR0
	and	100B		;ready for TX?
	jr	z,1b		;no, wait
	pop	af
	out	(SIO_A_D),a	;type A=char
	ret
;
ENDC
;
;       Print a byte in A (2 hexa chars, uppercase)
;
;       A=byte
;       registers not affected (except AF)
;
TypeA:
        push    de
        call    ByteToNibbles   ;High Nibble = D, Low Nibble = E
        ld      a,d
        call    NibbleToASCII
                                ;type High Nibble to console
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        ld      a,e
        call    NibbleToASCII
                                ;type Low Nibble to console
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        pop     de
        ret
;
;       Type String
;
;       Print string (zero terminated)
;
;       HL=string addr
;       BC,DE not affected
;
TypeString:
        ld      a,(hl)
        or      a
        ret     z
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        inc     hl
        jr      TypeString
;
;       Store Word
;
;       store DE in hexa at HL
;       DE not affected
;
StoreDE:
        push    de
        ld      a,d
        call    ByteToNibbles
        ld      a,d
        call    NibbleToASCII
        ld      (hl),a
        inc     hl
        ld      a,e
        call    NibbleToASCII
        ld      (hl),a
        inc     hl
        pop     de
        push    de
        ld      a,e
        call    ByteToNibbles
        ld      a,d
        call    NibbleToASCII
        ld      (hl),a
        inc     hl
        ld      a,e
        call    NibbleToASCII
        ld      (hl),a
        pop     de
        ret
;
;       Read a line from console, terminated with a <CR>
;
;       HL=buffer address
;       Up to 6 chars are accepted, including the <CR>, stored too
;       BackSpace is interpreted as "erase the last char, if any"
;       Cursor remains after last typed char (no CR echoed!)
;       AF,BC,HL affected
;
ReadLine:
        ld      b,6             ;char counter
        ld      a,(RepeatCmd)
        or      a               ;Repeat command at <CR> ?
        ld      a,0
        ld      (RepeatCmd),a   ;reset repeat!
        jr      z,1f
                                ;yes, now see if it's a <CR>
COND    1-SIM
        call	ReadChar
ENDC
COND    SIM
7:	in	a,(0)
	or	a
	jr	z,7b
	in	a,(1)
ENDC
        cp      CR
        ret     z               ;yes, it's a <CR>, return
        jp      2f
1:                              ;read char
COND    1-SIM
        call	ReadChar
ENDC
COND    SIM
7:	in	a,(0)
	or	a
	jr	z,7b
	in	a,(1)
ENDC
2:      ld      (hl),a          ;store-it
        cp      CR              ;CR?
        ret     z               ;if CR, do not output-it, just return
COND    SIM
        cp      DELETE          ;BackSpace?
ENDC
COND    1-SIM
        cp      BACKSPACE       ;BackSpace? / or DELETE ??? TO BE TESTED ON SCM !!!
ENDC
        jr      nz,2f
                                ;yes
        ld      a,b
        cp      6
        jr      z,1b            ;if first char, ignore-it
        dec     hl              ;else decrement pointer
        inc     b               ;...and increment counter
        PRINT   msgBSandDEL     ;output BACKSPACE,ESC,'[','K' (VT100 erase to EndOfLine)
        jr      1b              ;and wait for next char
2:
        inc     hl              ;increment pointer
                                ;type char
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        djnz    1b
        ret
;
;       Read Byte in A
;
;       HL=pointer of chars (2 hexa chars)
;       returns A=byte, increment HL=HL+2
;       handles syntax errors (jumps to SyntaxErr if non-hex chars or CR found)
;       registers not affected (except AF)
;
wReadA:
        push    bc
        ld      a,(hl)          ;1'st char
        cp      CR
        jp      z,SyntaxErr
        call    CharToNumber    ;...as number, A = the high half
        jp      c,SyntaxErr
        sla     a
        sla     a
        sla     a
        sla     a
        ld      c,a             ;store in C high half
        inc     hl
        ld      a,(hl)          ;2'nd char
        cp      CR
        jp      z,SyntaxErr
        call    CharToNumber    ;...as number, A = the low half
        jp      c,SyntaxErr
        or      c               ;merge A with high half from C
        pop     bc
        inc     hl
        ret
;
;       Read Word in BC, DE
;
;       HL=pointer of chars (4 hexa chars, followed by a <CR>)
;       returns BC/DE=word, increment HL=HL+4
;       handles syntax errors (jumps to SyntaxErr if non-hex chars or CR found)
;       registers not affected (except AF)
;
wReadBC:
        call    wReadA           ;read first 2 chars
        ld      b,a             ;in B
        call    wReadA           ;read last 2 chars
        ld      c,a             ;in C
        jr      1f
ReadDE:
        call    wReadA           ;read first 2 chars
        ld      d,a             ;in D
        call    wReadA           ;read last 2 chars
        ld      e,a             ;in E
1:
        ld      a,(hl)
        cp      CR
        jp      nz,SyntaxErr    ;must be followed by <CR>
        ret
;
;       Print a word in BC (4 hexa chars, uppercase)
;
;       BC=word
;       registers not affected (except AF)
;
TypeBC:
        ld      a,b             ;High byte
        call    TypeA
        ld      a,c             ;Low byte
        jp      TypeA
;
;       Print a word in DE (4 hexa chars, uppercase)
;
;       DE=word
;       registers not affected (except AF)
;
TypeDE:
        ld      a,d             ;High byte
        call    TypeA
        ld      a,e             ;Low byte
        jp      TypeA
;
;       Print a word in HL (4 hexa chars, uppercase)
;
;       HL=word
;       registers not affected (except AF)
;
TypeHL:
        ld      a,h             ;High byte
        call    TypeA
        ld      a,l             ;Low byte
        jp      TypeA
;
;       Converts Nibble A to ASCII
;
;       Converts Nibble (0-15) to its ASCII value ('0' to '9', or 'A' to 'F')
;
;       A=Nibble
;       returns A=ASCII value of byte (letters in uppercase)
;       registers not affected (except AF)
;
NibbleToASCII:
        cp      10              ;digit?
        jr      nc,1f
        add     a,'0'           ;it's a digit
        ret
1:      add     a,'A'-10        ;no, it's a letter (A to F)
        ret
;
;       Converts A to Upper Case
;
;       A=char to be converted to uppercase
;       returns A
;       registers not affected (except AF)
;
UpperCase:
        cp      'a'
        ret     c
        cp      'z'+1
        ret     nc
        sub     'a'-'A'
        ret
;
;       Char To Number
;
;       Convert character A to numeric value
;       A = ASCII character (0-9 or A-F)
;       If character is a valid hex digit:
;               returns A = Numeric value (0 to 15) and CARRY = 0
;       else
;               returns CARRY = 1
;       registers not affected (except AF)
;
CharToNumber:
        call    UpperCase
        cp      '0'             ;Character < '0'?
        ret     c               ;Yes, so no hex character
        cp      '9'+1           ;Character <= '9'?
        jr      c,1f            ;Yes, got hex character
        cp      'A'             ;Character < 'A'
        ret     c               ;Yes, so not hex character
        cp      'F'+1           ;Character <= 'F'
        jr      c,1f            ;No, not hex
        ccf                     ;CARRY=1
        ret                     ;Character is not a hex digit so return CARRY=1
                                ;Character is a hex digit so adjust from ASCII to number
1:      sub     '0'             ;Subtract '0'
        cp      0AH             ;Number < 10 ?
        jr      c,2f            ;Yes, so finished
        sub     7               ;Adjust for 'A' to 'F'
2:      or      a               ;Return A = number (0 to 15) and CARRY=0
        ret
;
;       Filter Char A
;
;       Filters non printable chars
;       A = char
;       returns A = printable char (if not printable then '.' is returned)
;       registers not affected (except AF)
;
FilterChar:
        cp      ' '             ;<SPACE?
        jr      c,1f
        cp      7FH             ;>7FH?
        ret     c
1:      ld      a,'.'
        ret
;
;       Byte To Nibbles
;
;       Convert byte to nibbles
;       A = Hex byte
;       returns D = Most significant nibble, E = Least significant nibble
;       registers not affected (except AF)
;
ByteToNibbles:
        ld      e,a
        rra
        rra
        rra
        rra
        and     0FH
        ld      d,a
        ld      a,e
        and     0FH
        ld      e,a
        ret
;
;       Is Hex A
;
;       Is character hexadecimal?
;
;       A = ASCII character
;       if character is hexadecimal (0 to 9, A to F)
;               returns CARRY=0 , A converted to uppercase
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
        call    UpperCase
        cp      'A'             ;Less than 'A'
        ret     c               ;Yes, so return NOT hex
        cp      'F'+1           ;Less than or equal to 'F'?
        ccf
        ret
;
;       Is Numeric A
;
;       Is character numeric?
;
;       A = ASCII character
;       if character is numeric (0 to 9)
;               returns CARRY=0
;       else
;               returns CARRY=1
;       registers not affected (except AF)
;
IsNumeric:
        cp      '0'             ;Less than '0'?
        ret     c               ;Yes, so return NOT numeric
        cp      '9'+1           ;Less than or equal to '9'?
        ccf
        ret
;
;       IsInL
;
;       Is element in the given list ?
;
;       must be called under interrupts DISABLED
;       HL=list header, BC=element
;       returns Z = 1 if element is in the list, Z = 0 if NOT
;       affected regs: A,DE,HL
;
IsInL:
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	dec	hl		;DE=next,HL=header
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
	inc	hl
	ld	d,(hl)		;DE=next.next
	pop	hl		
	jr	3b		;loop
;
;       Is it a task?
;
;       BC=TCB to be checked
;       returns Z=1 if it's a task, else Z=0 if it's NOT a task
;       BC not affected
;
wIsItTask:
        ld      hl,NXPV_OFF     ;adjust BC=BC+NXPV_OFF
        add     hl,bc
        ld      b,h
        ld      c,l             ;BC is to be searched
        ld      hl,(TasksH)     ;in all tasks list
        jr      IsInL
;
;       Is it an active task?
;
;       BC=TCB to be checked
;       returns Z=1 if it's an active task, else Z=0 if it's NOT an active task
;
wIsItActiveTask:
        ld      hl,(ActiveTasksH);search in active tasks list
        jr      IsInL
;
;       Is it RTClkB ?
;
;       BC=RTClkB
;
;       returns Z=1 if it is a RTClkB, else Z=0
;
IsItRTClkB:
        ld      hl,6
	add	hl,bc
        ld      e,(hl)
	inc	hl
        ld      d,(hl)          ;DE=Sem
	ex	de,hl
;
;       wIsItSemaphore ?
;
;       HL=semaphore address
;       returns Z=1 if it is a semaphore, else Z=0
;
wIsItSem:
        ld      c,(hl)
        inc     hl
        ld      b,(hl)          ;BC=first in sem list
        dec	hl              ;HL=sem
        or      a               ;CARRY=0
        sbc     hl,bc           ;BC equal to HL?
        ret     z               ;yes, it's a semaphore
        jr      wIsItTask       ;else, is it a task?
;
;       IsItList ?
;
;       HL=ListHeader
;       if it is a list,
;               returns Z=1
;       else
;               returns Z=0
;
;       HL not affected
;
IsItList:
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=first
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=last
	dec	hl
	dec	hl
	dec	hl		;HL=header
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
	inc	de
	inc	de
	ld	a,(de)		;A=low(first.prev)
	cp	l		;compare with low(header)
	ret	nz		;if not equal, it's not a list, return Z=0
	inc	de
	ld	a,(de)		;A=high(first.prev)
	cp	h		;compare with high(header)
	ret	nz		;if not equal, it's not a list, return Z=0
				;first.prev equal to header, 
				;let's check if last.next = header
	ld	a,(bc)		;A=low(last.next)
	cp	l		;compare with low(header)
	ret	nz		;if not equal, it's not a list, return Z=0
	inc	bc
	ld	a,(bc)		;A=high(last.next)
	cp	h		;compare with high(header)
	ret			;if not equal, it's not a list, return Z=0
				;else, it's a list, return Z=1
;
;	IsItQ
;
;       HL=queue address
;       returns Z=1 if it is a queue, else Z=0
;
IsItQ:
	ld	de,11
	add	hl,de		;HL=pointer to ReadS
	push	hl
	call	wIsItSem
	pop	hl
	ret	nz
	ld	de,6
	add	hl,de		;HL=pointer to WriteS
	jp	wIsItSem
;
;	GetTaskByID
;
;	Search task with ID=C
;	return Z=1 : no TCB was found, else Z=0 & HL=TCB
;	AF,HL,DE affected
;
GetTaskByID:
	ld	hl,(TasksH)
	ld	d,h
	ld	e,l		;DE=tasks header
NxT:  	ld      a,(hl)		;get next in list
        inc     hl
        ld      h,(hl)          
	ld	l,a		;HL=TCB+NXPV_OFF
	push	hl
	or	a		;CARRY=0
        sbc     hl,de
	pop	hl
        ret	z	        ;if next=header, return Z=1
	dec	hl		;HL=ID pointer
	ld	a,(hl)		;A=Crt ID
	inc	hl		;HL=TCB+NXPV_OFF
	cp	c		;equal to target ID?
	jr	nz,NxT
	ld	a,l
	sub	NXPV_OFF
	ld	l,a
	or	h		;HL=TCB, Z=0
	ret
