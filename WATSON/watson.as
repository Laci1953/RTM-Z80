;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	Z80SIM
;link
;link> -C100H -Ptext=100H,data,bss -owatson.com watson.obj wutil.obj wdiss.obj
;
;	RC2014 RAM
;link
;link> -ptext=0,data,bss=0DF00H -os.obj watson.obj wutil.obj wdiss.obj
;>objtohex s.obj watson.hex
;
;	RC2014 CP/M booted from SCM
;
;SETUP_UP_RAM=1
;zas cpmboot.as
;link
;link> -C100H -Pboot=0E300H/100H,text=0/,data/,bss/ -owatson.com \
;link> cpmboot.obj watson.obj wutil.obj wdiss.obj
;
;	RC2014 CP/M booted from RTM/Z80 booter (SC108 or 32KB ROM + 128KB RAM Memory Module)
;
;SETUP_UP_RAM=0
;zas cpmboot.as
;link
;link> -C100H -Pboot=0E300H/100H,text=0/,data/,bss/ -owatson.com \
;link> cpmboot.obj watson.obj wutil.obj wdiss.obj
;
;	RC2014 EPROM (SC108 or 32KB ROM + 128KB RAM Memory Module)
;link
;link> -ptext=0/6A00H,data/,bss=0DF00H/ -os.obj watson.obj wutil.obj wdiss.obj
;>objtohex s.obj watson.hex
;
;	RC2014 EPROM (512KB ROM + 512KB RAM Memory Module)
;link
;link> -ptext=0,data,bss=0DF00H -os.obj watson.obj wutil.obj wdiss.obj
;>objtohex s.obj watson.hex
;
;
*Include w.mac
;-----------------------------------------------------------------------SC108
COND	SC108

MEMP_PORT       equ     38H
;
ROMOUT          equ     00000001B
ROMIN           equ     00000000B
LOWER_64RAM     equ     00000000B
UPPER_64RAM     equ     10000000B

MACRO	UP_RAM
	ld	a,ROMOUT .or. UPPER_64RAM
	out	(MEMP_PORT),a
ENDM

ENDC
;-----------------------------------------------------------------------SC108
;-----------------------------------------------------------------------MM
COND	MM

MM_RAM_P	equ	30H

MM_UP_RAM	equ	1
MM_LOW_RAM	equ	0

MM_ROM_P	equ	38H

MM_ROM_IN	equ	0
MM_ROM_OUT	equ	1

MACRO	UP_RAM
	ld	a,MM_UP_RAM
	out	(MM_RAM_P),a
ENDM

ENDC
;-----------------------------------------------------------------------MM
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
        GLOBAL  wIsItTask
        GLOBAL  IsItList
	GLOBAL	IsItQ
        GLOBAL  SyntaxErr
        GLOBAL  TypeA
        GLOBAL  TypeString
        GLOBAL  TasksH
        GLOBAL  ActiveTasksH
        GLOBAL  ReadLine
        GLOBAL  wIsItActiveTask
        GLOBAL  IsItRTClkB
        GLOBAL  msgBSandDEL
        GLOBAL  ReadLine
        GLOBAL  RtClockLH
        GLOBAL  DisWrI
        GLOBAL  kStrBuffer
        GLOBAL  RepeatCmd
        GLOBAL  StoreDE
	GLOBAL	GetTaskByID
COND	1-SIM
	GLOBAL	TypeChar
ENDC
;
;       WATSON data inspector
;
        psect   text
;
;       Start Watson
;
;----------------------------------------------------------------------------------SIM
COND    SIM
					;loaded as .COM under CP/M
        di                              ;disable interrupts
        ld      sp,TopStack
	ld	hl,7F00H
        PRINT   CRLF
        ld      de,4
        ld      bc,2
        PRINT   msgAllT
        call    TypeHL
        PRINT   CRLF
;       ld      (TasksH),hl
        add     hl,de
        PRINT   msgActT
        call    TypeHL
        PRINT   CRLF
;       ld      (ActiveTasksH),hl
        add     hl,de
        PRINT   msgCrtT
        call    TypeHL
        PRINT   CRLF
;       ld      (CrtActiveTask),hl
        add     hl,bc
        PRINT   msgFreeL
        call    TypeHL
        PRINT   CRLF
;       ld      (FreeBHdrP),hl
        add     hl,bc
        PRINT   msgRTCL
        call    TypeHL
        PRINT   CRLF
;       ld      (RtClockLH),hl
ENDC
;----------------------------------------------------------------------------------SIM
;----------------------------------------------------------------------------------1-SIM
COND	1-SIM
;---------------------------------------------------------------------SC108 .or. MM
COND	SC108 .or. MM
;
;	Move from LOW RAM to UP RAM 100H of memory
;
;	IX=source, IY=Destination
;	returns IX=IX+100H,IY=IY+100H 
;
LowToUp100H:
	ld	a,21		;21 x 12 = 252, + 4 = 256 (100H)
