	psect	text

	GLOBAL _ReadFromUpRAM
	GLOBAL _type

UP_TO_LOW_6W equ	0DB4Dh
UP_TO_LOW_4B equ	0DB7Ch

;void type(char* buf)
_type:
	xor	a
	out	(38h),a		;ROM IN, LOW RAM
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=buf
	ex	de,hl
loop:
	ld	a,(hl)
	or	a
	ret	z
	ld	c,2
	push	hl
	rst	30H
	pop	hl
	inc	hl
	jr	loop
;
;void ReadFromUpRAM(void* p, char* buf);
_ReadFromUpRAM:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=p
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=buf
	push	ix
	push	de
	pop	iy		;from
	push	bc
	pop	ix		;to
	call	UpToLow100H
	pop	ix
	ret
;
;       Move from UP RAM to LOW RAM a 100H of memory
;
;       IY=Source, IX=Destination
;
UpToLow100H:
	ld	a,21		;21 x 12 = 252, + 4 = 256 (100H)
loop21:				;move 252 bytes
	ex	af,af'
        call	UP_TO_LOW_6W	;call    UpToLow_6W
	ex	af,af'
        ld      (ix+0),c
        ld      (ix+1),b
        ld      (ix+2),e
        ld      (ix+3),d
        ld      (ix+4),l
        ld      (ix+5),h
        exx
        ld      (ix+6),c
        ld      (ix+7),b
        ld      (ix+8),e
        ld      (ix+9),d
        ld      (ix+10),l
        ld      (ix+11),h
        exx
        ld      bc,12		;IX=IX+12, IY=IY+12
        add     iy,bc
        add     ix,bc
	dec	a
	jr	nz,loop21
				;move 4 bytes
	call	UP_TO_LOW_4B	
        ld      (ix+0),c
        ld      (ix+1),b
        ld      (ix+2),e
        ld      (ix+3),d
	ret
;
