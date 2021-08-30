; sets up for CP/M service routines for up_to_low RAM transport
;
	psect	text
;
;	>zas setupram.as'
;	link>
;		-ptext=8000h -oo.obj setupram.obj
;	>objtohex o.obj setupram.hex
;
MEMP_PORT       equ     38H
;
ROM_OUT         equ     00000001B
ROM_IN          equ     00000000B
;
LOWER_64RAM     equ     00000000B
UPPER_64RAM     equ     10000000B

MACRO	LOW_RAM
	ld	a,LOWER_64RAM .or. ROM_OUT
	out	(MEMP_PORT),a
ENDM

MACRO	UP_RAM
	ld	a,UPPER_64RAM .or. ROM_OUT
	out	(MEMP_PORT),a	
ENDM

start:
	ld	sp,end_stack
				;move up-to-low routines fragment in LowRAM
	ld	hl,$CF4D
	ld	de,0CF4DH
	ld	bc,$len
	ldir
				;move up-to-low routines fragment to UppRAM
	ld	ix,$CF4D
	ld	de,0CF4DH
	ld	a,$len
looptoup:
	push	af
	ld	a,(ix+0)
	ld	c,2BH		;(DE) in UpperRAM <-- A
	rst	30H
	inc	ix
	inc	de
	pop	af
	dec	a
	jr	nz,looptoup

	ld	a,1		;SCM warm reset
	ld	c,0
	rst	30H

;
;	The following code must be moved to Lower & Upper RAM at 
;
;	up to low 6W
;
$CF4D:  UP_RAM
        ld      c,(iy+0)
        ld      b,(iy+1)
        ld      e,(iy+2)
        ld      d,(iy+3)
        ld      l,(iy+4)
        ld      h,(iy+5)
        exx
        ld      c,(iy+6)
        ld      b,(iy+7)
        ld      e,(iy+8)
        ld      d,(iy+9)
        ld      l,(iy+10)
        ld      h,(iy+11)
        exx
        LOW_RAM
        ret
;
;	up to low 4B
;
$CF7C:	UP_RAM
        ld      c,(iy+0)
        ld      b,(iy+1)
        ld      e,(iy+2)
        ld      d,(iy+3)
	LOW_RAM
	ret
;
$len	equ	$-$CF4D

	defs	20H		;stack
end_stack:

