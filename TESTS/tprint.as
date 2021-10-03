; sample file print program
; print C:T.TXT to parallel line printer
;
*Include config.mac
*Include apiasm.mac

	GLOBAL _main

	psect text

openf 	equ 15 	; open file
closef 	equ 16 	; close file
deletef equ 19 	; delete file
readf 	equ 20	; sequential read
setdma	equ 26	; set DMA addr
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
buf128:	defs	128		;data buffer
;
; system interface subroutines
; (all return directly from bdos)
;
open: 	ld 	c,openf
 	jp 	__bdos
;
read: 	ld 	c,readf
 	jp 	__bdos
;
setDMA:	ld	c,setdma
	jp	__bdos
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
 	inc 	a 		; 255 becomes 0
 	jr 	z,finis 	; done if no file
;
; read & print until end of file on source
;
loop: 	ld 	de,sfcb 	; source
 	call 	read 		; read next record
 	or 	a 		; end of file?
 	jr 	nz,finis 	; skip print if so
;
; not end of file, print the record
;
	ld	de,buf128
	ld	c,128
	call	__LPT_Print
	ld	a,l
	or	a
	jr	z,loop
	cp	1
	jr	z,offline
	cp	2
	jr	z,paperout
	jr	perr

offline:
	ld	hl,msg_offline
	call	type_str
	jr	finis
paperout:
	ld	hl,msg_paperout
	call	type_str
	jr	finis
perr:
	ld	hl,msg_perr
	call	type_str
;
finis: 				; exit
	ld	hl,BDOS_Sem
	call	__Signal
	call	__GetCrtTask
	call	__StopTask
;
;	Type string
;	HL=string
;
type_str:
	push	hl
	ld	bc,0
loopt:	ld	a,(hl)
	or	a
	jr	z,1f
	inc	bc
	inc	hl
	jr	loopt
1:	pop	hl
	ld	de,(W)
	call	__CON_Write
	ld	hl,(W)
	call	__Wait
	ret
;
msg_offline:
	defb	0dh,0ah
	defm	'Printer OFFLINE !'
	defb	0
msg_paperout:
	defb	0dh,0ah
	defm	'Paper unavailable !'
	defb	0
msg_perr:
	defb	0dh,0ah
	defm	'Printer error !'
	defb	0
;
