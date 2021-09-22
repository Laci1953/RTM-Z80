;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
*Include w.mac
;
;-----------------------------------------------------------------------1-MM
COND	1-MM

MEMP_PORT       equ     38H
;
ROMOUT          equ     00000001B
ROMIN           equ     00000000B
LOWER_64RAM     equ     00000000B
UPPER_64RAM     equ     10000000B

MACRO	LOW_RAM
	ld	a,LOWER_64RAM .or. ROMOUT
	out	(MEMP_PORT),a
ENDM

MACRO	UP_RAM
	ld	a,UPPER_64RAM .or. ROMOUT
	out	(MEMP_PORT),a	
ENDM

ENDC
;-----------------------------------------------------------------------1-MM
;-----------------------------------------------------------------------MM
COND	MM

MM_RAM_P	equ	30H

MM_UP_RAM	equ	1
MM_LOW_RAM	equ	0

MACRO	LOW_RAM
	ld	a,MM_LOW_RAM
	out	(MM_RAM_P),a
ENDM

MACRO	UP_RAM
	ld	a,MM_UP_RAM
	out	(MM_RAM_P),a
ENDM

MM_ROM_P	equ	38H

MM_ROM_IN	equ	0
MM_ROM_OUT	equ	1

ENDC
;-----------------------------------------------------------------------MM

        psect   text
;
	GLOBAL	TypeChar,ReadChar
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
        GLOBAL  DEtoHL
        GLOBAL  TasksH
        GLOBAL  ActiveTasksH
        GLOBAL  RtClockLH
        GLOBAL  SnapLoadCD
        GLOBAL  SnapLoadDM
        GLOBAL  CrtPage
        GLOBAL  msgBSandDEL
        GLOBAL  ReadLine
        GLOBAL  RtClockLH
        GLOBAL  RepeatCmd
        GLOBAL  StoreDE
        GLOBAL  CheckPC
	GLOBAL	GetTaskByID
COND	SIM=0
	GLOBAL	$FFBC,$FFEB
ENDC
;
;       Verify DE and Adjust to HL
;
;       DE=address from Upper RAM to be verified and adjusted
;       returns HL = adjusted address in Lower RAM area
;       (pages from Upper RAM are also loaded if not already loaded)
;
;       BC,AF are affected, DE is conserved
;
; Verification rules:
;
;       check if HL < 0C000H or HL >= 0E000H, return CARRY=1 if verification fails,
;                       else check if page(HL) is loaded and load-it if necessary,
;                       then adjust HL, return HL adjusted and CARRY=0
; Adjusting rules:
;
;   if HL < 0A000H, return HL
;   if 0A000H <= HL < 0C000H, load* PAGE0 (0A000H - 0C000H) 8K Upper RAM, return HL
;   if 0C000H <= HL < 0E000H, load* PAGE1 (0C000H - 0E000H) 8K Upper RAM, HL=HL-2000H
;       load* = (if not already loaded; at start, PAGE0 is loaded)
;   if 0E000H <= HL <= 0FFFFH, HL=HL-2000H (Dynamic Memory page loaded at start)
;
DEtoHL:
        ld      h,d
        ld      l,e             ;HL=addr
        or      a               ;CARRY=0
COND    SIM
        ret
ENDC
        push    hl              ;save HL=addr
        ld      bc,0A000H
        sbc     hl,bc           ;is addr < 0A000H ?
        pop     hl              ;restore HL=addr
        jr      nc,2f
                                ;yes, addr < 0A000H
	ccf			;CARRY=0
	ret			;return HL not changed, CARRY=0
2:				;addr >= 0A000H, CARRY=0
	push	hl		;save addr
	ld	bc,0C000H	
	sbc	hl,bc		;is 0A000 <= addr <= 0C000H ?
	pop	hl		;restore HL=addr
	jr	nc,3f
				;yes, 0A000 <= addr <= 0C000H
        ld      a,(CrtPage+1)
        cp      PAGE0/256       ;is current loaded page = PAGE0 ?
        ret	z		;yes, return HL not changed, CARRY=0
                                ;no
        push    hl
        ld      bc,PAGE0
        call    SnapLoadCD      ;load page 0 (8K)
        pop     hl
	or	a		;CARRY=0
	ret			;return HL not changed, CARRY=0
