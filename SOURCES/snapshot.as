;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	Memory Snapshot support
;
*Include config.mac
*Include romram.mac

COND	NOCPM .and. RAM128K

	psect	text

COND	NOWATSON
	GLOBAL __LowToUp100H
COND	C_LANG
	GLOBAL _LowToUp100H
ENDC
ENDC
;
;	Move from Registers to UP RAM 6 words (12 bytes)
;
;	called under DISABLED interrupts
;	BC,DE,HL,BC',DE',HL' = to be moved to UP RAM
;	IY = destination addr in UP RAM
;	returns IY=IY+12, IX=IX+12
;	A,BC' affected
;
;LowToUp_6W:			;MOVED TO 0DF91H, ECHO in UPPER RAM
;	UP_RAM
;	ld	(iy+0),c
;	ld	(iy+1),b
;	ld	(iy+2),e
;	ld	(iy+3),d
;	ld	(iy+4),l
;	ld	(iy+5),h
;	exx
;	ld	(iy+6),c
;	ld	(iy+7),b
;	ld	(iy+8),e
;	ld	(iy+9),d
;	ld	(iy+10),l
;	ld	(iy+11),h
;	ld	bc,12
;	add	iy,bc
;	add	ix,bc
;	exx
;	LOW_RAM
;	ret
;
;void	_LowToUp100H(void* From, void* To)
;	IX not affected
;
_LowToUp100H:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=From
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=To
	push	ix		;save IX
	push	bc
	pop	iy		;IY=To
	push	de
	pop	ix		;IX=From
	call	__LowToUp100H
	pop	ix		;restore IX
	ret
;
;	Move from LOW RAM to UP RAM 100H of memory
;
;	IX=source, IY=Destination
;	returns IX=IX+100H,IY=IY+100H 
;
__LowToUp100H:
	ld	a,21		;21 x 12 = 252, + 4 = 256 (100H)
lloop21:			;move 252 bytes
	ld	c,(ix+0)
	ld	b,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	l,(ix+4)
	ld	h,(ix+5)
	di			;----------DI-----------
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
	ei			;----------EI-----------
	dec	a
	jr	nz,lloop21
				;move 4 bytes
	ld	c,(ix+0)
	ld	b,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	di			;----------DI-----------
	call	LOW_TO_UP_4B
	ei			;----------EI-----------
	ret
;	UP_RAM			;MOVED TO 0DFC7H, ECHO in UPPER RAM
;	ld	(iy+0),c
;	ld	(iy+1),b
;	ld	(iy+2),e
;	ld	(iy+3),d
;	ld	bc,4
;	add	iy,bc
;	add	ix,bc
;	LOW_RAM
;	ret

COND	WATSON

	GLOBAL Snapshot
;
;	Moves all 64K to UP RAM
;
;	affects all regs
;
Snapshot:
	ld	ix,0		;source
	ld	iy,0		;destination
	xor	a		;nr.of bytes to be moved = 64KB = 100H x 100H
loop:	push	af
	call	__LowToUp100H
	pop	af
	dec	a
	jr	nz,loop
	ret
;
ENDC

ENDC
