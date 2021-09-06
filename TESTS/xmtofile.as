*Include config.mac
*Include apiasm.mac

Z80SIM_TEST	equ	0

;
;	Receives a file via XMODEM and writes-it to D:XMODEM.TXT
;
	GLOBAL _main

	psect text

openf 	equ 15 	; open file func#
closef 	equ 16 	; close file func#
deletef equ 19 	; delete file func#
writef 	equ 21 	; sequential write
makef 	equ 22	; make file func#
setdma	equ 26	; set DMA addr func#
;
CR	equ	0DH
LF	equ	0AH
;
EOT 	equ	'D'- 040H
;
W:	defs	2		; CON_IO semaphore
MB:	defs	2		; data mailbox
;
dfcb:				; destination fcb
	defb	4		; D:
	defm	'XMODEM  TXT'	; XMODEM.TXT
	defb	0		; EX=0
	defs	2		; S1,S2
	defb	0		; RC=0
	defs	16		; D0,...D15
	defb	0		; CR=0
	defb	0,0,0		; R0,R1,R2
;
buf128:	defs	128		;data buffer
EOTmark:defs	1

COND	Z80SIM_TEST
S:	defs	2
T:	defs	2
msg123:	defm	'111111111111111111111111111111111111111111111111111111111111'
	defm	'222222222222222222222222222222222222222222222222222222222222'
	defm	'333333'
	defb	CR,LF
EOT_M:	defb	0
;
ENDC
_main:	
	ld	bc,060H
	ld	hl,Task
	ld	e,10
	call	__StartUp
	ret
;
TaskXmRecv:
COND	Z80SIM_TEST
	call	__MakeSem
	ld	(S),hl
	call	__MakeTimer
	ld	(T),hl
	ld	de,(S)
	ld	bc,10
	ld	a,1
	call	__StartTimer
	ld	b,20
loopsend:
	push	bc	
	ld	hl,(S)
	call	__Wait
	ld	hl,(MB)
	ld	de,msg123
	call	__SendMail
	pop	bc
	djnz	loopsend
	ld	hl,(MB)
	ld	de,msg123
	ld	a,EOT
	ld	(EOT_M),a
	call	__SendMail
	ld	l,1
ENDC
COND	Z80SIM_TEST-1
	ld	hl,(MB)
	call	__XmRecv
ENDC
	ld	a,l
	cp	1
	jr	z,ok
	cp	-1
	jr	z,canc
				;else failure
	ld	hl,Failed
	ld	c,FailedLen
type:	ld	de,(W)
	call	__CON_Write
	ld	hl,(W)
	call	__Wait
	call	__GetCrtTask
	call	__StopTask
;
ok:	ld	hl,Ok
	ld	c,OkLen
	jr	type
canc:	ld	hl,Canc
	ld	c,CancLen
	jr	type
;
Failed: defb	CR,LF
	defm	'Communication failure'
FailedLen equ $-Failed
Ok:	defb	CR,LF
	defm	'Communication ended OK'
OkLen	equ	$-Ok
Canc:	defb	CR,LF
	defm	'Communication cancelled'
CancLen	equ	$-Canc
;
nodir: 	defb	CR,LF
 	defm 	'no directory space'
	defb	0
space: 	defb	CR,LF
 	defm 	'out of data space'
	defb	0
wrprot: defb	CR,LF
	defm 	'write protected?'
	defb	0
normal: defb	CR,LF
	defm 	'copy complete'
	defb	0
;
; system interface subroutines
; (all return directly from bdos)
;
close: 	ld 	c,closef
 	jp 	_bdos
;
delete: ld 	c,deletef
 	jp 	_bdos
;
write: 	ld 	c,writef
 	jp 	_bdos
;
make: 	ld 	c,makef
 	jp 	_bdos
;
setDMA:	ld	c,setdma
	jp	_bdos
;
Task:
	call	__MakeSem
	ld	(W),hl
	ld	c,129
	call	__MakeMB
	ld	(MB),hl
	ld	bc,060H
	ld	hl,TaskXmRecv
	ld	e,100
	call	__RunTask

	ld	hl,BDOS_Sem
	call	__Wait
;
	ld	de,buf128	; use buf128 as data buffer
	call	setDMA
;
; prep destination file
 	ld 	de,dfcb 	; destination
 	call 	delete 		; remove if present
;
 	ld 	de,dfcb		; destination
 	call 	make 		; create the file
 	ld 	de,nodir 	; ready message
 	inc 	a 		; 255 becomes 0
 	jr 	z,finis 	; done if no dir space
;
getloop:
	ld	hl,(MB)
	ld	de,buf128
	call	__GetMail
	ld	a,(EOTmark)
	cp	EOT
	jr	z,CloseIt

; not end of file, write the record
 	ld 	de,dfcb 	; destination
 	call 	write 		; write the record
 	ld 	de,space 	; ready message
 	or 	a 		; 00 if write ok
 	jr 	nz,finis 	; end if so
	jr	getloop
;
CloseIt:
 	ld 	de,dfcb 	; destination
 	call 	close 		; 255 if error
 	ld 	hl,wrprot 	; ready message
 	inc 	a 		; 255 becomes 00
 	jr 	z,finis 	; shouldn't happen
;
; copy operation complete, end
 	ld 	de,normal 	; ready message
;
finis: 				; write message given in de, exit
	push	de
	ld	hl,BDOS_Sem
	call	__Signal
	pop	hl		; HL=msg
	call	type_str
	call	__GetCrtTask
	call	__StopTask
;
;	Type string
;	HL=string
;
type_str:
	push	hl
	ld	bc,0
loop:	ld	a,(hl)
	or	a
	jr	z,1f
	inc	bc
	inc	hl
	jr	loop
1:	pop	hl
	ld	de,(W)
	call	__CON_Write
	ld	hl,(W)
	call	__Wait
	ret
;
	
