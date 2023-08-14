Demo programs
-------------

New in v2.4: getxfile & putxfile implement the XMODEM protocol.

They can be used to move files from/to RC2014 - from/to the computer/laptop that runs the terminal (e.g. TeraTerm).

- getxfile copies files from the laptop to RC2014
- putxfile copies files from RC2014 to the laptop

getxfile.com & putxfile.com can be executed in CP/M; when started, RTM/Z80 is booted and a multitasking application is launched.

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

