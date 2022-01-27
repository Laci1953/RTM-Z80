# RTM-Z80
RTM/Z80 is a multitasking kernel, built for Z80 based computers, written in Z80 assembly language, providing its users with an Application Programming Interface (API) accessible from programs written in the C language and the Z80 assembly language.

It is intended to be a simple and easy to use learning tool, for those who want to understand the tips and tricks of the multitasking software systems.

Current version is 2.3

RTM/Z80 will run on the following environments:
• CP/M running under Udo Munk's Z80SIM Z80 simulator (e.g. on Windows, under CygWin)
• RC2014 homebrew Z80 computer, with or without CP/M, using the following configurations:
o SC112 + SC108(Z80 + 32KB SCM EPROM + 2x64KB RAM) + SC110(CTC, SIO) + Digital I/O module
o SC112 + SC108(Z80 + 32KB RTM/Z80 EPROM + 2x64KB RAM) + SC110(CTC, SIO) + Digital I/O module
o SC112 + Karl Brokstad’s Z80 22c module + Memory Module(32KB RTM/Z80 EPROM + 2x64KB RAM) + SC110(CTC, SIO) + Digital I/O module
o SC112 + Karl Brokstad’s Z80 22c module + 512KB RAM/ROM Memory Module + SC110(CTC, SIO) + Digital I/O module

An all other hardware, the I/O ports and interrupt levels must be set "by hand" (see manual, page 98: Porting RTM/Z80 to other hardware)