3:                              ;CARRY=0, addr >= 0C000H
        push    hl              ;save addr
        ld      bc,0E000H
        sbc     hl,bc           ;is 0C000H <= addr < 0E000H ?
        pop     hl              ;restore HL=addr
        jr      nc,4f
                                ;yes, 0C000H <= addr < 0E000H
        ld      a,(CrtPage+1)
        cp      PAGE1/256       ;is current loaded page = PAGE1 ?
        jr      z,4f
                                ;no
        push    hl
        ld      bc,PAGE1
        call    SnapLoadCD      ;load page 1 (8K)
        pop     hl
4:				;0C000H <= addr < 0E000H or addr >= 0E000H 
	or	a		;CARRY=0
        ld      bc,2000H
        sbc     hl,bc           ;CARRY=0, sub 2000H from addr
        ret                     ;return HL=HL-2000H, CARRY=0
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
;       Check pointer to code
;
;       HL=pointer to code
;       returns CARRY=1 if pointer too close to page boundaries
;
CheckPC:
        ld      a,h
	cp	9fH
	jr	z,check
        cp      0bfH
        jr      z,check
        cp      0ffh
        jr      z,check
        or      a               ;pointer is OK
        ret
check:  ld      a,l
        cp      0FDH
        ccf                     ;CARRY=1 if L>=0FDH
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
;       affected regs: A,DE
;
IsInL:
        push    hl              ;header on stack
        push    bc              ;element on stack
        ex      de,hl
        call    DEtoHL
        jp      c,SyntaxErr
        ld      a,(hl)
        push    af
        inc     de
        call    DEtoHL
        jp      c,SyntaxErr
        pop     af
        ld      b,(hl)
        ld      c,a             ;BC=next
        dec     de              ;DE=header
3:      ld      a,b             ;compare next ? header
        cp      d
        jr      nz,1f
        ld      a,c
        cp      e
        jr      nz,1f
                                ;equal, so element is not in the list, return Z=0
        or      b               ;Z=0
        pop     bc              ;restore BC=element
        pop     hl              ;restore HL=header
        ret
1:                              ;not equal, compare next ? element
        pop     hl              ;HL=element
        push    hl              ;keep-it on stack
        or      a               ;CARRY=0
        sbc     hl,bc           ;HL ? BC
        jr      nz,2f
                                ;equal, so element was found
        pop     bc              ;restore BC=element
        pop     hl              ;restore HL=header
        ret                     ;Z=1
2:                              ;not equal, so get the next one
        ld      e,c
        ld      d,b             ;DE=next
        call    DEtoHL
        jp      c,SyntaxErr
        ld      a,(hl)
        push    af
        inc     de
        call    DEtoHL
        jp      c,SyntaxErr
        pop     af
        ld      b,(hl)
        ld      c,a             ;BC=next.next
        pop     hl              ;HL=element
        pop     de              ;DE=header
        push    de              ;header back to stack
        push    hl              ;element back to stack
        jr      3b              ;loop
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
	ex	de,hl
        call    DEtoHL
        jp      c,SyntaxErr
        ld      a,(hl)
        push    af
        inc     de
        call    DEtoHL
        jp      c,SyntaxErr
        pop     af
        ld      d,(hl)
        ld      e,a             ;DE=Sem
	ex	de,hl
	jr	wIsItSem
;
;       wIsItSemaphore ?
;
;       HL=semaphore address
;       returns Z=1 if it is a semaphore, else Z=0
;
wIsItSem:
        push    hl              ;sem on stack
        ld      d,h
        ld      e,l
        call    DEtoHL
        jp      c,SyntaxErr
        ld      a,(hl)
        push    af
        inc     de
        call    DEtoHL
        jp      c,SyntaxErr
        pop     af
        ld      b,(hl)
        ld      c,a             ;BC=first in sem list
        pop     hl              ;HL=sem
        or      a               ;CARRY=0
        sbc     hl,bc           ;BC equal to HL?
        ret     z               ;yes, it's a semaphore
        jr      wIsItTask        ;else, is it a task?
