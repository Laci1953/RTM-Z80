*Include config.mac

IF	Z80ALL

	psect	text

IF	C_LANG

	GLOBAL	_MoveFrom32K, _MoveTo32K	
;
;void MoveFrom32K(int bank, void* source, void* dest, int count)
;void MoveTo32K(int bank, void* source, void* dest, int count)
;
_MoveFrom32K:
_MoveTo32K:
	ld	hl,2
	add	hl,sp
	ld	a,(hl)		;A=bank (0 or 1)
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=source
	push	de		;on stack
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=dest
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=count
	pop	hl		;HL=source

ENDIF

	GLOBAL	__MoveFrom32K, __MoveTo32K
;
__MoveFrom32K:
__MoveTo32K:
	inc	a		;A=bank(1 or 2)
	jp	MOVEBYTES32K

ENDIF
