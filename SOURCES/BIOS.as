*Include config.mac

COND	BDOS

	psect text

	GLOBAL	HOME
	GLOBAL	SELDSK
	GLOBAL	SETTRK
	GLOBAL	SETSEC
	GLOBAL	SETDMA
	GLOBAL	READ
	GLOBAL	WRITE
	GLOBAL	SECTRN

COND	SIM

;	Z80 CBIOS for Z80-Simulator
;
;	Copyright (C) 1988-2007 by Udo Munk
;
;	I/O ports
;
CONSTA	EQU	0		;console status port
CONDAT	EQU	1		;console data port
PRTSTA	EQU	2		;printer status port
PRTDAT	EQU	3		;printer data port
AUXDAT	EQU	5		;auxiliary data port
FDCD	EQU	10		;fdc-port: # of drive
FDCT	EQU	11		;fdc-port: # of track
FDCS	EQU	12		;fdc-port: # of sector
FDCOP	EQU	13		;fdc-port: command
FDCST	EQU	14		;fdc-port: status
DMAL	EQU	15		;dma-port: dma address low
DMAH	EQU	16		;dma-port: dma address high
;
;	fixed data tables for four-drive standard
;	IBM-compatible 8" SD disks
;
;	disk parameter header for disk 00
DPBASE:	DEFW	TRANS,0000H
	DEFW	0000H,0000H
	DEFW	DIRBF,DPBLK
	DEFW	CHK00,ALL00
;	disk parameter header for disk 01
	DEFW	TRANS,0000H
	DEFW	0000H,0000H
	DEFW	DIRBF,DPBLK
	DEFW	CHK01,ALL01
;	disk parameter header for disk 02
	DEFW	TRANS,0000H
	DEFW	0000H,0000H
	DEFW	DIRBF,DPBLK
	DEFW	CHK02,ALL02
;	disk parameter header for disk 03
	DEFW	TRANS,0000H
	DEFW	0000H,0000H
	DEFW	DIRBF,DPBLK
	DEFW	CHK03,ALL03
;
;	sector translate vector for the IBM 8" SD disks
;
TRANS:	DEFB	1,7,13,19	;sectors 1,2,3,4
	DEFB	25,5,11,17	;sectors 5,6,7,8
	DEFB	23,3,9,15	;sectors 9,10,11,12
	DEFB	21,2,8,14	;sectors 13,14,15,16
	DEFB	20,26,6,12	;sectors 17,18,19,20
	DEFB	18,24,4,10	;sectors 21,22,23,24
	DEFB	16,22		;sectors 25,26
;
;	disk parameter block, common to all IBM 8" SD disks
;
DPBLK:  DEFW	26		;sectors per track
	DEFB	3		;block shift factor
	DEFB	7		;block mask
	DEFB	0		;extent mask
	DEFW	242		;disk size-1
	DEFW	63		;directory max
	DEFB	192		;alloc 0
	DEFB	0		;alloc 1
	DEFW	16		;check size
	DEFW	2		;track offset
;
;	fixed data tables for 4MB harddisks
;
;	disk parameter header
HDB1:	DEFW	0000H,0000H
	DEFW	0000H,0000H
	DEFW	DIRBF,HDBLK
	DEFW	CHKHD1,ALLHD1
HDB2:	DEFW	0000H,0000H
	DEFW	0000H,0000H
	DEFW	DIRBF,HDBLK
	DEFW	CHKHD2,ALLHD2
;
;       disk parameter block for harddisk
;
HDBLK:  DEFW    128		;sectors per track
	DEFB    4		;block shift factor
	DEFB    15		;block mask
	DEFB    0		;extent mask
	DEFW    2039		;disk size-1
	DEFW    1023		;directory max
	DEFB    255		;alloc 0
	DEFB    255		;alloc 1
	DEFW    0		;check size
	DEFW    0		;track offset
;
;	end of fixed tables
;
;	scratch ram area for BDOS use
;
DIRBF:	DEFS	128		;scratch directory area
ALL00:	DEFS	31		;allocation vector 0
ALL01:	DEFS	31		;allocation vector 1
ALL02:	DEFS	31		;allocation vector 2
ALL03:	DEFS	31		;allocation vector 3
ALLHD1:	DEFS	255		;allocation vector harddisk 1
ALLHD2:	DEFS	255		;allocation vector harddisk 2
CHK00:	DEFS	16		;check vector 0
CHK01:	DEFS	16		;check vector 1
CHK02:	DEFS	16		;check vector 2
CHK03:	DEFS	16		;check vector 3
CHKHD1:	DEFS	0		;check vector harddisk 1
CHKHD2:	DEFS	0		;check vector harddisk 2
;
;	i/o drivers for the disk follow
;
;	move to the track 00 position of current drive
;	translate this call into a settrk call with parameter 00
;
HOME:	LD	C,0		;select track 0
	JP	SETTRK		;we will move to 00 on first read/write
