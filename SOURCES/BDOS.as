*Include config.mac

COND	BDOS

	psect text

	GLOBAL _bdos

	GLOBAL	HOME
	GLOBAL	SELDSK
	GLOBAL	SETTRK
	GLOBAL	SETSEC
	GLOBAL	SETDMA
	GLOBAL	READ
	GLOBAL	WRITE
	GLOBAL	SECTRN
;
EMPTYFCB:DEFB 0E5H;empty directory segment indicator.
WRTPRT:DEFW 0;write protect status for all 16 drives.
LOGIN:DEFW 0;drive active word (1 bit per drive).
USERDMA:DEFW 080H;user's dma address (defaults to 80h).
SCRATCH1:DEFW 0;relative position within dir segment for file (0-3).
SCRATCH2:DEFW 0;last selected track number.
SCRATCH3:DEFW 0;last selected sector number.
DIRBUF:DEFW 0;address of directory buffer to use.
DISKPB:DEFW 0;contains address of disk parameter block.
CHKVECT:DEFW 0;address of check vector.
ALOCVECT:DEFW 0;address of allocation vector (bit map).
SECTORS:DEFW 0;sectors per track from bios.
BLKSHFT:DEFB 0;block shift.
BLKMASK:DEFB 0;block mask.
EXTMASK:DEFB 0;extent mask.
DSKSIZE:DEFW 0;disk size from bios (number of blocks-1).
DIRSIZE:DEFW 0;directory size.
ALLOC0:DEFW 0;storage for first bytes of bit map (dir space used).
ALLOC1:DEFW 0
OFFSET:DEFW 0;first usable track number.
XLATE:DEFW 0;sector translation table address.
CLOSEFLG:DEFB 0;close flag (=0ffh is extent written ok).
RDWRTFLG:DEFB 0;read/write flag (0ffh=read, 0=write).
FNDSTAT:DEFB 0;filename found status (0=found first entry).
MODE:DEFB 0;I/o mode select (0=random, 1=sequential, 2=special random).
EPARAM:DEFB 0;storage for register (E) on entry to bdos.
RELBLOCK:DEFB 0;relative position within fcb of block number written.
COUNTER:DEFB 0;byte counter for directory name searches.
SAVEFCB:DEFW 0,0;save space for address of fcb (for directory searches).
BIGDISK:DEFB 0;if =0 then disk is > 256 blocks long.
AUTO:DEFB 0;if non-zero, then auto select activated.
OLDDRV:DEFB 0;on auto select, storage for previous drive.
AUTOFLAG:DEFB 0;if non-zero, then auto select changed drives.
SAVNXT:DEFB 0;storage for next record number to access.
SAVEXT:DEFB 0;storage for extent number of file.
SAVNREC:DEFW 0;storage for number of records in file.
BLKNMBR:DEFW 0;block number (physical sector) used within a file or logical sect
LOGSECT:DEFW 0;starting logical (128 byte) sector of block (physical sector).
FCBPOS:DEFB 0;relative position within buffer for fcb of file of interest.
FILEPOS:DEFW 0;files position within directory (0 to max entries -1).
CKSUMTBL:DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
FCB:DEFB 0
 DEFM '           '
 DEFB 0,0,0,0,0
 DEFM '           '
 DEFB 0,0,0,0,0
RTNCODE:DEFB 0               ;status returned from bdos call.
CDRIVE:DEFB 0               ;currently active drive.
CHGDRV:DEFB 0               ;change in drives flag (0=no change).
NBYTES:DEFW 0               ;byte counter used by TYPE.
 DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0

TDRIVE:defs	1;current drive name and user number.
TBUFF:defs	80h;i/o buffer and command line storage.

OUTFLAG:DEFB 0;output flag (non zero means no output).
STARTING:DEFB 2;starting position for cursor.
CURPOS:DEFB 0;cursor position (0=start of line).
PRTFLAG:DEFB 0;printer flag (control-p toggle). List if non zero.
CHARBUF:DEFB 0;single input character buffer.
USRSTACK:DEFW 0;save users stack pointer here.
 DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
 DEFB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
STKAREA:;end of stack area.
USERNO:DEFB 0;current user number.
ACTIVE:DEFB 0;currently active drive.
PARAMS:DEFW 0;save (DE) parameters here on entry.
STATUS:DEFW 0;status returned from bdos function.
BADSCTR:DEFW ERROR1;bad sector on read or write.
BADSLCT:DEFW ERROR2;bad disk select.
RODISK:DEFW ERROR3;disk is read only.
ROFILE:DEFW ERROR4;file is read only.
NFUNCTS     EQU 41;number of functions in following table.
FUNCTNS:DEFW RTN;WBOOT
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
	DEFW SETDSK
	DEFW OPENFIL
	DEFW CLOSEFIL
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
	DEFW WRTPRTD
	DEFW GETROV
	DEFW SETATTR
	DEFW GETPARM
	DEFW GETUSER
	DEFW RDRANDOM
	DEFW WTRANDOM
	DEFW FILESIZE
	DEFW SETRAN
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

ENTRY:
_bdos:
FBASE:
FBASE1:EX DE,HL;save the (DE) parameters.
	LD (PARAMS),HL
	EX DE,HL
	LD A,E;and save register (E) in particular.
	LD (EPARAM),A
	LD HL,0
	LD (STATUS),HL;clear return status.
	ADD HL,SP
	LD (USRSTACK),HL;save users stack pointer.
	LD SP,STKAREA;and set our own.
	XOR A;clear auto select storage space.
	LD (AUTOFLAG),A
	LD (AUTO),A
	LD HL,GOBACK;set return address.
	PUSH HL
	LD A,C;get function number.
	CP NFUNCTS;valid function number?
	RET NC
	LD C,E;keep single register function here.
	LD HL,FUNCTNS;now look thru the function table.
	LD E,A
	LD D,0;(DE)=function number.
	ADD HL,DE
	ADD HL,DE;(HL)=(start of table)+2*(function number).
	LD E,(HL)
	INC HL
	LD D,(HL);now (DE)=address for this function.
	LD HL,(PARAMS);retrieve parameters.
	EX DE,HL;now (DE) has the original parameters.
	JP (HL);execute desired function.

RESDSK:LD C,13
	JP ENTRY
DSKSEL:LD E,A
	LD C,14
	JP ENTRY
ENTRY1:CALL ENTRY
	LD (RTNCODE),A;save return code.
	INC A;set zero if 0ffh returned.
	RET 
OPEN:LD C,15
	JP ENTRY1
OPENFCB:XOR A;clear the record number byte at fcb+32
	LD (FCB+32),A
	LD DE,FCB
	JP OPEN
CLOSE:LD C,16
	JP ENTRY1
SRCHFST:LD C,17
	JP ENTRY1
SRCHNXT:LD C,18
	JP ENTRY1
SRCHFCB:LD DE,FCB
	JP SRCHFST
DELETE:LD C,19
	JP ENTRY
ENTRY2:CALL ENTRY
	OR A;set zero flag if appropriate.
	RET 
RDREC:LD C,20
	JP ENTRY2
