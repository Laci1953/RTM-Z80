;
;       Z80 disassembler
;
;       code core by Stephen C Cousins
;
        GLOBAL  DisWrI,kStrBuffer
;
        psect   text
;
; Common constants
kNull           EQU 0              ;Null character/byte (0x00)
kNewLine        EQU 5              ;New line character (0x05)
kBackspace      EQU 8              ;Backspace character (0x08)
kLinefeed       EQU 10             ;Line feed character (0x0A)
kReturn         EQU 13             ;Return character (0x0D)
kEscape         EQU 27             ;Escape character (0x1B)
kSpace          EQU 32             ;Space character (0x20)
kApostroph      EQU 39             ;Apostrophe character (0x27)
kComma          EQU 44             ;Comma character (0x2C)
kPeriod         EQU 46             ;Period character (0x2E)
kColon          EQU 58             ;Colon character (0x3A)
kSemicolon      EQU 59             ;Semicolon character (0x3B)
kDelete         EQU 127            ;Delete character (0x7F)
;
kDisSubsL       EQU 13  ;Last operand substitution string
kDisSubNN       EQU 4   ;Operand substitution string 'nn'
kDisSubC        EQU 10  ;Operand substitution string 'c'
kDisSubCC       EQU 11  ;Operand substitution string 'cc'
kDisBracHL      EQU 21  ;Bracketed HL
kDisHL          EQU 24  ;HL
kDisFlowF       EQU 27  ;First flow control instructions
kDisFlowL       EQU 34  ;Last flow control instructions
kDisJR          EQU 27  ;Operation string 'JR'
kDisDJNZ        EQU 28  ;Operation string 'DJNZ'
kDisRST         EQU 29  ;Operation string 'RST'
kDisJP          EQU 30  ;Operation string 'JP'
kDisCALL        EQU 31  ;Operation string 'CALL'
kDisRET         EQU 32  ;Operation string 'RET'
kDisOpMask      EQU 3FH ;Operand 1 mask to exclude pre-code bits
kDisMskC        EQU 18H ;Condition bit mask for Operand 1 = C
kDisMskCC       EQU 38H ;Condition bit mask for Operand 1 = CC
kDisMskRST      EQU 38H ;Restart address bits

kStrBuffer: DEFS        50H   ;String buffer
kStrSize   EQU 50H            ;Size of string buffer
;
iStrStart:  DEFW  0         ;Start of current string buffer
iStrSize:   DEFB  0           ;Size of current string buffer (0 to Len-1)
;
iRegisters:
; Order is hard coded so do not change (see strings above)
iPC:        DEFW  0001         ;Register pair PC (Program Counter)
iAF:        DEFW  0002         ;Register pair AF
iBC:        DEFW  0003         ;Register pair BC
iDE:        DEFW  0004         ;Register pair DE
iHL:        DEFW  0005         ;Register pair HL
iIX:        DEFW  0006         ;Register pair IX
iIY:        DEFW  0007         ;Register pair IY

