*Include config.mac

COND	BDOS

	psect text

	GLOBAL __bdos

	GLOBAL	HOME
	GLOBAL	SELDSK
	GLOBAL	SETTRK
	GLOBAL	SETSEC
	GLOBAL	SETDMA
	GLOBAL	READ
	GLOBAL	WRITE
	GLOBAL	SECTRN
COND	NOCPM
	GLOBAL	BOOT
ENDC
;
BTD:DEFB 0; 1=DONE
EFCB:DEFB 0E5H;empty directory segment indicator.
WP:DEFW 0;write protect status for all 16 drives.
LG:DEFW 0;drive active word (1 bit per drive).
UD:DEFW 080H;user's dma address (defaults to 80h).
S1:DEFW 0;relative position within dir segment for file (0-3).
S2:DEFW 0;last selected track number.
S3:DEFW 0;last selected sector number.
DB:DEFW 0;address of directory buffer to use.
DP:DEFW 0;contains address of disk parameter block.
CV:DEFW 0;address of check vector.
AV:DEFW 0;address of allocation vector (bit map).
SS:DEFW 0;sectors per track from bios.
BT:DEFB 0;block shift.
BM:DEFB 0;block mask.
EM:DEFB 0;extent mask.
DKS:DEFW 0;disk size from bios (number of blocks-1).
DIS:DEFW 0;directory size.
A0:DEFW 0;storage for first bytes of bit map (dir space used).
A1:DEFW 0
OF:DEFW 0;first usable track number.
XLATE:DEFW 0;sector translation table address.
CF:DEFB 0;close flag (=0ffh is extent written ok).
RF:DEFB 0;read/write flag (0ffh=read, 0=write).
FS:DEFB 0;filename found status (0=found first entry).
MODE:DEFB 0;I/o mode select (0=random, 1=sequential, 2=special random).
EP:DEFB 0;storage for register (E) on entry to bdos.
RB:DEFB 0;relative position within fcb of block number written.
CT:DEFB 0;byte counter for directory name searches.
SF:DEFW 0,0;save space for address of fcb (for directory searches).
BD:DEFB 0;if =0 then disk is > 256 blocks long.
AUTO:DEFB 0;if non-zero, then auto select activated.
OD:DEFB 0;on auto select, storage for previous drive.
ASF:DEFB 0;if non-zero, then auto select changed drives.
SN:DEFB 0;storage for next record number to access.
SE:DEFB 0;storage for extent number of file.
SR:DEFW 0;storage for number of records in file.
BN:DEFW 0;block number (physical sector) used within a file or logical sect
LS:DEFW 0;starting logical (128 byte) sector of block (physical sector).
FCP:DEFB 0;relative position within buffer for fcb of file of interest.
FP:DEFW 0;files position within directory (0 to max entries -1).
CKT:DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
FCB:DEFB 0
 DEFM '           '
 DEFB 0,0,0,0,0
 DEFM '           '
 DEFB 0,0,0,0,0
RC:DEFB 0               ;status returned from bdos call.
CDR:DEFB 0               ;currently active drive.
CHD:DEFB 0               ;change in drives flag (0=no change).
NBY:DEFW 0               ;byte counter used by TYPE.
 DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0

TDR:defs	1;current drive name and user number.
TBUFF:defs	80h;i/o buffer and command line storage.

UST:DEFW 0;save users stack pointer here.
 DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
STK:;end of stack area.
USN:DEFB 0;current user number.
ACT:DEFB 0;currently active drive.
PAR:DEFW 0;save (DE) parameters here on entry.
STS:DEFW 0;status returned from bdos function.
BSC:DEFW ERR1;bad sector on read or write.
BSL:DEFW ERR2;bad disk select.
ROD:DEFW ERR3;disk is read only.
ROF:DEFW ERR4;file is read only.
NFUNCTS     EQU 41;number of functions in following table.
FNCS:DEFW RTN;WBOOT
	DEFW RTN;GETCON
	DEFW RTN;OUTCON
	DEFW RTN;GETRDR
	DEFW RTN;PUNCH
	DEFW RTN;LIST
	DEFW RTN;DIRCIO
	DEFW RTN;GETIOB
	DEFW RTN;SETIOB
	DEFW RTN;PRTSTR
	DEFW RTN;RDBUFF
	DEFW RTN;GETCSTS
	DEFW RTN;GETVER
	DEFW RSTDSK
	DEFW SDK
	DEFW OFL
	DEFW CFL
	DEFW GETFST
	DEFW GETNXT
	DEFW DELFILE
	DEFW READSEQ
	DEFW WRTSEQ
	DEFW FCREATE
	DEFW RENFILE
	DEFW GETLOG
	DEFW GETCRNT
	DEFW PUTDMA
	DEFW GETALOC
	DEFW WPD
	DEFW GETROV
	DEFW SETATTR
	DEFW GETPARM
	DEFW GETUSER
	DEFW RDRANDOM
	DEFW WTRANDOM
	DEFW FILESIZE
	DEFW SRN
	DEFW LOGOFF
	DEFW RTN
	DEFW RTN
	DEFW WTSPECL

;BADSEC:DEFM 'Bad Sector$'
;BADSEL:DEFM 'Select$'
;FILERO:DEFM 'File '
;DISKRO:DEFM 'R/O$'
BADSEC	equ	-1
BADSEL	equ	-2
FILERO	equ	-3
DISKRO	equ	-4

EY:
__bdos:
COND	NOCPM
	ld	a,(BTD)
	or	a
	jr	nz,FB
	inc	a
	ld	(BTD),a
	call	BOOT
ENDC
FB:
FB1:EX DE,HL;save the (DE) parameters.
	LD (PAR),HL
	EX DE,HL
	LD A,E;and save register (E) in particular.
	LD (EP),A
	LD HL,0
	LD (STS),HL;clear return status.
	ADD HL,SP
	LD (UST),HL;save users stack pointer.
	LD SP,STK;and set our own.
	XOR A;clear auto select storage space.
	LD (ASF),A
	LD (AUTO),A
	LD HL,GOBACK;set return address.
	PUSH HL
	LD A,C;get function number.
	CP NFUNCTS;valid function number?
	RET NC
	LD C,E;keep single register function here.
	LD HL,FNCS;now look thru the function table.
	LD E,A
	LD D,0;(DE)=function number.
	ADD HL,DE
	ADD HL,DE;(HL)=(start of table)+2*(function number).
	LD E,(HL)
	INC HL
	LD D,(HL);now (DE)=address for this function.
	LD HL,(PAR);retrieve parameters.
	EX DE,HL;now (DE) has the original parameters.
	JP (HL);execute desired function.

ERR1:LD HL,BADSEC;bad sector message.
	RET
ERR2:LD HL,BADSEL;bad drive selected.
	RET
