This folder contains an example of RTM/Z80 application executed as overlayed tasks on an RC2014 provided with the 512KB RAM + 512KB ROM memory module

This is the same code as in TESTS/ttask.c

First task (main) is T.C, it contains StartUP, and calls another task using RunTask512.

To build T.COM, use:

>c -v -c t.c
>link
 -c100h -pboot=0E300h/100h,zero=0/,text/,data/,ram=8000h/,bss/ \
 -ot.com -dt.sym cpmboot.obj t.obj rt.lib libc.lib

The second task is T1.C (it calls the third task, using RunTask512), compile-it:

>c -v -c t1.c

The third task is T2.C, compile-it:

>c -v -c t2.c

Before linking T1 & T2, edit S.SYM, and keep only the functions called by T1 & T2:

1317 _Balloc
065A _RunTask512
08F0 _StopTask
0B0E _CON_Write
07A7 _IncTaskStack
09A4 _GetCrtTask
23B4 _strlen

Then, use SYMTOAS.COM (see RESOURCES/symtoas.c) and assemble the output, to obtain tbase.obj:

>symtoas tbase.as s.sym
>z80as tbase

Now, we can link T1 & T2 to obtain the .HEX files to be stored on the 512KB EPROM:

>link
 -ptext=4000h,data -ot1rom.obj t1.obj tbase.obj csv.obj
>link
 -ptext=4000h/8000h,data/ -ot2rom.obj t2.obj tbase.obj csv.obj
>objtohex t1rom.obj t1rom.hex
>objtohex t2rom.obj t2rom.hex

So, we built T1 to be stored at 4000H and executed at 4000H, and T2 to be stored at 8000H but executed at 4000H (they are the "overlays").

As a final step, we burn the T1ROM.HEX & T2ROM.HEX, after the CP/M booter (the 512KB EPROM allways has as the first 16KB bank the CP/M booter...).

Now, we can execute the application, simply by executing T.COM:

>T<CR>