iRegister2:
; Order is hard coded so do not change (see strings above)
iSP:        DEFW  0011H         ;Register pair SP (Stack Pointer)
iAF2:       DEFW  0012H         ;Register pair AF'
iBC2:       DEFW  0013H         ;Register pair BC'
iDE2:       DEFW  0014H         ;Register pair DE'
iHL2:       DEFW  0015H         ;Register pair HL'
iCSP:       DEFW  0016H         ;Register pair (SP)
iIR:        DEFW  0017H         ;Register pair IR
;
DisString:
        DEFB  80H               ;String 01H =
        DEFB  80H+'n'           ;String 02h = n
        DEFB  80H+'('
        DEFM 'n)'               ;String 03H = (n)
        DEFB  80H+'n'
        DEFM 'n'                ;String 04H = nn
        DEFB  80H+'('
        DEFM 'nn)'              ;String 05H = (nn)
        DEFB  80H+'r'           ;String 06H = r
        DEFB  80H+'r'
        DEFM '2'                ;String 07H = r2
        DEFB  80H+'d'
        DEFM 'd'                ;String 08H = dd
        DEFB  80H+'q'
        DEFM 'q'                ;String 09H = qq
        DEFB  80H+'c'           ;String 0AH = c
        DEFB  80H+'c'
        DEFM 'c'                ;String 0BH = cc
        DEFB  80H+'t'           ;String 0x0C = t
        DEFB  80H+'b'           ;String 0x0D = b
        DEFB  80H+'B'
        DEFM 'CDEHL-A'          ;String 0x0E = BCDEHL-A
        DEFB  80H+'B'
        DEFM 'CDE**SP'          ;String 0x0F = BCDE**SP
        DEFB  80H+'B'
        DEFM 'CDE**AF'          ;String 0x10 = BCDE**AF
        DEFB  80H+'N'
        DEFM 'ZZ.NCC.'          ;String 0x11 = NZZ.NCC.
        DEFB  80H+'N'
        DEFM 'ZZ.NCC.POPEP.M.'  ;String 0x12 = NZZ.NCC.POPEP.M.
        DEFB  80H+'0'
        DEFM '008101820283038'  ;String 0x13 = 0008101820283038
        DEFB  80H+'0'
        DEFM '1234567'          ;String 0x14 = 01234567
        DEFB  80H+'('
        DEFM 'HL)'              ;String 0x15 = (HL)
        DEFB  80H+'('
        DEFM 'IX+'              ;String 0x16 = (IX+
        DEFB  80H+'('
        DEFM 'IY+'              ;String 0x17 = (IY+
        DEFB  80H+'H'
        DEFM 'L'                ;String 0x18 = HL
        DEFB  80H+'I'
        DEFM 'X'                ;String 0x19 = IX
        DEFB  80H+'I'
        DEFM 'Y'                ;String 0x1A = IY
        DEFB  80H+'J'
        DEFM 'R'                ;String 0x1B = JR
        DEFB  80H+'D'
        DEFM 'JNZ'              ;String 0x1C = DJNZ
        DEFB  80H+'R'
        DEFM 'ST'               ;String 0x1D = RST
        DEFB  80H+'J'
        DEFM 'P'                ;String 0x1E = JP
        DEFB  80H+'C'
        DEFM 'ALL'              ;String 0x1F = CALL
        DEFB  80H+'R'
        DEFM 'ET'               ;String 0x20 = RET
        DEFB  80H+'R'
        DEFM 'ETI'              ;String 0x21 = RETI
        DEFB  80H+'R'
        DEFM 'ETN'              ;String 0x22 = RETN
        DEFB  80H+'A'           ;String 0x23 = A
        DEFB  80H+'('
        DEFM 'SP)'              ;String 0x24 = (SP)
        DEFB  80H+'A'
        DEFM 'F'                ;String 0x25 = AF
        DEFB  80H+'D'
        DEFM 'E'                ;String 0x26 = DE
        DEFB  80H+'0'           ;String 0x27 = 0
        DEFB  80H+'1'           ;String 0x28 = 1
        DEFB  80H+'2'           ;String 0x29 = 2
        DEFB  80H+'('
        DEFM 'BC)'              ;String 0x2A = (BC)
        DEFB  80H+'('
        DEFM 'DE)'              ;String 0x2B = (DE)
        DEFB  80H+'S'
        DEFM 'P'                ;String 0x2C = SP
        DEFB  80H+'I'           ;String 0x2D = I
        DEFB  80H+'R'           ;String 0x2E = R
        DEFB  80H+'('
        DEFM 'C)'               ;String 0x2F = (C)
        DEFB  80H+'A'
        DEFM 'F'
        DEFB  27H               ;String 0x30 = AF'
        DEFB  80H+'A'
        DEFM 'DC'               ;String 0x31 = ADC
        DEFB  80H+'A'
        DEFM 'DD'               ;String 0x32 = ADD
        DEFB  80H+'A'
        DEFM 'ND'               ;String 0x33 = AND
        DEFB  80H+'B'
        DEFM 'IT'               ;String 0x34 = BIT
        DEFB  80H+'C'
        DEFM 'CF'               ;String 0x35 = CCF
        DEFB  80H+'C'
        DEFM 'P'                ;String 0x36 = CP
        DEFB  80H+'C'
        DEFM 'PD'               ;String 0x37 = CPD
        DEFB  80H+'C'
        DEFM 'PDR'              ;String 0x38 = CPDR
        DEFB  80H+'C'
        DEFM 'PI'               ;String 0x39 = CPI
        DEFB  80H+'C'
        DEFM 'PIR'              ;String 0x3A = CPIR
        DEFB  80H+'C'
        DEFM 'PL'               ;String 0x3B = CPL
        DEFB  80H+'D'
        DEFM 'AA'               ;String 0x3C = DAA
        DEFB  80H+'D'
        DEFM 'EC'               ;String 0x3D = DEC
        DEFB  80H+'D'
        DEFM 'I'                ;String 0x3E = DI
        DEFB  80H+'E'
        DEFM 'I'                ;String 0x3F = EI
        DEFB  80H+'E'
        DEFM 'X'                ;String 0x40 = EX
        DEFB  80H+'E'
        DEFM 'XX'               ;String 0x41 = EXX
        DEFB  80H+'H'
        DEFM 'ALT'              ;String 0x42 = HALT
        DEFB  80H+'I'
        DEFM 'M'                ;String 0x43 = IM
        DEFB  80H+'I'
        DEFM 'N'                ;String 0x44 = IN
        DEFB  80H+'I'
        DEFM 'NC'               ;String 0x45 = INC
        DEFB  80H+'I'
        DEFM 'ND'               ;String 0x46 = IND
        DEFB  80H+'I'
        DEFM 'NDR'              ;String 0x47 = INDR
        DEFB  80H+'I'
        DEFM 'NI'               ;String 0x48 = INI
        DEFB  80H+'I'
        DEFM 'NIR'              ;String 0x49 = INIR
        DEFB  80H+'L'
        DEFM 'D'                ;String 0x4A = LD
        DEFB  80H+'L'
        DEFM 'DD'               ;String 0x4B = LDD
        DEFB  80H+'L'
        DEFM 'DDR'              ;String 0x4C = LDDR
        DEFB  80H+'L'
        DEFM 'DI'               ;String 0x4D = LDI
        DEFB  80H+'L'
        DEFM 'DIR'              ;String 0x4E = LDIR
        DEFB  80H+'N'
        DEFM 'EG'               ;String 0x4F = NEG
        DEFB  80H+'N'
        DEFM 'OP'               ;String 0x50 = NOP
        DEFB  80H+'O'
        DEFM 'R'                ;String 0x51 = OR
        DEFB  80H+'O'
        DEFM 'TDR'              ;String 0x52 = OTDR
        DEFB  80H+'O'
        DEFM 'TIR'              ;String 0x53 = OTIR
        DEFB  80H+'O'
        DEFM 'UT'               ;String 0x54 = OUT
        DEFB  80H+'O'
        DEFM 'UTD'              ;String 0x55 = OUTD
        DEFB  80H+'O'
        DEFM 'UTI'              ;String 0x56 = OUTI
        DEFB  80H+'P'
        DEFM 'OP'               ;String 0x57 = POP
        DEFB  80H+'P'
        DEFM 'USH'              ;String 0x58 = PUSH
        DEFB  80H+'R'
        DEFM 'ES'               ;String 0x59 = RES
        DEFB  80H+'R'
        DEFM 'L'                ;String 0x5A = RL
        DEFB  80H+'R'
        DEFM 'LA'               ;String 0x5B = RLA
        DEFB  80H+'R'
        DEFM 'LC'               ;String 0x5C = RLC
        DEFB  80H+'R'
        DEFM 'LCA'              ;String 0x5D = RLCA
        DEFB  80H+'R'
        DEFM 'LD'               ;String 0x5E = RLD
        DEFB  80H+'R'
        DEFM 'R'                ;String 0x5F = RR
        DEFB  80H+'R'
        DEFM 'RA'               ;String 0x60 = RRA
        DEFB  80H+'R'
        DEFM 'RC'               ;String 0x61 = RRC
        DEFB  80H+'R'
        DEFM 'RCA'              ;String 0x62 = RRCA
        DEFB  80H+'R'
        DEFM 'RD'               ;String 0x63 = RRD
        DEFB  80H+'S'
        DEFM 'BC'               ;String 0x64 = SBC
        DEFB  80H+'S'
        DEFM 'CF'               ;String 0x65 = SCF
        DEFB  80H+'S'
        DEFM 'ET'               ;String 0x66 = SET
        DEFB  80H+'S'
        DEFM 'LA'               ;String 0x67 = SLA
        DEFB  80H+'S'
        DEFM 'LL'               ;String 0x68 = SLL
        DEFB  80H+'S'
        DEFM 'RA'               ;String 0x69 = SRA
        DEFB  80H+'S'
        DEFM 'RL'               ;String 0x6A = SRL
        DEFB  80H+'S'
        DEFM 'UB'               ;String 0x6B = SUB
        DEFB  80H+'X'
        DEFM 'OR'               ;String 0x6C = XOR
        DEFB  80H+'?'
        DEFM '???'              ;String 0x6D = ????
        DEFB  80H

DisInst:
        DEFB 88H,0F8H,31H,23H,07H       ;Opcode: 0x88 - ADC  A   ,r2
        DEFB 0CEH,0FFH,31H,23H,02H      ;Opcode: 0xCE - ADC  A   ,n
        DEFB 4AH,0CFH,31H,0D8H,08H      ;Opcode: 0x4A - ADC  HL  ,dd
        DEFB 80H,0F8H,32H,23H,07H       ;Opcode: 0x80 - ADD  A   ,r2
        DEFB 0C6H,0FFH,32H,23H,02H      ;Opcode: 0xC6 - ADD  A   ,n
        DEFB 09H,0CFH,32H,18H,08H       ;Opcode: 0x09 - ADD  HL  ,dd
        DEFB 0A0H,0F8H,33H,07H,01H      ;Opcode: 0xA0 - AND  r2  ,
        DEFB 0E6H,0FFH,33H,02H,01H      ;Opcode: 0xE6 - AND  n   ,
        DEFB 40H,0C0H,34H,8DH,07H       ;Opcode: 0x40 - BIT  b   ,r2
        DEFB 0C4H,0C7H,1FH,0BH,04H      ;Opcode: 0xC4 - CALL cc  ,nn
        DEFB 0CDH,0FFH,1FH,04H,01H      ;Opcode: 0xCD - CALL nn  ,
        DEFB 3FH,0FFH,35H,01H,01H       ;Opcode: 0x3F - CCF      ,
        DEFB 0B8H,0F8H,36H,07H,01H      ;Opcode: 0xB8 - CP   r2  ,
        DEFB 0FEH,0FFH,36H,02H,01H      ;Opcode: 0xFE - CP   n   ,
        DEFB 0A9H,0FFH,37H,0C1H,01H     ;Opcode: 0xA9 - CPD      ,
        DEFB 0B9H,0FFH,38H,0C1H,01H     ;Opcode: 0xB9 - CPDR     ,
        DEFB 0A1H,0FFH,39H,0C1H,01H     ;Opcode: 0xA1 - CPI      ,
        DEFB 0B1H,0FFH,3AH,0C1H,01H     ;Opcode: 0xB1 - CPIR     ,
        DEFB 2FH,0FFH,3BH,01H,01H       ;Opcode: 0x2F - CPL      ,
        DEFB 27H,0FFH,3CH,01H,01H       ;Opcode: 0x27 - DAA      ,
        DEFB 0BH,0CFH,3DH,08H,01H       ;Opcode: 0x0B - DEC  dd  ,
        DEFB 05H,0C7H,3DH,06H,01H       ;Opcode: 0x05 - DEC  r   ,
        DEFB 0F3H,0FFH,3EH,01H,01H      ;Opcode: 0xF3 - DI       ,
        DEFB 10H,0FFH,1CH,02H,01H       ;Opcode: 0x10 - DJNZ n   ,
        DEFB 0FBH,0FFH,3FH,01H,01H      ;Opcode: 0xFB - EI       ,
        DEFB 0E3H,0FFH,40H,24H,18H      ;Opcode: 0xE3 - EX   (SP),HL
        DEFB 08H,0FFH,40H,25H,30H       ;Opcode: 0x08 - EX   AF  ,0AF'
        DEFB 0EBH,0FFH,40H,26H,18H      ;Opcode: 0xEB - EX   DE  ,HL
        DEFB 0D9H,0FFH,41H,01H,01H      ;Opcode: 0xD9 - EXX      ,
        DEFB 76H,0FFH,42H,01H,01H       ;Opcode: 0x76 - HALT     ,
        DEFB 46H,0FFH,43H,0E7H,01H      ;Opcode: 0x46 - IM   0   ,
        DEFB 56H,0FFH,43H,0E8H,01H      ;Opcode: 0x56 - IM   1   ,
        DEFB 5EH,0FFH,43H,0E9H,01H      ;Opcode: 0x5E - IM   2   ,
        DEFB 40H,0C7H,44H,0C6H,2FH      ;Opcode: 0x40 - IN   r   ,(C)
        DEFB 0DBH,0FFH,44H,23H,03H      ;Opcode: 0xDB - IN   A   ,(n)
        DEFB 03H,0CFH,45H,08H,01H       ;Opcode: 0x03 - INC  dd  ,
        DEFB 04H,0C7H,45H,06H,01H       ;Opcode: 0x04 - INC  r   ,
        DEFB 0AAH,0FFH,46H,0C1H,01H     ;Opcode: 0xAA - IND      ,
        DEFB 0BAH,0FFH,47H,0C1H,01H     ;Opcode: 0xBA - INDR     ,
        DEFB 0A2H,0FFH,48H,0C1H,01H     ;Opcode: 0xA2 - INI      ,
        DEFB 0B2H,0FFH,49H,0C1H,01H     ;Opcode: 0xB2 - INIR     ,
        DEFB 0E9H,0FFH,1EH,15H,01H      ;Opcode: 0xE9 - JP   (HL),
        DEFB 0C2H,0C7H,1EH,0BH,04H      ;Opcode: 0xC2 - JP   cc  ,nn
        DEFB 0C3H,0FFH,1EH,04H,01H      ;Opcode: 0xC3 - JP   nn  ,
        DEFB 20H,0E7H,1BH,0AH,02H       ;Opcode: 0x20 - JR   c   ,n
        DEFB 18H,0FFH,1BH,02H,01H       ;Opcode: 0x18 - JR   n   ,
        DEFB 40H,0C0H,4AH,06H,07H       ;Opcode: 0x40 - LD   r   ,r2
        DEFB 02H,0FFH,4AH,2AH,23H       ;Opcode: 0x02 - LD   (BC),0A
        DEFB 12H,0FFH,4AH,2BH,23H       ;Opcode: 0x12 - LD   (DE),0A
        DEFB 32H,0FFH,4AH,05H,23H       ;Opcode: 0x32 - LD   (nn),0A
        DEFB 22H,0FFH,4AH,05H,18H       ;Opcode: 0x22 - LD   (nn),HL
        DEFB 43H,0CFH,4AH,0C5H,08H      ;Opcode: 0x43 - LD   (nn),dd
        DEFB 0AH,0FFH,4AH,23H,2AH       ;Opcode: 0x0A - LD   A   ,(BC)
        DEFB 1AH,0FFH,4AH,23H,2BH       ;Opcode: 0x1A - LD   A   ,(DE)
        DEFB 3AH,0FFH,4AH,23H,05H       ;Opcode: 0x3A - LD   A   ,(nn)
        DEFB 2AH,0FFH,4AH,18H,05H       ;Opcode: 0x2A - LD   HL  ,(nn)
        DEFB 0F9H,0FFH,4AH,2CH,18H      ;Opcode: 0xF9 - LD   SP  ,HL
        DEFB 01H,0CFH,4AH,08H,04H       ;Opcode: 0x01 - LD   dd  ,nn
        DEFB 4BH,0CFH,4AH,0C8H,05H      ;Opcode: 0x4B - LD   dd  ,(nn)
        DEFB 57H,0FFH,4AH,0E3H,2DH      ;Opcode: 0x57 - LD   A   ,I
        DEFB 5FH,0FFH,4AH,0E3H,2EH      ;Opcode: 0x5F - LD   A   ,R
        DEFB 47H,0FFH,4AH,0EDH,23H      ;Opcode: 0x47 - LD   I   ,0A
        DEFB 4FH,0FFH,4AH,0EEH,23H      ;Opcode: 0x4F - LD   R   ,0A
        DEFB 06H,0C7H,4AH,06H,02H       ;Opcode: 0x06 - LD   r   ,n
        DEFB 0A8H,0FFH,4BH,0C1H,01H     ;Opcode: 0xA8 - LDD      ,
        DEFB 0B8H,0FFH,4CH,0C1H,01H     ;Opcode: 0xB8 - LDDR     ,
        DEFB 0A0H,0FFH,4DH,0C1H,01H     ;Opcode: 0xA0 - LDI      ,
        DEFB 0B0H,0FFH,4EH,0C1H,01H     ;Opcode: 0xB0 - LDIR     ,
        DEFB 44H,0FFH,4FH,0C1H,01H      ;Opcode: 0x44 - NEG      ,
        DEFB 00H,0FFH,50H,01H,01H       ;Opcode: 0x00 - NOP      ,
        DEFB 0B0H,0F8H,51H,07H,01H      ;Opcode: 0xB0 - OR   r2  ,
        DEFB 0F6H,0FFH,51H,02H,01H      ;Opcode: 0xF6 - OR   n   ,
        DEFB 0BBH,0FFH,52H,0C1H,01H     ;Opcode: 0xBB - OTDR     ,
        DEFB 0B3H,0FFH,53H,0C1H,01H     ;Opcode: 0xB3 - OTIR     ,
        DEFB 41H,0C7H,54H,0EFH,06H      ;Opcode: 0x41 - OUT  (C) ,r
        DEFB 0D3H,0FFH,54H,03H,23H      ;Opcode: 0xD3 - OUT  (n) ,0A
        DEFB 0ABH,0FFH,55H,0C1H,01H     ;Opcode: 0xAB - OUTD     ,
        DEFB 0A3H,0FFH,56H,0C1H,01H     ;Opcode: 0xA3 - OUTI     ,
        DEFB 0C1H,0CFH,57H,09H,01H      ;Opcode: 0xC1 - POP  qq  ,
        DEFB 0C5H,0CFH,58H,09H,01H      ;Opcode: 0xC5 - PUSH qq  ,
        DEFB 80H,0C0H,59H,8DH,07H       ;Opcode: 0x80 - RES  b   ,r2
        DEFB 0C9H,0FFH,20H,01H,01H      ;Opcode: 0xC9 - RET      ,
        DEFB 0C0H,0C7H,20H,0BH,01H      ;Opcode: 0xC0 - RET  cc  ,
        DEFB 4DH,0FFH,21H,0C1H,01H      ;Opcode: 0x4D - RETI     ,
        DEFB 45H,0FFH,22H,0C1H,01H      ;Opcode: 0x45 - RETN     ,
        DEFB 10H,0F8H,5AH,87H,01H       ;Opcode: 0x10 - RL   r2  ,
        DEFB 17H,0FFH,5BH,01H,01H       ;Opcode: 0x17 - RLA      ,
        DEFB 00H,0F8H,5CH,87H,01H       ;Opcode: 0x00 - RLC  r2  ,
        DEFB 07H,0FFH,5DH,01H,01H       ;Opcode: 0x07 - RLCA     ,
        DEFB 6FH,0FFH,5EH,0C1H,01H      ;Opcode: 0x6F - RLD      ,
        DEFB 18H,0F8H,5FH,87H,01H       ;Opcode: 0x18 - RR   r2  ,
        DEFB 1FH,0FFH,60H,01H,01H       ;Opcode: 0x1F - RRA      ,
        DEFB 08H,0F8H,61H,87H,01H       ;Opcode: 0x08 - RRC  r2  ,
        DEFB 0FH,0FFH,62H,01H,01H       ;Opcode: 0x0F - RRCA     ,
        DEFB 67H,0FFH,63H,0C1H,01H      ;Opcode: 0x67 - RRD      ,
        DEFB 0C7H,0C7H,1DH,0CH,01H      ;Opcode: 0xC7 - RST  t   ,
        DEFB 98H,0F8H,64H,23H,07H       ;Opcode: 0x98 - SBC  A   ,r2
        DEFB 0DEH,0FFH,64H,23H,02H      ;Opcode: 0xDE - SBC  A   ,n
        DEFB 42H,0CFH,64H,0D8H,08H      ;Opcode: 0x42 - SBC  HL  ,dd
        DEFB 37H,0FFH,65H,01H,01H       ;Opcode: 0x37 - SCF      ,
        DEFB 0C0H,0C0H,66H,8DH,07H      ;Opcode: 0xC0 - SET  b   ,r2
        DEFB 20H,0F8H,67H,87H,01H       ;Opcode: 0x20 - SLA  r2  ,
        DEFB 30H,0F8H,68H,87H,01H       ;Opcode: 0x30 - SLL  r2  ,
        DEFB 28H,0F8H,69H,87H,01H       ;Opcode: 0x28 - SRA  r2  ,
        DEFB 38H,0F8H,6AH,87H,01H       ;Opcode: 0x38 - SRL  r2  ,
        DEFB 90H,0F8H,6BH,07H,01H       ;Opcode: 0x90 - SUB  r2  ,
        DEFB 0D6H,0FFH,6BH,02H,01H      ;Opcode: 0xD6 - SUB  n   ,
        DEFB 0A8H,0F8H,6CH,07H,01H      ;Opcode: 0xA8 - XOR  r2  ,
        DEFB 0EEH,0FFH,6CH,02H,01H      ;Opcode: 0xEE - XOR  n   ,
        DEFB 00H,00H,6DH,01H,01H        ;Opcode: 0x00 - ????     ,
        DEFB 00H,00H,6DH,0C1H,01H       ;Opcode: 0x00 - ????     ,
;
*Include wdisu.as
;
; **********************************************************************
; **  Disassembler support                      by Stephen C Cousins  **
; **********************************************************************

; This module provides instruction disassembly support. There are two
; main public functions which disassemble an instruction and provide the
; result as a string in the current string buffer. These are:
;
; Function: DisWrInstruction
; This returns a string in the format: Address: Opcodes  Mnemonic
; eg.   0300: CD FB 01       CALL 01FB
; It also returns the length of the instruction in bytes and the
; address of the next instruction.
;
; Function: DisWrMnemonic
; This returns a string in the format: Mnemonic only
; eg.   CALL 01FB
; It also returns the length of the instruction in bytes.
;
; This module also provides the public helper function:
;
; Function: DisGetNextAddress
; Returns address of next instruction to be executed. This is used by
; the single stepping feature. It takes into account flags to determine
; outcome of conditional instructions.
;
; Further documentation and notes are at the end of this file.
;
; Public functions provided
;   DisWrInstruction      Returns string if full details
;   DisWrMnemonic         Returns string of mnemonic only
;   DisGetNextAddress     Returns address of next instruction
; Private support function (not intended to be called from outside)
;   DisWrOperand          Process suppied operand
;   DisGetOpcode          Get instruction opcode
;   DisWrChar             Write a character to the buffer with filters
;   DisWrString           Write a string to the buffer with filters


; **********************************************************************
; **  Constants                                                       **
; **********************************************************************

kDisBrack  EQU 5              ;Bracket flag
kDisImmed  EQU 4              ;Immediate value flag
kDisWord   EQU 3              ;Immediate value is word (not byte) flag
kDisLength EQU 2              ;Substite two characters (not one) flag
kDisMask   EQU 03H            ;Mask type 0=007,1=018,2=030,3=038
; Should create EQUates for all numeric values used below. It's the law!


; **********************************************************************
; **  Public functions                                                **
; **********************************************************************


; Disassembler: Write full disassembly to string buffer
;   On entry: HL = Start of instruction to be disassembled
;   On exit:  Address, opcodes and mnemonic in current string buffer
;             iDisIndex variable used
;             A = Length of instruction in bytes
;             HL = Start address of next instruction
;             BC DE IX IY I AF' BC' DE' HL' preserved
DisWrI:
            PUSH BC
            PUSH DE
        call    ClearBuffer
            LD   A,20           ;Select string for mnemonic...
            LD   DE,kStrBuffer+30H
            CALL StrInitialise  ;Initialise string for mnemonic
            CALL DisWrMnemonic  ;Disassemble to mnemonic string
            LD   C,A            ;Store length of instruction in bytes
;           XOR  A              ;CLear A to zero
            CALL StrInitDefault ;Select default string for opcodes
            LD   D,H            ;Get start of instruction..
            LD   E,L
            CALL StrWrAddress   ;Write address, colon and space
            LD   B,C            ;Get length of instruction
_Opcode:    LD   A,(HL)         ;Get instruction opcode
            CALL StrWrHexByte   ;Write as hex byte
            CALL StrWrSpace     ;Write space
            INC  HL             ;Point to next byte
            DJNZ _Opcode        ;Loop until all hex bytes written
            LD   A,19           ;Column number
            CALL StrWrPadding   ;Pad with spaces to specified column
            LD   B,C            ;Get length of instruction
_Ascii:     LD   A,(DE)         ;Get instruction opcode
            CALL StrWrAsciiChar ;Write as ASCII character
            INC  DE             ;Point to next byte
            DJNZ _Ascii         ;Loop until all characters written
            LD   A,25           ;Column number
            CALL StrWrPadding   ;Pad with spaces to specified column
_Mnemonic:  LD   DE,kStrBuffer+30H
            CALL StrAppend      ;Append disassembly string
;           CALL StrWrNewLine   ;Write new line to string buffer
            LD   A,C            ;Get length of instruction in bytes
            POP  DE
            POP  BC
            RET


; Disassembler: Write mnemonic only to string buffer
;   On entry: HL = Start of instruction to be disassembled
;   On exit:  Mnemonic is written to current string buffer
;             iDisIndex variable used
;             A = Length of instruction in bytes
;             BC DE HL IX IY I AF' BC' DE' HL' preserved
DisWrMnemonic:
            PUSH BC
            PUSH DE
            PUSH HL
            PUSH IX
            PUSH IY
; Prepare to disassemble
; HL = Address of current instruction
            PUSH HL             ;Copy start address of instruction
            POP  IY             ;  to IY
            LD   IX,DisInst     ;Start of instruction table
            XOR  A
            LD   (iDisIndex),A  ;Clear index instruction opcode
            LD   E,A            ;Clear prefix for extended instructions
            LD   D,(HL)         ;Instruction's primary opcode
            LD   B,A            ;Offset to instruction's primary opcode
; Check for index register instruction (IX or IY)
            LD   A,D            ;Could have been written LD A,(IY+0)
            CP   0DDH           ;IX instruction?
            JR   Z,_Index       ;Yes, so skip
            CP   0FDH           ;IY instruction?
            JR   NZ,_NotIndex   ;No, so skip
_Index:     LD   (iDisIndex),A  ;Store index instruction opcode
            INC  B              ;Increment offset to primary opcode
            LD   A,(IY+1)       ;Get next opcode byte
_NotIndex:
; Check for extended instruction
            CP   0CBH          ;Extended instruction?
            JR   Z,_Extend      ;Yes, so skip
            CP   0EDH           ;Extended instruction?
            JR   NZ,_NotExtend  ;No, so skip
_Extend:    LD   E,A            ;Store prefix for extended instructions
            INC  B              ;Increment offset to primary opcode
            LD   A,(iDisIndex)  ;Get index instruction opcode
            OR   A              ;Is this an index instruction?
            LD   A,B            ;Prepare to read primary opcode
            JR   Z,_ExNoIndx    ;No, so skip
            INC  A              ;Yes, skip index displacement byte
_ExNoIndx:  CALL DisGetOpcode   ;Get primary opcode
_NotExtend: LD   D,A            ;Remember instruction's primary opcode
            LD   (iDisOpcode),A ;Store primary opcode
; Locate instruction table entry for current instruction (pointer to by HL)
; BASIC: (i And iMask(n)) = (iValue(n) And iMask(n)) ?
_Table:     LD   A,(IX+0)       ;Get opcode value from table
            AND  (IX+1)         ;AND with opcode mask from table
            LD   C,A            ;Store Value AND Mask
            LD   A,(IX+1)       ;Get opcode mask from table
            AND  D              ;AND with instruction being disassembled
            CP   C              ;Is this the correct table entry?
            JR   NZ,_NotFound   ;No, so this is not the correct table
; BASIC: ... AND (p = iPrecode(n)) ?
            XOR  A              ;Default precode for comparison = 000
            BIT  7,(IX+3)       ;Precode (index or extended)?
            JR   Z,_GotPrCode   ;No, so skip
            LD   A,0CBH         ;Default precode for comparison = 0CB
            BIT  6,(IX+3)       ;Precode = 0ED?
            JR   Z,_GotPrCode   ;No, so skip
            LD   A,0EDH         ;Yes, so precode for comparison = 0ED
_GotPrCode: CP   E              ;Compare table precode with instruction
            JR   Z,_Found       ;Yes, so this is the correct table
_NotFound:  PUSH BC             ;Preserve BC
            LD   BC,5           ;No, so try next table entry
            ADD  IX,BC          ;Point to next table entry
            POP  BC             ;Restore BC
            JR   _Table
; We now have the correct instruction table entry (pointer to by IX)
; BASIC: (p = iPrecode(n)) And (i And iMask(n)) = (iValue(n) And iMask(n))
_Found:     LD   A,(IX+2)       ;Get operation string number
            LD   (iDisOpStr),A  ;Store operation string number
            CALL DisWrString    ;Write operation string
            CALL StrWrSpace
; BASIC: Operand sString(iOperand1(n)), t
            LD   A,(IX+3)       ;Get operand #1 string number
            LD   (iDisOp1Str),A ;Store opcode #1 string number
            LD   C,D            ;Get primary opcode value
            CALL DisWrOperand
; BASIC: Operand sString(iOperand2(n)), t
            LD   A,(IX+4)       ;Get operand #2 string number
            DEC  A              ;Is is 1? (null string)
            JR   Z,_NoOp2       ;Yes, so skip this operand
            LD   A,','          ;Get comma character
            CALL StrWrChar      ;Write comma to string
            LD   A,(IX+4)       ;Get operand #2 string number
            LD   C,D            ;Get primary opcode value
            CALL DisWrOperand
_NoOp2:
; If relative jump show absolute address in brackets
            LD   A,(iDisOpStr)  ;Get operation string number
            CP   kDisJR         ;JR instruction?
            JR   Z,_Rel         ;Yes, so skip
            CP   kDisDJNZ       ;DJNZ instruction?
            JR   NZ,_NotRel     ;No so skip
_Rel:       LD   DE,szDisTo     ;String = "  (to "
            CALL StrAppendZ     ;Append zero terminated string
            PUSH IY             ;Push address of instruction
            POP  HL             ;POP address of instruction
            INC  HL             ;Increment to
            INC  HL             ;  end of the JR/DJNZ instruction
            LD   A,(iDisImmed)  ;Get immediate value from instruction
            LD   E,A            ;Get displacement lo (signed byte)
            LD   D,0            ;Default to hi byte = zero
            BIT  7,A            ;Displacement negative?
            JR   Z,_JRadd       ;No, so skip
            DEC  D              ;Yes, so set hi byte to 0FF
_JRadd:     ADD  HL,DE          ;Add signed 16-bit displacement
            LD   D,H            ;Get destination address hi byte
            LD   E,L            ;Get destination address lo byte
;           CALL WrHexPrefix    ;Write hex prefix to string
            CALL StrWrHexWord   ;Write hex word to string
            LD   A,')'          ;Get close bracket character
            CALL StrWrChar      ;Write close bracket to string
_NotRel:
; Finish building mnemonic string
            LD   A,B            ;Get offset into instruction
            INC  A              ;Increment to give instruction length
            POP  IY
            POP  IX
            POP  HL
            POP  DE
            POP  BC
            RET



; **********************************************************************
; **  Private functions                                               **
; **********************************************************************


; Disassembler: Write operand to buffer
;   On entry: A = Operand string number
;             B = Offset to opcode from start of instruction
;             C = Primary op-code
;             IY = Start address of instruction
;   On exit:  A = Unspecified
;             B = Updated offset to opcode from start of instruction
;             C = Not specified
;             DE HL IX IY I AF' BC' DE' HL' preserved
DisWrOperand:
            AND  kDisOpMask     ;Mask off flag bits
            CP   kDisSubsL+1    ;Substitution operand string?
            JP   NC,DisWrString ;No, so just write string
_DisSubStr: PUSH DE
            PUSH HL
; Calculate operand table location for this operand and get details
            LD   HL,DisOperandTable-2
            ADD  A,A            ;Two bytes per entry
            ADD  A,L            ;Add to start of table
            LD   L,A            ;Store updated lo byte
            JR   NC,_NoOverFlo  ;Skip if no overflow
            INC  H              ;Overflow so increment hi byte
_NoOverFlo: LD   E,(HL)         ;Get substitution string number
            INC  HL             ;Point to BIILMM bits
            LD   D,(HL)         ;Get BIILMM function bits
            PUSH DE             ;So we can use E for scratch reg
; Process this operand as detailed in DE, left bracket?
            BIT  kDisBrack,D    ;Bracket flagged?
            JR   Z,_NoBracL     ;No, so skip
            LD   A,'('          ;Get left bracket character
            CALL StrWrChar      ;Print left bracket
_NoBracL:
; Process this operand as detailed in DE, immediate value?
            BIT  kDisImmed,D    ;Immediate value flagged?
            JR   Z,_NoImmedia   ;No, so skip
;           CALL WrHexPrefix    ;Print "0" (or whatever we use)
            INC  B              ;Increment offset to lo byte
            LD   A,B            ;Offset to instruction byte
            CALL DisGetOpcode   ;Get lo byte of immediate value
            LD   (iDisImmed),A  ;Store lo byte of immediate value
            LD   E,A            ;Store lo byte of immediate value
            BIT  kDisWord,D     ;Immediate value is a word?
            JR   Z,_ImmedLo     ;No, so skip
            INC  B              ;Increment offset to hi byte
            LD   A,B            ;Offset to instruction byte
            CALL DisGetOpcode   ;Get hi byte of immediate value
            LD   (iDisImmed+1),A  ;Store hi byte of immediate value
            CALL StrWrHexByte   ;Print hi byte of immediate value
_ImmedLo:   LD   A,E            ;Restore lo byte of immediate value
            CALL StrWrHexByte   ;Print lo byte of immediate value
_NoImmedia:
; Process this operand as detailed in DE, right bracket?
            BIT  kDisBrack,D    ;Bracket flagged?
            JR   Z,_NoBracR     ;No, so skip
            LD   A,')'          ;Get right bracket character
            CALL StrWrChar      ;Print right bracket
_NoBracR:
; Process this operand as detailed in DE, substitution string?
            POP  DE             ;Restore details
            LD   A,E            ;Get substitution string number
            OR   A              ;String specified?
            JR   Z,_SubEnd      ;No, so skip
            LD   A,D            ;Get BIILMM function bits
            AND  kDisMask     ;Separate mask type bits
            LD   HL,DisMaskTable  ;Point to table of mask bits
            ADD  A,L            ;Add to start of table
            LD   L,A            ;Store updated lo byte
            JR   NC,_NoOFlow    ;Skip if no overflow
            INC  H              ;Overflow so increment hi byte
_NoOFlow:   LD   A,(HL)         ;Get bit mask
            AND  C            ;Mask primary opcode
            LD   C,A            ;Store masked primary opcode
            LD   A,(HL)         ;Get bit mask
; Now shift primary opcode (masked) to right the number of
; times it takes to shift mask byte right before bit 1 is set
_SubsShift: SRL  A              ;Shift mask right
            JR   C,_DoneShift   ;Bit 1 was set so we're done
            SRL  C              ;Shift primary opcode (masked) right
            JR   _SubsShift     ;Go repeat..
_DoneShift: BIT  kDisLength,D   ;Length bit flagged?
            JR   Z,_Single      ;No, so skip
            SLA  C              ;Double value for two bytes
; C is now the offset into the substitute string
_Single:    LD   A,E            ;Substitute string number
            LD   HL,DisString   ;Start of string list
            CALL FindStrInList ;Get start of string (=HL)
            LD   A,C            ;Offset into string
            ADD  A,L            ;Add to start of string
            LD   L,A            ;Store updated lo byte
            JR   NC,_NoOver     ;Skip if no overflow
            INC  H              ;Overflow so increment hi byte
_NoOver:    LD   A,(HL)         ;Get substitute character
            CP   '*'            ;Code for 2 byte HL/IX/IY string
            JR   NZ,_NotStar    ;No, so skip
            LD   A,24           ;String = "HL"
            CALL DisWrString    ;Print string with substitutions
            JR   _SubEnd
_NotStar:   CALL DisWrChar      ;Print character with filters
            BIT  kDisLength,D   ;Length bit flagged?
            JR   Z,_SubEnd      ;No, so skip
            INC  HL             ;Point to second substitute character
            LD   A,(HL)         ;Get substitute character
            CP   '.'            ;Do not print '.' character
            CALL NZ,DisWrChar   ;Print character with filters
_SubEnd:    POP  HL
            POP  DE
            RET


; Disassembler: Get instruction opcode
;   On entry: A = Offset from start of instruction
;             IY = Start of instruction
;   On exit:  A = Opcode
;             BC DE HL IX IY I AF' BC' DE' HL' preserved
DisGetOpcode:
            PUSH BC
            PUSH IY
            LD   C,A            ;Offset from start of instruction
            LD   B,0            ;Clear hi byte ready for addition
            ADD  IY,BC          ;Calculate location of opcode
            LD   A,(IY+0)       ;Get opcode from memory
            POP  IY
            POP  BC
            RET


; Disassembler: Write character to string buffer
;   On entry: A = Character to write
;   On exit:  AF BC DE HL IX IY I AF' BC' DE' HL' preserved
; This version of write character removes bit 7 (the new string flag)
; and replaces "-" with "(HL)"
DisWrChar:
            PUSH AF
            AND  07FH         ;Mask off bit 7 (string start bit)
            CP   '-'            ;Code for "(HL)" ?
            JR   Z,_SubHL       ;Yes, so go write "(HL)" instead
            CALL StrWrChar      ;Print character
            JR   _Done
_SubHL:     LD   A,21           ;String number for "(HL)"
            CALL DisWrString    ;Write "(HL)" instead of "-"
_Done:      POP  AF
            RET                 ;JP instead to save byte


; Write disassembler string
;   On entry: A = Disassembler data string number
;             B = Offset to current opcode from start of instruction
;             IY = Start address for current instruction
;             (iDisIndex) = Index instruction opcode or zero
;   On exit:  AF C DE HL IX IY I AF' BC' DE' HL' preserved
;             B is incremented if (IX/IY+d) is substituted
; This version of write string removes bit 7 (the new string flag)
; If iDisTmp1 (the current index instruction opcode) is 0DD or 0FD,
; is not zero then strings are replaced:
;   HL is replaced with IX or IY
;   (HL) is replaced with (IX + d) or (IY + d) except for JP instruction
;   where is is just replaced by (IX) or (IY)
DisWrString:
            PUSH AF
            PUSH HL
            LD   L,A            ;Store string number
            CP   kDisBracHL     ;String = (HL) ?
            JR   Z,_Subs        ;Yes, so go do substitution
            CP   kDisHL         ;String = HL ?
            JR   NZ,_GotString  ;No, so just write the string
; Substitute IX/IY in HL string or (IX/IY+d) in (HL) string
_Subs:      LD   A,(iDisIndex)  ;Get index instruction opcode
            OR   A              ;Index instruction?
            JR   Z,_GotString   ;No, so skip substitutions
            INC  L              ;Increment to IX string number
            CP   0DDH           ;IX instruction?
            JR   Z,_GotString   ;Yes, so go write it
            INC  L              ;Increment to IY string
_GotString: LD   A,L            ;Get string number
            LD   HL,DisString   ;Start of string list
            CALL FindStrInList ;Find start of string A
; HL now points to disassembler string
_Char:      LD   A,(HL)         ;Get character from string
            AND  07FH           ;Mask off string start bit
            CP   '+'            ;Is it a '+' sign (displacement) ?
            JR   Z,_Plus        ;No, so skip to next character
            CALL StrWrChar      ;Write character
            JR   _Next          ;No, so skip to next character
; Encountered a plus sign so expecting to show a displacement
_Plus:      LD   A,(iDisOpStr)  ;Get instruction string
            CP   kDisJP         ;JP instruction?
            JR   NZ,_Displace   ;No, so go show displacement
            LD   A,')'          ;Yes, so just terminate with ')'
            CALL StrWrChar      ;Write close bracket character
            JR   _End
; Show displacement in (IX+...) and (IY+...) instructions
_Displace:  LD   A,'+'
            CALL StrWrChar      ;Write plus character
;           CALL WrHexPrefix
            LD   A,(IY+2)       ;Get index instruction displacement
            CALL StrWrHexByte   ;Write displacement in hex
            LD   A,')'
            CALL StrWrChar      ;Write close bracket character
            INC  B              ;Increment opcode offset
; Consider next character in disassembler string
_Next:      INC  HL             ;Point to next character
            BIT  7,(HL)         ;Start of new string?
            JR   Z,_Char        ;No, so go get next character
_End:       POP  HL
            POP  AF
            RET


; **********************************************************************
; **  Constant data                                                   **
; **********************************************************************


; Strings
szDisTo:    DEFM  '  (to '
            DEFB  kNull


; Operand table:
;   Index into table is the operand string number 1 to 13)
;   Contents: Substitution string number, function bits BIILMM
;
; Op  String  Offset  Bracket  Immediate  Substitue     subsLen  subsMask  ->  BIILMM
;  1  =""     +0      No       No   (00)  No                n/a  n/a           000000
;  2  ="n"    +1      No       Byte (10)  No                n/a  n/a           010000
;  3  ="(n)"  +1      Yes      Byte (10)  No                n/a  n/a           110000
;  4  ="nn"   +2      No       Word (11)  No                n/a  n/a           011000
;  5  ="(nn)" +2      Yes      Word (11)  No                n/a  n/a           111000
;  6  ="r"    +0      No       No   (00)  "BCDEHL-A"          1  038 (11)     000011
;  7  ="r2"   +0      No       No   (00)  "BCDEHL-A"          1  007 (00)     000000
;  8  ="dd"   +0      No       No   (00)  "BCDEHLSP"          2  030 (10)     000110
;  9  ="qq"   +0      No       No   (00)  "BCDEHLAF"          2  030 (10)     000110
; 10  ="c"    +0      No       No   (00)  "NZZ NCC "          2  018 (01)     000101
; 11  ="cc"   +0      No       No   (00)  "NZZ NCC POPEP M "  2  038 (11)     000111
; 12  ="t"    +0      No       No   (00)  "0008101820283038"  2  038 (11)     000111
; 13  ="b"    +0      No       No   (00)  "01234567"          1  038 (11)     000011
; Each table entry is coded with the string number plus a byte containing BIILMM bits
; Length bit is hi for strings with two character substitutions
DisOperandTable:
            DEFB  000H,000H      ;0b000000 ;Operand  1 = ""
            DEFB  000H,010H      ;0b010000 ;Operand  2 = "n"
            DEFB  000H,030H      ;0b110000 ;Operand  3 = "(n)"
            DEFB  000H,018H      ;0b011000 ;Operand  4 = "nn"
            DEFB  000H,038H      ;0b111000 ;Operand  5 = "(nn)"
            DEFB  00EH,003H      ;0b000011 ;Operand  6 = "r"
            DEFB  00EH,000H      ;0b000000 ;Operand  7 = "r2"
            DEFB  00FH,006H      ;0b000110 ;Operand  8 = "dd"
            DEFB  010H,006H      ;0b000110 ;Operand  9 = "qq"
            DEFB  011H,005H      ;0b000101 ;Operand 10 = "c"
            DEFB  012H,007H      ;0b000111 ;Operand 11 = "cc"
            DEFB  013H,007H      ;0b000111 ;Operand 12 = "t"
            DEFB  014H,003H      ;0b000011 ;Operand 13 = "b"

; Mask table
; These are the masks used to separate token values such as register "BCDEHL-A"
; The index into the table is coded in the two mask bits from the above table.
DisMaskTable:
            DEFB  007H           ;Mask type 0
            DEFB  018H           ;Mask type 1
            DEFB  030H           ;Mask type 2
            DEFB  038H           ;Mask type 3


; Condition mask table
; The condition mask table contains one byte for each condition flag:
; NZ,Z,NC,C,PO,PE,P,M where offset into table is 0 for Z/NZ, 1 for C/NC, etc
; The value of each table entry is a bit mask, which when exclusively for the flags register
            ;SZ-H-PNC   Condition, Flag, Description
DisConTab:  DEFB  040H           ;xZxxxxxx   NZ,        Z=0,  Not Zero
            DEFB  001H           ;xxxxxxxC   NC,        C=0,  No Carry
            DEFB  004H           ;xxxxxxxC   PO,        P=0,  Parity Odd
            DEFB  080H           ;xxxxxxxC   PO,        S=0,  Positive


; Include the data tables  DisString: and DisInst:
;
; Disassembler string table: (DisString)
; This contains many string which are not null terminated and have no length
; value. Instead they are tightly packed with the start of each string
; indicated by the first character having bit 7 set.
;
; Instruction table: (DisInst)
; The instruction table definition of the processor's instruction set.
; Each instruction is described by 5 bytes:
;    Byte 0:  Opcode value
;    Byte 1:  Opcode mask
;    Byte 2:  Operation string number
;    Byte 3:  Operand #1 string number, plus bits 6-7 define precode
;    Byte 4:  Operand #2 string number
; The precode values code in bits 6-7 are:
;    00x xxxx = No precode
;    10x xxxx = Precode 0CB
;    11xx xxxx = Precode 0ED
; Precodes are used by the processor's extended instructions


; **********************************************************************
; **  Private workspace (in RAM)                                      **
; **********************************************************************

iDisIndex:  DEFB  000           ;Index instruction opcode
iDisOpStr:  DEFB  000           ;Operation string number
iDisOp1Str: DEFB  000           ;Operand 1 string number
iDisOpcode: DEFB  000           ;Primary instruction opcode
iDisImmed:  DEFW  00000         ;Immediate value


; Disassembler: How it works...
; Solution is to use data table to define functions for each operand (see below)
; Decoding table: where the table entry is determined by the operand string number
; String numbers 0 to 12:
;   If bracket flagged print "("
;   If immediate byte flagged print hex byte at PC+Offset+1, Offset += 1
;   If immediate word flagged print word byte at PC+Offset+1 and PC+Offset+2, Offset += 2
;   If bracket flagged print ")"
;   If substitution string specified: (non-zero value)
;     n = opcode and SubsMask
;     n = n >> x, where x is the number of right shifts of the mask til bit 0 is a 1
;     If subsLen is 2 then n = n << 1
;     c =  character at (start of Substitution String + n + 0)
;     if = "-" then print "(HL)" else print character c
;     If SubsLen = 2 then
;       print character at (start of Substitution String + n + 1)
;     Endif
;   End if


; Single stepping
; Instructions which can change flow of code (ie. alter PC)
;   DJNZ d          10 nn      0001 0000
;   JR   d          18 nn      0001 1000
;   JR   c,  d      xx nn      001c c000
;   JP   nn         C3 nn nn   1100 0011
;   JP   cc, nn     xx nn nn   11cc c010
;   JP   HL         E9         1110 1001
;   JP   IX         DD E9      1110 1001
;   JP   IY         FD E9      1110 1001
;   CALL nn         CD nn nn   1100 1101
;   CALL cc, nn     xx nn nn   11cc c100
;   RET             C9         1100 1001
;   RET  cc         xx         11cc c000
;   RETI            ED 4D      0100 1101
;   RETN            ED 45      0100 0101
;   RST  aa         xx         11tt t111
; Also an interrupt or reset signal changes PC
; The above instructions are trapped after disassembly and the next instruction
; determined. The breakpoint is then placed here to allow single stepping.


; **********************************************************************
; **  End of Disassembler support module                              **
; **********************************************************************