;
;	select disk given by register C
;
SELDSK: LD	HL,0000H	;error return code
	LD	A,C
	CP	4		;FD drive 0-3?
	JP	C,SELFD		;go
	CP	8		;harddisk 1?
	JP	Z,SELHD1	;go
	CP	9		;harddisk 2?
	JP	Z,SELHD2	;go
	RET			;no, error
;	disk number is in the proper range
;	compute proper disk parameter header address
SELFD:	OUT	(FDCD),A	;selekt disk drive
	LD	L,A		;L=disk number 0,1,2,3
	ADD	HL,HL		;*2
	ADD	HL,HL		;*4
	ADD	HL,HL		;*8
	ADD	HL,HL		;*16 (size of each header)
	LD	DE,DPBASE
	ADD	HL,DE		;HL=.dpbase(diskno*16)
	RET
SELHD1:	LD	HL,HDB1		;dph harddisk 1
	JP	SELHD
SELHD2:	LD	HL,HDB2		;dph harddisk 2
SELHD:	OUT	(FDCD),A	;select harddisk drive
	RET
;
;	set track given by register c
;
SETTRK: LD	A,C
	OUT	(FDCT),A
	RET
;
;	set sector given by register c
;
SETSEC: LD	A,C
	OUT	(FDCS),A
	RET
;
;	translate the sector given by BC using the
;	translate table given by DE
;
SECTRN:
	LD	A,D		;do we have a translation table?
	OR	E
	JP	NZ,SECT1	;yes, translate
	LD	L,C		;no, return untranslated
	LD	H,B		;in HL
	INC	L		;sector no. start with 1
	RET	NZ
	INC	H
	RET
SECT1:	EX	DE,HL		;HL=.trans
	ADD	HL,BC		;HL=.trans(sector)
	LD	L,(HL)		;L = trans(sector)
	LD	H,0		;HL= trans(sector)
	RET			;with value in HL
;
;	set dma address given by registers b and c
;
SETDMA: LD	A,C		;low order address
	OUT	(DMAL),A
	LD	A,B		;high order address
	OUT	(DMAH),A	;in dma
	RET
;
;	perform read operation
;
READ:	XOR	A		;read command -> A
	JP	WAITIO		;to perform the actual i/o
;
;	perform a write operation
;
WRITE:	LD	A,1		;write command -> A
;
;	enter here from read and write to perform the actual i/o
;	operation.  return a 00h in register a if the operation completes
;	properly, and 01h if an error occurs during the read or write
;
WAITIO: OUT	(FDCOP),A	;start i/o operation
	IN	A,(FDCST)	;status of i/o operation -> A
	RET

ENDC

COND	NOSIM

	GLOBAL	BOOT

;==================================================================================
; This is Grant Searle's code, modified for use with Small Computer Workshop IDE.
; Compile options added for LiNC80 and RC2014 systems to set correct addresses.
; Warning: This may not be the same as the 'official' BIOS for each retro system.
; Changes marked with "<SCC>"
; SCC 2018-04-13
; Added option for 64MB compact flash.
; JL 2018-04-28
;==================================================================================
; Contents of this file are copyright Grant Searle
; Blocking/unblocking routines are the published version by Digital Research
; (bugfixed, as found on the web)
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; http://searle.hostei.com/grant/index.html
;
; eMail: home.micros01@btinternet.com
;
; If the above don't work, please perform an Internet search to see if I have
; updated the web page hosting service.
;
;==================================================================================

; <JL> Select one of the two size options: 64MB or 128MB
SIZE64 equ 1; set 0 for 128

blksiz      equ 4096           ;CP/M allocation size
hstsiz      equ 512            ;host disk sector size
hstspt      equ 32             ;host disk sectors/trk
hstblk      equ hstsiz/128     ;CP/M sects/host buff
cpmspt      equ hstblk * hstspt  ;CP/M sectors/track
secmsk      equ hstblk-1       ;sector mask

wrall       equ 0              ;write to allocated
wrdir       equ 1              ;write to directory
wrual       equ 2              ;write to unallocated