lloop21:			;move 252 bytes
	ld	c,(ix+0)
	ld	b,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	l,(ix+4)
	ld	h,(ix+5)
	exx
	ld	c,(ix+6)
	ld	b,(ix+7)
	ld	e,(ix+8)
	ld	d,(ix+9)
	ld	l,(ix+10)
	ld	h,(ix+11)
	exx
	ex	af,af'
	call	LOW_TO_UP_6W	;LowToUp_6W
	ex	af,af'
	dec	a
	jr	nz,lloop21
				;move 4 bytes
	ld	c,(ix+0)
	ld	b,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	call	LOW_TO_UP_4B
	ret
;
;	WE ARE AT 0040H
;
;	Start of Watson 
;
	ld	sp,TopStack
					;move all code also to Upper RAM
	ld	ix,0
	ld	iy,0
	ld	a,18H			;18 x 100H
1:
	push	af
	call	LowToUp100H
	pop	af
	dec	a
	jr	nz,1b

	UP_RAM				;select UpperRAM
ENDC
;---------------------------------------------------------------------SC108 .or. MM
;---------------------------------------------------------------------M512
COND	M512
	defs	40H
;
;	WE ARE AT 0040H
;
;	Start of Watson
	ld	sp,TopStack
ENDC
;---------------------------------------------------------------------M512
ENDC
        call    SanityCheck
        jr      z,2f
        ld      hl,SorryQuitting
        call    TypeString
EXIT:					;quit Watson
COND    SIM
        ld      c,0
        jp      5
ENDC
COND	1-SIM
	jr	$
ENDC
2:      				;check ok
	ld	hl,_PC
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,d
	or	e			;guess about the outcome of RTM/Z80 run
	ld	hl,msgBreakpoint
	jr	nz,1f
	ld	hl,msgShutdown
1:	call	TypeString

	ld      hl,msgWatson            ;print wellcome msg
        call    TypeString
	xor	a
	ld	(RepeatCmd),a
loop:   ld      hl,msgPrompt            ;print CR,LF,':'
        call    TypeString
        ld      hl,InputBuf             ;HL=pointer in buf
        call    ReadLine
        ld      a,(InputBuf)
        call    UpperCase
        call    FindCommand
        jr      z,1f
                                        ;command not found
        ld      a,'?'                   ;type '?'
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        jr      loop
1:
        ld      bc,loop                 ;return address = loop
        push    bc                      ;on stack
        ld      de,InputBuf+1           ;DE=pointer of next char after command
        jp      (hl)                    ;execute command
;
;       FindCommand
;
;       A=char to be searched (uppercase) in CommandsList
;       if found,
;               returns Z=1 and HL=Command_routine
;       else
;               returns Z=0
;       affects AF,BC,HL
;
FindCommand:
        ld      hl,CommandsList ;list of commands names
        ld      bc,CMD_CNT      ;commands counter
        cpir                    ;search for char == A
        ret     nz
        dec     hl              ;HL=pointer of found char
        or      a               ;CARRY=0
        ld      bc,CommandsList
        sbc     hl,bc           ;HL=0-based index of found char
        add     hl,hl           ;double-it
        ld      bc,Commands     ;access commands vector
        add     hl,bc           ;pointer of command routine
        ld      a,(hl)          ;get it
        inc     hl
        ld      h,(hl)
        ld      l,a             ;HL=Command_routine
        xor     a               ;Z=1
        ret
;
;       Display a memory block of 40H
;       DE=InputBuf+1
;
;       :Maddr<CR>
;       addr vv vv vv vv vv vv vv vv vv vv vv vv vv vv vv vv aaaaaaaaaaaaaaaa
;       addr vv vv vv vv vv vv vv vv vv vv vv vv vv vv vv vv aaaaaaaaaaaaaaaa
;       addr vv vv vv vv vv vv vv vv vv vv vv vv vv vv vv vv aaaaaaaaaaaaaaaa
;       addr vv vv vv vv vv vv vv vv vv vv vv vv vv vv vv vv aaaaaaaaaaaaaaaa
;
MemDisplay:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ex      de,hl
        call    ReadDE          ;read DE
        push    de              ;keep addr on stack
	ex	de,hl
        ld      bc,0410H        ;4 lines x 16 bytes
linesloop:
        PRINT   CRLF            ;type CR,LF
        pop     de              ;addr
        push    de              ;keep it on stack
        call    TypeDE          ;print addr
                                ;print 16 bytes in hexa
