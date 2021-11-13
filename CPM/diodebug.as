;
;	Digital I/O module based debugger
;
;	At start, leds will display 1111 0000, to show that you may enter a new address (or return)
;	Then, press button 7 to set a new address, leds will display 0001 0000, or
;		press button 0 to return
;	Then, set a new address, by feeding in the address nibbles, using buttons 0 to 3, 
;		(leds will display also the bit being fed-in) in the following order:
;			low byte low nibble, then press button 7, leds will display 0010 0000
;			low byte high nibble, then press button 7, leds will display 0100 0000
;			high byte low nibble, then press button 7, leds will display 1000 0000
;			high byte high nibble, then press button 7, leds will display 1111 0000
;	Then, 
;		press button 6 to display byte @address and wait next command, or
;		press button 5 to increment address & display byte @address and wait next command, or
;		press button 4 to decrement address & display byte @address and wait next command, or
;		press button 1 to set a breakpoint @address and return, or
;		press button 0 to return
;
;	After a breakpoint is reached, registers (AF,BC,DE,HL,AF',BC',DE',HL',IX,IY,SP,PC) are stored at 8H
;	leds will display 1111 0000, then you may enter a new address or return
;
	psect	text

	GLOBAL	_diodebug
;
;	status definitions (reg B)
;
INITIAL		equ	0	;at start
ADDR_SET	equ	1	;addr is set
WAIT_LOW_LOW	equ	2	;waiting to set low-low address nibble
WAIT_LOW_HIGH	equ	3	;waiting to set low-high address nibble
WAIT_HIGH_LOW	equ	4	;waiting to set high-low address nibble
WAIT_HIGH_HIGH	equ	5	;waiting to set high-high address nibble
;
;	button definitions
;
;	7 = set address
;	6 = display byte @addr
;	5 = increments addr & display byte @addr
;	4 = decrements addr & display byte @addr
;	when in address setting mode, 3,2,1,0 = set bit in nibble
;	else, 1 = set breakpoint @ addr, or
;	      0 = return
;
;	button masks
;
B0	equ	1H
B1	equ	2H
B2	equ	4H
B3	equ	8H
B4	equ	10H
B5	equ	20H
B6	equ	40H
B7	equ	80H
;
;	led definitions (reg E)
;
;	7 = WAIT_HIGH_HIGH
;	6 = WAIT_LOW_HIGH
;	5 = WAIT_LOW_HIGH
;	4 = WAIT_LOW_LOW
;	4,5,6,7 = ADDR_SET
;
;	reg HL = address
;
;	Check button
;
;	C=button mask (1H=0, 2H=1, 4H=2, 8H=3, 10H=4, 20H=5, 40H=6, 80H=7)
;
;	returns Z=0 : button not pushed
;		Z=1 : button was pushed, A=button index
;
Check:
	in	a,(0)
	and	c
	ret	z
waitoff:			;wait for button release
	in	a,(0)
	and	c
	jr	nz,waitoff
				;button was released
	or	c		;Z=0, A=button index
	ret
;
;	Inital call
;
_diodebug:
	push	af
	push	bc
	push	de
	push	hl
	xor	a
	ld	d,a		;set BrkSts=initial run
enter:
	ld	a,0F0H		;set leds as ADDR set
	out	(0),a
	ld	b,INITIAL	;set status as INITIAL
loop:
				;B=status, D=BrkSts(0:initial run, 1:breakpoint was reached), E=leds
	ld	c,B7
	call	Check
	jp	nz,B7pushed
	ld	c,B6
	call	Check
	jp	nz,B6pushed
	ld	c,B5
	call	Check
	jp	nz,B5pushed
	ld	c,B4
	call	Check
	jp	nz,B4pushed
	ld	c,B3
	call	Check
	jp	nz,B3pushed
	ld	c,B2
	call	Check
	jp	nz,B2pushed
	ld	c,B1
	call	Check
	jp	nz,B1pushed
	ld	c,B0
	call	Check
	jp	nz,B0pushed
	jp	loop
;
B7pushed:
	ld	a,b
	cp	INITIAL
	jp	z,set_w_low_low
	cp	ADDR_SET
	jp	z,set_w_low_low
	cp	WAIT_LOW_LOW
	jp	z,set_w_low_high
	cp	WAIT_LOW_HIGH
	jp	z,set_w_high_low
	cp	WAIT_HIGH_LOW
	jp	z,set_w_high_high
	cp	WAIT_HIGH_HIGH
	jp	z,set_addr_set
	jp	loop
;
set_addr_set:
	ld	b,ADDR_SET
	ld	a,0F0H
	out	(0),a
	jp	loop
;
set_w_low_low:
	ld	hl,0			;reset addr
	ld	b,WAIT_LOW_LOW
	ld	a,B4
	ld	e,a			;save leds
	out	(0),a
	jp	loop
;
set_w_low_high:
	ld	b,WAIT_LOW_HIGH
	ld	a,B5
	ld	e,a			;save leds
	out	(0),a
	jp	loop
;
set_w_high_low:
	ld	b,WAIT_HIGH_LOW
	ld	a,B6
	ld	e,a			;save leds
	out	(0),a
	jp	loop
;
set_w_high_high:
	ld	b,WAIT_HIGH_HIGH
	ld	a,B7
	ld	e,a			;save leds
	out	(0),a
	jp	loop
;
B6pushed:
	ld	a,b
	cp	ADDR_SET
	jp	nz,loop
display:
	ld	a,(hl)			;get byte from addr
	out	(0),a			;display-it
	jp	loop
;
B5pushed:
	ld	a,b
	cp	ADDR_SET
	jp	nz,loop
	inc	hl
	jp	display