; CF registers
CF_DATA     equ 010H
CF_FEATURES equ 011H
CF_ERROR    equ 011H
CF_SECCOUNT equ 012H
CF_SECTOR   equ 013H
CF_CYL_LOW  equ 014H
CF_CYL_HI   equ 015H
CF_HEAD     equ 016H
CF_STATUS   equ 017H
CF_COMMAND  equ 017H
CF_LBA0     equ 013H
CF_LBA1     equ 014H
CF_LBA2     equ 015H
CF_LBA3     equ 016H

;CF Features
CF_8BIT     equ 1
CF_NOCACHE  equ 082H
;CF Commands
CF_READ_SEC equ 020H
CF_WRITE_SEC equ 030H
CF_SET_FEAT equ  0EFH

;================================================================================================
; Disk parameter headers for disk 0 to 15
;================================================================================================
; <JL> Added IFDEF/ELSE block to select 64/128 MB
dpbase:
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb0,0000h,alv00
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv01
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv02
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv03
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv04
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv05
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv06
COND      SIZE64
            defw 0000h,0000h,0000h,0000h,dirbuf,dpbLast,0000h,alv07
ENDC
COND	1-SIZE64
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv07
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv08
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv09
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv10
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv11
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv12
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv13
            defw 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv14
            defw 0000h,0000h,0000h,0000h,dirbuf,dpbLast,0000h,alv15
ENDC
            
; First drive has a reserved track for CP/M
dpb0:
            defw 128             ;SPT - sectors per track
            defb 5               ;BSH - block shift factor
            defb 31              ;BLM - block mask
            defb 1               ;EXM - Extent mask
            defw 2043            ; (2047-4) DSM - Storage size (blocks - 1)
            defw 511             ;DRM - Number of directory entries - 1
            defb 240             ;AL0 - 1 bit set per directory block
            defb 0               ;AL1 -            "
            defw 0               ;CKS - DIR check vector size (DRM+1)/4 (0=fixed disk)
            defw 1               ;OFF - Reserved tracks

dpb:
            defw 128             ;SPT - sectors per track
            defb 5               ;BSH - block shift factor
            defb 31              ;BLM - block mask
            defb 1               ;EXM - Extent mask
            defw 2047            ;DSM - Storage size (blocks - 1)
            defw 511             ;DRM - Number of directory entries - 1
            defb 240             ;AL0 - 1 bit set per directory block
            defb 0               ;AL1 -            "
            defw 0               ;CKS - DIR check vector size (DRM+1)/4 (0=fixed disk)
            defw 0               ;OFF - Reserved tracks

; Last drive is smaller because CF is never full 64MB or 128MB
; <JL> Added IFDEF/ELSE block to select 64/128 MB
dpbLast:
            defw 128             ;SPT - sectors per track
            defb 5               ;BSH - block shift factor
            defb 31              ;BLM - block mask
            defb 1               ;EXM - Extent mask
COND      SIZE64
            defw 1279            ;DSM - Storage size (blocks - 1)  ; 1279 = 5MB (for 64MB card)
ENDC
COND	1-SIZE64
            defw 511             ;DSM - Storage size (blocks - 1)  ; 511 = 2MB (for 128MB card)
ENDC
            defw 511             ;DRM - Number of directory entries - 1
            defb 240             ;AL0 - 1 bit set per directory block
            defb 0               ;AL1 -            "
            defw 0               ;CKS - DIR check vector size (DRM+1)/4 (0=fixed disk)
            defw 0               ;OFF - Reserved tracks

;================================================================================================
; Data storage
;================================================================================================

dirbuf:     defs 128             ;scratch directory area
alv00:      defs 257             ;allocation vector 0
alv01:      defs 257             ;allocation vector 1
alv02:      defs 257             ;allocation vector 2
alv03:      defs 257             ;allocation vector 3
alv04:      defs 257             ;allocation vector 4
alv05:      defs 257             ;allocation vector 5
alv06:      defs 257             ;allocation vector 6
alv07:      defs 257             ;allocation vector 7
; <JL> Added IFDEF block to select 64/128 MB
COND	1-SIZE64
alv08:      defs 257             ;allocation vector 8
alv09:      defs 257             ;allocation vector 9
alv10:      defs 257             ;allocation vector 10
alv11:      defs 257             ;allocation vector 11
alv12:      defs 257             ;allocation vector 12
alv13:      defs 257             ;allocation vector 13
alv14:      defs 257             ;allocation vector 14
alv15:      defs 257             ;allocation vector 15
ENDC