bytesloop:
        ld      a,BLANK         ;print BLANK
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        ld      a,(hl)          ;get byte
        call    TypeA           ;print-it in hexa
        inc     hl
        dec     c
        jr      nz,bytesloop
                                ;print 16 bytes
        pop     hl              ;addr
        push    hl              ;keep it on stack
        ld      a,BLANK         ;print BLANK
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        ld      c,10H
asciiloop:
        ld      a,(hl)          ;get byte
        call    FilterChar      ;make-it printable
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        inc     hl
        dec     c
        jr      nz,asciiloop
                                ;next line
        pop     hl              ;HL=addr
        ld      de,10H
        add     hl,de           ;add 10H
        push    hl              ;on stack
        ld      c,10H
        djnz    linesloop
                                ;prepare possible repeat
	ex	de,hl
        ld      hl,InputBuf+1
        call    StoreDE         ;store next addr in input buffer
        ld      a,1
        ld      (RepeatCmd),a   ;repeat allowed!
        jp      Return
;
;       Display Double linked List
;       DE=InputBuf+1
;
;       :Laddr<CR>->addr->addr ...
;
ListDisplay:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ex      de,hl           ;HL=pointer in input buffer
        call    ReadDE          ;DE=header
        ex      de,hl           ;HL=header
        push    hl              ;keep header on stack
        call    IsItList
        jp      nz,SyntaxErr
	ld	c,(hl)
	inc	hl
	ld	b,(hl)          
				;BC=first, CARRY=0
1:      or	a
	pop     hl              ;HL=header
        push    hl              ;keep header on stack
        sbc     hl,bc           ;is crt == header ?
        jp      z,Return        ;if yes, return
        PRINT   msgLinkTo       ;print '->'
        call    TypeBC          ;print BC=crt in hexa
	ld	h,b
	ld	l,c
	ld	c,(hl)
	inc	hl
	ld	b,(hl)          ;BC=next
        jr      1b
;
;       Display Semaphore
;       DE=InputBuf+1
;
;       :Saddr<CR>->addr->addr,counter
;
SemDisplay:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ex      de,hl           ;HL=pointer in input buffer
        call    ReadDE          ;DE=header
        ex      de,hl           ;HL=header
        push    hl              ;keep header on stack
        call    IsItList
        jp      nz,SyntaxErr
	ld	c,(hl)
	inc	hl
	ld	b,(hl)          
				;BC=first, CARRY=0
        PRINT   msgTCBsWaiting
1:      or	a
	pop     hl              ;HL=header
        push    hl              ;keep header on stack
        sbc     hl,bc           ;is crt == header ?
        jr      z,ReadCnt       ;if yes, go read the counter
                                ;no, it must be a TCB
        push    bc              ;save crt
        call    wIsItTask       ;is it as TCB?
        pop     bc              ;BC=crt
        jp      nz,SyntaxErr    ;it's not a TCB
                                ;it is a TCB, print its address
        ld      a,BLANK
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        call    TypeBC          ;print BC=next in hexa
 	ld	h,b
	ld	l,c
	ld	c,(hl)
	inc	hl
	ld	b,(hl)          ;BC=next
        jr      1b
                                ;get the semaphore counter
ReadCnt:PRINT   msgCounter
        pop     hl              ;DE=sem addr
        inc     hl
        inc     hl
        inc     hl
        inc     hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=counter
        jp      TypeBC          ;type counter
;
;       Display TCB details
;
;       DE=InputBuf+1
;       Taddr<CR> Size=NNNN Priority=NN SP=NNNN Status=Active/Waiting semaphore:SSSS/Suspended
;
TCBDisplay:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ex      de,hl           ;HL=pointer in input buffer
        call    wReadBC          ;BC=TCB
        push    bc              ;on stack
        call    wIsItTask        ;is it a task?
        jp      nz,SyntaxErr
        pop     bc              ;BC=TCB
        push    bc              ;back on stack
        ld      hl,msgSize      ;print size
        call    TypeString
        ld      hl,5
        add     hl,bc           ;HL=pointer of block size
        ld      a,(hl)          ;A=block size
        inc     hl              ;HL=pointer of priority
        push    hl              ;on stack
        ld      hl,10H
2:      add     hl,hl
        dec     a
        jr      nz,2b
        call    TypeHL
        ld      hl,msgPriority  ;print priority
        call    TypeString
        pop     hl              ;HL=pointer of priority
        ld      a,(hl)
        call    TypeA
        inc     hl              ;HL=pointer of SP
        PRINT   msgSP           ;print SP
        ld      c,(hl)
        inc     hl
        ld      b,(hl)          ;BC=SP
        inc     hl              ;HL=pointer of local semaphore
        call    TypeBC
        PRINT   msgStatus       ;print status
        ld      c,(hl)
        inc     hl
        ld      b,(hl)          ;BC=first in local sem list
        ex      (sp),hl         ;pointer of local semaphore+1 on stack, HL=TCB
        push    hl              ;TCB on stack
        or      a               ;CARRY=0
        sbc     hl,bc           ;first in local sem list = TCB ?
        jr      nz,3f
        ld      hl,msgSuspended ;yes, task is suspended
        call    TypeString
        jp      Return
3:
        pop     bc              ;BC=TCB
        call    wIsItActiveTask
        jr      nz,4f
        ld      hl,msgActive    ;yes, it's active
        call    TypeString
        jp      Return
