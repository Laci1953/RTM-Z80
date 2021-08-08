# RTM-Z80
Retro Tiny Multitasking system for Z80 based computers
RTM/Z80 is a multitasking kernel, built for Z80 based computers, written in Z80 assembly language, providing its users with an Application Programming Interface (API) accessible from programs written in the C language and the Z80 assembly language.
It is intended to be a simple and easy to use learning tool, for those who want to understand the tips and tricks of the multitasking software systems.
Basic RTM/Z80 characteristics and features:
•	May be run directly under CP/M 2.2 on any vintage Z80 based computer as a .COM executable program, or may be run on any simulated/emulated Z80 system, or on any Z80 retro/home brew computer (e.g. RC2014).
•	It’s very easy to build applications that use RTM/Z80. Using the HiTech vintage C compiler, assembler and linker, the application can be quickly compiled, assembled and linked with the RTM/Z80 library, in a minimal number of steps.
•	It’s easy to configure. It can be quickly tailored according to the user options. Can be built as an object code library or can be ported to a (E)EPROM + RAM configuration.
•	It’s quite small. In its minimal version, it requires less than 4KB ROM plus 8K RAM
•	It’s enough fast. The following measurements are valid for a Z80 CPU running at 7.3728 MHz:
o	Task switching time (switching from a task executing a semaphore “signal” to another task “waiting” for the semaphore) is under 160 microseconds. 
o	Allocate/deallocate a block of dynamic memory takes under 130 microseconds
o	Run/stop task operations are executed in less than 220 microseconds
•	Its functions are easy to be used (no complicated C or assembler data structures need to be initialized)
•	Provides 8KB of RAM dynamic memory, enabling users to allocate/deallocate blocks of memory of variable sizes, from 16 bytes to 4 Kbytes.
•	Users can define and run up to 32 concurrent tasks. The highest priority task gains CPU access.
•	RTM/Z80 is basically a “cooperative” multitsaking system; however, round-robin pre-emptive scheduling is possible, and can be switched on/off using the API
•	Semaphores can be used to control access to common resources. Semaphores are implemented as “counting” semaphores. There is no limit regarding the number of semaphores that can be used.
•	Queues and mailboxes can be used for inter-task communication. Messages can be sent and received between tasks. There is no limit regarding the number of queues or mailboxes that can be used.
•	Timers can be used to delay/wait for variable time intervals (multiple of 5 milliseconds). There is no limit regarding the number of timers that can be used.
•	Interrupt driven I/O drivers are used to perform I/O requests targeted to serial hardware devices (console, printer, etc.) for baud rates up to 115.2 K
RTM/Z80 is a “low profile” multitasking system; it is written entirely in Z80 assembler language and uses as a building platform the vintage HiTech Z80 software, which may be run on a “real” Z80 computer or on a Z80 “simulator”. However, you can use also the C language and “mix” C code with Z80 assembly code when writing RTM/Z80 applications.
RTM/Z80 does not pretend to be a “real-time” system; for this target, you need much more powerful CPU power; the 7.3728 MHz Z80 is a low-placed processor in this perspective.
Builing RTM/Z80 applications does not imply the use of any Unix/Linux development platform. All you need is CP/M, knowledge of Z80 assembly language or C language and being used to operate the HiTech tools (assembler, C compiler, linker).
RTM/Z80 is not a “concurrent” of the many Z80 multitasking systems available on the market, it is only a learning tool for those who want to understand the “tips & tricks” of multitasking; because of this, it’s structure is simple and straightforward. However, the author tried to build also a versatile and efficient system, with performances comparable with other popular Z80 multitasking systems.
