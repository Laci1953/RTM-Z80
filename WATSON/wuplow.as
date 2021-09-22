;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
*Include w.mac
;
        psect   text
;
        GLOBAL  SnapLoadCD
        GLOBAL  SnapLoadDM
COND	SIM=0
	GLOBAL	UpToLow100H
	GLOBAL	?UP_TO_LOW_6W,?UP_TO_LOW_4B
ENDC
;
        GLOBAL  CrtPage
COND    SIM
        GLOBAL  TypeString
        GLOBAL  TypeBC
ENDC
;
;       Move from UP RAM to Registers 6 words (12 bytes)
;
;       called under DISABLED interrupts
;       BC,DE,HL,BC',DE',HL' = to be loaded from UP RAM
;       IY = source addr in UP RAM
;       DE' affected
;
;UpToLow_6W:
;        UP_RAM
;        ld      c,(iy+0)
;        ld      b,(iy+1)
;        ld      e,(iy+2)
;        ld      d,(iy+3)
;        ld      l,(iy+4)
;        ld      h,(iy+5)
;        exx
;        ld      c,(iy+6)
;        ld      b,(iy+7)
;        ld      e,(iy+8)
;        ld      d,(iy+9)
;        ld      l,(iy+10)
;        ld      h,(iy+11)
;        exx
;        LOW_RAM
;        ret
;
;       Move from UP RAM to LOW RAM a 100H of memory
;
;       called under DISABLED interrupts
;       IY=Source, IX=Destination
;	returns IX=IX+100H,IY=IY+100H 
;
UpToLow100H:
	ld	a,21		;21 x 12 = 252, + 4 = 256 (100H)
loop21:				;move 252 bytes
	ex	af,af'
?UP_TO_LOW_6W:
        call	O_UP_TO_LOW_6W	;call    UpToLow_6W
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
;	UP_RAM
;        ld      c,(iy+0)
;        ld      b,(iy+1)
;        ld      e,(iy+2)
;        ld      d,(iy+3)
;	LOW_RAM

?UP_TO_LOW_4B:
	call	O_UP_TO_LOW_4B	

        ld      (ix+0),c
        ld      (ix+1),b
        ld      (ix+2),e
        ld      (ix+3),d
	ld	bc,4
	add	iy,bc
	add	ix,bc
	ret
;
;       Load Code and Data to LowerRAM from the snapshot image in UpperRAM
;
;       called under DISABLED interrupts
;       Loads from UpperRAM to LowerRAM a single 8KB page of code+data
;       (page0) from A000H - C000H UpperRam to A000H - C000H LowerRAM (8KB)
;       (page1) from C000H - E000H UpperRam to A000H - C000H LowerRAM (8KB)
;
;       BC=0000H for PAGE0
;       BC=2000H for PAGE1
;
;       IX,IY,DE,HL not affected
;
SnapLoadCD:
        push    de              ;save regs
        push    hl
        push    ix
        push    iy
        ld      (CrtPage),bc    ;save current page base addr
COND    SIM
        ld      hl,bufcrtp
        call    TypeString
        call    TypeBC
        pop     iy              ;restore regs
        pop     ix
        pop     hl
        pop     de
        ret
bufcrtp:defb    0DH,0AH
        defm    'Loading page:'
        defb    0
ENDC
        ld      iy,0A000H
        add     iy,bc		;code source in UpperRAM
        ld      ix,0A000H	;code destination in LowerRAM
        ld      a,20H		;8KB to be moved (20H x 100H)
loop20:	push	af
	call	UpToLow100H
	pop	af
	dec	a
	jr	nz,loop20
        pop     iy              ;restore regs
        pop     ix
        pop     hl
        pop     de
        ret
;
;       Load Dynamic Memory to LowerRAM from the snapshot image in UpperRAM
;
;       called under DISABLED interrupts
;       Loads from UpperRam to LowerRAM the Dynamic Memory area
;       from E000H - FE00H UpperRAM to C000H - DF00H LowerRAM
;       IX,IY,DE,HL,BC not affected
;
SnapLoadDM:
COND    SIM
        ret
ENDC
        push    bc              ;save regs
        push    de
        push    hl
        push    ix
        push    iy
        ld      iy,0E000H       ;dynamic memory source in UpperRAM
        ld      ix,0C000H       ;dynamic memory destination in LowerRAM
        ld      a,1FH           ;8KB-100H to be moved (1FH x 100H)
loopDM:	push	af
	call	UpToLow100H
	pop	af
	dec	a
	jr	nz,loopDM
        pop     iy              ;restore regs
        pop     ix
        pop     hl
        pop     de
        pop     bc
        ret
;
