;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	Verify register values 
;
	psect 	bss

ra:	defs	1
rbc:	defs	2
rde:	defs	2
rhl:	defs	2
rix:	defs	2
riy:	defs	2
;
mask:	defs	1
;
MASK_A	equ	0
MASK_BC	equ	1
MASK_DE	equ	2
MASK_HL	equ	3
MASK_IX	equ	4
MASK_IY	equ	5

	GLOBAL _SaveRegs,_CheckRegs,_GetMask

	psect	text
;
;	Save regs & reset mask
;
_SaveRegs:
	ld	(ra),a
	ld	(rbc),bc
	ld	(rde),de
	ld	(rhl),hl
	ld	(rix),ix
	ld	(riy),iy
	push	af
	xor	a
	ld	(mask),a
	pop	af
	ret
;
;	Check regs
;	Result is marked on the mask
_CheckRegs:
	push	hl
	ld	hl,mask
	ld	(hl),0	;reset mask
	ld	hl,ra	;check A
	cp	(hl)
	jr	z,1f
	ld	hl,mask
	set	MASK_A,(hl)
1:	ld	hl,(rbc);check BC
	or	a	;CARRY=0
	sbc	hl,bc
	jr	z,2f
	ld	hl,mask
	set	MASK_BC,(hl)
2:	ld	hl,(rde);check DE
	or	a	;CARRY=0
	sbc	hl,de
	jr	z,3f
	ld	hl,mask
	set	MASK_DE,(hl)
3:	pop	hl	;check HL
	push	af
	ld	a,(rhl)
	cp	l
	jr	z,4f
	ld	a,(mask)
	set	MASK_HL,a
	ld	(mask),a
4:	ld	a,(rhl+1)
	cp	h
	jr	z,5f
	ld	a,(mask)
	set	MASK_HL,a
	ld	(mask),a
5:	pop	af	;check IX
	push	hl
	push	bc
	push	ix
	pop	bc
	ld	hl,(rix)
	or	a	;CARRY=0
	sbc	hl,bc
	jr	z,6f
	ld	hl,mask
	set	MASK_IX,(hl)
6:	push	iy	;check IY
	pop	bc
	or	a	;CARRY=0
	sbc	hl,bc
	jr	z,7f
	ld	hl,mask
	set	MASK_IY,(hl)
7:	pop	bc
	pop	hl
	ret
;
;	GetMask
;	return HL, H=0, L=mask 
_GetMask:
	ld	a,(mask)
	ld	h,0
	ld	l,a
	ret
;	