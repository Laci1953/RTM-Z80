*Include config.mac
*Include apiasm.mac

	GLOBAL _main

	psect text

_main:	
	ld	bc,1E0H
	ld	hl,Task
	ld	e,10
	call	__StartUp
	ld	c,0
	jp	5

Task:	
	call	__MakeSem
	ld	(Sem),hl
	call	__MakeTimer
	ld	(Timer),hl
	call	__Reset_RWB
	ld	hl,buf9
	ld	de,(Sem)
	ld	c,9
	ld	ix,1234H		;10 sec
	ld	iy,(Timer)
	call	__ReadB
	ld	hl,(Sem)
	call	__Wait
	call	__GetCountB
	cp	9
	jr	z,timeout
	ld	c,a
	ld	a,9
	sub	c
	ld	b,0
	ld	c,a
	inc	c
	inc	c
	ld	hl,msg
type:
	ld	de,(Sem)
	call	__CON_Write
	ld	hl,(Sem)
	call	__Wait
	call	__GetCrtTask
	call	__StopTask

timeout:
	ld	hl,tmo
	ld	bc,5
	jr	type

Sem:	defs	2
Timer:	defs	2
msg:	defb	0dh,0ah
buf9:	defs	9
tmo:	defb	0dh,0ah
	defm	'tmo'
