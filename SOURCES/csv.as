;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
; C / assembler interface routines
; used by the HiTech Z80 C Compiler v3.09
;
	psect	text

	GLOBAL	csv,ncsv,indir,cret,_exit,_close

csv:   pop     hl      ;HL=ret addr
       push    iy      ;save IY
       push    ix      ;save IX
       ld      ix,0
       add     ix,sp   ;SP=IX points to : IX,IY, Routine ret addr, P1, P2, ..., Pn
indir: jp      (hl)    ;continue with code after CALL csv

cret:  ld      sp,ix   ;restore SP
       pop     ix
       pop     iy
_close:
_exit: ret

ncsv:  pop     hl      ;HL = ret addr
       push    iy      ;save IY
       push    ix      ;save IX
       ld      ix,0
       add     ix,sp   ;IX points to : saved regs, Routine ret addr, P1, P2, ..., Pn
       ld      e,(hl)
       inc     hl
       ld      d,(hl)  ;DE = -(Routine local vars buffer size)
       inc     hl      ;HL = pointer of code after DEFW
       ex      de,hl   ;HL = -(Routine local vars buffer size), DE = pointer of code after DEFW
       add     hl,sp
       ld      sp,hl   ;Move SP below the local vars buffer
       ex      de,hl
       jp      (hl)    ;continue with code after DEFW