4:
        pop     hl              ;HL=pointer of local semaphore+1
        ld      bc,10
        add     hl,bc           ;HL=pointer of WaitSem
        ld      c,(hl)
        inc     hl
        ld      b,(hl)          ;BC=semaphore
        ld      hl,msgWaiting
        call    TypeString
        jp      TypeBC
;
;       Display list of active TCB's
;
;       DE=InputBuf+1
;       :A<CR> tcb1 tcb2
;
ActTCBDisplay:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ld      a,(de)
        cp      CR
        jp      nz,SyntaxErr
        ld      hl,(ActiveTasksH)
        ld      bc,0            ;TCB offset
        jr      DspTL
;
;       Display list of all TCB's
;
;       DE=InputBuf+1
;       :O<CR> tcb1 tcb2
;
AllTCBDisplay:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ld      a,(de)
        cp      CR
        jp      nz,SyntaxErr
        ld      hl,(TasksH)
        ld      bc,0FFF0H       ;TCB offset
DspTL:
        push    bc              ;offset on stack
        push    hl              ;header on stack
NxTCB:  
        ld      e,(hl)          ;get next in list
        inc     hl
        ld      d,(hl)          ;DE=next
        pop     hl              ;HL=header
        pop     bc              ;BC=offset
        push    bc              ;offset on stack
        push    hl              ;header on stack
	or	a
        sbc     hl,de
        jp      z,Return        ;if next=header, return
        ld      l,e
        ld      h,d             ;HL=DE=next
        add     hl,bc           ;HL=next+offset
        ld      a,BLANK
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        call    TypeHL          ;print TCB
	ex	de,hl
        jr      NxTCB
;
;       Display Current Active Task
;
;       DE=InputBuf+1
;       :C<CR> addr
;
CrtTCBDisplay:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ld      a,(de)
        cp      CR
        jp      nz,SyntaxErr
        ld      hl,(CrtActiveTask)
        ld      c,(hl)          ;get TCB addr
        inc     hl              ;no need to verify and adjust!
        ld      b,(hl)          ;BC=TCB of Current Active Task
        ld      a,BLANK         ;type a blank
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        jp      TypeBC          ;print BC=TCB in hexa
;
;       Display Dynamic Memory status
;
;       DE=InputBuf+1
;       :D<CR>
;       Available blocks of size NNNN : adr1 adr2 ...
;       ...
;       Total free dynamic memory : MMMM
;
DynMemDisplay:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ld      a,(de)
        cp      CR
        jp      nz,SyntaxErr
        ld      hl,(FreeBHdrP)  ;HL=pointer of pointer of vector of free mem block list headers
        ld      e,(hl)          ;get pointer to vector
        inc     hl              ;no need to verify
        ld      d,(hl)          ;DE=pointer to vector
        ld      iy,0            ;IY=total size of free dynamic memory
        ld      b,10            ;B=10 lists
        ld      hl,10H          ;HL=first block size
5:
        push    bc              ;lists counter on stack
        push    hl              ;block size on stack
        ld      a,(de)          ;get list header
	ld	l,a
        inc     de
	ld	a,(de)
	ld	h,a
	inc	de
        push    de              ;incremented pointer to vector on stack
        push    hl              ;list header on stack
	ld	e,(hl)
	inc	hl
	ld	d,(hl)          ;DE=first
        pop     hl              ;HL=header
        push    hl              ;back on stack
	or	a
        sbc     hl,de           ;first=header?
        jr      z,1f
                                ;no, print free blocks
        PRINT   msgAvailSize    ;print header message for list of available blocks
        ld      c,(ix-4)
        ld      b,(ix-3)        ;BC=block size
        call    TypeBC          ;print crt block size
        ld      a,':'
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
2:      ld      a,BLANK
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        call    TypeDE          ;print block addr
        ld      c,(ix-4)
        ld      b,(ix-3)        ;BC=block size
        add     iy,bc           ;add-it to the total size of free dynamic memory
        ex	de,hl
        ld      e,(hl)          ;get next
        inc     hl
        ld      d,(hl)		;DE=next
        pop     hl              ;HL=header
        push    hl              ;back on stack
        or	a
	sbc     hl,de           ;next=header?
        jr      nz,2b           ;if no, go print-it
1:
        pop     hl              ;drop header
        pop     de              ;DE=incremented pointer to vector
        pop     hl              ;HL=block size
        add     hl,hl           ;double the block size
        pop     bc              ;B=counter
        djnz    5b
                                ;print total free mem
        PRINT   msgTotalFree
        push    iy
        pop     bc
        call    TypeBC
;				;walk trough the dynamic memory
COND	SIM
	ld	hl,8000H
ENDC
COND	SIM=0
	ld	hl,0E000H
ENDC
	push	hl
	pop	iy		;IY=Dynamic memory begin
	ld	de,2000H
	add	hl,de
	push	hl
	pop	ix		;IX=Dynamic memory end