ERR3:LD HL,DISKRO;disk is read only.
	RET
ERR4:LD HL,FILERO;file is read only.
	RET
SETS:LD (STS),A
RTN:RET 
IOERR1:LD A,1
	JP SETS
SLER:LD HL,BSL
JHL:LD E,(HL)
	INC HL
	LD D,(HL);now (DE) contain the desired address.
	EX DE,HL
	JP (HL)
DE2HL:INC C;is count down to zero?
1:DEC C
	RET Z;yes, we are done.
	LD A,(DE);no, move one more byte.
	LD (HL),A
	INC DE
	INC HL
	JP 1b;and repeat.
SLCT:LD A,(ACT);get active disk.
	LD C,A
	CALL SELDSK;select it.
	LD A,H;valid drive?
	OR L;valid drive?
	RET Z;return if not.
	LD E,(HL);yes, get address of translation table into (DE).
	INC HL
	LD D,(HL)
	INC HL
	LD (S1),HL;save pointers to scratch areas.
	INC HL
	INC HL
	LD (S2),HL;ditto.
	INC HL
	INC HL
	LD (S3),HL;ditto.
	INC HL
	INC HL
	EX DE,HL;now save the translation table address.
	LD (XLATE),HL
	LD HL,DB;put the next 8 bytes here.
	LD C,8;they consist of the directory buffer
	CALL DE2HL;pointer, parameter block pointer,
	LD HL,(DP);check and allocation vectors.
	EX DE,HL
	LD HL,SS;move parameter block into our ram.
	LD C,15;it is 15 bytes long.
	CALL DE2HL
	LD HL,(DKS);check disk size.
	LD A,H;more than 256 blocks on this?
	LD HL,BD
	LD (HL),0FFH;set to samll.
	OR A
	JP Z,1f
	LD (HL),0;wrong, set to large.
1:LD A,0FFH;clear the zero flag.
	OR A
	RET 
HMD:CALL HOME;home the head.
	XOR A
	LD HL,(S2);set our track pointer also.
	LD (HL),A
	INC HL
	LD (HL),A
	LD HL,(S3);and our sector pointer.
	LD (HL),A
	INC HL
	LD (HL),A
	RET 
DRD:CALL READ
	JP 1f
DWT:CALL WRITE
1:OR A
	RET Z;return unless an error occured.
	LD HL,BSC;bad read/write on this sector.
	JP JHL
TKS:LD HL,(FP);get position of last accessed file
	LD C,2;in directory and compute sector #.
	CALL SHR;sector #=file-position/4.
	LD (BN),HL;save this as the block number of interest.
	LD (CKT),HL;what's it doing here too?
TKS1:LD HL,BN
	LD C,(HL);move sector number into (BC).
	INC HL
	LD B,(HL)
	LD HL,(S3);get current sector number and
	LD E,(HL);move this into (DE).
	INC HL
	LD D,(HL)
	LD HL,(S2);get current track number.
	LD A,(HL);and this into (HL).
	INC HL
	LD H,(HL)
	LD L,A
2:LD A,C;is desired sector before current one?
	SUB E
	LD A,B
	SBC A,D
	JP NC,3f
	PUSH HL;yes, decrement sectors by one track.
	LD HL,(SS);get sectors per track.
	LD A,E
	SUB L
	LD E,A
	LD A,D
	SBC A,H
	LD D,A;now we have backed up one full track.
	POP HL
	DEC HL;adjust track counter.
	JP 2b
3:PUSH HL;desired sector is after current one.
	LD HL,(SS);get sectors per track.
	ADD HL,DE;bump sector pointer to next track.
	JP C,4f
	LD A,C;is desired sector now before current one?
	SUB L
	LD A,B
	SBC A,H
	JP C,4f
	EX DE,HL;not yes, increment track counter
	POP HL;and continue until it is.
	INC HL
	JP 3b
