;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;	Save to / Load from 512MB RAM
;
*Include config.mac
*Include romram.mac

COND	M512

	psect 	text

	GLOBAL	__Save100H,__Load100H
COND	C_LANG
	GLOBAL	_Save100H,_Load100H
ENDC
;
COND C_LANG
;short	_Save100H(void* source, void* dest_high)
;
;	Destination address = dest_high 00 H
;
;	returns HL=0 : params out of range, else 1
;
_Save100H:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=dest high
	ex	de,hl		;HL=source
	call	__Save100H
	ld	hl,1
	ret	nc		;return HL=1 if OK
	dec	hl		;else return HL=0
	ret
ENDC
;
;	Save 100H bytes
;
;	HL = source (from 0000H to BF00H)
;	BC'00' = destination ( BC from 0 to 73FH )
;
;	ret CARRY=1 : wrong source or dest addr
;
__Save100H:
COND	DEBUG
	push	hl
	ld	de,0BF01H
	xor	a		;CARRY=0
	sbc	hl,de		;source > BF00 ?
	jr	c,ok1
				;return CARRY=1
err:	
	pop	hl
	scf
	ret
ok1:
	xor	a		;CARRY=0
	ld	hl,73FH
	sbc	hl,bc		;dest > 73F00H ?
	jr	c,err
	pop	hl
ENDC
	push	bc		;save dest
	rl	c		;2 shift left BC
	rl	b
	rl	c
	rl	b
	ld	a,32+3
	add	a,b		;A=dest RAM physical bank
	pop	bc		;restore dest
	di			;disable interrupts
	out	(78H+3),a	;select dest physical RAM
	ld	a,c
	and	3FH		
	add	a,0C0H		;CARRY=0
	ld	d,a
	ld	e,0		;DE=dest
	ld	bc,100H
	ldir			;move 100H bytes
	SETRAM	3,2		;restore original Physical RAM
	ei			;enable interrupts
	ret
;
COND C_LANG
;short	_Load100H(void* dest, void* source_high)
;
;	Source address = source_high 00 H
;
;	returns HL=0 : params out of range, else 1
;
_Load100H:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)		;DE=dest
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)		;BC=source high
	call	__Load100H
	ld	hl,1
	ret	nc		;return HL=1 if OK
	dec	hl		;else return HL=0
	ret
ENDC
;
;	Load 100H bytes
;
;	DE = dest (from 0000H to BF00H)
;	BC'00' = source ( BC from 0 to 73FH )
;
;	ret CARRY=1 : wrong source or dest addr
;
__Load100H:
COND	DEBUG
	ld	hl,0BF00H
	xor	a		;CARRY=0
	sbc	hl,de		;dest > BF00 ?
	ret	c		;return CARRY=1
				;CARRY=0
	ld	hl,73FH
	sbc	hl,bc		;source > 73F00H ?
	ret	c		;return CARRY=1
ENDC
	push	bc		;save source
	rl	c		;2 shift left BC
	rl	b
	rl	c
	rl	b
	ld	a,32+3
	add	a,b		;A=source RAM physical bank
	pop	bc		;restore source
	di			;disable interrupts
	out	(78H+3),a	;select source physical RAM
	ld	a,c
	and	3FH		
	add	a,0C0H		;CARRY=0
	ld	h,a
	ld	l,0		;HL=source
	ld	bc,100H
	ldir			;move 100H bytes
	SETRAM	3,2		;restore original Physical RAM
	ei			;enable interrupts
	ret
;
	ENDC