loopm:	ld	a,(iy+5)	;A=bElement size
	add	a,a
	ld	c,a
	ld	b,0
	ld	hl,Buddy
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc		;size of block on stack
	ld	a,(iy+4)	;A=status
	or	a
	jr	z,2f
				;block is allocated
	PRINT	msgBlockSize	
	call	TypeBC
	PRINT	msgBlockAddr
	push	iy
	pop	hl
	call	TypeHL
	PRINT	msgTCBOwner
	ld	c,(iy+4)
	call	GetTaskByID	;HL=owner TCB
	call	TypeHL
2:	
	pop	bc		;BC=size of block
	add	iy,bc		;IY=next block addr
	push	iy		
	pop	bc		;BC=next block addr
	push	ix
	pop	hl		;HL=Dyn mem end
	or	a
	sbc	hl,bc
	jr	nz,loopm
	ret
;
;       Display queue
;
;       DE=InputBuf+1
;       Qaddr<CR> WritePointer=xxxx ReadPointer=yyyy Buffer=zzzz Size=ssss BatchSize=bb
;
QueueDisplay:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ex      de,hl           ;HL=pointer in input buffer
        call    ReadDE          ;DE=queue=WP pointer
	ex	de,hl
	push	hl
	call	IsItQ
	jp	nz,SyntaxErr
	pop	de		;DE=WP pointer
        ld      a,(de)
	ld	c,a
        inc     de
        ld      a,(de)		
	ld	b,a		;BC=WP
        ld      hl,msgWP
        call    TypeString
        call    TypeBC
        inc     de              ;DE=RP pointer
        ld      a,(de)
	ld	c,a
        inc     de
        ld      a,(de)		
	ld	b,a		;BC=RP
        ld      hl,msgRP
        call    TypeString
        call    TypeBC
        inc     de              ;DE=Buf pointer
        ld      a,(de)
	ld	c,a
        inc     de
        ld      a,(de)		
	ld	b,a		;BC=Buf
        ld      hl,msgBuf
        call    TypeString
        call    TypeBC
        push    bc              ;buf on stack
        inc     de              ;DE=pointer of BufEnd
        ld      a,(de)
	ld	l,a
        inc     de
        ld      a,(de)		
	ld	h,a		;HL=BufEnd
        PRINT   msgSize
        or      a
        pop     bc
        sbc     hl,bc           ;HL=size
        call    TypeHL
        inc     de
        inc     de              ;DE=pointer of BatchSize
        PRINT   msgBatchSize
        ld      a,(de)
        jp      TypeA
;
;       Display Mailbox
;
;       DE=InputBuf+1
;       Baddr<CR> TCB Waiting: TTTT Mails list: AAAA BBBB Message size=SS
MBDisplay:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ex      de,hl           ;HL=pointer in input buffer
        call    ReadDE          ;DE=mailbox
        ex      de,hl           ;HL=mailbox=sem header
        push    hl              ;header on stack
        call    IsItList
        jp      nz,SyntaxErr
        ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=first
        PRINT   msgTCBsWaiting
1:      pop     hl              ;HL=header
        push    hl              ;keep header on stack
	or	a        
	sbc     hl,bc           ;is crt == header ?
        jr      z,2f            ;if yes, go list mails
                                ;no, it must be a TCB
        push    bc              ;save crt
        call    wIsItTask       ;is it as TCB?
        pop     bc              ;BC=crt
        jp      nz,SyntaxErr    ;it's not a TCB
                                ;it is a TCB, print its address
        ld      a,BLANK
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        call    TypeBC          ;print DE=next in hexa
        ld      d,b
        ld      e,c             ;DE=crt
        ld      a,(de)          ;get next
	ld	c,a
        inc     de
        ld      a,(de)		
	ld	b,a		;BC=next
        jr      1b
2:
        pop     hl              ;HL=pointer of semaphore
        ld      bc,6
        add     hl,bc           ;HL=pointer of header of mails list
        push    hl              ;header on stack
        call    IsItList
        jp      nz,SyntaxErr
        ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=first
        PRINT   msgMailList
3:      or	a
	pop     hl              ;HL=header
        push    hl              ;keep header on stack
        sbc     hl,bc           ;is crt == header ?
        jr      z,4f            ;if yes, go print msg size
        ld      a,BLANK
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        call    TypeBC          ;print BC=next in hexa
        ld      d,b
        ld      e,c             ;DE=crt
        ld      a,(de)          ;get next
	ld	c,a
        inc     de
        ld      a,(de)		
	ld	b,a		;BC=next
        jr      3b
4:      pop     hl              ;HL=pointer of header of mails list
        ld      bc,4
        add     hl,bc           ;HL=pointer of MessageSize
        PRINT   msgMsgSize
        ld      a,(hl)
        jp      TypeA
