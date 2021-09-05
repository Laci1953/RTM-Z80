; sample file-to-file copy program
; copy C:T.TXT to D:X.TXT
*Include config.mac
*Include apiasm.mac

	GLOBAL _main

	psect text

openf 	equ 15 	; open file func#
closef 	equ 16 	; close file func#
deletef equ 19 	; delete file func#
readf 	equ 20	; sequential read func#
writef 	equ 21 	; sequential write
makef 	equ 22	; make file func#
setdma	equ 26	; set DMA addr func#
;
CR	equ	0DH
LF	equ	0AH
;
W:	defs	2		; CON_IO semaphore
;
sfcb:				; source fcb
	defb	3		; C:
	defm	'T       TXT'	; T.TXT
	defb	0		; EX=0
	defs	2		; S1,S2
	defb	0		; RC=0
	defs	16		; D0,...D15
	defb	0		; CR=0
	defb	0,0,0		; R0,R1,R2
;
dfcb:				; destination fcb
	defb	4		; D:
	defm	'X       TXT'	; X.TXT
	defb	0		; EX=0
	defs	2		; S1,S2
	defb	0		; RC=0
	defs	16		; D0,...D15
	defb	0		; CR=0
	defb	0,0,0		; R0,R1,R2
;
buf128:	defs	128		;data buffer
;
; console messages
;
nofile: defb	CR,LF
	defm 	'no source file'
	defb	0
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
open: 	ld 	c,openf
 	jp 	_bdos
;
close: 	ld 	c,closef
 	jp 	_bdos
;
delete: ld 	c,deletef
 	jp 	_bdos
;
read: 	ld 	c,readf
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
_main:	
	ld	bc,0E0H
	ld	hl,Task
	ld	e,10
	call	__StartUp
	ret
;
Task:
	call	__MakeSem
	ld	(W),hl
	ld	hl,BDOS_Sem
	call	__Wait
;
	ld	de,buf128	; use buf128 as data buffer
	call	setDMA
;
 	ld 	de,sfcb 	; source file
 	call 	open 		; error if 255
 	ld 	de,nofile 	; ready message
 	inc 	a 		; 255 becomes 0
 	jp 	z,finis 	; done if no file
;
; source file open, prep destination
 	ld 	de,dfcb 	; destination
 	call 	delete 		; remove if present
;
 	ld 	de,dfcb		; destination
 	call 	make 		; create the file
 	ld 	de,nodir 	; ready message
 	inc 	a 		; 255 becomes 0
 	jp 	z,finis 	; done if no dir space
;
; source file open, dest file open
; copy until end of file on source
;
copy: 	ld 	de,sfcb 	; source
 	call 	read 		; read next record
 	or 	a 		; end of file?
 	jp 	nz,eofile 	; skip write if so
;
; not end of file, write the record
 	ld 	de,dfcb 	; destination
 	call 	write 		; write the record
 	ld 	de,space 	; ready message
 	or 	a 		; 00 if write ok
 	jp 	nz,finis 	; end if so
 	jp 	copy 		; loop until eof
;
eofile: 			; end of file, close destination
 	ld 	de,dfcb 	; destination
 	call 	close 		; 255 if error
 	ld 	hl,wrprot 	; ready message
 	inc 	a 		; 255 becomes 00
 	jp 	z,finis 	; shouldn't happen
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