;
B4pushed:
	ld	a,b
	cp	ADDR_SET
	jp	nz,loop
	dec	hl
	jp	display
;
B3pushed:
	ld	a,b
	cp	INITIAL
	jp	z,loop
	cp	ADDR_SET
	jp	z,loop
	cp	WAIT_LOW_LOW
	jp	z,set_b3L
	cp	WAIT_LOW_HIGH
	jp	z,set_b7L
	cp	WAIT_HIGH_LOW
	jp	z,set_b3H
;	cp	WAIT_HIGH_HIGH		;status is WAIT_HIGH_HIGH
set_b7H:set	7,h			;set_b7H
setB3:
	ld	a,e
	or	B3
	ld	e,a
	out	(0),a
	jp	loop
;
set_b3L:set	3,l
	jp	setB3
;
set_b7L:set	7,l
	jp	setB3
;
set_b3H:set	3,h
	jp	setB3
;
B2pushed:
	ld	a,b
	cp	INITIAL
	jp	z,loop
	cp	ADDR_SET
	jp	z,loop
	cp	WAIT_LOW_LOW
	jp	z,set_b2L
	cp	WAIT_LOW_HIGH
	jp	z,set_b6L
	cp	WAIT_HIGH_LOW
	jp	z,set_b2H
;	cp	WAIT_HIGH_HIGH		;status is WAIT_HIGH_HIGH
set_b6H:set	6,h			;set_b6H
setB2:
	ld	a,e
	or	B2
	ld	e,a
	out	(0),a
	jp	loop
;
set_b2L:set	2,l
	jp	setB2
;
set_b6L:set	6,l
	jp	setB2
;
set_b2H:set	2,h
	jp	setB2
;
B1pushed:
	ld	a,b
	cp	INITIAL
	jp	z,loop
	cp	ADDR_SET
	jp	z,setbreak
	cp	WAIT_LOW_LOW
	jp	z,set_b1L
	cp	WAIT_LOW_HIGH
	jp	z,set_b5L
	cp	WAIT_HIGH_LOW
	jp	z,set_b1H
;	cp	WAIT_HIGH_HIGH		;status is WAIT_HIGH_HIGH
set_b5H:set	5,h			;set_b5H
setB1:
	ld	a,e
	or	B1
	ld	e,a
	out	(0),a
	jp	loop
;	
set_b1L:set	1,l
	jp	setB1
;
set_b5L:set	5,l
	jp	setB1
;
set_b1H:set	1,h
	jp	setB1
;
B0pushed:
	ld	a,b
	cp	INITIAL
	jp	z,return
	cp	ADDR_SET
	jp	z,return
	cp	WAIT_LOW_LOW
	jp	z,set_b0L
	cp	WAIT_LOW_HIGH
	jp	z,set_b4L
	cp	WAIT_HIGH_LOW
	jp	z,set_b0H
;	cp	WAIT_HIGH_HIGH		;status is WAIT_HIGH_HIGH
set_b4H:set	4,h			;set_b4H
setB0:
	ld	a,e
	or	B0
	ld	e,a
	out	(0),a
	jp	loop
;	
set_b0L:set	0,l
	jp	setB0
;
set_b4L:set	4,l
	jp	setB0
;
set_b0H:set	0,h
	jp	setB0
;
setbreak:
	ld	a,(hl)			;get byte @addr
	ld	(B_at_brk),a		;save-it
	ld	a,0FFH
	ld	(hl),a			;store 'RST 38H' @addr
	ld	a,0C3H			;store 'jp breakpoint' @38H
	ld	(38H),a
	ld	hl,breakpoint
	ld	(39H),hl
return:
	xor	a
	out	(0),a			;all leds OFF
	ld	a,d			;D=BrkSts (0=initial call, 1=breakpoint was reached)
	or	a			;check BrkSts
	jp	z,nobrk
					;we are returning from a breakpoint
	ld	hl,($PC)
	push	hl			;prepare return addr
	ld	hl,($AFp)
	push	hl
	pop	af			;AF was restored
	ld	bc,($BCp)		;BC was restored
	ld	de,($DEp)		;DE was restored
	ld	hl,($HLp)		;HL was restored
	ret				;return
nobrk:					;we are returning from the initial call
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret
;
breakpoint:
	ld	($HLp),hl		;save HL
	ld	($DEp),de		;save DE
	ld	($BCp),bc		;save BC
	push	af
	pop	hl
	ld	($AFp),hl		;save AF
	exx
	ld	($HLs),hl		;save HL
	ld	($DEs),de		;save DE
	ld	($BCs),bc		;save BC
	exx
	ex	af,af'
	push	af
	pop	hl
	ld	($AFp),hl		;save AF'
	ex	af,af'
	ld	($IX),ix		;save IX
	ld	($IY),iy		;save IY
	pop	hl			
	dec	hl	
	ld	($PC),hl		;save PC
					;restore byte @breakpoint
	ld	a,(B_at_brk)
	ld	(hl),a
	ld	hl,0
	add	hl,sp
	ld	($SP),hl		;save SP
					;breakpoint was reached
	ld	d,1			;D=1 : BrkSts = breakpoint was reached
	jp	enter
;
	psect	bss
;
B_at_brk:defs	1			;byte @ breakpoint
;
;registers
$AFp	equ	08H
$BCp	equ	0AH
$DEp	equ	0CH
$HLp	equ	0EH
$AFs	equ	10H
$BCs	equ	12H
$DEs	equ	14H
$HLs	equ	16H
$IX	equ	18H
$IY	equ	1AH
$SP	equ	1CH
$PC	equ	1EH
;