;
;       Display List of RealTimeClock Control Blocks
;
;       DE=InputBuf+1
;       K<CR> AAAA BBBB CCCC
;
LRTCDisplay:
        ld      ix,0
        add     ix,sp                   ;save SP to IX
        ld      a,(de)
        cp      CR
        jp      nz,SyntaxErr
        ld      hl,(RtClockLH)
        ld      bc,0
        jp      DspTL
;
;       Display RealTimeClock Control Block details
;
;       DE=InputBuf+1
;       Jaddr<CR> Tics:NNNN Sem:AAAA
;
RTCDisplay:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ex      de,hl           ;HL=pointer in input buffer
        call    wReadBC         ;BC=RTC
        push    bc              ;on stack
        call    IsItRTClkB      ;is it a RTC?
        jp      nz,SyntaxErr
        pop     hl              ;HL=RTC
        ld      bc,4
        add     hl,bc		
	ex	de,hl		;DE=counter pointer
        ld      a,(de)
	ld	c,a
        inc     de
        ld      a,(de)		
	ld	b,a		;BC=counter
        ld      hl,msgTics
        call    TypeString
        call    TypeBC
        inc     de
        ld      a,(de)
	ld	c,a
        inc     de
        ld      a,(de)		
	ld	b,a		;BC=semaphore
        ld      hl,msgSem
        call    TypeString
        jp      TypeBC
;
;       Dissasemble
;       DE=InputBuf+1
;
;       Eaddr,addr<CR>
;
Disassemble:
        ld      ix,0
        add     ix,sp           ;save SP to IX
        ex      de,hl           ;HL=pointer in input buffer
        call    ReadDE
        ld      hl,20H
        add     hl,de           ;HL=stop
        push    hl              ;stop on stack
loopD:  ld	l,e
	ld	h,d
        call    DisWrI          ;A=instr size, text in kStrBuffer
        push    af              ;save instr size
        push    de              ;save crt PC
        ld      hl,kStrBuffer+1 ;adjust PC (set it = DE)
        call    StoreDE         ;DE in hexa stored at HL
        ld      hl,kStrBuffer+20H
        ld      b,20H
findto: ld      a,(hl)          ;check if '(to AAAA' is present
        cp      't'
        inc     hl
        jr      nz,1f
        ld      a,(hl)
        cp      'o'
        inc     hl
        jr      nz,1f
        inc     hl              ;found 'to', HL points to AAAA
        push    hl
        call    wReadA
        ld      d,a
        call    wReadA
        ld      e,a             ;DE=new ADDR
        pop     hl
        call    StoreDE ;store-it
        jr      2f
1:      djnz    findto
2:                              ;print disassembled instr
        ld      hl,CRLF
        call    TypeString
        ld      hl,kStrBuffer
        ld      b,(hl)          ;B=counter
3:      inc     hl
        ld      a,(hl)
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        djnz    3b
        pop     de              ;DE=crt PC
        pop     af              ;A=instr size
        ld      h,0
        ld      l,a
        add     hl,de           ;HL=incremented PC
        ld      d,h
        ld      e,l             ;DE=incremented PC
        pop     bc              ;BC=stop
	or	a        
	sbc     hl,bc
        jp      nc,retD         ;return if incremented PC >= stop
        push    bc
        jr      loopD
retD:                           ;prepare possible repeat
        ld      hl,InputBuf+1
        call    StoreDE         ;store next PC in input buffer
        ld      a,1
        ld      (RepeatCmd),a   ;repeat allowed!
        jp      Return
;
;       Display Registers
;       DE=InputBuf+1
;
;       :R<CR> AF=...
;
DisplayRegs:
        ld      ix,0
        add     ix,sp                   ;save SP to IX
        ld      a,(de)
        cp      CR
        jp      nz,SyntaxErr
	ld	de,_REGS
	ld	b,12			;12 regs
	ld	hl,msgRegs+5
1:	push	bc
	push	de
	push	hl
        ld      a,(de)
	ld	c,a
	inc	de
        ld      a,(de)       
	ld	d,a
	ld	e,c		      	;DE=reg
	pop	hl
	push	hl
	call	StoreDE
	pop	hl
	ld	de,9
	add	hl,de
	pop	de
	inc	de
	inc	de
	pop	bc
	djnz	1b
	ld	hl,msgRegs
	call	TypeString
	jp	Return
;
;       Exit Watson
;       DE=InputBuf+1
;
;       :X<CR>
;
Exit:
        ld      ix,0
        add     ix,sp                   ;save SP to IX
        ld      a,(de)
        cp      CR
        jp      nz,SyntaxErr
	jp	EXIT
;
;       Help - type commands summary
;
Help:   ld      hl,msgHelp
        jp      TypeString
;
;       Type '?'
;
SyntaxErr:
        ld      sp,ix                   ;restore SP
        ld      a,'?'                   ;type ?
COND    1-SIM
        call	TypeChar
ENDC
COND    SIM
	out	(1),a
