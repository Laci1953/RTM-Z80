;
;	Z80ALL VGA routines
;
*Include config.mac

IF	Z80ALL

;---------------------------------------------------------------------------------------SYSSTS
IF	SYSSTS

	GLOBAL	MarkLen, DisplaySysScr, Bin2Hex, TaskCnt

	psect	text
;
MarkLen:defs	1	;dynamic memory marks lenght
TaskCnt:defb	0	;tasks counter

MsgSys:	defz	'RTM/Z80 - System status display'
MsgSysROW	equ	0
MsgSysCOL	equ	15

MsgDyn:	defm	'Dynamic memory (8KB) - each '
	defb	' '+80H
	defz	' = a block of 16 bytes'
MsgDynROW	equ	2
MsgDynCOL	equ	3

MsgLine:
	REPT	64
	defb	'-'
	ENDM
	defb	0
MsgLineROW1	equ	3
MsgLineROW2	equ	12
MsgLineROW3	equ	20
MsgLineCOL	equ	0

MsgTasks:
	defz	'Tasks              Status'
MsgTasksROW	equ	19
MsgTasksCOL	equ	7

MsgStatus:
	defz	'Priority(hexa) Running Waiting'	
MsgStatusROW	equ	21
MsgStatusCOL	equ	7

StsROW		equ	23
PriCOL		equ	7
RunCOL		equ	22
WaitCOL		equ	30

	MACRO	Message	txt,row,col
	ld	b,col
	ld	c,row
	call	__CrtLocate
	ld	hl,txt
	call	PrintStr
	ENDM

;
;	Print string
;	HL=string pointer (zero terminated)
;
PrintStr:
	ld	bc,(Cursor)
nextch:	ld	a,(hl)
	or	a
	ret	z
	out	(c),a
	inc	b
	inc	hl
	jr	nextch
;
;
;	Display system status initial screen
;
DisplaySysScr:
	call	__CrtClear
	Message	MsgSys,MsgSysROW,MsgSysCOL
	Message	MsgDyn,MsgDynROW,MsgDynCOL
	Message	MsgLine,MsgLineROW1,MsgLineCOL
	Message	MsgTasks,MsgTasksROW,MsgTasksCOL
	Message	MsgLine,MsgLineROW2,MsgLineCOL
	Message	MsgStatus,MsgStatusROW,MsgStatusCOL
	Message	MsgLine,MsgLineROW3,MsgLineCOL
	ret
;
;	Bin2Hex
;
;	A = byte
;
;	returns DE = hexa representation of A
;		A = high nibble in hexa (ready to be stored/printed)
;
Bin2Hex:
	ld	e,a		;E = byte
	and	0FH		;A = low nibble
	call	nibble2hex	;D = hexa
	ld	a,e		;A = byte
	ld	e,d		;E = low nibble in hexa
	and	0F0H		;A = (high nibble, 0000)
	rrca
	rrca
	rrca
	rrca			;A = high nibble
				;falls through, will return A = D = high nibble in hexa
;
;	A = bin
;	returns A = D = hexa
;
nibble2hex:			;A = bin
	add     a,090h
        daa
        adc     a,040h
        daa			;A = hexa
	ld	d,a
	ret

ENDIF
;---------------------------------------------------------------------------------------SYSSTS

	GLOBAL	__OutCharVGA, __OutStringVGA, __CrtClear, __CrtLocate
IF	C_LANG
	GLOBAL	_OutCharVGA, _OutStringVGA, _CrtClear, _CrtLocate
ENDIF

	psect	text
;
VGAbase		equ 0		;first 4 lines of VGA display memory
line45_48       equ 0Bh         ;VGA display memory, last 4 lines

CR	equ	0DH
LF	equ	0AH
ESC	equ	1BH
BS	equ	8

Cursor: defw    0	;cursor registers
fEscape:defb	0	;flag for VT52 escape sequence
fEscExt:defb	0	;flag for extended escape sequence, e.g. set cursor location x,y
fRev:	defb	0	;flag for reverse video
EscYX:	defs	1	;new cursor position Y

;
;	Clear screen
;
IF	C_LANG
;void	CrtClear(void);
;
_CrtClear:
ENDIF
;
__CrtClear:
        ld      a,' '
        ld      bc,0BH          ;go to last group of 4 lines, first column
clr4lines:
        out     (c),a
        djnz    clr4lines
        dec     c               ;decrement 4 lines group #
        jp      p,clr4lines     ;if C >= 0 , repeat
	ld	bc,0		;set cursor to home
	ld	(Cursor),bc
        ret
;
;	Set screen cursor
;
IF	C_LANG
;void   CrtLocate(int col, int row);
;       row=0...47
;       col=0...63
;
_CrtLocate:
        ld      hl,2
        add     hl,sp
        ld      b,(hl)          ;B = col
        inc     hl
        inc     hl
        ld      c,(hl)          ;C = row
ENDIF
;
;	C=row, B=col
;
__CrtLocate:
        xor     a               ;init A=col index#
        srl     c               ;shift right row#
        jr      nc,1f
        add     a,64            ;if Carry then col index# += 64
