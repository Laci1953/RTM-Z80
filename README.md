# RTM-Z80 - last update on 18 Sept 2023
RTM/Z80 is a multitasking kernel, built for Z80 based computers, written in Z80 assembly language, providing its users with an Application Programming Interface (API) accessible from programs written in the C language and the Z80 assembly language.

It is intended to be a simple and easy to use learning tool, for those who want to understand the tips and tricks of the multitasking software systems.

Current version is 2.6 

RTM/Z80 can be used on the following environments:

• Z80SIM Z80 simulator (e.g. on Windows, under CygWin)

• Z80ALL standalone homebrew Z80 computer (25MHz Z80, 4 x 32KB RAM, KIO, VGA, PS/2, DS1302)

• RC2014 homebrew Z80 computer, using the following hardware configuration options:

  o SC108(Z80 + 2x64KB RAM) + SC110(CTC+SIO) , or
  o any Z80 board + 64/128KB RAM + SC110(CTC+SIO) , or
  o any Z80 board + 512KB RAM+512KB ROM Memory Module + SC110(CTC+SIO)

• RCBUS based homebrew Z80 computer, using the following hardware configuration options:

  o SC706(Z80) + (SC707 / SC714 RAM) + ( SC716(SIO) + SC718(CTC) ) / SC725(CTC+SIO) 

• any CPU Z80 board supporting IM2 + any 64KB RAM board + any CTC board + any SIO ( or KIO board ) (in this case, the I/O ports must be set in the source code, see manual, chapter Porting RTM/Z80 to other hardware)

The mandatory hardware requirements: 64KB RAM, support of Z80 Interrupt Mode 2, CTC, SIO or KIO.   

New in v2.4 : see DEMO folder for getxfile, putxfile (XMODEM compatible)

New in v2.5 : 
KIO support added

New in v2.6 :
Z80ALL version added, 

VGA display support added for Z80ALL, 

VGA System status display added for Z80ALL, 

PS/2 keyboard support added for Z80ALL, 

extra 2x32KB RAM support added for Z80ALL,

real time clock DS1302 added for Z80ALL


