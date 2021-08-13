*Include config.mac
*Include apiasm.mac

	GLOBAL _main

	psect text

_main:	
	ld	bc,1E0H
	ld	hl,Task
	ld	e,10
	call	__StartUp
	ret

Task:	jp	$
