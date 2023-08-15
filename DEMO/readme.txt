Demo programs
-------------

New in v2.4: getxfile & putxfile implement the XMODEM protocol (SIO, 115200 bauds).

They can be used to move files from/to RC2014 - from/to the computer/laptop that runs the terminal (e.g. TeraTerm).

- getxfile copies files from the laptop to RC2014
- putxfile copies files from RC2014 to the laptop

getxfile.com & putxfile.com can be executed in CP/M; when started, RTM/Z80 is booted and a multitasking application is launched.

Of course, you must use in TeraTerm the command : File > Transfer > XMODEM > Send or Receive, after being notified 
( you receive a message like: "...you have 30 secs to initiate sending the file via XMODEM..." )

They perform all the serial communication I/O, at 115200 bauds, on interrupts.

They are configured to be used on RC2014's provided with SC108 + SC110.

Example of use:
--------------

D>getxfile

RTM/Z80 2.3
Receive files via XMODEM
Save file as (e.g. a:myfile.txt<CR>) : d:bdosbios.as
...you have 30 secs to initiate sending the file via XMODEM...
File received & saved
Press 'y/Y' to receive another file:n

Small Computer Monitor - S3
*cpm
RC2014 CP/M BIOS 1.2 by G. Searle 2007-18

CP/M 2.2 Copyright 1979 (c) by Digital Research

A>d:
D>sdir bdosbios.as

Directory For Drive D:  User  0

    Name     Bytes   Recs   Attributes
------------ ------ ------ ------------
BDOSBIOS AS    168k   1334 Dir RW

D>z80as bdosbios.as
Z80AS Macro-Assembler V4.8

Errors: 0
Finished.

D>putxfile

RTM/Z80 2.3
Sends files via XMODEM
Send file (e.g. a:myfile.txt<CR>) : d:t.txt
...you have 30 secs to initiate receiving the file via XMODEM...
File sent
Press 'y/Y' to send another file:n

Small Computer Monitor - S3
*

How to configure RTM/Z80 to use getxfile & putxfile
---------------------------------------------------

In config.mac, use the following settings:

DEBUG		equ 0	;1=debug mode ON: verify task SP, task TCB, dealloc, lists, etc.
SIM	    equ 0	;1=Runs under Z80SIM, 0=Runs on RC2014(SC108+SC110)
DIG_IO		equ 1	;1=RC2014 Digital I/O module is used    ( IN CASE YOU HAVE THE DIGITAL MODULE ! )
CMD	    equ 0	;1=CON CMD task is included
RSTS		equ 1	;1=use RST for list routines (not for SIM)
WATSON		equ 0	;1=Watson is used (not for SIM)
C_LANG		equ 1	;1=Support for C language API
IO_COMM		equ 1	;1=Support for async communications I/O
SC108		equ 1	;1=SC108 is used (32KB ROM, 128KB RAM)
MM	    equ 0	;1=Memory Module is used (32KB ROM, 128KB RAM)
M512		equ 0	;1=512KB ROM & RAM module is used (512KB ROM, 512KB RAM)
BDOS		equ 1	;1=BDOS disk file support
LPT	    equ 0	;1=Parallel Printer (Compatibility mode)
DYNM512		equ 0	;1=Extended dynamic memory support for M512 (set-it to 0 if M512=0)
;
;	ROM/RAM options (only if SIM=0)
;
RAM128K		equ 1	;0=only 64K RAM, 1= 2 x 64K RAM available
ROM		    equ 0	;1=sys code on ROM, 0=ROM not used
BOOT_CODE	equ 0	;1=bootstrap code included in code, 0=no bootstrap code

Then, build RTM/Z80:

>submit make

and the RT.LIB library:

>submit makelib

Then, to build the executables: (you need the following files: filex.as, getxfile.c, putxfile.c )

>submit makegetx
>submit makeputx

Now, the executables are ready to be used...