4:POP HL;get track number (HL).
	PUSH BC
	PUSH DE
	PUSH HL
	EX DE,HL
	LD HL,(OF);adjust for first track offset.
	ADD HL,DE
	LD B,H
	LD C,L
	CALL SETTRK;select this track.
	POP DE;reset current track pointer.
	LD HL,(S2)
	LD (HL),E
	INC HL
	LD (HL),D
	POP DE
	LD HL,(S3);reset the first sector on this track.
	LD (HL),E
	INC HL
	LD (HL),D
	POP BC
	LD A,C;now subtract the desired one.
	SUB E;to make it relative (1-# sectors/track).
	LD C,A
	LD A,B
	SBC A,D
	LD B,A
	LD HL,(XLATE);translate this sector according to this table.
	EX DE,HL
	CALL SECTRN;let the bios translate it.
	LD C,L
	LD B,H
	JP SETSEC;and select it.
GETB:LD HL,BT;get logical to physical conversion.
	LD C,(HL);note that this is base 2 log of ratio.
	LD A,(SR);get record number.
1:OR A;compute (A)=(A)/2^BT.
	RRA 
	DEC C
	JP NZ,1b
	LD B,A;save result in (B).
	LD A,8
	SUB (HL)
	LD C,A;compute (C)=8-BT.
	LD A,(SE)
2:DEC C;compute (A)=SE*2^(8-BT).
	JP Z,3f
	OR A
	RLA 
	JP 2b
3:ADD A,B
	RET 
EK:LD HL,(PAR);get fcb address.
	LD DE,16;block numbers start 16 bytes into fcb.
	ADD HL,DE
	ADD HL,BC
	LD A,(BD);are we using a big-disk?
	OR A
	JP Z,1f
	LD L,(HL);no, extract an 8 bit number from the fcb.
	LD H,0
	RET 
1:ADD HL,BC;yes, extract a 16 bit number.
	LD E,(HL)
	INC HL
	LD D,(HL)
	EX DE,HL;return in (HL).
	RET 
CMB:CALL GETB
	LD C,A
	LD B,0
	CALL EK
	LD (BN),HL
	RET 
CKB:LD HL,(BN)
	LD A,L;is it zero?
	OR H
	RET 
LGC:LD A,(BT);get log2(physical/logical sectors).
	LD HL,(BN);get physical sector desired.
1:ADD HL,HL;compute logical sector number.
	DEC A;note logical sectors are 128 bytes long.
	JP NZ,1b
	LD (LS),HL;save logical sector.
	LD A,(BM);get block mask.
	LD C,A
	LD A,(SR);get next sector to access.
	AND C;extract the relative position within physical block.
	OR L;and add it too logical sector.
	LD L,A
	LD (BN),HL;and store.
	RET 
STE:LD HL,(PAR)
	LD DE,12;it is the twelth byte.
	ADD HL,DE
	RET 
HLDE:LD HL,(PAR)
	LD DE,15;record count byte (#15).
	ADD HL,DE
	EX DE,HL
	LD HL,17;next record number (#32).
	ADD HL,DE
	RET 
STD:CALL HLDE
	LD A,(HL);get and store record count byte.
	LD (SR),A
	EX DE,HL
	LD A,(HL);get and store next record number byte.
	LD (SN),A
	CALL STE;point to extent byte.
	LD A,(EM);get extent mask.
	AND (HL)
	LD (SE),A;and save extent here.
	RET 
SNR:CALL HLDE
	LD A,(MODE);get sequential flag (=1).
	CP 2;a 2 indicates that no adder is needed.
	JP NZ,1f
	XOR A;clear adder (random access?).
1:LD C,A
	LD A,(SR);get last record number.
	ADD A,C;increment record count.
	LD (HL),A;and set fcb's next record byte.
	EX DE,HL
	LD A,(SN);get next record byte from storage.
	LD (HL),A;and put this into fcb as number of records used.
	RET 
SHR:INC C
1:DEC C
	RET Z
	LD A,H
	OR A
	RRA 
	LD H,A
	LD A,L
	RRA 
	LD L,A
	JP 1b
CKS:LD C,128;length of buffer.
	LD HL,(DB);get its location.
	XOR A;clear summation byte.
1:ADD A,(HL);and compute sum ignoring carries.
	INC HL
	DEC C
	JP NZ,1b
	RET 
SHIFTL:INC C
1:DEC C
	RET Z
	ADD HL,HL;shift left 1 bit.
	JP 1b
STB:PUSH BC;save 16 bit word.
	LD A,(ACT);get active drive.
	LD C,A
	LD HL,1
	CALL SHIFTL;shift bit 0 into place.
	POP BC;now 'or' t	his with the original word.
	LD A,C
	OR L
	LD L,A;low byte done, do high byte.
	LD A,B
	OR H
	LD H,A
	RET 
GWP:LD HL,(WP);get status bytes.
	LD A,(ACT);which drive is current?
	LD C,A
	CALL SHR;shift status such that bit 0 is the
	LD A,L;one of interest for this drive.
	AND 01H;and isolate it.
	RET 
WPD:LD HL,WP;point to status word.
	LD C,(HL);set (BC) equal to the status.
	INC HL
	LD B,(HL)
	CALL STB;and set this bit according to current drive.
	LD (WP),HL;then save.
	LD HL,(DIS);now save directory size limit.
	INC HL;remember the last one.
	EX DE,HL
	LD HL,(S1);and store it here.
	LD (HL),E;put low byte.
	INC HL
	LD (HL),D;then high byte.
	RET 
CKF:CALL FCB2HL;set (HL) to file entry in directory buffer.
CKR1:LD DE,9;look at bit 7 of the ninth byte.
	ADD HL,DE
	LD A,(HL)
	RLA 
	RET NC;return if ok.
	LD HL,ROF;else, print error message and terminate.
	JP JHL
CKW:CALL GWP
	RET Z;return if ok.
	LD HL,ROD;else print message and terminate.
	JP JHL
FCB2HL:LD HL,(DB);get address of buffer.
	LD A,(FCP);relative position of file.
AHL:ADD A,L
	LD L,A
	RET NC
	INC H;take care of any carry.
	RET 
GETS2:LD HL,(PAR);get address of fcb.
	LD DE,14;relative position of 's2'.
	ADD HL,DE
	LD A,(HL);extract this byte.
	RET 
CS2:CALL GETS2;this sets (HL) pointing to it.
	LD (HL),0;now clear it.
	RET 
SS7:CALL GETS2;get the byte.
	OR 80H;and set bit 7.
	LD (HL),A;then store.
	RET 
MRF:LD HL,(FP);we are here.
	EX DE,HL
	LD HL,(S1);and don't go past here.
	LD A,E;compute difference but don't keep.
	SUB (HL)
	INC HL
	LD A,D
	SBC A,(HL);set carry if no more names.
	RET 
CKNM:CALL MRF;S1 too big?
	RET C
	INC DE;yes, reset it to (FP).
	LD (HL),D
	DEC HL
	LD (HL),E
	RET 
SUBHL:LD A,E;compute difference.
	SUB L
	LD L,A;store low byte.
	LD A,D
	SBC A,H
	LD H,A;and then high byte.
	RET 
SDR:LD C,0FFH
CKDR:LD HL,(CKT)
	EX DE,HL
	LD HL,(A1)
	CALL SUBHL
	RET NC;ok if (CKT) > (A1), so return.
	PUSH BC
	CALL CKS;else compute checksum.
	LD HL,(CV);get address of checksum table.
	EX DE,HL
	LD HL,(CKT)
	ADD HL,DE;set (HL) to point to byte for this drive.
	POP BC
	INC C;set or check ?
	JP Z,1f
	CP (HL);check them.
	RET Z;return if they are the same.
	CALL MRF;not the same, do we care?
	RET NC
	CALL WPD;yes, mark this as write protected.
	RET 
1:LD (HL),A;just set the byte.
	RET 
DRW:CALL SDR;set checksum byte.
	CALL DDM;set directory dma address.
	LD C,1;tell the bios to actually write.
	CALL DWT;then do the write.
	JP DFD
DRR:CALL DDM;set the directory dma address.
	CALL DRD;and read it.
DFD:LD HL,UD;reset the default dma address and return.
	JP 1f
DDM:LD HL,DB
1:LD C,(HL)
	INC HL
	LD B,(HL);setup (BC) and go to the bios to set it.
	JP SETDMA
MVD:LD HL,(DB);buffer is located here, and
	EX DE,HL
	LD HL,(UD);put it here.
	LD C,128;this is its length.
	JP DE2HL;move it now and return.
CKFP:LD HL,FP
	LD A,(HL)
	INC HL
	CP (HL);are both bytes the same?
	RET NZ
	INC A;yes, but are they each 0ffh?
	RET 
STFP:LD HL,0FFFFH
	LD (FP),HL
	RET 
NXEY:LD HL,(DIS);get directory entry size limit.
	EX DE,HL
	LD HL,(FP);get current count.
	INC HL;go on to the next one.
	LD (FP),HL
	CALL SUBHL;(HL)=(DIS)-(FP)
	JP NC,NXENT1;is there more room left?
	JP STFP;no. Set this flag and return.
NXENT1:LD A,(FP);get file position within directory.
	AND 03H;only look within this sector (only 4 entries fit).
	LD B,5;convert to relative position (32 bytes each).
2:ADD A,A;note that this is not efficient code.
	DEC B;5 'ADD A's would be better.
	JP NZ,2b
	LD (FCP),A;save it as position of fcb.
	OR A
	RET NZ;return if we are within buffer.
	PUSH BC
	CALL TKS;we need the next directory sector.
	CALL DRR
	POP BC
	JP CKDR
CKBMP:LD A,C;determine bit number of interest.
	AND 07H;compute (D)=(E)=(C and 7)+1.
	INC A
	LD E,A;save particular bit number.
	LD D,A
	LD A,C
	RRCA;now shift right 3 bits.
	RRCA 
	RRCA 
	AND 1FH;and clear bits 7,6,5.
	LD C,A
	LD A,B
	ADD A,A;now shift (B) into bits 7,6,5.
	ADD A,A
	ADD A,A
	ADD A,A
	ADD A,A
	OR C;and add in (C).
	LD C,A;ok, (C) ha been completed.
	LD A,B;is there a better way of doing this?
	RRCA 
	RRCA 
	RRCA 
	AND 1FH
	LD B,A;and now (B) is completed.
	LD HL,(AV)
	ADD HL,BC
	LD A,(HL);now get correct byte.
1:RLCA;get correct bit into position 0.
	DEC E
	JP NZ,1b
	RET 
STBMP:PUSH DE
	CALL CKBMP;get the byte of interest.
	AND 0FEH;clear the affected bit.
	POP BC
	OR C;and now set it acording to (C).
STBMAP1:RRCA;restore original bit position.
	DEC D
	JP NZ,STBMAP1
	LD (HL),A;and stor byte in table.
	RET 
STFL:CALL FCB2HL;get address of fcb
	LD DE,16
	ADD HL,DE;get to block number bytes.
	PUSH BC
	LD C,17;check all 17 bytes (max) of table.
1:POP DE
	DEC C;done all bytes yet?
	RET Z
	PUSH DE
	LD A,(BD);check disk size for 16 bit block numbers.
	OR A
	JP Z,2f
	PUSH BC;only 8 bit numbers. set (BC) to this one.
	PUSH HL
	LD C,(HL);get low byte from table, always
	LD B,0;set high byte to zero.
	JP 3f
2:DEC C;for 16 bit block numbers, adjust counter.
	PUSH BC
	LD C,(HL);now get both the low and high bytes.
	INC HL
	LD B,(HL)
	PUSH HL
3:LD A,C;block used?
	OR B
	JP Z,4f
	LD HL,(DKS);is this block number within the
	LD A,L;space on the disk?
	SUB C
	LD A,H
	SBC A,B
	CALL NC,STBMP;yes, set the proper bit.
4:POP HL;point to next block number in fcb.
	INC HL
	POP BC
	JP 1b
BMP:LD HL,(DKS);compute size of allocation table.
	LD C,3
	CALL SHR;(HL)=(HL)/8.
	INC HL;at lease 1 byte.
	LD B,H
	LD C,L;set (BC) to the allocation table length.
	LD HL,(AV);now zero out the table now.
1:LD (HL),0
	INC HL
	DEC BC
	LD A,B
	OR C
	JP NZ,1b
	LD HL,(A0);get initial space used by directory.
	EX DE,HL
	LD HL,(AV);and put this into map.
	LD (HL),E
	INC HL
	LD (HL),D
	CALL HMD;now home the drive.
	LD HL,(S1)
	LD (HL),3;force next directory request to read
	INC HL;in a sector.
	LD (HL),0
	CALL STFP;clear initial file position also.
2:LD C,0FFH;read next file name in directory
	CALL NXEY;and set checksum byte.
	CALL CKFP;is there another file?
	RET Z
	CALL FCB2HL;yes, get its address.
	LD A,0E5H
	CP (HL);empty file entry?
	JP Z,2b
	LD A,(USN);no, correct user number?
	CP (HL)
	JP NZ,3f
	INC HL
	LD A,(HL);yes, does name start with a '$'?
	SUB '$'
	JP NZ,3f
	DEC A;yes, set atatus to minus one.
	LD (STS),A
3:LD C,1;now set this file's space as used in bit map.
	CALL STFL
	CALL CKNM;keep (S1) in bounds.
	JP 2b
STSTS:LD A,(FS)
	JP SETS
SAMEXT:PUSH BC
	PUSH AF
	LD A,(EM);get extent mask and use it to
	CPL;to compare both extent numbers.
	LD B,A;save resulting mask here.
	LD A,C;mask first extent and save in (C).
	AND B
	LD C,A
	POP AF;now mask second extent and compare
	AND B;with the first one.
	SUB C
	AND 1FH;(* only check buts 0-4 *)
	POP BC;the zero flag is set if they are the same.
	RET;restore (BC) and return.
FDF:LD A,0FFH
	LD (FS),A
	LD HL,CT;save character count.
	LD (HL),C
	LD HL,(PAR);get filename to match.
	LD (SF),HL;and save.
	CALL STFP;clear initial file position (set to 0ffffh).
	CALL HMD;home the drive.
FNX:LD C,0;write protect the disk if changed.
	CALL NXEY;get next filename entry in directory.
	CALL CKFP;is file position = 0ffffh?
	JP Z,6f;yes, exit now then.
	LD HL,(SF);set (DE) pointing to filename to match.
	EX DE,HL
	LD A,(DE)
	CP 0E5H;empty directory entry?
	JP Z,1f;(* are we trying to reserect erased entries? *)
	PUSH DE
	CALL MRF;more files in directory?
	POP DE
	JP NC,6f;no more. Exit now.
1:CALL FCB2HL;get address of this fcb in directory.
	LD A,(CT);get number of bytes (characters) to check.
	LD C,A
	LD B,0;initialize byte position counter.
2:LD A,C;are we done with the compare?
	OR A
	JP Z,5f
	LD A,(DE);no, check next byte.
	CP '?';don't care about this character?
	JP Z,4f
	LD A,B;get bytes position in fcb.
	CP 13;don't care about the thirteenth byte either.
	JP Z,4f
	CP 12;extent byte?
	LD A,(DE)
	JP Z,3f
	SUB (HL);otherwise compare characters.
	AND 7FH
	JP NZ,FNX;not the same, check next entry.
	JP 4f;so far so good, keep checking.
3:PUSH BC;check the extent byte here.
	LD C,(HL)
	CALL SAMEXT
	POP BC
	JP NZ,FNX;not the same, look some more.
4:INC DE;bump pointers.
	INC HL
	INC B
	DEC C;adjust character counter.
	JP 2b
5:LD A,(FP);return the position of this entry.
	AND 03H
	LD (STS),A
	LD HL,FS
	LD A,(HL)
	RLA 
	RET NC
	XOR A
	LD (HL),A
	RET 
6:CALL STFP;set (FP) to 0ffffh.
	LD A,0FFH;say not located.
	JP SETS
ERF:CALL CKW;is disk write protected?
	LD C,12;only compare file names.
	CALL FDF;get first file name.
1:CALL CKFP;any found?
	RET Z;nope, we must be done.
	CALL CKF;is file read only?
	CALL FCB2HL;nope, get address of fcb and
	LD (HL),0E5H;set first byte to 'empty'.
	LD C,0;clear the space from the bit map.
	CALL STFL
	CALL DRW;now write the directory sector back out.
	CALL FNX;find the next file name.
	JP 1b;and repeat process.
FSPCE:LD D,B;set (DE) as the block that is checked.
	LD E,C
1:LD A,C;is block 0 specified?
	OR B
	JP Z,2f
	DEC BC;nope, check previous block.
	PUSH DE
	PUSH BC
	CALL CKBMP
	RRA;is this block empty?
	JP NC,3f;yes. use this.
	POP BC;nope, check some more.
	POP DE
2:LD HL,(DKS);is block (DE) within disk limits?
	LD A,E
	SUB L
	LD A,D
	SBC A,H
	JP NC,4f
	INC DE;yes, move on to next one.
	PUSH BC
	PUSH DE
	LD B,D
	LD C,E
	CALL CKBMP;check it.
	RRA;empty?
	JP NC,3f
	POP DE;nope, continue searching.
	POP BC
	JP 1b
3:RLA;reset byte.
	INC A;and set bit 0.
	CALL STBMAP1;update bit map.
	POP HL;set return registers.
	POP DE
	RET 
4:LD A,C
	OR B
	JP NZ,1b
	LD HL,0;set 'not found' status.
	RET 
FCBSET:LD C,0
	LD E,32;length of each entry.
UPD:PUSH DE
	LD B,0;set (BC) to relative byte position.
	LD HL,(PAR);get address of fcb.
	ADD HL,BC;compute starting byte.
	EX DE,HL
	CALL FCB2HL;get address of fcb to update in directory.
	POP BC;set (C) to number of bytes to change.
	CALL DE2HL
UPD1:CALL TKS;determine the track and sector affected.
	JP DRW;then write this sector out.
CHGN:CALL CKW;check for a write protected disk.
	LD C,12;match first 12 bytes of fcb only.
	CALL FDF;get first name.
	LD HL,(PAR);get address of fcb.
	LD A,(HL);get user number.
	LD DE,16;move over to desired name.
	ADD HL,DE
	LD (HL),A;keep same user number.
1:CALL CKFP;any matching file found?
	RET Z;no, we must be done.
	CALL CKF;check for read only file.
	LD C,16;start 16 bytes into fcb.
	LD E,12;and update the first 12 bytes of directory.
	CALL UPD
	CALL FNX;get te next file name.
	JP 1b;and continue.
SAVEATTR:LD C,12;match first 12 bytes.
	CALL FDF;look for first filename.
1:CALL CKFP;was one found?
	RET Z;nope, we must be done.
	LD C,0;yes, update the first 12 bytes now.
	LD E,12
	CALL UPD;update filename and write directory.
	CALL FNX;and get the next file.
	JP 1b;then continue until done.
OPN:LD C,15;compare the first 15 bytes.
	CALL FDF;get the first one in directory.
	CALL CKFP;any at all?
	RET Z
OPN1:CALL STE;point to extent byte within users fcb.
	LD A,(HL);and get it.
	PUSH AF;save it and address.
	PUSH HL
	CALL FCB2HL;point to fcb in directory.
	EX DE,HL
	LD HL,(PAR);this is the users copy.
	LD C,32;move it into users space.
	PUSH DE
	CALL DE2HL
	CALL SS7;set bit 7 in 's2' byte (unmodified).
	POP DE;now get the extent byte from this fcb.
	LD HL,12
	ADD HL,DE
	LD C,(HL);into (C).
	LD HL,15;now get the record count byte into (B).
	ADD HL,DE
	LD B,(HL)
	POP HL;keep the same extent as the user had originally.
	POP AF
	LD (HL),A
	LD A,C;is it the same as in the directory fcb?
	CP (HL)
	LD A,B;if yes, then use the same record count.
	JP Z,2f
	LD A,0;if the user specified an extent greater than
	JP C,2f;the one in the directory, then set record count to 0.
	LD A,128;otherwise set to maximum.
2:LD HL,(PAR);set record count in users fcb to (A).
	LD DE,15
	ADD HL,DE;compute relative position.
	LD (HL),A;and set the record count.
	RET 
MVW:LD A,(HL);check for a zero word.
	INC HL
	OR (HL);both bytes zero?
	DEC HL
	RET NZ;nope, just return.
	LD A,(DE);yes, move two bytes from (DE) into
	LD (HL),A;this zero space.
	INC DE
	INC HL
	LD A,(DE)
	LD (HL),A
	DEC DE;don't disturb these registers.
	DEC HL
	RET 
CLS:XOR A;clear status and file position bytes.
	LD (STS),A
	LD (FP),A
	LD (FP+1),A
	CALL GWP;get write protect bit for this drive.
	RET NZ;just return if it is set.
	CALL GETS2;else get the 's2' byte.
	AND 80H;and look at bit 7 (file unmodified?).
	RET NZ;just return if set.
	LD C,15;else look up this file in directory.
	CALL FDF
	CALL CKFP;was it found?
	RET Z;just return if not.
	LD BC,16;set (HL) pointing to records used section.
	CALL FCB2HL
	ADD HL,BC
	EX DE,HL
	LD HL,(PAR);do the same for users specified fcb.
	ADD HL,BC
	LD C,16;this many bytes are present in this extent.
1:LD A,(BD);8 or 16 bit record numbers?
	OR A
	JP Z,4f
	LD A,(HL);just 8 bit. Get one from users fcb.
	OR A
	LD A,(DE);now get one from directory fcb.
	JP NZ,2f
	LD (HL),A;users byte was zero. Update from directory.
2:OR A
	JP NZ,3f
	LD A,(HL);directories byte was zero, update from users fcb.
	LD (DE),A
3:CP (HL);if neither one of these bytes were zero,
	JP NZ,7f;then close error if they are not the same.
	JP 5f;ok so far, get to next byte in fcbs.
4:CALL MVW;update users fcb if it is zero.
	EX DE,HL
	CALL MVW;update directories fcb if it is zero.
	EX DE,HL
	LD A,(DE);if these two values are no different,
	CP (HL);then a close error occured.
	JP NZ,7f
	INC DE;check second byte.
	INC HL
	LD A,(DE)
	CP (HL)
	JP NZ,7f
	DEC C;remember 16 bit values.
5:INC DE;bump to next item in table.
	INC HL
	DEC C;there are 16 entries only.
	JP NZ,1b;continue if more to do.
	LD BC,0FFECH;backup 20 places (extent byte).
	ADD HL,BC
	EX DE,HL
	ADD HL,BC
	LD A,(DE)
	CP (HL);directory's extent already greater than the
	JP C,6f;users extent?
	LD (HL),A;no, update directory extent.
	LD BC,3;and update the record count byte in
	ADD HL,BC;directories fcb.
	EX DE,HL
	ADD HL,BC
	LD A,(HL);get from user.
	LD (DE),A;and put in directory.
6:LD A,0FFH;set 'was open and is now closed' byte.
	LD (CF),A
	JP UPD1;update the directory now.
7:LD HL,STS;set return status and then return.
	DEC (HL)
	RET 
GTEY:CALL CKW;make sure disk is not write protected.
	LD HL,(PAR);save current parameters (fcb).
	PUSH HL
	LD HL,EFCB;use special one for empty space.
	LD (PAR),HL
	LD C,1;search for first empty spot in directory.
	CALL FDF;(* only check first byte *)
	CALL CKFP;none?
	POP HL
	LD (PAR),HL;restore original fcb address.
	RET Z;return if no more space.
	EX DE,HL
	LD HL,15;point to number of records for this file.
	ADD HL,DE
	LD C,17;and clear all of this space.
	XOR A
1:LD (HL),A
	INC HL
	DEC C
	JP NZ,1b
	LD HL,13;clear the 's1' byte also.
	ADD HL,DE
	LD (HL),A
	CALL CKNM;keep (S1) within bounds.
	CALL FCBSET;write out this fcb entry to directory.
	JP SS7;set 's2' byte bit 7 (unmodified at present).
GTNX:XOR A
	LD (CF),A;clear close flag.
	CALL CLS;close this extent.
	CALL CKFP
	RET Z;not there???
	LD HL,(PAR);get extent byte.
	LD BC,12
	ADD HL,BC
	LD A,(HL);and increment it.
	INC A
	AND 1FH;keep within range 0-31.
	LD (HL),A
	JP Z,1f;overflow?
	LD B,A;mask extent byte.
	LD A,(EM)
	AND B
	LD HL,CF;check close flag (0ffh is ok).
	AND (HL)
	JP Z,2f;if zero, we must read in next extent.
	JP 3f;else, it is already in memory.
1:LD BC,2;Point to the 's2' byte.
	ADD HL,BC
	INC (HL);and bump it.
	LD A,(HL);too many extents?
	AND 0FH
	JP Z,5f;yes, set error code.
2:LD C,15;set to check first 15 bytes of fcb.
	CALL FDF;find the first one.
	CALL CKFP;none available?
	JP NZ,3f
	LD A,(RF);no extent present. Can we open an empty one?
	INC A;0ffh means reading (so not possible).
	JP Z,5f;or an error.
	CALL GTEY;we are writing, get an empty entry.
	CALL CKFP;none?
	JP Z,5f;error if true.
	JP 4f;else we are almost done.
3:CALL OPN1;open this extent.
4:CALL STD;move in updated data (rec #, extent #, etc.)
	XOR A;clear status and return.
	JP SETS
5:CALL IOERR1;set error code, clear bit 7 of 's2'
	JP SS7;so this is not written on a close.
RDS:LD A,1;set sequential access mode.
	LD (MODE),A
RDS1:LD A,0FFH;don't allow reading unwritten space.
	LD (RF),A
	CALL STD;put rec# and ext# into fcb.
	LD A,(SR);get next record to read.
	LD HL,SN;get number of records in extent.
	CP (HL);within this extent?
	JP C,2f
	CP 128;no. Is this extent fully used?
	JP NZ,3f;no. End-of-file.
	CALL GTNX;yes, open the next one.
	XOR A;reset next record to read.
	LD (SR),A
	LD A,(STS);check on open, successful?
	OR A
	JP NZ,3f;no, error.
2:CALL CMB;ok. compute block number to read.
	CALL CKB;check it. Within bounds?
	JP Z,3f;no, error.
	CALL LGC;convert (BN) to logical sector (128 byte).
	CALL TKS1;set the track and sector for this block #.
	CALL DRD;and read it.
	JP SNR;and set the next record to be accessed.
3:JP IOERR1
WTS:LD A,1;set sequential access mode.
	LD (MODE),A
WTS1:LD A,0;allow an addition empty extent to be opened.
	LD (RF),A
	CALL CKW;check write protect status.
	LD HL,(PAR)
	CALL CKR1;check for read only file, (HL) already set to fcb.
	CALL STD;put updated data into fcb.
	LD A,(SR);get record number to write.
	CP 128;within range?
	JP NC,IOERR1;no, error(?).
	CALL CMB;compute block number.
	CALL CKB;check number.
	LD C,0;is there one to write to?
	JP NZ,6f;yes, go do it.
	CALL GETB;get next block number within fcb to use.
	LD (RB),A;and save.
	LD BC,0;start looking for space from the start
	OR A;if none allocated as yet.
	JP Z,2f
	LD C,A;extract previous block number from fcb
	DEC BC;so we can be closest to it.
	CALL EK
	LD B,H
	LD C,L
2:CALL FSPCE;find the next empty block nearest number (BC).
	LD A,L;check for a zero number.
	OR H
	JP NZ,3f
	LD A,2;no more space?
	JP SETS
3:LD (BN),HL;save block number to access.
	EX DE,HL;put block number into (DE).
	LD HL,(PAR);now we must update the fcb for this
	LD BC,16;newly allocated block.
	ADD HL,BC
	LD A,(BD);8 or 16 bit block numbers?
	OR A
	LD A,(RB);(* update this entry *)
	JP Z,4f;zero means 16 bit ones.
	CALL AHL;(HL)=(HL)+(A)
	LD (HL),E;store new block number.
	JP 5f
4:LD C,A;compute spot in this 16 bit table.
	LD B,0
	ADD HL,BC
	ADD HL,BC
	LD (HL),E;stuff block number (DE) there.
	INC HL
	LD (HL),D
5:LD C,2;set (C) to indicate writing to un-used disk space.
6:LD A,(STS);are we ok so far?
	OR A
	RET NZ
	PUSH BC;yes, save write flag for bios (register C).
	CALL LGC;convert (BN) over to loical sectors.
	LD A,(MODE);get access mode flag (1=sequential,
	DEC A;0=random, 2=special?).
	DEC A
	JP NZ,9f
	POP BC
	PUSH BC
	LD A,C;get write status flag (2=writing unused space).
	DEC A
	DEC A
	JP NZ,9f
	PUSH HL
	LD HL,(DB);zero out the directory buffer.
	LD D,A;note that (A) is zero here.
7:LD (HL),A
	INC HL
	INC D;do 128 bytes.
	JP P,7b
	CALL DDM;tell the bios the dma address for directory access.
	LD HL,(LS);get sector that starts current block.
	LD C,2;set 'writing to unused space' flag.
8:LD (BN),HL;save sector to write.
	PUSH BC
	CALL TKS1;determine its track and sector numbers.
	POP BC
	CALL DWT;now write out 128 bytes of zeros.
	LD HL,(BN);get sector number.
	LD C,0;set normal write flag.
	LD A,(BM);determine if we have written the entire
	LD B,A;physical block.
	AND L
	CP B
	INC HL;prepare for the next one.
	JP NZ,8b;continue until (BM+1) sectors written.
	POP HL;reset next sector number.
	LD (BN),HL
	CALL DFD;and reset dma address.
9:CALL TKS1;determine track and sector for this write.
	POP BC;get write status flag.
	PUSH BC
	CALL DWT;and write this out.
	POP BC
	LD A,(SR);get number of records in file.
	LD HL,SN;get last record written.
	CP (HL)
	JP C,10f
	LD (HL),A;we have to update record count.
	INC (HL)
	LD C,2
;*   This area has been patched to correct disk update problem
;* when using blocking and de-blocking in the BIOS.
10:NOP;was 'dcr c'
	NOP;was 'dcr c'
	LD HL,0;was 'jnz wtseq99'
;*   End of patch.
	PUSH AF
	CALL GETS2;set 'extent written to' flag.
	AND 7FH;(* clear bit 7 *)
	LD (HL),A
	POP AF;get record count for this extent.
	CP 127;is it full?
	JP NZ,12f
	LD A,(MODE);yes, are we in sequential mode?
	CP 1
	JP NZ,12f
	CALL SNR;yes, set next record number.
	CALL GTNX;and get next empty space in directory.
	LD HL,STS;ok?
	LD A,(HL)
	OR A
	JP NZ,11f
	DEC A;yes, set record count to -1.
	LD (SR),A
11:LD (HL),0;clear status.
12:JP SNR;set next record to access.
PSN:XOR A;set random i/o flag.
	LD (MODE),A
POS1:PUSH BC;save read/write flag.
	LD HL,(PAR);get address of fcb.
	EX DE,HL
	LD HL,33;now get byte 'r0'.
	ADD HL,DE
	LD A,(HL)
	AND 7FH;keep bits 0-6 for the record number to access.
	PUSH AF
	LD A,(HL);now get bit 7 of 'r0' and bits 0-3 of 'r1'.
	RLA 
	INC HL
	LD A,(HL)
	RLA 
	AND 1FH;and save this in bits 0-4 of (C).
	LD C,A;this is the extent byte.
	LD A,(HL);now get the extra extent byte.
	RRA 
	RRA 
	RRA 
	RRA 
	AND 0FH
	LD B,A;and save it in (B).
	POP AF;get record number back to (A).
	INC HL;check overflow byte 'r2'.
	LD L,(HL)
	INC L
	DEC L
	LD L,6;prepare for error.
	JP NZ,5f;out of disk space error.
	LD HL,32;store record number into fcb.
	ADD HL,DE
	LD (HL),A
	LD HL,12;and now check the extent byte.
	ADD HL,DE
	LD A,C
	SUB (HL);same extent as before?
	JP NZ,2f
	LD HL,14;yes, check extra extent byte 's2' also.
	ADD HL,DE
	LD A,B
	SUB (HL)
	AND 7FH
	JP Z,3f;same, we are almost done then.
2:PUSH BC
	PUSH DE
	CALL CLS;close current extent.
	POP DE
	POP BC
	LD L,3;prepare for error.
	LD A,(STS)
	INC A
	JP Z,4f;close error.
	LD HL,12;put desired extent into fcb now.
	ADD HL,DE
	LD (HL),C
	LD HL,14;and store extra extent byte 's2'.
	ADD HL,DE
	LD (HL),B
	CALL OPN;try and get this extent.
	LD A,(STS);was it there?
	INC A
	JP NZ,3f
	POP BC;no. can we create a new one (writing?).
	PUSH BC
	LD L,4;prepare for error.
	INC C
	JP Z,4f;nope, reading unwritten space error.
	CALL GTEY;yes we can, try to find space.
	LD L,5;prepare for error.
	LD A,(STS)
	INC A
	JP Z,4f;out of space?
3:POP BC;restore stack.
	XOR A;and clear error code byte.
	JP SETS
4:PUSH HL
	CALL GETS2
	LD (HL),0C0H
	POP HL
5:POP BC
	LD A,L;get error code.
	LD (STS),A
	JP SS7
RDRN:LD C,0FFH;set 'read' status.
	CALL PSN;position the file to proper record.
	CALL Z,RDS1;and read it as usual (if no errors).
	RET 
WRN:LD C,0;set 'writing' flag.
	CALL PSN;position the file to proper record.
	CALL Z,WTS1;and write as usual (if no errors).
	RET 
CPRN:EX DE,HL;save fcb pointer in (DE).
	ADD HL,DE;compute relative position of record #.
	LD C,(HL);get record number into (BC).
	LD B,0
	LD HL,12;now get extent.
	ADD HL,DE
	LD A,(HL);compute (BC)=(record #)+(extent)*128.
	RRCA;move lower bit into bit 7.
	AND 80H;and ignore all other bits.
	ADD A,C;add to our record number.
	LD C,A
	LD A,0;take care of any carry.
	ADC A,B
	LD B,A
	LD A,(HL);now get the upper bits of extent into
	RRCA;bit positions 0-3.
	AND 0FH;and ignore all others.
	ADD A,B;add this in to 'r1' byte.
	LD B,A
	LD HL,14;get the 's2' byte (extra extent).
	ADD HL,DE
	LD A,(HL)
	ADD A,A;and shift it left 4 bits (bits 4-7).
	ADD A,A
	ADD A,A
	ADD A,A
	PUSH AF;save carry flag (bit 0 of flag byte).
	ADD A,B;now add extra extent into 'r1'.
	LD B,A
	PUSH AF;and save carry (overflow byte 'r2').
	POP HL;bit 0 of (L) is the overflow indicator.
	LD A,L
	POP HL;and same for first carry flag.
	OR L;either one of these set?
	AND 01H;only check the carry flags.
	RET 
RSZE:LD C,12;look thru directory for first entry with
	CALL FDF;this name.
	LD HL,(PAR);zero out the 'r0, r1, r2' bytes.
	LD DE,33
	ADD HL,DE
	PUSH HL
	LD (HL),D;note that (D)=0.
	INC HL
	LD (HL),D
	INC HL
	LD (HL),D
1:CALL CKFP;is there an extent to process?
	JP Z,3f;no, we are done.
	CALL FCB2HL;set (HL) pointing to proper fcb in dir.
	LD DE,15;point to last record in extent.
	CALL CPRN;and compute random parameters.
	POP HL
	PUSH HL;now check these values against those
	LD E,A;already in fcb.
	LD A,C;the carry flag will be set if those
	SUB (HL);in the fcb represent a larger size than
	INC HL;this extent does.
	LD A,B
	SBC A,(HL)
	INC HL
	LD A,E
	SBC A,(HL)
	JP C,2f
	LD (HL),E;we found a larger (in size) extent.
	DEC HL;stuff these values into fcb.
	LD (HL),B
	DEC HL
	LD (HL),C
2:CALL FNX;now get the next extent.
	JP 1b;continue til all done.
3:POP HL;we are done, restore the stack and
	RET;return.
SRN:LD HL,(PAR);point to fcb.
	LD DE,32;and to last used record.
	CALL CPRN;compute random position.
	LD HL,33;now stuff these values into fcb.
	ADD HL,DE
	LD (HL),C;move 'r0'.
	INC HL
	LD (HL),B;and 'r1'.
	INC HL
	LD (HL),A;and lastly 'r2'.
	RET 
LGD:LD HL,(LG);get the login vector.
	LD A,(ACT);get the default drive.
	LD C,A
	CALL SHR;position active bit for this drive
	PUSH HL;into bit 0.
	EX DE,HL
	CALL SLCT;select this drive.
	POP HL
	CALL Z,SLER;valid drive?
	LD A,L;is this a newly activated drive?
	RRA 
	RET C
	LD HL,(LG);yes, update the login vector.
	LD C,L
	LD B,H
	CALL STB
	LD (LG),HL;and save.
	JP BMP;now update the bitmap.
SDK:LD A,(EP);get parameter passed and see if this
	LD HL,ACT;represents a change in drives.
	CP (HL)
	RET Z
	LD (HL),A;yes it does, log it in.
	JP LGD
AUTOSEL:LD A,0FFH;say 'auto-select activated'.
	LD (AUTO),A
	LD HL,(PAR);get drive specified.
	LD A,(HL)
	AND 1FH;look at lower 5 bits.
	DEC A;adjust for (1=A, 2=B) etc.
	LD (EP),A;and save for the select routine.
	CP 1EH;check for 'no change' condition.
	JP NC,1f;yes, don't change.
	LD A,(ACT);we must change, save currently active
	LD (OD),A;drive.
	LD A,(HL);and save first byte of fcb also.
	LD (ASF),A;this must be non-zero.
	AND 0E0H;whats this for (bits 6,7 are used for
	LD (HL),A;something)?
	CALL SDK;select and log in this drive.
1:LD A,(USN);move user number into fcb.
	LD HL,(PAR);(* upper half of first byte *)
	OR (HL)
	LD (HL),A
	RET;and return (all done).
RSTDSK:LD HL,0;clear write protect status and log
	LD (WP),HL;in vector.
	LD (LG),HL
	XOR A;select drive 'A'.
	LD (ACT),A
	LD HL,TBUFF;setup default dma address.
	LD (UD),HL
	CALL DFD
	JP LGD;now log in drive 'A'.
OFL:CALL CS2;clear 's2' byte.
	CALL AUTOSEL;select proper disk.
	JP OPN;and open the file.
CFL:CALL AUTOSEL;select proper disk.
	JP CLS;and close the file.
GETFST:LD C,0;prepare for special search.
	EX DE,HL
	LD A,(HL);is first byte a '?'?
	CP '?'
	JP Z,1f;yes, just get very first entry (zero length match).
	CALL STE;get the extension byte from fcb.
	LD A,(HL);is it '?'? if yes, then we want
	CP '?';an entry with a specific 's2' byte.
	CALL NZ,CS2;otherwise, look for a zero 's2' byte.
	CALL AUTOSEL;select proper drive.
	LD C,15;compare bytes 0-14 in fcb (12&13 excluded).
1:CALL FDF;find an entry and then move it into
	JP MVD;the users dma space.
GETNXT:LD HL,(SF);restore pointers. note that no
	LD (PAR),HL;other dbos calls are allowed.
	CALL AUTOSEL;no error will be returned, but the
	CALL FNX;results will be wrong.
	JP MVD
DELFILE:CALL AUTOSEL;select proper drive.
	CALL ERF;erase the file.
	JP STSTS;set status and return.
READSEQ:CALL AUTOSEL;select proper drive then read.
	JP RDS
WRTSEQ:CALL AUTOSEL;select proper drive then write.
	JP WTS
FCREATE:CALL CS2;clear the 's2' byte on all creates.
	CALL AUTOSEL;select proper drive and get the next
	JP GTEY;empty directory space.
RENFILE:CALL AUTOSEL;select proper drive and then switch
	CALL CHGN;file names.
	JP STSTS
GETLOG:LD HL,(LG)
	JP GETPRM1
GETCRNT:LD A,(ACT)
	JP SETS
PUTDMA:EX DE,HL
	LD (UD),HL;save in our space and then get to
	JP DFD;the bios with this also.
GETALOC:LD HL,(AV)
	JP GETPRM1
GETROV:LD HL,(WP)
	JP GETPRM1
SETATTR:CALL AUTOSEL;select proper drive then save attributes.
	CALL SAVEATTR
	JP STSTS
GETPARM:LD HL,(DP)
GETPRM1:LD (STS),HL
	RET 
GETUSER:LD A,(EP);get parameter.
	CP 0FFH;get user number?
	JP NZ,SETUSER
	LD A,(USN);yes, just do it.
	JP SETS
SETUSER:AND 1FH;no, we should set it instead. keep low
	LD (USN),A;bits (0-4) only.
	RET 
RDRANDOM:CALL AUTOSEL;select proper drive and read.
	JP RDRN
WTRANDOM:CALL AUTOSEL;select proper drive and write.
	JP WRN
FILESIZE:CALL AUTOSEL;select proper drive and check file length
	JP RSZE
LOGOFF:LD HL,(PAR);get drives to log off.
	LD A,L;for each bit that is set, we want
	CPL;to clear that bit in (LG)
	LD E,A;and (WP).
	LD A,H
	CPL 
	LD HL,(LG);reset the login vector.
	AND H
	LD D,A
	LD A,L
	AND E
	LD E,A
	LD HL,(WP)
	EX DE,HL
	LD (LG),HL;and save.
	LD A,L;now do the write protect vector.
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	LD (WP),HL;and save. all done.
	RET 
GOBACK:LD A,(AUTO);was auto select activated?
	OR A
	JP Z,1f
	LD HL,(PAR);yes, but was a change made?
	LD (HL),0;(* reset first byte of fcb *)
	LD A,(ASF)
	OR A
	JP Z,1f
	LD (HL),A;yes, reset first byte properly.
	LD A,(OD);and get the old drive and select it.
	LD (EP),A
	CALL SDK
1:LD HL,(UST);reset the users stack pointer.
	LD SP,HL
	LD HL,(STS);get return status.
	LD A,L;force version 1.4 compatability.
	LD B,H
	RET;and go back to user.
WTSPECL:CALL AUTOSEL;select proper drive.
	LD A,2;use special write mode.
	LD (MODE),A
	LD C,0;set write indicator.
	CALL POS1;position the file.
	CALL Z,WTS1;and write (if no errors).
	RET 

ENDC