1:
        srl     c               ;shift right row#
        jr      nc,2f
        add     a,128           ;if Carry then col index# += 128
2:
        add     a,b             ;add col#
        ld      b,a             ;B=col index#
        ld      (Cursor),bc     ;save cursor
        ret
;
;	Writes zero-terminated string to VGA
;	
IF	C_LANG
;void	OutStringVGA(char*);
;
_OutStringVGA:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
ENDIF
;
;	HL=pointer of string
;
__OutStringVGA:
	ld	a,(hl)
	or	a
	ret	z
	call	__OutCharVGA
	inc	hl
	jr	__OutStringVGA
;
;	Write character to VGA (VT52 compatible)
;
IF	C_LANG
;void	OutCharVGA(char);
;
_OutCharVGA:
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
ENDIF
;
;	A=char to be written on screen
;	HL not affected
;
__OutCharVGA:
	ld	bc,(Cursor)	;load cursor
        ld      e,a             ;save it also in E
        ld      a,(fEscape)     ;get escape sequence flag
        cp      ESC
        jr      z,escapeSeq     ;branch if escape sequence started
        ld      a,e             ;reg E contains the character to send out
        cp      ESC             ;escape sequence?
        jp      nz,chkCR        ;drop down if start of escape sequence
        ld      (fEscape),a     ;set escape sequence started flag
        ret                     ;no effect on cursor

escapeSeq:
                                ;VT52 escape sequence
                                ; A, cursor up
                                ; B, cursor down
                                ; C, cursor right
                                ; D, cursor left
                                ; H, cursor home
                                ; J, clear to end of screen
                                ; K, clear to end of line
                                ; p, set reverse video mode
                                ; q, set normal video mode (default)
                                ; Y, set cursor to y,x
                                ;While in escape sequence routine,
                                ;first check whether extended escape sequence flag is set
        ld      a,(fEscExt)     ;load extended escape sequence flag
        cp      'Y'
        jp      z,EscYdata      ;branch if extended escape-Y command
        ld      a,e             ;reg A now contains the VT52 escape code
        cp      'A'             ;cursor up
        jr      z,EscA
        cp      'B'             ;cursor down
        jr      z,EscB
        cp      'C'             ;cursor right
        jr      z,EscC
        cp      'D'             ;cursor left
        jr      z,EscD
        cp      'H'             ;home cursor
        jr      z,EscH
        cp      'J'             ;clear to end of screen
        jr      z,EscJ
        cp      'K'             ;clear to end of line
        jr      z,EscK
        cp      'Y'             ;set cursor to row,column
        jr      z,EscY
        cp      'p'             ;set reverse video mode
        jr      z,ReverseVideo
        cp      'q'             ;set normal video mode
        jr      z,NormalVideo
                                ;none of above valid values, cancel escape sequence, return
escapeSeqEnd:
        xor     a
        ld      (fEscape),a     ;escape sequence completed

saveCursor:
        ld      (Cursor),bc     ;save (updated) cursor
        ret

ReverseVideo:
        ld      a,80H           ;set video reverse bit
        ld      (fRev),a
        jr      escapeSeqEnd

NormalVideo:
        xor     a               ;clear video reverse bit
        ld      (fRev),a
        jr      escapeSeqEnd

EscA:
                                ;move cursor up one line
                                ;do not change cursor if it is already at the first line
        ld      a,b
        sub     64              ;go up one line
        ld      b,a
        jr      nc,escapeSeqEnd ;branch if BO4 boundary not crossed
                                ;crossing block-of-4 boundary
                                ;do not reverse scroll if top of screen
        ld      a,c
        or      a
        jr      z,firstBO4      ;branch if first line of first BO4
        dec     c
        jr      escapeSeqEnd

lastBO4:
firstBO4:
                                ;do not change cursor
        ld      bc,(Cursor)     ;reload current cursor and exit
        jr      escapeSeqEnd

EscB:
                                ;move cursor down one line
                                ;do no change cursor if it is already at the last line
        ld      a,b
        add     64              ;go down one line
        ld      b,a
        jr      nc,escapeSeqEnd ;branch if BO4 boundary not crossed
                                ;crossing block-of-4 boundary
                                ;do not scroll if bottom of screen
        ld      a,line45_48
        cp      c
        jr      z,lastBO4       ;branch if first line of first BO4
        inc     c
        jr      escapeSeqEnd

EscC:
                                ;cursor right, do not go past end of line
        ld      a,b
        and     3fh
        cp      3fh             ;check for last char of a line
        jr      z,escapeSeqEnd  ;do nothing if cursor is at the end of a line
        inc     b               ;move cursor to right
        jr      escapeSeqEnd

EscD:
                                ;cursor left, do not go past beginning of a line
        ld      a,b
        and     3fh
        jr      z,escapeSeqEnd  ;do nothing if cursor is at the beginning of a line
        dec     b               ;move cursor to left
        jr      escapeSeqEnd

EscH:
                                ;move cursor to home position
        ld      c,VGAbase       ;first BO4
        ld      b,0             ;beginning of line
        jr      escapeSeqEnd

