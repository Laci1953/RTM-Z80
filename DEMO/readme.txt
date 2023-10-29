Demo programs
-------------

Various demo apps, showing RTM/Z80 in action.

RTMDEMO: 2 concurrent games (Chess Knights's tour & Hanoi towers) being played in parallel
MSORT: merge sort using multitasking
BIRDS: the 'birds, eagle & kite' game
GETXFILE & PUTXFILE implement the XMODEM protocol (SIO, 115200 bauds).
They can be used to move files from/to RC2014 - from/to the computer/laptop that runs the terminal (e.g. TeraTerm).

- getxfile copies files from the laptop to RC2014
- putxfile copies files from RC2014 to the laptop

getxfile.com & putxfile.com can be executed in CP/M; when started, RTM/Z80 is booted and a multitasking application is launched.

Of course, you must use in TeraTerm the command : File > Transfer > XMODEM > Send or Receive, after being notified 
( you receive a message like: "...you have 30 secs to initiate sending the file via XMODEM..." )

They perform all the serial communication I/O, at 115200 bauds, on interrupts.