ENDC
        ret
;
;       Return from command
;
Return:
        ld      sp,ix
        ret
;
;       Sanity Check
;
;       Set accordingly RTM/Z80 fixed pointers
;       Check Task Lists, Current Active Task, Free memory lists, Clock lists
;
;       if all OK,
;               returns Z=1
;       else (if system not found)
;               returns Z=0
;
SanityCheck:
        ld      hl,W_P
        call    SetRTM_Pointers
					;check list of all tasks
        ld      hl,(TasksH)
        call    IsItList
        jr      z,10f
	push	af
        ld      hl,XTaskList
        call    TypeString
	pop	af
	ret				;Z=0
10:                                     ;check list of active tasks
        ld      hl,(ActiveTasksH)
        call    IsItList
        jr      z,11f
	push	af
        ld      hl,XActTList
        call    TypeString
	pop	af
	ret				;Z=0
11:                                     ;check current active task
        ld      hl,(CrtActiveTask)
        ld      c,(hl)                  ;get TCB addr
        inc     hl                      ;no need to verify and adjust!
        ld      b,(hl)                  ;BC=TCB of Current Active Task
        call    wIsItTask
        jr      z,12f
        ld      hl,XCrtTask
        call    TypeString
12:                                     ;check vector of free mem block list headers
        ld      hl,(FreeBHdrP)
        ld      e,(hl)                  ;get pointer to vector
        inc     hl
        ld      d,(hl)                  ;DE=pointer to vector
        ld      b,10                    ;lists counter
5:      push    bc                      ;on stack
        ld      a,(de)                  ;get list header
	ld	l,a
        inc     de
        ld      a,(de)	                
	ld	h,a			;HL=list header
	inc	de
        push    de                      ;incremented pointer to vector on stack
        call    IsItList
        pop     de                      ;DE=incremented pointer to vector
        pop     bc                      ;B=counter
        jr      nz,13f
        djnz    5b
                                        ;check list of real time clock control blocks
        ld      hl,(RtClockLH)
        call    IsItList
        ret     z                       ;all checks passed, return Z=1
        push    af
        ld      hl,XClkList
        call    TypeString
        pop     af                      ;Z=0
        ret
13:
        push    af
        ld      hl,XFreeBL
        call    TypeString
        pop     af                      ;Z=0
        ret
;
;       SetRTM_Pointers
;
;       HL=pointers base addr
;
SetRTM_Pointers:
        ld      bc,2
        ld      de,4
        ld      (TasksH),hl
        add     hl,de                   ;HL=base+4H
        ld      (ActiveTasksH),hl
        add     hl,de                   ;HL=base+8H
        ld      (CrtActiveTask),hl
        add     hl,bc                   ;HL=base+0AH
        ld      (FreeBHdrP),hl
        add     hl,bc                   ;HL=base+0CH
        ld      (RtClockLH),hl
        ret
;
	psect 	data
;
COND	SIM
msgAllT:        defm    'All tasks list header='
                defb    0
msgActT:        defm    'Active tasks list header='
                defb    0
msgCrtT:        defm    'Current active task='
                defb    0
msgFreeL:       defm    'Free memory list headers vector='
                defb    0
msgRTCL:        defm    'RealTimeClock blocks list header='
                defb    0
ENDC
;
;       Commands list
;
CommandsList:
        defm    'M'     ;Memory display
        defm    'L'     ;Double linked list display
        defm    'S'     ;Semaphore display
        defm    'T'     ;TCB display
        defm    'A'     ;Active tasks list display
        defm    'O'     ;All tasks list display
        defm    'C'     ;Current active task display
        defm    'D'     ;Dynamic memory display
        defm    'Q'     ;Queue display
        defm    'B'     ;Mailbox display
        defm    'K'     ;Display list of RealTimeClockControlBlocks
        defm    'J'     ;Display RealTimeClockControlBlock
        defm    'E'     ;Disassemble
	defm	'R'	;Registers
        defm    'X'     ;Exit
        defm    '?'     ;Help
;
CMD_CNT equ     $-CommandsList
;
Commands:
        defw    MemDisplay              ;ok
        defw    ListDisplay             ;ok
        defw    SemDisplay              ;ok
        defw    TCBDisplay              ;ok
        defw    ActTCBDisplay           ;ok
        defw    AllTCBDisplay           ;ok
        defw    CrtTCBDisplay           ;ok
        defw    DynMemDisplay           ;ok
        defw    QueueDisplay            ;ok
        defw    MBDisplay               ;ok
        defw    LRTCDisplay             ;ok
        defw    RTCDisplay              ;ok
        defw    Disassemble             ;ok
	defw	DisplayRegs		;ok
        defw    Exit                    ;ok
        defw    Help                    ;ok
;
Buddy:	defw	10H,20H,40H,80H,100H,200H,400H,800H,1000H,2000H
;
msgWatson:      defb    CR,LF
                defm    'Watson at your service!'
                defb    0
