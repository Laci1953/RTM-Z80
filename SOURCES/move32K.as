;
;	Copyright (C) 2023 by Ladislau Szilagyi
;
TITLE       Z80ALL extra 2x32KB RAM support routines
;
*Include config.mac

IF	Z80ALL

	psect	text

IF	C_LANG

	GLOBAL	_MoveFrom32K, _MoveTo32K	
;
;void MoveFrom32K(int bank, void* source, void* dest, int count)
;void MoveTo32K(int bank, void* source, void* dest, int count)
;
IF	DEBUG

_MoveFrom32K:
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
;
;	source must be < 8000H, dest must be > BMEM_BASE, count must be < 1000H
;
	push	hl
	push	de
	push	bc
	or	a		;CARRY = 0
	ld	de,8000H
	sbc	hl,de
	jr	nc,err		;if source >= 8000H, quit
	or	a
	ld	hl,1000H
	sbc	hl,bc
	jr	c,err		;if count > 1000H, quit
	pop	bc
	pop	de
	ld	hl,BMEM_BASE
	sbc	hl,de
	jr	nc,err1		;if dest < BMEM_BASE, quit
	pop	hl
	jr	doit		;else do it
err:	pop	bc
	pop	de
err1:	pop	hl
	ret
;
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
;
;	source must be > BMEM_BASE, dest must be < 8000H, count must be < 1000H
;
	push	hl
	push	de
	push	bc
	or	a		;CARRY = 0
	ld	de,BMEM_BASE
	sbc	hl,de
	jr	c,err		;if source < BMEM_BASE, quit
	or	a
	ld	hl,1000H
	sbc	hl,bc
	jr	c,err		;if count > 1000H, quit
	pop	bc
	pop	de
	ld	hl,8000H
	sbc	hl,de
	jr	c,err1		;if dest > 8000H, quit
	pop	hl
				;else do it
;
doit:

ELSE

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

ENDIF

	GLOBAL	__MoveFrom32K, __MoveTo32K
;
__MoveFrom32K:
__MoveTo32K:
	inc	a		;A=bank(1 or 2)
	jp	MOVEBYTES32K

ENDIF