READFCB:LD DE,FCB
	JP RDREC
WRTREC:LD C,21
	JP ENTRY2
CREATE:LD C,22
	JP ENTRY1
RENAM:LD C,23
	JP ENTRY
GETUSR:LD E,0FFH
GETSETUC:LD C,32
	JP ENTRY
SETCDRV:CALL GETUSR;get user number
	ADD A,A;and shift into the upper 4 bits.
	ADD A,A
	ADD A,A
	ADD A,A
	LD HL,CDRIVE;now add in the current drive number.
	OR (HL)
	LD (TDRIVE),A;and save.
	RET 
MOVECD:LD A,(CDRIVE)
	LD (TDRIVE),A
	RET 
GETDSK:LD C,25
	JP ENTRY
STDDMA:LD DE,TBUFF
DMASET:LD C,26
	JP ENTRY
ERROR1:LD HL,BADSEC;bad sector message.
	ld	(STATUS),hl
	RET
ERROR2:LD HL,BADSEL;bad drive selected.
	ld	(STATUS),hl
	RET
ERROR3:LD HL,DISKRO;disk is read only.
	ld	(STATUS),hl
	RET
ERROR4:LD HL,FILERO;file is read only.
	ld	(STATUS),hl
	RET

SETSTAT:LD (STATUS),A
RTN:RET 
IOERR1:LD A,1
	JP SETSTAT
SLCTERR:LD HL,BADSLCT
JUMPHL:LD E,(HL)
	INC HL
	LD D,(HL);now (DE) contain the desired address.
	EX DE,HL
	JP (HL)
DE2HL:INC C;is count down to zero?
DE2HL1:DEC C
	RET Z;yes, we are done.
	LD A,(DE);no, move one more byte.
	LD (HL),A
	INC DE
	INC HL
	JP DE2HL1;and repeat.
SELECT:LD A,(ACTIVE);get active disk.
	LD C,A
	CALL SELDSK;select it.
	LD A,H;valid drive?
	OR L;valid drive?
	RET Z;return if not.
	LD E,(HL);yes, get address of translation table into (DE).
	INC HL
	LD D,(HL)
	INC HL
	LD (SCRATCH1),HL;save pointers to scratch areas.
	INC HL
	INC HL
	LD (SCRATCH2),HL;ditto.
	INC HL
	INC HL
	LD (SCRATCH3),HL;ditto.
	INC HL
	INC HL
	EX DE,HL;now save the translation table address.
	LD (XLATE),HL
	LD HL,DIRBUF;put the next 8 bytes here.
	LD C,8;they consist of the directory buffer
	CALL DE2HL;pointer, parameter block pointer,
	LD HL,(DISKPB);check and allocation vectors.
	EX DE,HL
	LD HL,SECTORS;move parameter block into our ram.
	LD C,15;it is 15 bytes long.
	CALL DE2HL
	LD HL,(DSKSIZE);check disk size.
	LD A,H;more than 256 blocks on this?
	LD HL,BIGDISK
	LD (HL),0FFH;set to samll.
	OR A
	JP Z,SELECT1
	LD (HL),0;wrong, set to large.
SELECT1:LD A,0FFH;clear the zero flag.
	OR A
	RET 
HOMEDRV:CALL HOME;home the head.
	XOR A
	LD HL,(SCRATCH2);set our track pointer also.
	LD (HL),A
	INC HL
	LD (HL),A
	LD HL,(SCRATCH3);and our sector pointer.
	LD (HL),A
	INC HL
	LD (HL),A
	RET 
DOREAD:CALL READ
	JP IORET
DOWRITE:CALL WRITE
IORET:OR A
	RET Z;return unless an error occured.
	LD HL,BADSCTR;bad read/write on this sector.
	JP JUMPHL
TRKSEC:LD HL,(FILEPOS);get position of last accessed file
	LD C,2;in directory and compute sector #.
	CALL SHIFTR;sector #=file-position/4.
	LD (BLKNMBR),HL;save this as the block number of interest.
	LD (CKSUMTBL),HL;what's it doing here too?
TRKSEC1:LD HL,BLKNMBR
	LD C,(HL);move sector number into (BC).
	INC HL
	LD B,(HL)
	LD HL,(SCRATCH3);get current sector number and
	LD E,(HL);move this into (DE).
	INC HL
	LD D,(HL)
	LD HL,(SCRATCH2);get current track number.
	LD A,(HL);and this into (HL).
	INC HL
	LD H,(HL)
	LD L,A
TRKSEC2:LD A,C;is desired sector before current one?
	SUB E
	LD A,B
	SBC A,D
	JP NC,TRKSEC3
	PUSH HL;yes, decrement sectors by one track.
	LD HL,(SECTORS);get sectors per track.
	LD A,E
	SUB L
	LD E,A
	LD A,D
	SBC A,H
	LD D,A;now we have backed up one full track.
	POP HL
	DEC HL;adjust track counter.
	JP TRKSEC2
TRKSEC3:PUSH HL;desired sector is after current one.
	LD HL,(SECTORS);get sectors per track.
	ADD HL,DE;bump sector pointer to next track.
	JP C,TRKSEC4
	LD A,C;is desired sector now before current one?
	SUB L
	LD A,B
	SBC A,H
	JP C,TRKSEC4
	EX DE,HL;not yes, increment track counter
	POP HL;and continue until it is.
	INC HL
	JP TRKSEC3
TRKSEC4:POP HL;get track number (HL).
	PUSH BC
	PUSH DE
	PUSH HL
	EX DE,HL
	LD HL,(OFFSET);adjust for first track offset.
	ADD HL,DE
	LD B,H
	LD C,L
	CALL SETTRK;select this track.
	POP DE;reset current track pointer.
	LD HL,(SCRATCH2)
	LD (HL),E
	INC HL
	LD (HL),D
	POP DE
	LD HL,(SCRATCH3);reset the first sector on this track.
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
GETBLOCK:LD HL,BLKSHFT;get logical to physical conversion.
	LD C,(HL);note that this is base 2 log of ratio.
	LD A,(SAVNREC);get record number.
GETBLK1:OR A;compute (A)=(A)/2^BLKSHFT.
	RRA 
	DEC C
	JP NZ,GETBLK1
	LD B,A;save result in (B).
	LD A,8
	SUB (HL)
	LD C,A;compute (C)=8-BLKSHFT.
	LD A,(SAVEXT)
GETBLK2:DEC C;compute (A)=SAVEXT*2^(8-BLKSHFT).
	JP Z,GETBLK3
	OR A
	RLA 
	JP GETBLK2
GETBLK3:ADD A,B
	RET 
EXTBLK:LD HL,(PARAMS);get fcb address.
	LD DE,16;block numbers start 16 bytes into fcb.
	ADD HL,DE
	ADD HL,BC
	LD A,(BIGDISK);are we using a big-disk?
	OR A
	JP Z,EXTBLK1
	LD L,(HL);no, extract an 8 bit number from the fcb.
	LD H,0
	RET 
EXTBLK1:ADD HL,BC;yes, extract a 16 bit number.
	LD E,(HL)
	INC HL
	LD D,(HL)
	EX DE,HL;return in (HL).
	RET 
