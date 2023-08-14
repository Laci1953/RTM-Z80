;
;	Copyright (C) 2021 by Ladislau Szilagyi
;
;*****************************************************************************
; Xmodem for Z80 CP/M 2.2 using CON:
;Copyright 2017 Mats Engstrom, SmallRoomLabs
;
;Licensed under the MIT license
;*****************************************************************************
;
TITLE      XMODEM support routines for RTM/Z80
;
;original XMODEM algorithm by Mats Engstrom
;modified by Ladislau Szilagyi
;
*Include config.mac

TERATERM_TEST	equ	1	;1=receiver waits 30 sec before sending NAK

IF	IO_COMM
;
IF	C_LANG
	GLOBAL _XmRecv
	GLOBAL _XmSend
ENDIF
	GLOBAL __XmRecv
	GLOBAL __XmSend
        GLOBAL __WriteB
        GLOBAL __ReadB
        GLOBAL __GetCountB
        GLOBAL __Reset_RWB
	GLOBAL __SendMail
	GLOBAL __GetMail
	GLOBAL __MakeTimer
	GLOBAL __DropTimer
        GLOBAL __StartTimer
	GLOBAL __MakeSem
	GLOBAL __DropSem
	GLOBAL __Wait
;
;ASCII codes
;
LF	equ	'J'-40h	;^J LF
CR 	equ 	'M'-40h	;^M CR/ENTER
SOH	equ	'A'-40h	;^A CTRL-A
EOT	equ	'D'-40h	;^D = End of Transmission
ACK	equ	'F'-40h	;^F = Positive Acknowledgement
NAK	equ	'U'-40h	;^U = Negative Acknowledgement
CAN	equ	'X'-40h	;^X = Cancel
;
MAX_RETRY_COUNT	equ	10
;
;return codes
;
XM_OK		equ	1
XM_CANCELLED	equ	-1
XM_FAILURE	equ	-2
;
	psect	bss

MB_Data:	defs	2	;Data mailbox pointer
S_Done:		defs	2	;Semaphore Done pointer
Timer:		defs	2	;Timer pointer
Sem:		defs	2	;Semaphore pointer
;
retrycnt:	defs 	1	;Counter for retries before giving up
chksum:	 	defs	1	;For calculating the ckecksum of the packet
pktNo:	 	defs 	1 	;Current packet Number
pktNo1c: 	defs 	1 	;Current packet Number 1-complemented

bufbyte:	defs	1

PACK_LEN	equ	132

packet:	 	defs 	1	;SOH
	 	defs	1	;PacketN
	 	defs	1	;-PacketNo,
data:	 	defs	128	;data*128,
EOTmark: 	defs	1 	;chksum / EOT mark (not zero==EOT)

packcnt:	defs	1
PACK_GRP	equ	64

	psect	text
;
;	Receive packets
;
;short	XmRecv(struct MailBox* MB_Data)
;on stack
;	MB_Data must be created using MakeMB(129)
;
;	AF,BC,DE,IX,IY not affected
;	returns HL=1 if ok, 
;	else -1 if uploader cancelled
;	else -2 if comm failure
;
;	The task who receives the data must use:
;
;		MB=MakeMB(129);
;		(run task to do ) XmRecv(MB);
;		do
;		{
;		  GetMail(MB, buf129);
;		  if (EOTmark)	;byte # 129
;		    break;
;		  process buf128 (e.g. write-it to a file)
;		}
;		see the result of XmRecv
;	
XM_MB	equ	14
_XmRecv:
	PUSH_REGS
	ld	hl,XM_MB
	add	hl,sp		;IX=SP,stack=AF,BC,DE,HL,IX,IY,retaddr,MB_Data
	ld	a,(hl)
	inc	hl
	ld	h,(hl)		
	ld	l,a		;HL=MB_Data
	call	__XmRecv
	pop	iy
	pop	ix
	pop	bc
	pop	de
	inc	sp		;keep HL=return val
	inc	sp
	pop	af
	ret
;
;	Receive packets - internal
;
;	HL=pointer to user mailbox
;
;	returns HL=1 if ok, 
;	else -1 if uploader cancelled
;	else -2 if comm failure
;
__XmRecv:
	ld	(MB_Data),hl	;save data mailbox pointer
	call	__MakeSem
	ld	(Sem),hl
	call	__MakeTimer
	ld	(Timer),hl
	call	__Reset_RWB	;reset SIO ring
IF	TERATERM_TEST
	ld	hl,(Timer)
	ld	de,(Sem)
	ld	bc,6000		;30 secs
	xor	a		;no repeat
	call	__StartTimer
	ld	hl,(Sem)
	call	__Wait		;wait 30 secs
ENDIF
	ld	a,NAK		;Send NAK to uploader
	call	SendBack1B
	ld 	a,1		;The first packet is number 1
	ld 	(pktNo),a
	ld 	a,255-1		;Also store the 1-complement of it
	ld 	(pktNo1c),a

	ld	a,PACK_GRP	;Init pack counter
	ld	(packcnt),a

GetNewPacket:
	ld	a,MAX_RETRY_COUNT
	ld	(retrycnt),a
Retry:
	ld	hl,packet
	ld	de,(Sem)
	ld	c,PACK_LEN
	ld	iy,(Timer)
	ld	ix,20		;100 ms
	call	__ReadB
	ld	hl,(Sem)
	call	__Wait
	call	__GetCountB
	or	a
	jr	z,packread	;full packet was received
	cp	PACK_LEN
	jp	nz,truncated
				;received nothing
	ld	hl,retrycnt
	dec	(hl)
	jr	nz,Retry
				;too many retries, failed!
Failure:
	call	MailEOT		;Tell data consumer we're done
	call	Drop
	ld	hl,XM_FAILURE
	ret
truncated:			;received something truncated
				;suppose just 1 char received
	ld	a,(packet)
	cp	EOT		;Did uploader say we're finished?
	jp	z,Done		;Yes, then we're done
	cp 	CAN		;Uploader wants to abort transfer?
	jp 	z,Cancelled	;Yes, then we're also done
	jp	Failure		;else, it a failure...
packread:			;full packet was read
	ld	a,(packet)
	cp	SOH		;Did we get a start-of-new-packet?
	jp	nz,GetNewPacket	;No, go back and try again
				;Yes, we have a new packet...
	ld	hl,data		;Calculate checksum from 128 bytes of data
	ld	b,128
	xor	a
csloop:	add	a,(hl)		;Just add up the bytes
	inc	hl
	djnz	csloop
	xor	(hl)		;HL points to the received checksum so
	jp	nz,BadCKS	;by xoring it to our sum we check for equality
	ld	a,(pktNo)	;Check if agreement of packet numbers
	ld	c,a
	ld	a,(packet+1)
	cp	c
	jp	nz,Failure
	ld	a,(pktNo1c)	;Check if agreement of 1-compl packet numbers
	ld	c,a
	ld	a,(packet+2)
	cp	c
	jp	nz,Failure
				;packet is checked, send-it to the user
	xor	a
	ld	(EOTmark),a	;not the last one
	ld	hl,(MB_Data)
	ld	de,data
	call	__SendMail
	ld	hl,pktNo	;Update the packet counters
	inc 	(hl)
	ld	hl,pktNo1c
	dec	(hl)
				;wait ...
	ld	hl,(Timer)
	ld	de,(Sem)
	ld	bc,10		;50 ms
	ld	a,(packcnt)
	dec	a
	jr	nz,1f
	ld	bc,200		;1 sec
	ld	a,PACK_GRP
1:
	ld	(packcnt),a
	xor	a		;no repeat
	call	__StartTimer
	ld	hl,(Sem)
	call	__Wait		;wait
	ld 	a,ACK		;Tell uploader that last packet was OK
	call	SendBack1B
	jp	GetNewPacket
BadCKS:
	ld	a,NAK		;Tell uploader to send again the last packet
	call	SendBack1B
	jp	GetNewPacket
Done:
	ld 	a,ACK		;Tell uploader that we're done
	call	SendBack1B
	call	MailEOT		;Tell data consumer we're done
	call	Drop
	ld	hl,XM_OK	;success
	ret
;
Cancelled:
	call	MailEOT		;Tell data consumer we're done
	call	Drop
	ld	hl,XM_CANCELLED
	ret
;
;	Send to data consumer EOT message
;
MailEOT:
	ld	a,EOT		;Tell data consumer we're done
	ld	(EOTmark),a	
	ld	hl,(MB_Data)
	ld	de,data
	jp	__SendMail
;
;	A=byte to be sent to the uploader
;
SendBack1B:
	ld	hl,bufbyte
	ld	(hl),a
	ld	de,0		;no Wait
	ld	c,1
	jp	__WriteB
;
;	Drop sys objs
;
Drop:
	ld	hl,(Sem)
	call	__DropSem
	ld	hl,(Timer)
	jp	__DropTimer
;
;	Send packets
;
;short	XmSend(struct MailBox* MB_Data)
;on stack
;	MB_Data must be created using MakeMB(129)
;
;	AF,BC,DE,IX,IY not affected
;	returns HL=1 if ok, 
;	else -1 if receiver cancelled
;	else -2 if comm failure
;
;	The task who produces the data must use:
;
;		MB=MakeMB(129);
;		(run task to do) XmSend(MB);
;		while (data to be sent, e.g. read from a file)
;		do
;		{
;		  EOTMark = 0;byte #129
;		  SendMail(MB, buf129);
;		}
;		EOT_Mark=EOT;byte # 129
;		SendMail(MB, buf129);
;		get the result of XmSend
;
_XmSend:
	PUSH_REGS
	ld	hl,XM_MB
	add	hl,sp		;IX=SP,stack=AF,BC,DE,HL,IX,IY,retaddr,MB_Data
	ld	a,(hl)
	inc	hl
	ld	h,(hl)		
	ld	l,a		;HL=MB_Data
	call	__XmSend
	pop	iy
	pop	ix
	pop	bc
	pop	de
	inc	sp		;keep HL=return val
	inc	sp
	pop	af
	ret
;
;	Send packets - internal
;
;	HL=pointer to user mailbox
;
;	returns HL=1 if ok, 
;	else -1 if uploader cancelled
;	else -2 if comm failure
;
__XmSend:
	ld	(MB_Data),hl	;save data mailbox pointer
	call	__MakeSem
	ld	(Sem),hl
	call	__MakeTimer
	ld	(Timer),hl
	call	__Reset_RWB	;reset SIO ring
				;wait for NAK from the receiver
	ld	ix,6000		;30 sec timeout
	call	Get1B
	jp	nz,FailureS	;if no response, failure
	cp	NAK
	jp	nz,FailureS	;if not NAK, failure
				;NAK received
	ld	hl,packet
	ld 	a,SOH		;Start packet with SOH
	ld 	(hl),a
	inc	hl
	ld 	a,1		;The first packet is number 1
	ld 	(hl),a
	inc	hl
	ld 	a,255-1		;Also store the 1-complement of it
	ld 	(hl),a
GetData:
	ld	hl,(MB_Data)
	ld	de,data
	call	__GetMail
	ld	a,(EOTmark)
	cp	EOT
	jp	z,DoneS		;data producer tels us EOT
	ld	hl,data		;Calculate checksum of the 128 data bytes
	ld	b,128
	xor	a
csloop1:add	a,(hl)		;Just add up the bytes
	inc	hl
	djnz	csloop1
	ld	(hl),a		;And store it at the end of packet
GotNAK:	
	ld	hl,packet	;send packet
	ld	de,(Sem)
	ld	c,PACK_LEN
	call	__WriteB
	ld	hl,(Sem)
	call	__Wait
				;read response (1 byte)
	ld	ix,20		;100 ms timeout
	call	Get1B
	jp	nz,FailureS	;no byte received, timeout
 	cp 	CAN		;Downloader wants to abort transfer?
 	jp 	z,CancelledS	;Yes, then we're also done
 	cp	NAK		;Downloader want retransmit?
 	jp	z,GotNAK	;Yes, resend last packet
	cp	ACK		;Downloader approved and wants next pkt?
	jp	nz,FailureS	;else, protocol failed 
				;got ACK
	ld	hl,packet+1	;Update the packet counters
	inc 	(hl)
	inc	hl
	dec	(hl)
	jp	GetData		;get new data & send-it
;
DoneS:
	ld	a,EOT		;tell receiver we're done
	call	SendBack1B
	ld	ix,2000		;10 s timeout
	call	Get1B
;
;	it seems TeraTerm sends a NAK !!!
;
;	jr	nz,FailureS	;if no response, failure
;	cp	ACK
;	jr	nz,FailureS	;if response not ACK, failure
	call	Drop
	ld	hl,XM_OK	;success
	ret
;
CancelledS:
	call	Drop
	ld	hl,XM_CANCELLED
	ret
;
FailureS:
	call	Drop
	ld	hl,XM_FAILURE
	ret
;
;	Get response from receiver
;
;	IX=timeout
;
;	returns Z=1 : A = byte received
;	else Z=0 : timeout occured
;
Get1B:
	ld	hl,bufbyte	;read response
	ld	de,(Sem)
	ld	c,1		;1 byte
	ld	iy,(Timer)
	call	__ReadB
	ld	hl,(Sem)
	call	__Wait
	call	__GetCountB
	or	a
	ld	a,(bufbyte)
	ret
;
ENDIF