EscJ:
                                ;clear to end of screen
                                ;write blank from cursor to end of line45_48
        ld      a,' '
EscJloop:
        out     (c),a
        inc     b
        jr      nz,EscJloop
        inc     c               ;next BO4
        ld      a,line45_48+1   ;end of the video memory?
        cp      c
        jr      nz,EscJ
        ld      bc,(Cursor)     ;restore current cursor
        jr      escapeSeqEnd

EscK:
                                ;clear to end of line
        ld      a,' '           ;write blank from cursor to end of this line
        out     (c),a
        inc     b
        ld      a,b
        and     3fh             ;looking at current line only
        jr      nz,EscK         ;end of current line?
        ld      bc,(Cursor)     ;restore current cursor
        jr      escapeSeqEnd

EscY:
                                ;set flag to expect row(y), column(x) variables
        ld      (fEscExt),a     ;set extended escape sequence flag
        xor     a
        ld      (EscYX),a       ;clear new cursor position Y
        ret

EscYdata:
                                ;if new cursor position Y (EscYX) is zero, update Y
                                ; else the data must be new cursor positon X (ESCYY)
				; so compute new cursor position
        ld      a,(EscYX)       ;check new cursor position Y for vacancy
        or      a
        jr      z,saveNewY      ;branch is data is updated cursor position X
                                ;data must be updated cursor position Y, 
				; have the necessary data to compute new cursor position
                                ;(cursor) is vertical displacement = (y-31)/4
                                ;(cursor+1) is horizontal displacement = (remainder ((y-31)/4) * 64) + (EscYX-31)
        ld      a,e
        ld      (Cursor+1),a    ;temporary save the new X position
        ld      a,(EscYX)       ;get the new Y position
        sub     32
        ld      c,0             ;regC contains remainder * 64
        srl     a               ;divide by 2
        rr      c               ;lsb remainder goes into regC
        srl     a               ;divide by 2
        rr      c               ;msb remainder goes into regC, regC now contains (remainder * 64)
        ld      (Cursor),a      ;update cursor, this is vertical displacement (Y)
        ld      a,(Cursor+1)    ;retrieve the saved X position
        sub     32
        add     c
        ld      (Cursor+1),a    ;update cursor, this is the horizontal displacement (X)
        xor     a
        ld      (fEscExt),a     ;end of extended escape sequence
        ld      (fEscape),a     ;escape sequence completed
        ret

saveNewY:
                                ;save the updated cursor Y value
        ld      a,e
        ld      (EscYX),a
        ret                     ;get ready for new cursor X value
                                ;don't change fEscape, fEscExt
chkCR:
        cp      CR              ;carriage return?
        jr      nz,chkLF        ;drop down to process carriage return
                                ;carriage return
        ld      a,0c0h          ;move cursor to beginning of current line
        and     b
        ld      b,a
        jp      saveCursor      ;don't write the CR character

chkLF:
        cp      LF              ;line feed?
        jr      nz,chkBS
                                ;line feed
        ld      a,3fh           ;move to end of current line
        or      b
        ld      b,a
        jr      nextChar

chkBS:
                                ;check for backspace, if yes, move cursor back one space
        cp      BS
        jr      nz,writeNormalChar
        dec     b               ;decrement the cursor
        jp      saveCursor

writeNormalChar:
                                ;write char, according to current video mode
        ld      a,(fRev)	;apply reverse video flag
        or      e               ;to char in E
        out     (c),a           ;write out the character

nextChar:
                                ;advance cursor to next position
                                ;no hardware scrolling capability
                                ;here is where hardware scroll register is used if available
        inc     b
        jp      nz,saveCursor
        ld      a,c             ;check for last line of 48-line screen
        cp      line45_48
        jr      z,scrolling     ;if last line, scroll the entire screen
        inc     c               ;regC points to next 4 lines
        jp      saveCursor

scrolling:
                                ;move the entire screen up one line, start with the first line
        ld      de,64           ;source is e, destination is d
        ld      c,VGAbase
cp3lines:
        ld      b,e             ;point to source
        in      a,(c)           ;get character from next line
        ld      b,d             ;point to destination
        out     (c),a           ;write char to destination
        inc     d               ;increment source & destination
        inc     e
        jr      nz,cp3lines     ;do this for 3 lines
cp4thline:
                                ;last line source is next block of 4 lines
        inc     c               ;next block of 4 lines
        ld      b,e
        in      a,(c)
        ld      b,d
        dec     c               ;destination is last line of previous block of 4 lines
        out     (c),a
        inc     e
        inc     d
        jr      nz,cp4thline
        inc     c
        ld      a,c             ;the last block of 4 lines?
        cp      line45_48+1
        jr      nz,cp3lines
                                ;enter the scrolling routine with c=line45_48
                                ;clear the last line
        ld      c,line45_48
        ld      b,192
        ld      a,' '           ;blank out the last line
blankline:
        out     (c),a
        inc     b
        jr      nz,blankline
        ld      b,192           ;exit the scrolling routine with cursor at beginning of last line
        jp      saveCursor
;
;-------------------------------------------------------------------------------

ENDIF