COMBLK:CALL GETBLOCK
	LD C,A
	LD B,0
	CALL EXTBLK
	LD (BLKNMBR),HL
	RET 
CHKBLK:LD HL,(BLKNMBR)
	LD A,L;is it zero?
	OR H
	RET 
LOGICAL:LD A,(BLKSHFT);get log2(physical/logical sectors).
	LD HL,(BLKNMBR);get physical sector desired.
LOGICL1:ADD HL,HL;compute logical sector number.
	DEC A;note logical sectors are 128 bytes long.
	JP NZ,LOGICL1
	LD (LOGSECT),HL;save logical sector.
	LD A,(BLKMASK);get block mask.
	LD C,A
	LD A,(SAVNREC);get next sector to access.
	AND C;extract the relative position within physical block.
	OR L;and add it too logical sector.
	LD L,A
	LD (BLKNMBR),HL;and store.
	RET 
SETEXT:LD HL,(PARAMS)
	LD DE,12;it is the twelth byte.
	ADD HL,DE
	RET 
SETHLDE:LD HL,(PARAMS)
	LD DE,15;record count byte (#15).
	ADD HL,DE
	EX DE,HL
	LD HL,17;next record number (#32).
	ADD HL,DE
	RET 
STRDATA:CALL SETHLDE
	LD A,(HL);get and store record count byte.
	LD (SAVNREC),A
	EX DE,HL
	LD A,(HL);get and store next record number byte.
	LD (SAVNXT),A
	CALL SETEXT;point to extent byte.
	LD A,(EXTMASK);get extent mask.
	AND (HL)
	LD (SAVEXT),A;and save extent here.
	RET 
SETNREC:CALL SETHLDE
	LD A,(MODE);get sequential flag (=1).
	CP 2;a 2 indicates that no adder is needed.
	JP NZ,STNREC1
	XOR A;clear adder (random access?).
STNREC1:LD C,A
	LD A,(SAVNREC);get last record number.
	ADD A,C;increment record count.
	LD (HL),A;and set fcb's next record byte.
	EX DE,HL
	LD A,(SAVNXT);get next record byte from storage.
	LD (HL),A;and put this into fcb as number of records used.
	RET 
SHIFTR:INC C
SHIFTR1:DEC C
	RET Z
	LD A,H
	OR A
	RRA 
	LD H,A
	LD A,L
	RRA 
	LD L,A
	JP SHIFTR1
CHECKSUM:LD C,128;length of buffer.
	LD HL,(DIRBUF);get its location.
	XOR A;clear summation byte.
CHKSUM1:ADD A,(HL);and compute sum ignoring carries.
	INC HL
	DEC C
	JP NZ,CHKSUM1
	RET 
SHIFTL:INC C
SHIFTL1:DEC C
	RET Z
	ADD HL,HL;shift left 1 bit.
	JP SHIFTL1
SETBIT:PUSH BC;save 16 bit word.
	LD A,(ACTIVE);get active drive.
	LD C,A
	LD HL,1
	CALL SHIFTL;shift bit 0 into place.
	POP BC;now 'or' this with the original word.
	LD A,C
	OR L
	LD L,A;low byte done, do high byte.
	LD A,B
	OR H
	LD H,A
	RET 
GETWPRT:LD HL,(WRTPRT);get status bytes.
	LD A,(ACTIVE);which drive is current?
	LD C,A
	CALL SHIFTR;shift status such that bit 0 is the
	LD A,L;one of interest for this drive.
	AND 01H;and isolate it.
	RET 
WRTPRTD:LD HL,WRTPRT;point to status word.
	LD C,(HL);set (BC) equal to the status.
	INC HL
	LD B,(HL)
	CALL SETBIT;and set this bit according to current drive.
	LD (WRTPRT),HL;then save.
	LD HL,(DIRSIZE);now save directory size limit.
	INC HL;remember the last one.
	EX DE,HL
	LD HL,(SCRATCH1);and store it here.
	LD (HL),E;put low byte.
	INC HL
	LD (HL),D;then high byte.
	RET 
CHKROFL:CALL FCB2HL;set (HL) to file entry in directory buffer.
CKROF1:LD DE,9;look at bit 7 of the ninth byte.
	ADD HL,DE
	LD A,(HL)
	RLA 
	RET NC;return if ok.
	LD HL,ROFILE;else, print error message and terminate.
	JP JUMPHL
CHKWPRT:CALL GETWPRT
	RET Z;return if ok.
	LD HL,RODISK;else print message and terminate.
	JP JUMPHL
FCB2HL:LD HL,(DIRBUF);get address of buffer.
	LD A,(FCBPOS);relative position of file.
ADDA2HL:ADD A,L
	LD L,A
	RET NC
	INC H;take care of any carry.
	RET 
GETS2:LD HL,(PARAMS);get address of fcb.
	LD DE,14;relative position of 's2'.
	ADD HL,DE
	LD A,(HL);extract this byte.
	RET 
CLEARS2:CALL GETS2;this sets (HL) pointing to it.
	LD (HL),0;now clear it.
	RET 
SETS2B7:CALL GETS2;get the byte.
	OR 80H;and set bit 7.
	LD (HL),A;then store.
	RET 
MOREFLS:LD HL,(FILEPOS);we are here.
	EX DE,HL
	LD HL,(SCRATCH1);and don't go past here.
	LD A,E;compute difference but don't keep.
	SUB (HL)
	INC HL
	LD A,D
	SBC A,(HL);set carry if no more names.
	RET 
CHKNMBR:CALL MOREFLS;SCRATCH1 too big?
	RET C
	INC DE;yes, reset it to (FILEPOS).
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
SETDIR:LD C,0FFH
CHECKDIR:LD HL,(CKSUMTBL)
	EX DE,HL
	LD HL,(ALLOC1)
	CALL SUBHL
	RET NC;ok if (CKSUMTBL) > (ALLOC1), so return.
	PUSH BC
	CALL CHECKSUM;else compute checksum.
	LD HL,(CHKVECT);get address of checksum table.
	EX DE,HL
	LD HL,(CKSUMTBL)
	ADD HL,DE;set (HL) to point to byte for this drive.
	POP BC
	INC C;set or check ?
	JP Z,CHKDIR1
	CP (HL);check them.
	RET Z;return if they are the same.
	CALL MOREFLS;not the same, do we care?
	RET NC
	CALL WRTPRTD;yes, mark this as write protected.
	RET 
CHKDIR1:LD (HL),A;just set the byte.
	RET 
DIRWRITE:CALL SETDIR;set checksum byte.
	CALL DIRDMA;set directory dma address.
	LD C,1;tell the bios to actually write.
	CALL DOWRITE;then do the write.
	JP DEFDMA
DIRREAD:CALL DIRDMA;set the directory dma address.
	CALL DOREAD;and read it.
DEFDMA:LD HL,USERDMA;reset the default dma address and return.
	JP DIRDMA1
DIRDMA:LD HL,DIRBUF
DIRDMA1:LD C,(HL)
	INC HL
	LD B,(HL);setup (BC) and go to the bios to set it.
	JP SETDMA
MOVEDIR:LD HL,(DIRBUF);buffer is located here, and
	EX DE,HL
	LD HL,(USERDMA);put it here.
	LD C,128;this is its length.
	JP DE2HL;move it now and return.
CKFILPOS:LD HL,FILEPOS
	LD A,(HL)
	INC HL
	CP (HL);are both bytes the same?
	RET NZ
	INC A;yes, but are they each 0ffh?
	RET 
STFILPOS:LD HL,0FFFFH
	LD (FILEPOS),HL
	RET 
NXENTRY:LD HL,(DIRSIZE);get directory entry size limit.
	EX DE,HL
	LD HL,(FILEPOS);get current count.
	INC HL;go on to the next one.
	LD (FILEPOS),HL
	CALL SUBHL;(HL)=(DIRSIZE)-(FILEPOS)
	JP NC,NXENT1;is there more room left?
	JP STFILPOS;no. Set this flag and return.
NXENT1:LD A,(FILEPOS);get file position within directory.
	AND 03H;only look within this sector (only 4 entries fit).
	LD B,5;convert to relative position (32 bytes each).
NXENT2:ADD A,A;note that this is not efficient code.
	DEC B;5 'ADD A's would be better.
	JP NZ,NXENT2
	LD (FCBPOS),A;save it as position of fcb.
	OR A
	RET NZ;return if we are within buffer.
	PUSH BC
	CALL TRKSEC;we need the next directory sector.
	CALL DIRREAD
	POP BC
	JP CHECKDIR
CKBITMAP:LD A,C;determine bit number of interest.
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
	LD HL,(ALOCVECT)
	ADD HL,BC
	LD A,(HL);now get correct byte.
CKBMAP1:RLCA;get correct bit into position 0.
	DEC E
	JP NZ,CKBMAP1
	RET 
STBITMAP:PUSH DE
	CALL CKBITMAP;get the byte of interest.
	AND 0FEH;clear the affected bit.
	POP BC
	OR C;and now set it acording to (C).
STBMAP1:RRCA;restore original bit position.
	DEC D
	JP NZ,STBMAP1
	LD (HL),A;and stor byte in table.
	RET 
SETFILE:CALL FCB2HL;get address of fcb
	LD DE,16
	ADD HL,DE;get to block number bytes.
	PUSH BC
	LD C,17;check all 17 bytes (max) of table.
SETFL1:POP DE
	DEC C;done all bytes yet?
	RET Z
	PUSH DE
	LD A,(BIGDISK);check disk size for 16 bit block numbers.
	OR A
	JP Z,SETFL2
	PUSH BC;only 8 bit numbers. set (BC) to this one.
	PUSH HL
	LD C,(HL);get low byte from table, always
	LD B,0;set high byte to zero.
	JP SETFL3
SETFL2:DEC C;for 16 bit block numbers, adjust counter.
	PUSH BC
	LD C,(HL);now get both the low and high bytes.
	INC HL
	LD B,(HL)
	PUSH HL
SETFL3:LD A,C;block used?
	OR B
	JP Z,SETFL4
	LD HL,(DSKSIZE);is this block number within the
	LD A,L;space on the disk?
	SUB C
	LD A,H
	SBC A,B
	CALL NC,STBITMAP;yes, set the proper bit.
SETFL4:POP HL;point to next block number in fcb.
	INC HL
	POP BC
	JP SETFL1
BITMAP:LD HL,(DSKSIZE);compute size of allocation table.
	LD C,3
	CALL SHIFTR;(HL)=(HL)/8.
	INC HL;at lease 1 byte.
	LD B,H
	LD C,L;set (BC) to the allocation table length.
	LD HL,(ALOCVECT);now zero out the table now.
BITMAP1:LD (HL),0
	INC HL
	DEC BC
	LD A,B
	OR C
	JP NZ,BITMAP1
	LD HL,(ALLOC0);get initial space used by directory.
	EX DE,HL
	LD HL,(ALOCVECT);and put this into map.
	LD (HL),E
	INC HL
	LD (HL),D
	CALL HOMEDRV;now home the drive.
	LD HL,(SCRATCH1)
	LD (HL),3;force next directory request to read
	INC HL;in a sector.
	LD (HL),0
	CALL STFILPOS;clear initial file position also.
BITMAP2:LD C,0FFH;read next file name in directory
	CALL NXENTRY;and set checksum byte.
	CALL CKFILPOS;is there another file?
	RET Z
	CALL FCB2HL;yes, get its address.
	LD A,0E5H
	CP (HL);empty file entry?
	JP Z,BITMAP2
	LD A,(USERNO);no, correct user number?
	CP (HL)
	JP NZ,BITMAP3
	INC HL
	LD A,(HL);yes, does name start with a '$'?
	SUB '$'
	JP NZ,BITMAP3
	DEC A;yes, set atatus to minus one.
	LD (STATUS),A
BITMAP3:LD C,1;now set this file's space as used in bit map.
	CALL SETFILE
	CALL CHKNMBR;keep (SCRATCH1) in bounds.
	JP BITMAP2
STSTATUS:LD A,(FNDSTAT)
	JP SETSTAT
SAMEXT:PUSH BC
	PUSH AF
	LD A,(EXTMASK);get extent mask and use it to
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
FINDFST:LD A,0FFH
	LD (FNDSTAT),A
	LD HL,COUNTER;save character count.
	LD (HL),C
	LD HL,(PARAMS);get filename to match.
	LD (SAVEFCB),HL;and save.
	CALL STFILPOS;clear initial file position (set to 0ffffh).
	CALL HOMEDRV;home the drive.
FINDNXT:LD C,0;write protect the disk if changed.
	CALL NXENTRY;get next filename entry in directory.
	CALL CKFILPOS;is file position = 0ffffh?
	JP Z,FNDNXT6;yes, exit now then.
	LD HL,(SAVEFCB);set (DE) pointing to filename to match.
	EX DE,HL
	LD A,(DE)
	CP 0E5H;empty directory entry?
	JP Z,FNDNXT1;(* are we trying to reserect erased entries? *)
	PUSH DE
	CALL MOREFLS;more files in directory?
	POP DE
	JP NC,FNDNXT6;no more. Exit now.
FNDNXT1:CALL FCB2HL;get address of this fcb in directory.
	LD A,(COUNTER);get number of bytes (characters) to check.
	LD C,A
	LD B,0;initialize byte position counter.
FNDNXT2:LD A,C;are we done with the compare?
	OR A
	JP Z,FNDNXT5
	LD A,(DE);no, check next byte.
	CP '?';don't care about this character?
	JP Z,FNDNXT4
	LD A,B;get bytes position in fcb.
	CP 13;don't care about the thirteenth byte either.
	JP Z,FNDNXT4
	CP 12;extent byte?
	LD A,(DE)
	JP Z,FNDNXT3
	SUB (HL);otherwise compare characters.
	AND 7FH
	JP NZ,FINDNXT;not the same, check next entry.
	JP FNDNXT4;so far so good, keep checking.
FNDNXT3:PUSH BC;check the extent byte here.
	LD C,(HL)
	CALL SAMEXT
	POP BC
	JP NZ,FINDNXT;not the same, look some more.
FNDNXT4:INC DE;bump pointers.
	INC HL
	INC B
	DEC C;adjust character counter.
	JP FNDNXT2
FNDNXT5:LD A,(FILEPOS);return the position of this entry.
	AND 03H
	LD (STATUS),A
	LD HL,FNDSTAT
	LD A,(HL)
	RLA 
	RET NC
	XOR A
	LD (HL),A
	RET 
FNDNXT6:CALL STFILPOS;set (FILEPOS) to 0ffffh.
	LD A,0FFH;say not located.
	JP SETSTAT
ERAFILE:CALL CHKWPRT;is disk write protected?
	LD C,12;only compare file names.
	CALL FINDFST;get first file name.
ERAFIL1:CALL CKFILPOS;any found?
	RET Z;nope, we must be done.
	CALL CHKROFL;is file read only?
	CALL FCB2HL;nope, get address of fcb and
	LD (HL),0E5H;set first byte to 'empty'.
	LD C,0;clear the space from the bit map.
	CALL SETFILE
	CALL DIRWRITE;now write the directory sector back out.
	CALL FINDNXT;find the next file name.
	JP ERAFIL1;and repeat process.
FNDSPACE:LD D,B;set (DE) as the block that is checked.
	LD E,C
FNDSPA1:LD A,C;is block 0 specified?
	OR B
	JP Z,FNDSPA2
	DEC BC;nope, check previous block.
	PUSH DE
	PUSH BC
	CALL CKBITMAP
	RRA;is this block empty?
	JP NC,FNDSPA3;yes. use this.
	POP BC;nope, check some more.
	POP DE
FNDSPA2:LD HL,(DSKSIZE);is block (DE) within disk limits?
	LD A,E
	SUB L
	LD A,D
	SBC A,H
	JP NC,FNDSPA4
	INC DE;yes, move on to next one.
	PUSH BC
	PUSH DE
	LD B,D
	LD C,E
	CALL CKBITMAP;check it.
	RRA;empty?
	JP NC,FNDSPA3
	POP DE;nope, continue searching.
	POP BC
	JP FNDSPA1
FNDSPA3:RLA;reset byte.
	INC A;and set bit 0.
	CALL STBMAP1;update bit map.
	POP HL;set return registers.
	POP DE
	RET 
FNDSPA4:LD A,C
	OR B
	JP NZ,FNDSPA1
	LD HL,0;set 'not found' status.
	RET 
FCBSET:LD C,0
	LD E,32;length of each entry.
UPDATE:PUSH DE
	LD B,0;set (BC) to relative byte position.
	LD HL,(PARAMS);get address of fcb.
	ADD HL,BC;compute starting byte.
	EX DE,HL
	CALL FCB2HL;get address of fcb to update in directory.
	POP BC;set (C) to number of bytes to change.
	CALL DE2HL
UPDATE1:CALL TRKSEC;determine the track and sector affected.
	JP DIRWRITE;then write this sector out.
CHGNAMES:CALL CHKWPRT;check for a write protected disk.
	LD C,12;match first 12 bytes of fcb only.
	CALL FINDFST;get first name.
	LD HL,(PARAMS);get address of fcb.
	LD A,(HL);get user number.
	LD DE,16;move over to desired name.
	ADD HL,DE
	LD (HL),A;keep same user number.
CHGNAM1:CALL CKFILPOS;any matching file found?
	RET Z;no, we must be done.
	CALL CHKROFL;check for read only file.
	LD C,16;start 16 bytes into fcb.
	LD E,12;and update the first 12 bytes of directory.
	CALL UPDATE
	CALL FINDNXT;get te next file name.
	JP CHGNAM1;and continue.
SAVEATTR:LD C,12;match first 12 bytes.
	CALL FINDFST;look for first filename.
SAVATR1:CALL CKFILPOS;was one found?
	RET Z;nope, we must be done.
	LD C,0;yes, update the first 12 bytes now.
	LD E,12
	CALL UPDATE;update filename and write directory.
	CALL FINDNXT;and get the next file.
	JP SAVATR1;then continue until done.
OPENIT:LD C,15;compare the first 15 bytes.
	CALL FINDFST;get the first one in directory.
	CALL CKFILPOS;any at all?
	RET Z
OPENIT1:CALL SETEXT;point to extent byte within users fcb.
	LD A,(HL);and get it.
	PUSH AF;save it and address.
	PUSH HL
	CALL FCB2HL;point to fcb in directory.
	EX DE,HL
	LD HL,(PARAMS);this is the users copy.
	LD C,32;move it into users space.
	PUSH DE
	CALL DE2HL
	CALL SETS2B7;set bit 7 in 's2' byte (unmodified).
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
	JP Z,OPENIT2
	LD A,0;if the user specified an extent greater than
	JP C,OPENIT2;the one in the directory, then set record count to 0.
	LD A,128;otherwise set to maximum.
OPENIT2:LD HL,(PARAMS);set record count in users fcb to (A).
	LD DE,15
	ADD HL,DE;compute relative position.
	LD (HL),A;and set the record count.
	RET 
MOVEWORD:LD A,(HL);check for a zero word.
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
CLOSEIT:XOR A;clear status and file position bytes.
	LD (STATUS),A
	LD (FILEPOS),A
	LD (FILEPOS+1),A
	CALL GETWPRT;get write protect bit for this drive.
	RET NZ;just return if it is set.
	CALL GETS2;else get the 's2' byte.
	AND 80H;and look at bit 7 (file unmodified?).
	RET NZ;just return if set.
	LD C,15;else look up this file in directory.
	CALL FINDFST
	CALL CKFILPOS;was it found?
	RET Z;just return if not.
	LD BC,16;set (HL) pointing to records used section.
	CALL FCB2HL
	ADD HL,BC
	EX DE,HL
	LD HL,(PARAMS);do the same for users specified fcb.
	ADD HL,BC
	LD C,16;this many bytes are present in this extent.
CLOSEIT1:LD A,(BIGDISK);8 or 16 bit record numbers?
	OR A
	JP Z,CLOSEIT4
	LD A,(HL);just 8 bit. Get one from users fcb.
	OR A
	LD A,(DE);now get one from directory fcb.
	JP NZ,CLOSEIT2
	LD (HL),A;users byte was zero. Update from directory.
CLOSEIT2:OR A
	JP NZ,CLOSEIT3
	LD A,(HL);directories byte was zero, update from users fcb.
	LD (DE),A
CLOSEIT3:CP (HL);if neither one of these bytes were zero,
	JP NZ,CLOSEIT7;then close error if they are not the same.
	JP CLOSEIT5;ok so far, get to next byte in fcbs.
CLOSEIT4:CALL MOVEWORD;update users fcb if it is zero.
	EX DE,HL
	CALL MOVEWORD;update directories fcb if it is zero.
	EX DE,HL
	LD A,(DE);if these two values are no different,
	CP (HL);then a close error occured.
	JP NZ,CLOSEIT7
	INC DE;check second byte.
	INC HL
	LD A,(DE)
	CP (HL)
	JP NZ,CLOSEIT7
	DEC C;remember 16 bit values.
CLOSEIT5:INC DE;bump to next item in table.
	INC HL
	DEC C;there are 16 entries only.
	JP NZ,CLOSEIT1;continue if more to do.
	LD BC,0FFECH;backup 20 places (extent byte).
	ADD HL,BC
	EX DE,HL
	ADD HL,BC
	LD A,(DE)
	CP (HL);directory's extent already greater than the
	JP C,CLOSEIT6;users extent?
	LD (HL),A;no, update directory extent.
	LD BC,3;and update the record count byte in
	ADD HL,BC;directories fcb.
	EX DE,HL
	ADD HL,BC
	LD A,(HL);get from user.
	LD (DE),A;and put in directory.
CLOSEIT6:LD A,0FFH;set 'was open and is now closed' byte.
	LD (CLOSEFLG),A
	JP UPDATE1;update the directory now.
CLOSEIT7:LD HL,STATUS;set return status and then return.
	DEC (HL)
	RET 
GETEMPTY:CALL CHKWPRT;make sure disk is not write protected.
	LD HL,(PARAMS);save current parameters (fcb).
	PUSH HL
	LD HL,EMPTYFCB;use special one for empty space.
	LD (PARAMS),HL
	LD C,1;search for first empty spot in directory.
	CALL FINDFST;(* only check first byte *)
	CALL CKFILPOS;none?
	POP HL
	LD (PARAMS),HL;restore original fcb address.
	RET Z;return if no more space.
	EX DE,HL
	LD HL,15;point to number of records for this file.
	ADD HL,DE
	LD C,17;and clear all of this space.
	XOR A
GETMT1:LD (HL),A
	INC HL
	DEC C
	JP NZ,GETMT1
	LD HL,13;clear the 's1' byte also.
	ADD HL,DE
	LD (HL),A
	CALL CHKNMBR;keep (SCRATCH1) within bounds.
	CALL FCBSET;write out this fcb entry to directory.
	JP SETS2B7;set 's2' byte bit 7 (unmodified at present).
GETNEXT:XOR A
	LD (CLOSEFLG),A;clear close flag.
	CALL CLOSEIT;close this extent.
	CALL CKFILPOS
	RET Z;not there???
	LD HL,(PARAMS);get extent byte.
	LD BC,12
	ADD HL,BC
	LD A,(HL);and increment it.
	INC A
	AND 1FH;keep within range 0-31.
	LD (HL),A
	JP Z,GTNEXT1;overflow?
	LD B,A;mask extent byte.
	LD A,(EXTMASK)
	AND B
	LD HL,CLOSEFLG;check close flag (0ffh is ok).
	AND (HL)
	JP Z,GTNEXT2;if zero, we must read in next extent.
	JP GTNEXT3;else, it is already in memory.
GTNEXT1:LD BC,2;Point to the 's2' byte.
	ADD HL,BC
	INC (HL);and bump it.
	LD A,(HL);too many extents?
	AND 0FH
	JP Z,GTNEXT5;yes, set error code.
GTNEXT2:LD C,15;set to check first 15 bytes of fcb.
	CALL FINDFST;find the first one.
	CALL CKFILPOS;none available?
	JP NZ,GTNEXT3
	LD A,(RDWRTFLG);no extent present. Can we open an empty one?
	INC A;0ffh means reading (so not possible).
	JP Z,GTNEXT5;or an error.
	CALL GETEMPTY;we are writing, get an empty entry.
	CALL CKFILPOS;none?
	JP Z,GTNEXT5;error if true.
	JP GTNEXT4;else we are almost done.
GTNEXT3:CALL OPENIT1;open this extent.
GTNEXT4:CALL STRDATA;move in updated data (rec #, extent #, etc.)
	XOR A;clear status and return.
	JP SETSTAT
GTNEXT5:CALL IOERR1;set error code, clear bit 7 of 's2'
	JP SETS2B7;so this is not written on a close.
RDSEQ:LD A,1;set sequential access mode.
	LD (MODE),A
RDSEQ1:LD A,0FFH;don't allow reading unwritten space.
	LD (RDWRTFLG),A
	CALL STRDATA;put rec# and ext# into fcb.
	LD A,(SAVNREC);get next record to read.
	LD HL,SAVNXT;get number of records in extent.
	CP (HL);within this extent?
	JP C,RDSEQ2
	CP 128;no. Is this extent fully used?
	JP NZ,RDSEQ3;no. End-of-file.
	CALL GETNEXT;yes, open the next one.
	XOR A;reset next record to read.
	LD (SAVNREC),A
	LD A,(STATUS);check on open, successful?
	OR A
	JP NZ,RDSEQ3;no, error.
RDSEQ2:CALL COMBLK;ok. compute block number to read.
	CALL CHKBLK;check it. Within bounds?
	JP Z,RDSEQ3;no, error.
	CALL LOGICAL;convert (BLKNMBR) to logical sector (128 byte).
	CALL TRKSEC1;set the track and sector for this block #.
	CALL DOREAD;and read it.
	JP SETNREC;and set the next record to be accessed.
RDSEQ3:JP IOERR1
WTSEQ:LD A,1;set sequential access mode.
	LD (MODE),A
WTSEQ1:LD A,0;allow an addition empty extent to be opened.
	LD (RDWRTFLG),A
	CALL CHKWPRT;check write protect status.
	LD HL,(PARAMS)
	CALL CKROF1;check for read only file, (HL) already set to fcb.
	CALL STRDATA;put updated data into fcb.
	LD A,(SAVNREC);get record number to write.
	CP 128;within range?
	JP NC,IOERR1;no, error(?).
	CALL COMBLK;compute block number.
	CALL CHKBLK;check number.
	LD C,0;is there one to write to?
	JP NZ,WTSEQ6;yes, go do it.
	CALL GETBLOCK;get next block number within fcb to use.
	LD (RELBLOCK),A;and save.
	LD BC,0;start looking for space from the start
	OR A;if none allocated as yet.
	JP Z,WTSEQ2
	LD C,A;extract previous block number from fcb
	DEC BC;so we can be closest to it.
	CALL EXTBLK
	LD B,H
	LD C,L
WTSEQ2:CALL FNDSPACE;find the next empty block nearest number (BC).
	LD A,L;check for a zero number.
	OR H
	JP NZ,WTSEQ3
	LD A,2;no more space?
	JP SETSTAT
WTSEQ3:LD (BLKNMBR),HL;save block number to access.
	EX DE,HL;put block number into (DE).
	LD HL,(PARAMS);now we must update the fcb for this
	LD BC,16;newly allocated block.
	ADD HL,BC
	LD A,(BIGDISK);8 or 16 bit block numbers?
	OR A
	LD A,(RELBLOCK);(* update this entry *)
	JP Z,WTSEQ4;zero means 16 bit ones.
	CALL ADDA2HL;(HL)=(HL)+(A)
	LD (HL),E;store new block number.
	JP WTSEQ5
WTSEQ4:LD C,A;compute spot in this 16 bit table.
	LD B,0
	ADD HL,BC
	ADD HL,BC
	LD (HL),E;stuff block number (DE) there.
	INC HL
	LD (HL),D
WTSEQ5:LD C,2;set (C) to indicate writing to un-used disk space.
WTSEQ6:LD A,(STATUS);are we ok so far?
	OR A
	RET NZ
	PUSH BC;yes, save write flag for bios (register C).
	CALL LOGICAL;convert (BLKNMBR) over to loical sectors.
	LD A,(MODE);get access mode flag (1=sequential,
	DEC A;0=random, 2=special?).
	DEC A
	JP NZ,WTSEQ9
	POP BC
	PUSH BC
	LD A,C;get write status flag (2=writing unused space).
	DEC A
	DEC A
	JP NZ,WTSEQ9
	PUSH HL
	LD HL,(DIRBUF);zero out the directory buffer.
	LD D,A;note that (A) is zero here.
WTSEQ7:LD (HL),A
	INC HL
	INC D;do 128 bytes.
	JP P,WTSEQ7
	CALL DIRDMA;tell the bios the dma address for directory access.
	LD HL,(LOGSECT);get sector that starts current block.
	LD C,2;set 'writing to unused space' flag.
WTSEQ8:LD (BLKNMBR),HL;save sector to write.
	PUSH BC
	CALL TRKSEC1;determine its track and sector numbers.
	POP BC
	CALL DOWRITE;now write out 128 bytes of zeros.
	LD HL,(BLKNMBR);get sector number.
	LD C,0;set normal write flag.
	LD A,(BLKMASK);determine if we have written the entire
	LD B,A;physical block.
	AND L
	CP B
	INC HL;prepare for the next one.
	JP NZ,WTSEQ8;continue until (BLKMASK+1) sectors written.
	POP HL;reset next sector number.
	LD (BLKNMBR),HL
	CALL DEFDMA;and reset dma address.
WTSEQ9:CALL TRKSEC1;determine track and sector for this write.
	POP BC;get write status flag.
	PUSH BC
	CALL DOWRITE;and write this out.
	POP BC
	LD A,(SAVNREC);get number of records in file.
	LD HL,SAVNXT;get last record written.
	CP (HL)
	JP C,WTSEQ10
	LD (HL),A;we have to update record count.
	INC (HL)
	LD C,2
;*   This area has been patched to correct disk update problem
;* when using blocking and de-blocking in the BIOS.
WTSEQ10:NOP;was 'dcr c'
	NOP;was 'dcr c'
	LD HL,0;was 'jnz wtseq99'
;*   End of patch.
	PUSH AF
	CALL GETS2;set 'extent written to' flag.
	AND 7FH;(* clear bit 7 *)
	LD (HL),A
	POP AF;get record count for this extent.
WTSEQ99:CP 127;is it full?
	JP NZ,WTSEQ12
	LD A,(MODE);yes, are we in sequential mode?
	CP 1
	JP NZ,WTSEQ12
	CALL SETNREC;yes, set next record number.
	CALL GETNEXT;and get next empty space in directory.
	LD HL,STATUS;ok?
	LD A,(HL)
	OR A
	JP NZ,WTSEQ11
	DEC A;yes, set record count to -1.
	LD (SAVNREC),A
WTSEQ11:LD (HL),0;clear status.
WTSEQ12:JP SETNREC;set next record to access.
POSITION:XOR A;set random i/o flag.
	LD (MODE),A
POSITN1:PUSH BC;save read/write flag.
	LD HL,(PARAMS);get address of fcb.
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
	JP NZ,POSITN5;out of disk space error.
	LD HL,32;store record number into fcb.
	ADD HL,DE
	LD (HL),A
	LD HL,12;and now check the extent byte.
	ADD HL,DE
	LD A,C
	SUB (HL);same extent as before?
	JP NZ,POSITN2
	LD HL,14;yes, check extra extent byte 's2' also.
	ADD HL,DE
	LD A,B
	SUB (HL)
	AND 7FH
	JP Z,POSITN3;same, we are almost done then.
POSITN2:PUSH BC
	PUSH DE
	CALL CLOSEIT;close current extent.
	POP DE
	POP BC
	LD L,3;prepare for error.
	LD A,(STATUS)
	INC A
	JP Z,POSITN4;close error.
	LD HL,12;put desired extent into fcb now.
	ADD HL,DE
	LD (HL),C
	LD HL,14;and store extra extent byte 's2'.
	ADD HL,DE
	LD (HL),B
	CALL OPENIT;try and get this extent.
	LD A,(STATUS);was it there?
	INC A
	JP NZ,POSITN3
	POP BC;no. can we create a new one (writing?).
	PUSH BC
	LD L,4;prepare for error.
	INC C
	JP Z,POSITN4;nope, reading unwritten space error.
	CALL GETEMPTY;yes we can, try to find space.
	LD L,5;prepare for error.
	LD A,(STATUS)
	INC A
	JP Z,POSITN4;out of space?
POSITN3:POP BC;restore stack.
	XOR A;and clear error code byte.
	JP SETSTAT
POSITN4:PUSH HL
	CALL GETS2
	LD (HL),0C0H
	POP HL
POSITN5:POP BC
	LD A,L;get error code.
	LD (STATUS),A
	JP SETS2B7
READRAN:LD C,0FFH;set 'read' status.
	CALL POSITION;position the file to proper record.
	CALL Z,RDSEQ1;and read it as usual (if no errors).
	RET 
WRITERAN:LD C,0;set 'writing' flag.
	CALL POSITION;position the file to proper record.
	CALL Z,WTSEQ1;and write as usual (if no errors).
	RET 
COMPRAND:EX DE,HL;save fcb pointer in (DE).
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
RANSIZE:LD C,12;look thru directory for first entry with
	CALL FINDFST;this name.
	LD HL,(PARAMS);zero out the 'r0, r1, r2' bytes.
	LD DE,33
	ADD HL,DE
	PUSH HL
	LD (HL),D;note that (D)=0.
	INC HL
	LD (HL),D
	INC HL
	LD (HL),D
RANSIZ1:CALL CKFILPOS;is there an extent to process?
	JP Z,RANSIZ3;no, we are done.
	CALL FCB2HL;set (HL) pointing to proper fcb in dir.
	LD DE,15;point to last record in extent.
	CALL COMPRAND;and compute random parameters.
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
	JP C,RANSIZ2
	LD (HL),E;we found a larger (in size) extent.
	DEC HL;stuff these values into fcb.
	LD (HL),B
	DEC HL
	LD (HL),C
RANSIZ2:CALL FINDNXT;now get the next extent.
	JP RANSIZ1;continue til all done.
RANSIZ3:POP HL;we are done, restore the stack and
	RET;return.
SETRAN:LD HL,(PARAMS);point to fcb.
	LD DE,32;and to last used record.
	CALL COMPRAND;compute random position.
	LD HL,33;now stuff these values into fcb.
	ADD HL,DE
	LD (HL),C;move 'r0'.
	INC HL
	LD (HL),B;and 'r1'.
	INC HL
	LD (HL),A;and lastly 'r2'.
	RET 
LOGINDRV:LD HL,(LOGIN);get the login vector.
	LD A,(ACTIVE);get the default drive.
	LD C,A
	CALL SHIFTR;position active bit for this drive
	PUSH HL;into bit 0.
	EX DE,HL
	CALL SELECT;select this drive.
	POP HL
	CALL Z,SLCTERR;valid drive?
	LD A,L;is this a newly activated drive?
	RRA 
	RET C
	LD HL,(LOGIN);yes, update the login vector.
	LD C,L
	LD B,H
	CALL SETBIT
	LD (LOGIN),HL;and save.
	JP BITMAP;now update the bitmap.
SETDSK:LD A,(EPARAM);get parameter passed and see if this
	LD HL,ACTIVE;represents a change in drives.
	CP (HL)
	RET Z
	LD (HL),A;yes it does, log it in.
	JP LOGINDRV
AUTOSEL:LD A,0FFH;say 'auto-select activated'.
	LD (AUTO),A
	LD HL,(PARAMS);get drive specified.
	LD A,(HL)
	AND 1FH;look at lower 5 bits.
	DEC A;adjust for (1=A, 2=B) etc.
	LD (EPARAM),A;and save for the select routine.
	CP 1EH;check for 'no change' condition.
	JP NC,AUTOSL1;yes, don't change.
	LD A,(ACTIVE);we must change, save currently active
	LD (OLDDRV),A;drive.
	LD A,(HL);and save first byte of fcb also.
	LD (AUTOFLAG),A;this must be non-zero.
	AND 0E0H;whats this for (bits 6,7 are used for
	LD (HL),A;something)?
	CALL SETDSK;select and log in this drive.
AUTOSL1:LD A,(USERNO);move user number into fcb.
	LD HL,(PARAMS);(* upper half of first byte *)
	OR (HL)
	LD (HL),A
	RET;and return (all done).
RSTDSK:LD HL,0;clear write protect status and log
	LD (WRTPRT),HL;in vector.
	LD (LOGIN),HL
	XOR A;select drive 'A'.
	LD (ACTIVE),A
	LD HL,TBUFF;setup default dma address.
	LD (USERDMA),HL
	CALL DEFDMA
	JP LOGINDRV;now log in drive 'A'.
OPENFIL:CALL CLEARS2;clear 's2' byte.
	CALL AUTOSEL;select proper disk.
	JP OPENIT;and open the file.
CLOSEFIL:CALL AUTOSEL;select proper disk.
	JP CLOSEIT;and close the file.
GETFST:LD C,0;prepare for special search.
	EX DE,HL
	LD A,(HL);is first byte a '?'?
	CP '?'
	JP Z,GETFST1;yes, just get very first entry (zero length match).
	CALL SETEXT;get the extension byte from fcb.
	LD A,(HL);is it '?'? if yes, then we want
	CP '?';an entry with a specific 's2' byte.
	CALL NZ,CLEARS2;otherwise, look for a zero 's2' byte.
	CALL AUTOSEL;select proper drive.
	LD C,15;compare bytes 0-14 in fcb (12&13 excluded).
GETFST1:CALL FINDFST;find an entry and then move it into
	JP MOVEDIR;the users dma space.
GETNXT:LD HL,(SAVEFCB);restore pointers. note that no
	LD (PARAMS),HL;other dbos calls are allowed.
	CALL AUTOSEL;no error will be returned, but the
	CALL FINDNXT;results will be wrong.
	JP MOVEDIR
DELFILE:CALL AUTOSEL;select proper drive.
	CALL ERAFILE;erase the file.
	JP STSTATUS;set status and return.
READSEQ:CALL AUTOSEL;select proper drive then read.
	JP RDSEQ
WRTSEQ:CALL AUTOSEL;select proper drive then write.
	JP WTSEQ
FCREATE:CALL CLEARS2;clear the 's2' byte on all creates.
	CALL AUTOSEL;select proper drive and get the next
	JP GETEMPTY;empty directory space.
RENFILE:CALL AUTOSEL;select proper drive and then switch
	CALL CHGNAMES;file names.
	JP STSTATUS
GETLOG:LD HL,(LOGIN)
	JP GETPRM1
GETCRNT:LD A,(ACTIVE)
	JP SETSTAT
PUTDMA:EX DE,HL
	LD (USERDMA),HL;save in our space and then get to
	JP DEFDMA;the bios with this also.
GETALOC:LD HL,(ALOCVECT)
	JP GETPRM1
GETROV:LD HL,(WRTPRT)
	JP GETPRM1
SETATTR:CALL AUTOSEL;select proper drive then save attributes.
	CALL SAVEATTR
	JP STSTATUS
GETPARM:LD HL,(DISKPB)
GETPRM1:LD (STATUS),HL
	RET 
GETUSER:LD A,(EPARAM);get parameter.
	CP 0FFH;get user number?
	JP NZ,SETUSER
	LD A,(USERNO);yes, just do it.
	JP SETSTAT
SETUSER:AND 1FH;no, we should set it instead. keep low
	LD (USERNO),A;bits (0-4) only.
	RET 
RDRANDOM:CALL AUTOSEL;select proper drive and read.
	JP READRAN
WTRANDOM:CALL AUTOSEL;select proper drive and write.
	JP WRITERAN
FILESIZE:CALL AUTOSEL;select proper drive and check file length
	JP RANSIZE
LOGOFF:LD HL,(PARAMS);get drives to log off.
	LD A,L;for each bit that is set, we want
	CPL;to clear that bit in (LOGIN)
	LD E,A;and (WRTPRT).
	LD A,H
	CPL 
	LD HL,(LOGIN);reset the login vector.
	AND H
	LD D,A
	LD A,L
	AND E
	LD E,A
	LD HL,(WRTPRT)
	EX DE,HL
	LD (LOGIN),HL;and save.
	LD A,L;now do the write protect vector.
	AND E
	LD L,A
	LD A,H
	AND D
	LD H,A
	LD (WRTPRT),HL;and save. all done.
	RET 
GOBACK:LD A,(AUTO);was auto select activated?
	OR A
	JP Z,GOBACK1
	LD HL,(PARAMS);yes, but was a change made?
	LD (HL),0;(* reset first byte of fcb *)
	LD A,(AUTOFLAG)
	OR A
	JP Z,GOBACK1
	LD (HL),A;yes, reset first byte properly.
	LD A,(OLDDRV);and get the old drive and select it.
	LD (EPARAM),A
	CALL SETDSK
GOBACK1:LD HL,(USRSTACK);reset the users stack pointer.
	LD SP,HL
	LD HL,(STATUS);get return status.
	LD A,L;force version 1.4 compatability.
	LD B,H
	RET;and go back to user.
WTSPECL:CALL AUTOSEL;select proper drive.
	LD A,2;use special write mode.
	LD (MODE),A
	LD C,0;set write indicator.
	CALL POSITN1;position the file.
	CALL Z,WTSEQ1;and write (if no errors).
	RET 

ENDC
