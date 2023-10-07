;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
TITLE	Memory Snapshot support
;
*Include config.mac
*Include romram.mac

IF	NOSIM 

	psect	text

	GLOBAL Snapshot

IF	RAM128K

IF	SC108

	GLOBAL __LowToUp100H
	GLOBAL __UpToLow100H
IF	C_LANG
	GLOBAL _LowToUp100H
	GLOBAL _UpToLow100H
ENDIF

	GLOBAL	CtoHfromIX_0
	GLOBAL	CtoHfromIX_6
	GLOBAL	CtoDfromIX_0
	GLOBAL	IX_0_fromCtoH
	GLOBAL	IX_6_fromCtoH
	GLOBAL	IX_0_fromCtoD

CtoHfromIX_0:
	ld	c,(ix+0)
	ld	b,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ld	l,(ix+4)
	ld	h,(ix+5)
	ret
CtoHfromIX_6:
	ld	c,(ix+6)
	ld	b,(ix+7)
	ld	e,(ix+8)
	ld	d,(ix+9)
	ld	l,(ix+10)
	ld	h,(ix+11)
	ret
CtoDfromIX_0:
	ld	c,(ix+0)
	ld	b,(ix+1)
	ld	e,(ix+2)
	ld	d,(ix+3)
	ret
IX_0_fromCtoH:
        ld      (ix+0),c
        ld      (ix+1),b
        ld      (ix+2),e
        ld      (ix+3),d
        ld      (ix+4),l
        ld      (ix+5),h
	ret
IX_6_fromCtoH:
        ld      (ix+6),c
        ld      (ix+7),b
        ld      (ix+8),e
        ld      (ix+9),d
        ld      (ix+10),l
        ld      (ix+11),h
	ret
IX_0_fromCtoD:
        ld      (ix+0),c
        ld      (ix+1),b
        ld      (ix+2),e
        ld      (ix+3),d
	ret
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
	call	CtoHfromIX_0
	di			;----------DI-----------
	exx
	call	CtoHfromIX_6
	exx
	ex	af,af'
	call	LOW_TO_UP_6W	;LowToUp_6W
	ex	af,af'
	ei			;----------EI-----------
	dec	a
	jr	nz,lloop21
				;move 4 bytes
	call	CtoDfromIX_0
	di			;----------DI-----------
	call	LOW_TO_UP_4B
	ei			;----------EI-----------
	ret
;
;void	_UpToLow100H(void* From, void* To)
;	IX not affected
;
_UpToLow100H:
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
	pop	ix		;IX=To
	push	de
	pop	iy		;IY=From
	call	__UpToLow100H
	pop	ix		;restore IX
	ret
;
;       Move from UP RAM to LOW RAM a 100H of memory
;
;       called under DISABLED interrupts
;       IY=Source, IX=Destination
;	returns IX=IX+100H,IY=IY+100H 
;
__UpToLow100H:
	ld	a,21		;21 x 12 = 252, + 4 = 256 (100H)
loop21:				;move 252 bytes
	di			;----------DI-----------
	ex	af,af'
        call	UP_TO_LOW_6W	;UpToLow6W
	ex	af,af'
	ei			;----------EI-----------
	call	IX_0_fromCtoH
	di			;----------DI-----------
        exx
	call	IX_6_fromCtoH
        exx
	ei			;----------EI-----------
        ld      bc,12		;IX=IX+12, IY=IY+12
        add     iy,bc
        add     ix,bc
	dec	a
	jr	nz,loop21
				;move 4 bytes
	di			;----------DI-----------
	call	UP_TO_LOW_4B	
	ei			;----------EI-----------
	call	IX_0_fromCtoD
	ld	bc,4
	add	iy,bc
	add	ix,bc
	ret
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

ENDIF
ENDIF

IF	Z80ALL

;bank#0	(0000 - 8000H)	loaded at boot
;bank#1	(0000 - 8000H)	copy of bank#0
;bank#2	(0000 - 8000H)	copy of bank#3
;bank#3	(8000H - FFFFH)	loaded at boot

COPY_0_TO_1	equ	0DF67H
COPY_3_TO_2	equ	0DFB5H

;CPMBOOT stores in bank#3 at DFxxH the copy-bank routines

Snapshot:
	ld	iy,ret1
	jp	COPY_0_TO_1
ret1:
	ld	iy,ret2
	jp	COPY_3_TO_2
ret2:
	ret
;

ENDIF

ENDIF