;
;       IsItList ?
;
;       HL=ListHeader
;       if it is a list,
;               returns Z=1, CARRY=0 and BC=first in list ( or header )
;       else
;               returns Z=0
;
;       HL not affected
;
IsItList:
        push    ix
        push    hl              ;header on stack
        ld      ix,0
        add     ix,sp           ;IX=SP, on stack: header, IX
        ex      de,hl           ;DE=header, check if first.prev == header
        call    DEtoHL
        jr      c,7f
        ld      a,(hl)          ;get first
        push    af              ;save A
        inc     de
        call    DEtoHL
        jr      c,7f
        pop     af
        ld      b,(hl)
        ld      c,a             ;BC=first
        pop     de              ;DE=header
        push    bc              ;first on stack
        push    de              ;header on stack
        ld      d,b
        ld      e,c             ;DE=first, verify back link
        inc     de
        inc     de              ;DE=pointer of first.prev
        call    DEtoHL
        jr      c,7f
        ld      a,(hl)
        push    af
        inc     de
        call    DEtoHL
        jr      c,7f
        pop     af              ;CARRY=0
        ld      h,(hl)
        ld      l,a             ;HL=first.prev
                                ;compare with header, must be equal
        pop     de              ;DE=header
        push    de              ;keep header on stack
        sbc     hl,de           ;equal?
        jr      nz,7f           ;if not, this is not a double linked list!
                                ;DE=header, check if last.next == header
        inc     de
        inc     de
        call    DEtoHL
        jr      c,7f
        ld      a,(hl)          ;get last
        push    af              ;save A
        inc     de
        call    DEtoHL
        jr      c,7f
        pop     af
        ld      d,(hl)
        ld      e,a             ;DE=last, verify forward link
                                ;DE=pointer of last.next
        call    DEtoHL
        jr      c,7f
        ld      a,(hl)
        push    af
        inc     de
        call    DEtoHL
        jr      c,7f
        pop     af              ;CARRY=0
        ld      h,(hl)
        ld      l,a             ;HL=last.next
                                ;compare with header, must be equal
        pop     de              ;DE=header
        sbc     hl,de           ;equal?
        ex      de,hl           ;HL=header
        pop     bc              ;BC=first
        pop     ix
        ret                     ;if yes, return Z=1, CARRY=0, this is a double linked list!
                                ;if not, return Z=0, this is not a double linked list!
7:                              ;return Z=0
        ld      sp,ix
        pop     hl
        pop     ix
        ld      a,l
        or      h               ;Z=0
        ret
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
;	IX,IY not affected
;
GetTaskByID:
        ld      de,(TasksH)
	push	de		;real header on stack
  	push	bc		;target ID on stack
	call    DEtoHL		;HL=mapped header
NxT:    ld      e,(hl)          ;get next in list
        inc     hl              ;no need to verify and adjust!
        ld      d,(hl)        	;DE=real TCB+NXPV_OFF
	push	de		;real TCB+NXPV_OFF on stack
	call    DEtoHL          ;HL=mapped TCB+NXPV_OFF, CARRY=0
	ex	de,hl		;DE=mapped TCB+NXPV_OFF
	pop	hl		;HL=real TCB+NXPV_OFF
	pop	bc		;C=ID
	ld	a,c		;A=ID
        pop     bc              ;BC=real header
	push	hl
        sbc     hl,bc		;compare next & header
	pop	hl
        ret	z	        ;if next=header, return Z=1
	ex	de,hl		;HL=mapped TCB+NXPV_OFF, DE=real TCB+NXPV_OFF
	dec	hl		;HL=ID pointer, no need to verify and adjust!
	cp	(hl)
	inc	hl		;HL=mapped TCB+NXPV_OFF, no need to verify and adjust!
	jr	nz,1f
				;CARRY=0
	ex	de,hl		;HL=real TCB+NXPV_OFF
	ld	bc,NXPV_OFF
	sbc	hl,bc		;HL=real TCB, Z=0, no need to verify and adjust!
	ret
1:
	push	bc		;real header on stack
	ld	c,a		;C=ID
 	push	bc		;ID on stack
	jr      NxT

COND	SIM=0
;
;	up to low 6W
;	(size 2FH)
$FFBC:  UP_RAM
        ld      c,(iy+0)
        ld      b,(iy+1)
        ld      e,(iy+2)
        ld      d,(iy+3)
        ld      l,(iy+4)
        ld      h,(iy+5)
        exx
        ld      c,(iy+6)
        ld      b,(iy+7)
        ld      e,(iy+8)
        ld      d,(iy+9)
        ld      l,(iy+10)
        ld      h,(iy+11)
        exx
        LOW_RAM
        ret
;
;	up to low 4B
;	(size 15H)
$FFEB:	UP_RAM
        ld      c,(iy+0)
        ld      b,(iy+1)
        ld      e,(iy+2)
        ld      d,(iy+3)
	LOW_RAM
	ret
;
ENDC
