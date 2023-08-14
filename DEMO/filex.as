*Include config.mac
*Include apiasm.mac

	GLOBAL _setname
	GLOBAL _openfile
	GLOBAL _createfile
	GLOBAL _writefile
	GLOBAL _readfile
	GLOBAL _closefile
	GLOBAL _setdma
        GLOBAL _setdisk
	GLOBAL _cleanfcb

openf 	equ 15 	; open file
closef 	equ 16 	; close file
deletef equ 19 	; delete file
writef 	equ 21 	; sequential write
readf 	equ 20 	; sequential read
makef 	equ 22	; make file
setdmaf	equ 26	; set DMA addr
;
	psect	text

dfcb:				; destination fcb
	defs	1		; disk (A=1,B=2,...)
n_e:	defm	'           '	; file name & ext
dfcbz:	defb	0		; EX=0
	defs	2		; S1,S2
	defb	0		; RC=0
	defs	16		; D0,...D15
	defb	0		; CR=0
	defb	0,0,0		; R0,R1,R2

DFCBZ_LEN	equ	$-dfcbz
;
_cleanfcb:
	ld	hl,dfcbz
	xor	a
	ld	b,DFCBZ_LEN
clloop:	ld	(hl),a
	inc	hl
	djnz	clloop
	ret
;
_setdisk:
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	ld	(dfcb),a
	ret
;
_setdma:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	c,setdmaf
	jp	__bdos
;
_setname:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	bc,11		;BC=count
	ex	de,hl		;HL=source
	ld	de,n_e		;DE=dest
	ldir
	ret
;
_openfile:
	ld	hl,BDOS_Sem
	call	__Wait
 	ld 	de,dfcb
	ld	c,openf
 	call 	__bdos
	cp	0FFH		;A=FFH if openf failed
	ld	hl,1
	ret	nz
	dec	hl
	ret

_createfile:
	ld	hl,BDOS_Sem
	call	__Wait
 	ld 	de,dfcb
	ld 	c,deletef
	call	__bdos
 	ld 	de,dfcb
	ld	c,makef
 	call 	__bdos
	cp	0FFH		;A=FFH if makef failed
	ld	hl,1
	ret	nz
	dec	hl
	ret

;
_writefile:
 	ld 	de,dfcb
	ld	c,writef
 	call 	__bdos
	or	a		;A=0 for writef success
	ld	hl,1
	ret	z
	dec	hl
	ret

_readfile:
 	ld 	de,dfcb
	ld	c,readf
 	call 	__bdos
	or	a		;A=0 for readf success
	ld	hl,1
	ret	z
	dec	hl
	ret

_closefile:
 	ld 	de,dfcb 	; destination
	ld	c,closef
 	call 	__bdos
	ld	hl,BDOS_Sem
	jp	__Signal
;