lba0:        defb 00h
lba1:        defb 00h
lba2:        defb 00h
lba3:        defb 00h

sekdsk:     defs 1               ;seek disk number
sektrk:     defs 2               ;seek track number
seksec:     defs 2               ;seek sector number
;
hstdsk:     defs 1               ;host disk number
hsttrk:     defs 2               ;host track number
hstsec:     defs 1               ;host sector number
;
sekhst:     defs 1               ;seek shr secshf
hstact:     defs 1               ;host active flag
hstwrt:     defs 1               ;host written flag
;
unacnt:     defs 1               ;unalloc rec cnt
unadsk:     defs 1               ;last unalloc disk
unatrk:     defs 2               ;last unalloc track
unasec:     defs 1               ;last unalloc sector
;
erflag:     defs 1               ;error reporting
rsflag:     defs 1               ;read sector flag
readop:     defs 1               ;1 if read operation
wrtype:     defs 1               ;write operation type
dmaAddr:    defs 2               ;last dma address
hstbuf:     defs 512             ;host buffer

userdrv: defs 1

;================================================================================================
; Disk processing entry points
;================================================================================================

BOOT:
            CALL cfWait
            LD  A,CF_8BIT       ; Set IDE to be 8bit
            OUT (CF_FEATURES),A
            LD A,CF_SET_FEAT
            OUT (CF_COMMAND),A

            CALL cfWait
            LD  A,CF_NOCACHE    ; No write cache
            OUT (CF_FEATURES),A
            LD A,CF_SET_FEAT
            OUT (CF_COMMAND),A

            XOR A               ; Clear I/O & drive bytes.
            LD (userdrv),A

	    RET
;
SELDSK:
            LD HL,0
            LD A,C
; <JL> Added IFDEF/ELSE block to select 64/128 MB
COND      SIZE64
            CP 8                ; 8 for 64MB disk, 16 for 128MB disk
ENDC
COND	1-SIZE64
            CP 16               ; 16 for 128MB disk, 8 for 64MB disk
ENDC
            jr C,chgdsk         ; if invalid drive will give BDOS error
            LD A,(userdrv)      ; so set the drive back to a:
            CP C                ; If the default disk is not the same as the
            RET NZ              ; selected drive then return, 
            XOR A               ; else reset default back to a:
            LD (userdrv),A      ; otherwise will be stuck in a loop
            LD (sekdsk),A
            ret

chgdsk:     LD  (sekdsk),A
            RLC A               ;*2
            RLC A               ;*4
            RLC A               ;*8
            RLC A               ;*16
            LD  HL,dpbase
            LD B,0
            LD c,A 
            ADD HL,BC

            RET

;------------------------------------------------------------------------------------------------
HOME:
            ld a,(hstwrt)       ;check for pending write
            or A
            jr nz,homed
            ld (hstact),A       ;clear host active flag
homed:
            LD  BC,0000h

;------------------------------------------------------------------------------------------------
SETTRK:     LD  (sektrk),BC     ; Set track passed from BDOS in register BC.
            RET

;------------------------------------------------------------------------------------------------
SETSEC:     LD  (seksec),BC     ; Set sector passed from BDOS in register BC.
            RET

;------------------------------------------------------------------------------------------------
SETDMA:     LD  (dmaAddr),BC    ; Set DMA ADDress given by registers BC.
            RET

;------------------------------------------------------------------------------------------------
SECTRN:    PUSH  BC
            POP  HL
            RET

;------------------------------------------------------------------------------------------------
READ:
            ;read the selected CP/M sector
            xor A
            ld (unacnt),A
            ld A,1
            ld (readop),A       ;read operation
            ld (rsflag),A       ;must read data
            ld A,wrual
            ld (wrtype),A       ;treat as unalloc
            jp rwoper           ;to perform the read


;------------------------------------------------------------------------------------------------
WRITE:
            ;write the selected CP/M sector
            xor A               ;0 to accumulator
            ld (readop),A       ;not a read operation
            ld A,C              ;write type in c
            ld (wrtype),A
            cp wrual            ;write unallocated?
            jr nz,chkuna        ;check for unalloc
;
;                               write to unallocated, set parameters
            ld A,blksiz/128     ;next unalloc recs
            ld (unacnt),A
            ld A,(sekdsk)       ;disk to seek
            ld (unadsk),A       ;unadsk = sekdsk
            ld HL,(sektrk)
            ld (unatrk),HL      ;unatrk = sectrk
            ld A,(seksec)
            ld (unasec),A       ;unasec = seksec