msgPrompt:      defb    CR,LF
                defm    ':'
                defb    0
msgShutdown:
		defb	CR,LF
		defm	'System was shutdown...'
		defb	0
msgBreakpoint:	defb	CR,LF
		defm	'System probably reached a breakpoint...'
		defb	0
msgHelp:        defb    CR,LF
                defm    'M<addr><CR>    Memory display (*)'
                defb    CR,LF
                defm    'L<addr><CR>    Double linked list display'
                defb    CR,LF
                defm    'S<addr><CR>    Semaphore display'
                defb    CR,LF
                defm    'T<addr><CR>    TCB display'
                defb    CR,LF
                defm    'A<CR>          Active tasks list display'
                defb    CR,LF
                defm    'O<CR>          All tasks list display'
                defb    CR,LF
                defm    'C<CR>          Current active task display'
                defb    CR,LF
                defm    'D<CR>          Dynamic memory display'
                defb    CR,LF
                defm    'Q<addr><CR>    Queue display'
                defb    CR,LF
                defm    'B<addr><CR>    Mailbox display'
                defb    CR,LF
                defm    'K<CR>          Display list of Timer Control Blocks'
                defb    CR,LF
                defm    'J<addr><CR>    Display Timer Control Block'
                defb    CR,LF
                defm    'E<addr><CR>    Disassemble (*)'
                defb    CR,LF
		defm	'R<CR>          Registers'
		defb	CR,LF
                defm    'X<CR>          Exit'
                defb    CR,LF
                defm    'where <addr> = 4 hexa digits'
                defb    CR,LF
                defm    '(*) autorepeat at <CR>'
                defb    0
msgLinkTo:      defm    '->'
                defb    0
msgBSandDEL:    defb    BACKSPACE,BLANK,BACKSPACE
                defb    0
CRLF:           defb    CR,LF
                defb    0
XTaskList:      defb    CR,LF
                defm    'Task list seems corrupted!'
                defb    0
XActTList:      defb    CR,LF
                defm    'Active Task list seems corrupted!'
                defb    0
XCrtTask:       defb    CR,LF
                defm    'Current Active Task pointer seems corrupted!'
                defb    0
XFreeBL:        defb    CR,LF
                defm    'Dynamic memory seems corrupted!'
                defb    0
XClkList:       defb    CR,LF
                defm    'Real Time Clock Control Block list seems corrupted!'
                defb    0
SorryQuitting:  defb    CR,LF
                defm    'Sorry, quitting...'
                defb    0
msgAvailSize:   defb    CR,LF
                defm    'Available blocks of size '
                defb    0
msgTotalFree:   defb    CR,LF
                defm    'Total free dynamic memory : '
                defb    0
msgSize:        defm    ' Size='
                defb    0
msgPriority:    defm    ' Priority='
                defb    0
msgSP:          defm    ' SP='
                defb    0
msgStatus:      defm    ' Status='
                defb    0
msgActive:      defm    'Active'
                defb    0
msgWaiting:     defm    'Waiting semaphore '
                defb    0
msgSuspended:   defm    'Suspended'
                defb    0
msgTics:        defm    ' Tics:'
                defb    0
msgSem:         defm    ' Sem:'
                defb    0
msgTCBsWaiting: defm    ' TCB waiting:'
                defb    0
msgCounter:     defm    ' Counter:'
                defb    0
msgWP:          defm    ' Write pointer='
                defb    0
msgRP:          defm    ' Read pointer='
                defb    0
msgBuf:         defm    ' Buffer='
                defb    0
msgBatchSize:   defm    ' Batch size='
                defb    0
msgMailList:    defm    ' Mails list:'
                defb    0
msgMsgSize:     defm    ' Message size='
                defb    0
msgRegs:	defm	' AF= 1234 BC= 1234 DE= 1234 HL= 1234 AF'
		defb	27H	;'
		defm	'=1234 BC'
		defb	27H	;'
		defm	'=1234 DE'
		defb	27H	;'
		defm	'=1234 HL'
		defb	27H	;'
		defm	'=1234 IX =1234 IY =1234 SP =1234 PC =1234'
		defb	0
msgBlockSize:	defb	CR,LF
		defm	'Block of size='
		defb	0
msgBlockAddr:	defm	' at address='
		defb	0
msgTCBOwner:	defm	' owned by TCB='
		defb	0

	psect	bss
;
;       Pointers to RTM/Z80 data
TasksH:         defs    2       ;all tasks header
ActiveTasksH:   defs    2       ;active tasks header
CrtActiveTask:  defs    2       ;current active task
FreeBHdrP:      defs    2       ;pointer of vector of free mem block list headers
RtClockLH:      defs    2       ;real time clock control block list header
;
RepeatCmd:      defs    1       ;1=repeat last command at <CR>
;
InputBuf:       defs    6       ;chars read from console
;
                defs    30H     ;Stack
TopStack:
;
