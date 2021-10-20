;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;       Reads a .HEX file (with wrong checksums), compute the correct checksums,
;       and types the correct .HEX file on the console
;
MACRO   CharToNumber
        sub     '0'
        cp      10
        jr      c,8f
        sub     7
8:
ENDM

MACRO   ReadChar
        push    bc
        push    de
        push    hl
9:
        ld      c,6
        ld      e,0FFH
        call    5
        or      a
        jr      z,9b
        pop     hl
        pop     de
        pop     bc
ENDM

MACRO   TypeChar
        push    af
        push    bc
        push    de
        push    hl
        ld      c,2
        ld      e,a
        call    5
        pop     hl
        pop     de
        pop     bc
        pop     af
ENDM

MACRO   ToHex
        cp      0AH
        jr      c,7f
                        ;A to F
        add     a,'A'-0AH
        jr      6f
7:                      ;0 to 9
        add     a,'0'
6:
ENDM

        psect   text

        org     100h

        global  _main

_main:
        ld      sp,stack
        ld      d,0             ;D=EOF mark
loop:
        ld      c,0
        call    GetByte         ;get counter
        ld      b,a             ;save B=counter

        call    GetByte         ;skip addr
        call    GetByte

        call    GetByte         ;get type
        ld      d,a             ;save it in D (1 = EOF)

        ld      a,b             ;if zero bytes, skip reading
        or      a
        jr      z,2f
                                ;read bytes
1:      call    GetByte
        djnz    1b
2:                              ;skip cks
        ReadChar
        ReadChar
                                ;compute cks
        ld      hl,100H
        ld      b,0
        xor     a
        sbc     hl,bc           ;L=cks
                                ;type hi nibble in hex
        ld      a,l
        srl     a
        srl     a
        srl     a
        srl     a
        ToHex
        TypeChar
                                ;type low nibble in hex
        ld      a,l
        and     0FH
        ToHex
        TypeChar

        ld      a,d             ;EOF?
        or      a
        jp      z,loop
                                ;YES, quit
        ld      c,0
        jp      5
;
;       Get Byte
;
;       C=checksum
;       returns A, C=Checksum updated
;
GetByte:
        ReadChar

        cp      0DH
        jr      z,GetByte
        cp      0AH
        jr      z,GetByte
        cp      ':'
        jr      nz,1f
        ld      a,0dh
        TypeChar
        ld      a,0ah
        TypeChar
        ld      a,':'
        TypeChar
        jr      GetByte
1:
        TypeChar
                                ;hi nibble
        CharToNumber
        rlca
        rlca
        rlca
        rlca
        ld      e,a
        ReadChar
        TypeChar
                                ;low nibble
        CharToNumber
        or      e
        ld      e,a             ;save to E
        add     a,c             ;add to checksum
        ld      c,a             ;save checksum
        ld      a,e
        ret

        defs    20
stack:
