;	PUTSYS for 2014 systems with 64MB CF
;
;	Adapted from:
;==================================================================================
; Grant Searle's code, modified for use with Small Computer Workshop IDE.
; Also embedded CP/M hex files into this utility to make it easier to use.
; Compile options for LiNC80 and RC2014 systems.
; SCC 2018-04-13
; Added option for 64MB compact flash.
; JL 2018-04-28
;==================================================================================
; Contents of this file are copyright Grant Searle
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

	PSECT	text

; NOTE: Some memory locations are overwritten when HEX files are inserted

CodeORG     EQU 08000H         ;Code runs here
loadAddr    EQU 09000H         ;CP/M hex files load here

numSecs     EQU 24             ;Number of 512 sectors to be loaded


; CF registers
CF_DATA     EQU 10H
CF_FEATURES EQU 11H
CF_ERROR    EQU 11H
CF_SECCOUNT EQU 12H
CF_SECTOR   EQU 13H
CF_CYL_LOW  EQU 14H
CF_CYL_HI   EQU 15H
CF_HEAD     EQU 16H
CF_STATUS   EQU 17H
CF_COMMAND  EQU 17H
CF_LBA0     EQU 13H
CF_LBA1     EQU 14H
CF_LBA2     EQU 15H
CF_LBA3     EQU 16H

;CF Features
CF_8BIT     EQU 1
CF_NOCACHE  EQU 082H
;CF Commands
CF_READ_SEC EQU 020H
CF_WRITE_SEC EQU 030H
CF_SET_FEAT EQU 0EFH

LF          EQU 0AH            ;line feed
FF          EQU 0CH            ;form feed
CR          EQU 0DH            ;carriage RETurn

;================================================================================================

            ORG CodeORG        ;Code runs here

            CALL printInline
            DEFM 'CP/M System Transfer by G. Searle 2012'
            DEFB  CR,LF,0

            CALL cfWait
            LD   A,CF_8BIT      ; Set IDE to be 8bit
            OUT  (CF_FEATURES),A
            LD   A,CF_SET_FEAT
            OUT  (CF_COMMAND),A

            CALL cfWait
            LD   A,CF_NOCACHE   ; No write cache
            OUT  (CF_FEATURES),A
            LD   A,CF_SET_FEAT
            OUT  (CF_COMMAND),A

            LD   B,numSecs

            LD   A,0
            LD   (secNo),A
            LD   HL,loadAddr
            LD   (dmaAddr),HL
processSectors:

            CALL cfWait

            LD   A,(secNo)
            OUT  (CF_LBA0),A
            LD   A,0
            OUT  (CF_LBA1),A
            OUT  (CF_LBA2),A
            LD   A,0E0H
            OUT  (CF_LBA3),A
            LD   A,1
            OUT  (CF_SECCOUNT),A

            CALL write

            LD   DE,0200H
            LD   HL,(dmaAddr)
            ADD  HL,DE
            LD   (dmaAddr),HL
            LD   A,(secNo)
            INC  A
            LD   (secNo),A

            LD A,'.'
            RST 08

            DJNZ processSectors

            CALL printInline
            DEFB  CR,LF
            DEFM 'System transfer complete'
            DEFB  CR,LF,0

            RET


;================================================================================================
; Write physical sector to host
;================================================================================================

write:
            PUSH AF
            PUSH BC
            PUSH HL

            CALL cfWait

            LD   A,CF_WRITE_SEC
            OUT  (CF_COMMAND),A

            CALL cfWait


TstDRQ:    IN   A,(CF_STATUS)  ;Read status register
            BIT  3,A            ;Test DRQ flag
            JR   Z,TstDRQ      ;Low so not ready

            LD   C,4
            LD   HL,(dmaAddr)
wr4secs:
            LD   B,128
wrByte:     LD   A,(HL)
            NOP
            NOP
            OUT  (CF_DATA),A
            INC  HL
            DEC  B
            JR   NZ, wrByte

            DEC  C
            JR   NZ,wr4secs

            POP  HL
            POP  BC
            POP  AF

            RET

;================================================================================================
; Wait for disk to be ready (busy=0,ready=1)
;================================================================================================

cfWait:     PUSH AF
TstBusy:   IN   A,(CF_STATUS)  ;Read status register
            BIT  7,A            ;Test Busy flag
            JR   NZ,TstBusy    ;High so busy
TstReady:  IN   A,(CF_STATUS)  ;Read status register
            BIT  6,A            ;Test Ready flag
            JR   Z,TstBusy     ;Low so not ready
            POP  AF
            RET


;================================================================================================
; Utilities
;================================================================================================

printInline:
            EX   (SP),HL        ; PUSH HL and put RET ADDress into HL
            PUSH AF
            PUSH BC
nextILChar: LD   A,(HL)
            CP   0
            JR   Z,endOfPrint
            RST  08H
            INC  HL
            JR   nextILChar
endOfPrint: INC  HL             ; Get past 'null' terminator
            POP  BC
            POP  AF
            EX   (SP),HL        ; PUSH new RET ADDress on stack and restore HL
            RET

dmaAddr:     DEFW  0
secNo:       DEFB  0