;
chkuna:
;                               check for write to unallocated sector
            ld A,(unacnt)       ;any unalloc remain?
            or A 
            jr z,alloc          ;skip if not
;
;                               more unallocated records remain
            dec A               ;unacnt = unacnt-1
            ld (unacnt),A
            ld A,(sekdsk)       ;same disk?
            ld HL,unadsk
            cp (HL)             ;sekdsk = unadsk?
            jp nz,alloc         ;skip if not
;
;                               disks are the same
            ld HL,unatrk
            call sektrkcmp      ;sektrk = unatrk?
            jp nz,alloc         ;skip if not
;
;                               tracks are the same
            ld A,(seksec)       ;same sector?
            ld HL,unasec
            cp (HL)             ;seksec = unasec?
            jp nz,alloc         ;skip if not
;
;                               match, move to next sector for future ref
            inc (HL)            ;unasec = unasec+1
            ld A,(HL)           ;end of track?
            cp cpmspt           ;count CP/M sectors
            jr c,noovf          ;skip if no overflow
;
;                               overflow to next track
            ld (HL),0           ;unasec = 0
            ld HL,(unatrk)
            inc HL
            ld (unatrk),HL      ;unatrk = unatrk+1
;
noovf:
            ;match found, mark as unnecessary read
            xor a               ;0 to accumulator
            ld (rsflag),a       ;rsflag = 0
            jr rwoper           ;to perform the write
;
alloc:
            ;not an unallocated record, requires pre-read
            xor a               ;0 to accum
            ld (unacnt),a       ;unacnt = 0
            inc a               ;1 to accum
            ld (rsflag),a       ;rsflag = 1

;------------------------------------------------------------------------------------------------
rwoper:
            ;enter here to perform the read/write
            xor a               ;zero to accum
            ld (erflag),a       ;no errors (yet)
            ld a,(seksec)       ;compute host sector
            or a                ;carry = 0
            rra                 ;shift right
            or a                ;carry = 0
            rra                 ;shift right
            ld (sekhst),a       ;host sector to seek
;
;                               active host sector?
            ld hl,hstact        ;host active flag
            ld a,(hl)
            ld (hl),1           ;always becomes 1
            or a                ;was it already?
            jr z,filhst         ;fill host if not
;
;                               host buffer active, same as seek buffer?
            ld a,(sekdsk)
            ld hl,hstdsk        ;same disk?
            cp (hl)             ;sekdsk = hstdsk?
            jr nz,nomatch
;
;                               same disk, same track?
            ld hl,hsttrk
            call sektrkcmp      ;sektrk = hsttrk?
            jr nz,nomatch
;
;                               same disk, same track, same buffer?
            ld a,(sekhst)
            ld hl,hstsec        ;sekhst = hstsec?
            cp (hl)
            jr z,match          ;skip if match
;
nomatch:
            ;proper disk, but not correct sector
            ld a,(hstwrt)       ;host written?
            or a
            call nz,writehst    ;clear host buff
;
filhst:
            ;may have to fill the host buffer
            ld a,(sekdsk)
            ld (hstdsk),a
            ld hl,(sektrk)
            ld (hsttrk),hl
            ld a,(sekhst)
            ld (hstsec),a
            ld a,(rsflag)       ;need to read?
            or a
            call nz,readhst     ;yes, if 1
            xor a               ;0 to accum
            ld (hstwrt),a       ;no pending write
;
match:
            ;copy data to or from buffer
            ld a,(seksec)       ;mask buffer number
            and secmsk          ;least signif bits
            ld l,a              ;ready to shift
            ld h,0              ;double count
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
            add hl,hl
;                               hl has relative host buffer address
            ld de,hstbuf
            add hl,de           ;hl = host address
            ex de,hl            ;now in DE
            ld hl,(dmaAddr)     ;get/put CP/M data
            ld c,128            ;length of move
            ld a,(readop)       ;which way?
            or a
            jr nz,rwmove        ;skip if read
;
;           write operation, mark and switch direction
            ld a,1
            ld (hstwrt),a       ;hstwrt = 1
            ex de,hl            ;source/dest swap
;
rwmove:
            ;C initially 128, DE is source, HL is dest
            ld a,(de)           ;source character
            inc de
            ld (hl),a           ;to dest
            inc hl
            dec c               ;loop 128 times
            jr nz,rwmove
;
;                               data has been moved to/from host buffer
            ld a,(wrtype)       ;write type
            cp wrdir            ;to directory?
            ld a,(erflag)       ;in case of errors
            ret nz              ;no further processing
;
;                               clear host buffer for directory write
            or a                ;errors?
            ret nz              ;skip if so
            xor a               ;0 to accum
            ld (hstwrt),a       ;buffer written
            call writehst
            ld a,(erflag)
            ret

;------------------------------------------------------------------------------------------------
;Utility subroutine for 16-bit compare
sektrkcmp:
            ;HL = .unatrk or .hsttrk, compare with sektrk
            ex de,hl
            ld hl,sektrk
            ld a,(de)           ;low byte compare
            cp (HL)             ;same?
            ret nz              ;return if not
;                               low bytes equal, test high 1s
            inc de
            inc hl
            ld a,(de)
            cp (hl)             ;sets flags
            ret

;================================================================================================
; Convert track/head/sector into LBA for physical access to the disk
;================================================================================================
setLBAaddr:
            LD HL,(hsttrk)
            RLC L
            RLC L
            RLC L
            RLC L
            RLC L
            LD A,L
            AND 0E0H
            LD L,A
            LD A,(hstsec)
            ADD A,L
            LD (lba0),A

            LD HL,(hsttrk)
            RRC L
            RRC L
            RRC L
            LD A,L
            AND 01FH
            LD L,A
            RLC H
            RLC H
            RLC H
            RLC H
            RLC H
            LD A,H
            AND 020H
            LD H,A
            LD A,(hstdsk)
            RLC a
            RLC a
            RLC a
            RLC a
            RLC a
            RLC a
            AND 0C0H
            ADD A,H
            ADD A,L
            LD (lba1),A
            

            LD A,(hstdsk)
            RRC A
            RRC A
            AND 03H
            LD (lba2),A

; LBA Mode using drive 0 = E0
            LD a,0E0H
            LD (lba3),A


            LD A,(lba0)
            OUT  (CF_LBA0),A

            LD A,(lba1)
            OUT  (CF_LBA1),A

            LD A,(lba2)
            OUT  (CF_LBA2),A

            LD A,(lba3)
            OUT  (CF_LBA3),A

            LD  A,1
            OUT  (CF_SECCOUNT),A

            RET    

;================================================================================================
; Read physical sector from host
;================================================================================================

readhst:
            PUSH  AF
            PUSH  BC
            PUSH  HL

            CALL  cfWait

            CALL  setLBAaddr

            LD  A,CF_READ_SEC
            OUT  (CF_COMMAND),A

            CALL  cfWait

            LD  c,4
            LD  HL,hstbuf
rd4secs:
            LD  b,128
rdByte:
            in  A,(CF_DATA)
            LD  (HL),A
            iNC  HL
            dec  b
            JR  NZ, rdByte
            dec  c
            JR  NZ,rd4secs

            POP  HL
            POP  BC
            POP  AF

            XOR  a
            ld (erflag),a
            RET

;================================================================================================
; Write physical sector to host
;================================================================================================

writehst:
            PUSH  AF
            PUSH  BC
            PUSH  HL


            CALL  cfWait

            CALL  setLBAaddr

            LD  A,CF_WRITE_SEC
            OUT  (CF_COMMAND),A

            CALL  cfWait

            LD  c,4
            LD  HL,hstbuf
wr4secs:
            LD  b,128
wrByte:     LD  A,(HL)
            OUT  (CF_DATA),A
            iNC  HL
            dec  b
            JR  NZ, wrByte

            dec  c
            JR  NZ,wr4secs

            POP  HL
            POP  BC
            POP  AF

            XOR  a
            ld (erflag),a
            RET

;================================================================================================
; Wait for disk to be ready (busy=0,ready=1)
;================================================================================================
;#IFDEF      GrantsOriginal
;cfWait:
;            PUSH  AF
;cfWait1:
;            in  A,(CF_STATUS)
;            AND  080H
;            cp  080H
;            JR Z,cfWait1
;            POP  AF
;            RET
;#ELSE
cfWait:     PUSH AF
TstBusy:   IN   A,(CF_STATUS)  ;Read status register
            BIT  7,A            ;Test Busy flag
            JR   NZ,TstBusy    ;High so busy
TstReady:  IN   A,(CF_STATUS)  ;Read status register
            BIT  6,A            ;Test Ready flag
            JR   Z,TstBusy     ;Low so not ready
            POP  AF
            RET
;#ENDIF


ENDC

ENDC
