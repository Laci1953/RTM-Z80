/********************************************************************

Game 'Birds, eagle and the kite'

Designed for RTM/Z80
as an example of a CP/M game running 
on a Z80 multitasking operating system

Build procedure:

1. RTM/Z80

Use the following settings in CONFIG.MAC:

C_LANG equ 1

then execute:

submit make
submit makelib
(this will build RT.LIB - the RTM/Z80 system library)

2. BIRDS.COM

Build-it on CP/M with the HiTech C compiler,
using the following SUBMIT file:

xsub
z80as rand
c -v -c -o birds.c
link
-pboot=0E300H/100H,zero=0/,text/,data/,ram=0D000H/,bss/ -c100h -obirds.com \
cpmboot.obj birds.obj rand.obj rt.lib libc.lib

Run the 'birds.com' as a CP/M executable
(it will boot RTM/Z80 & execute the game)

Ladislau Szilagyi, September 2023

********************************************************************/

//#define Z80ALL	

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

// RTM/Z80 include files
#include "dlist.h"
#include "balloc.h"
#include "rtsys.h"
#include "rtclk.h"
#include "io.h"

#ifdef Z80ALL
#include "vga.h"
#endif

typedef char bool;
#define TRUE 	1
#define FALSE 	0

// screen size

#define	X_COUNT		64
#define	Y_COUNT		48

#define	EMPTY	' '
#define	KITE	'#'

#define BIRD_AVAILABLE	0
#define BIRD_FLYING	1

typedef struct _bird
{
	int 	x;
	int 	y;
	char 	status;
} bird;

#define MIN_DELTA	200

#define	BIRDS_COUNT		X_COUNT
#define	FLYING_BIRDS_MAX_COUNT	10

bird	FlyingBirds[FLYING_BIRDS_MAX_COUNT];
int	Delta[FLYING_BIRDS_MAX_COUNT];

int	MovesToWait = 10;

#define	X_EAGLE		(X_COUNT / 2) - 1
#define	Y_EAGLE		0

#define	X_KITE		(X_COUNT / 2) - 1
#define	Y_KITE		(Y_COUNT / 2) - 1

#define	UP	'e'
#define	DOWN	'x'
#define	LEFT	's'
#define	RIGHT	'd'
#define	FASTER	'm'
#define	SLOWER	'l'
#define QUIT	'q'

// bird flap wings
// 1,2,1		v _ v 
#define	BIRD_1	'v'
#define	BIRD_2	'_'

// eagle flap wings
// 1,2,1		W _ W	
#define	EAGLE_1	'W'
#define	EAGLE_2	'_'

char	Key;

int	Escaped = 0;
int	Captured = 0;

bool	gotBird;

#define	BASE_EMPTY	0
#define	BASE_BIRD	1

char 	BirdsBase[X_COUNT];
int 	BirdsAvailable;

int 	EagleX, EagleY;
int 	KiteX, KiteY;

int	FLAP_WINGS_TICS;
int	KITE_TICS;

void (*fp)(void);

struct Semaphore	*SemFlapWings;
struct Semaphore	*SemKite;
struct Semaphore	*SemBase;
struct Semaphore 	*W;
#ifndef Z80ALL
struct Semaphore	*WXY;
#endif

struct RTClkCB		*TimerFlapWings;
struct RTClkCB		*TimerKite;

char	*MsgBegin1 = 	"\r\n\nThe game 'Birds, eagle and the kite'\r\n\n"
#ifndef Z80ALL
			"(please increase the window size to 48 lines)\r\n"
#endif
			"By moving the kite (#), try to protect the 64 birds (v)\r\n";
char	*MsgBegin2 =	" from the attack of the quick eagle (W).\r\n"
			"Each bird will try to fly higher and higher, to safety;\r\n";
char	*MsgBegin3 =	" reaching the top of screen, it escapes the eagle.\r\n"
			"The eagle will try to hunt them, by moving closer and closer.\r\n";
char	*MsgBegin4 =	"If the eagle reaches a bird, the bird is captured.\r\n"
			"But, the eagle can be blocked by the kite and must\r\n";
char	*MsgBegin5 =	" go around it; it's the only chance for the poor birds!\r\n"
			"Keys to move the kite: s=left, d=right, e=up, x=down\r\n";
char	*MsgBegin6 =	"To change the speed at which the eagle flies, press m=faster, l=slower\r\n"
			" (the game starts with a lazy eagle)\r\n"	
			"To quit, press q\r\nPress any key to start...";
char	*MsgEndGame = 	"\r\n\n%d birds escaped and %d birds were captured by the eagle\r\n";

char 	buf[100];

unsigned int	xrnd(void);
void    	xrndseed(void);

void	TaskBirdsAndEagle(void);
void	TaskKite(void);

struct TaskCB	*TCBBirdsAndEagle;

#ifndef Z80ALL

#define	ESC	0x1B

char	*pScreen;

char	Screen(int x, int y)
{
	return *(pScreen + (y * X_COUNT) + x);
}

char	InCharVGA(int x, int y)
{
	return Screen(x, y);
}

// returns 0xAhAl : Ah = decimal ascii (high part), Al = decimal ascii (low part)
int 	IntToDecAscii(int v)
{
        char Ah = '0', Al;

        Al = '0' + (v % 10);
        v /= 10;

        if (v != 0)
                Ah = '0' + (v % 10);

        return (int)(Ah << 8) | Al;
}

void	OutCharVGA(int col, int row, char ch)
{
        int v, n;
        char a, b;

	*(pScreen + (row * X_COUNT) + col) = ch;

        buf[0] = ESC;
        buf[1] = '[';

        n = 2;
        v = IntToDecAscii(row+1);
        a = (char)(v >> 8);
        b = (char)(v & 0xFF);

        if (a != '0')
                buf[n++] = a;

        buf[n++] = b;
        buf[n++] = ';';

        v = IntToDecAscii(col+1);
        a = (char)(v >> 8);
        b = (char)(v & 0xFF);

        if (a != '0')
                buf[n++] = a;

        buf[n++] = b;
        buf[n++] = 'H';

        buf[n++] = ch;

	CON_Write(buf, n, W);
	Wait(W);
}

char	*cOFF = "\x1B[?25l";
void	CursorOFF(void)
{
	CON_Write(cOFF, strlen(cOFF), W);
	Wait(W);
}

char	*cON = "\x1B[?25h";
void	CursorON(void)
{
	CON_Write(cON, strlen(cON), W);
	Wait(W);
}

char	*clear = "\x1B[2J\x1BH";
void 	CrtClear(void)
{
	int	x, y;
	char	*p = pScreen;

	CON_Write(clear, strlen(clear), W);
	Wait(W);

	for (x = 0; x < X_COUNT; x++)
		for (y = 0; y < Y_COUNT; y++)
			*p++ = EMPTY;
}  

#endif

int	RandBird(void)
{
	return (xrnd() >> 8) & 0x3F;
}

bool	IsEmpty(int x, int y)
{
	return (InCharVGA(x, y) == EMPTY);
}

void	Init(void)
{
	int	x, n;

	n = GetHost();

	if (n == 0)
	{		//Z80SIM
		FLAP_WINGS_TICS = 5;	//50 ms
		KITE_TICS = 10;		//100 ms
	}
	else if (n == 1)
	{		//RC2014 SC108
		FLAP_WINGS_TICS = 10;	//50 ms
		KITE_TICS = 20;		//100 ms
	}
	else
	{		//Z80ALL
		FLAP_WINGS_TICS = 20;	//50 ms
		KITE_TICS = 40;		//100 ms
	}

#ifndef Z80ALL
	pScreen = Balloc(8);	// alloc 1000H

	pScreen += 6;	// skip memory block link area
#endif
	W = MakeSem();
	SemFlapWings = MakeSem();
	SemKite = MakeSem();
	SemBase = MakeSem();

#ifndef Z80ALL
	WXY = MakeSem();
	Signal(WXY);
#endif

	TimerFlapWings = MakeTimer();
	TimerKite = MakeTimer();

	CON_Write(MsgBegin1, strlen(MsgBegin1), W);
	Wait(W);
	CON_Write(MsgBegin2, strlen(MsgBegin2), W);
	Wait(W);
	CON_Write(MsgBegin3, strlen(MsgBegin3), W);
	Wait(W);
	CON_Write(MsgBegin4, strlen(MsgBegin4), W);
	Wait(W);
	CON_Write(MsgBegin5, strlen(MsgBegin5), W);
	Wait(W);
	CON_Write(MsgBegin6, strlen(MsgBegin6), W);
	Wait(W);

	do
	{
	} while (CON_Status() == 0);

	xrndseed();

	CrtClear();

#ifndef Z80ALL
	CursorOFF();
#endif

	for (x = 0; x < X_COUNT; x++)
	{
		BirdsBase[x] = BASE_BIRD;
		OutCharVGA(x, Y_COUNT - 1, BIRD_1);
	}

	EagleX = X_EAGLE;
	EagleY = Y_EAGLE;
	OutCharVGA(X_EAGLE, Y_EAGLE, EAGLE_1);

	KiteX = X_KITE;
	KiteY = Y_KITE;
	OutCharVGA(X_KITE, Y_KITE, KITE);

	// populate FlyingBirds
	n = 0;

	do
	{
		x = RandBird();
		
		if (BirdsBase[x] != BASE_EMPTY)
		{
			FlyingBirds[n].x = x;
			FlyingBirds[n].y = Y_COUNT - 1;
			FlyingBirds[n].status = BIRD_FLYING;
			BirdsBase[x] = BASE_EMPTY;
			n++;
		}
	} while (n < FLYING_BIRDS_MAX_COUNT);

	BirdsAvailable = X_COUNT - FLYING_BIRDS_MAX_COUNT;

	// start "kite" timer
	StartTimer(TimerKite, SemKite, KITE_TICS, 1);

	fp = TaskBirdsAndEagle;
	TCBBirdsAndEagle = RunTask(0x1E0, (void*)fp, 60);

	fp = TaskKite;
	RunTask(0x1E0, (void*)fp, 80);
}

// report results & shutdown
void	ReportResult(void)
{
	if (GetCrtTask() != TCBBirdsAndEagle)
		StopTask(TCBBirdsAndEagle);

	CrtClear();

	sprintf(buf, MsgEndGame, Escaped, Captured);

	CON_Write(buf, strlen(buf), W);
	Wait(W);

#ifndef Z80ALL	
	CursorON();
#endif

	ShutDown();
}

// takes 2 x FLAP_WINGS_TICS (100ms)
void FlapBirdWings(int i, int deltaX, int deltaY)
{
	int	x, y;

	x = FlyingBirds[i].x;
	y = FlyingBirds[i].y;

#ifndef Z80ALL
	Wait(WXY);
#endif

	StartTimer(TimerFlapWings, SemFlapWings, FLAP_WINGS_TICS, 1);

	// BIRD_1 is already shown
	OutCharVGA(x, y, BIRD_2);
	Wait(SemFlapWings);
	OutCharVGA(x, y, BIRD_1);
	Wait(SemFlapWings);

	StopTimer(TimerFlapWings);

	OutCharVGA(x, y, EMPTY); //erase-it

	FlyingBirds[i].x += deltaX; 
	FlyingBirds[i].y += deltaY; 

	OutCharVGA(FlyingBirds[i].x, FlyingBirds[i].y, BIRD_1);

#ifndef Z80ALL
	Signal(WXY);
#endif
}

// takes 2 x FLAP_WINGS_TICS (100ms)
void FlapEagleWings(int deltaX, int deltaY)
{
#ifndef Z80ALL
	Wait(WXY);
#endif

	StartTimer(TimerFlapWings, SemFlapWings, FLAP_WINGS_TICS, 1);

	// EAGLE_1 is already shown
	OutCharVGA(EagleX, EagleY, EAGLE_2);
	Wait(SemFlapWings);
	OutCharVGA(EagleX, EagleY, EAGLE_1);
	Wait(SemFlapWings);

	StopTimer(TimerFlapWings);

	OutCharVGA(EagleX, EagleY, EMPTY); //erase-it

	EagleX += deltaX;
	EagleY += deltaY;

	OutCharVGA(EagleX, EagleY, EAGLE_1);

#ifndef Z80ALL
	Signal(WXY);
#endif
}

// returns delta to eagle
int DeltaToEagle(int x, int y)
{
	int	dx, dy;

	dx = abs(x - EagleX);
	dy = abs(y - EagleY);
	return ((dx * dx) + (dy * dy));
}

bool	EagleTooClose(int x, int y)
{
	return (DeltaToEagle(x, y) < MIN_DELTA);
}

// move eagle if kite is not obstructing passage
bool	MoveEagle(int deltaX, int deltaY)
{
	// if KITE not next...
	if (InCharVGA(EagleX + deltaX, EagleY + deltaY) != KITE) 
	{
		FlapEagleWings(deltaX, deltaY);
		return TRUE;
	}
	else // kite obstructs the eagle
		return FALSE;
}

// eagle moves towards the closest bird
void	MoveEagleCloser(void)
{
	int	i, x, y, dx, dy, min, i_min;
	bool	hasMoved;

	i_min = 99;
	hasMoved = FALSE;

	// compute distance metrics
	for (i = 0; i < FLYING_BIRDS_MAX_COUNT; i++)
	{
		if (FlyingBirds[i].status == BIRD_FLYING)
		{
			dx = abs(EagleX - FlyingBirds[i].x);
			dy = abs(EagleY - FlyingBirds[i].y);
			Delta[i] = (dx * dx) + (dy * dy);
		}
	}

	// find the closest bird index
	min = 0x7FFF;

	for (i = 0; i < FLYING_BIRDS_MAX_COUNT; i++)
	{
		if (FlyingBirds[i].status == BIRD_FLYING)
		{
			if (min > Delta[i])
			{
				min = Delta[i];
				i_min = i;
			}
		}
	}

	if (i_min == 99)
		return;

	// i_min = closest bird index
	x = FlyingBirds[i_min].x;
	y = FlyingBirds[i_min].y;
		
	if (y == Y_COUNT - 1)
	{
		i = (xrnd() >> 8) & 3;
		
		switch (i)
		{
			case 0:	
				if (EagleY > 0)
					MoveEagle(0, -1);
				break;
			case 1:
				if (EagleX > 0)
					MoveEagle(-1, 0);
				break;
			case 2:
				if (EagleX < X_COUNT - 1)
					MoveEagle(1, 0);
				break;
		}
		return;
	}

	if (abs(EagleX - x) > abs(EagleY - y))
	{
		// try to move on the X axis
		if (EagleX < x)
			hasMoved = MoveEagle(1, 0);
		else
			hasMoved = MoveEagle(-1, 0);
	}

	if (!hasMoved)
	{
		// try to move on the Y axis
		if (EagleY < y)
			MoveEagle(0, 1);
		else
			MoveEagle(0, -1);
	}
}

// capture bird
void	CaptureBird(int birdIndex, int deltaX, int deltaY)
{
	FlapEagleWings(deltaX, deltaY);

	FlyingBirds[birdIndex].status = BIRD_AVAILABLE;
	Captured ++;

	if (Escaped + Captured == BIRDS_COUNT)
		ReportResult();

	Signal(SemBase); // ask for another bird
				
	gotBird = TRUE;
}

// handles eagle behavior
void	Eagle(void)
{
	int	i, x, y;

	// try to capture a bird
	gotBird = FALSE;

	for (i = 0; i < FLYING_BIRDS_MAX_COUNT; i++)
	{
		if (!gotBird)
		{
			if (FlyingBirds[i].status == BIRD_FLYING)
			{
				x = FlyingBirds[i].x;
				y = FlyingBirds[i].y;

				if (EagleX == x - 1 && EagleY == y)
					CaptureBird(i, 1, 0);
				else if (EagleX == x + 1 && EagleY == y)
					CaptureBird(i, -1, 0);
				else if (EagleX == x && EagleY == y - 1)
					CaptureBird(i, 0, 1);
				else if (EagleX == x && EagleY == y + 1)
					CaptureBird(i, 0, -1);
			}
		}
	}

	// otherwise move towards the closest bird
	if (!gotBird)
		MoveEagleCloser();
}

// handles birds & eagle
// medium priority
void	TaskBirdsAndEagle(void)
{
	int	i, x, y, birds_moved;

	birds_moved = 0;
	
	do
	{
		// handle the birds
		for (i = 0; i < FLYING_BIRDS_MAX_COUNT; i++)
		{	
			if (FlyingBirds[i].status == BIRD_FLYING)
			{
				x = FlyingBirds[i].x;
				y = FlyingBirds[i].y;

				//try moving bird
				birds_moved ++;

				if (y == 0)
				{
					// if bird at top screen, bird escapes
#ifndef Z80ALL
					Wait(WXY);
#endif
					OutCharVGA(x, y, EMPTY);
#ifndef Z80ALL
					Signal(WXY);
#endif
					Escaped++;

					if (Escaped + Captured == BIRDS_COUNT)
						ReportResult();

					FlyingBirds[i].status = BIRD_AVAILABLE;
					Signal(SemBase); // ask for another bird
				}
				else if (!EagleTooClose(x, y))
				{
					if (IsEmpty(x, y - 1))
						FlapBirdWings(i, 0, -1);
					else if (x != 0 && IsEmpty(x - 1, y))
						FlapBirdWings(i, -1, 0);
					else if (x != X_COUNT - 1 && IsEmpty(x + 1, y))
						FlapBirdWings(i, 1, 0);
					else if (y != Y_COUNT - 1 && IsEmpty(x, y + 1))
						FlapBirdWings(i, 0, 1);
				}
				else
				{
					if (IsEmpty(x, y - 1) && DeltaToEagle(x, y - 1) > DeltaToEagle(x, y))
						FlapBirdWings(i, 0, -1);
					else if (x != 0 && IsEmpty(x - 1, y) && DeltaToEagle(x - 1, y) > DeltaToEagle(x, y))
						FlapBirdWings(i, -1, 0);
					else if (x != X_COUNT - 1 && IsEmpty(x + 1, y) && DeltaToEagle(x + 1, y) > DeltaToEagle(x, y))
						FlapBirdWings(i, 1, 0);
					else if (y != Y_COUNT - 1 && IsEmpty(x, y + 1) && DeltaToEagle(x, y + 1) > DeltaToEagle(x, y))
						FlapBirdWings(i, 0, 1);
					// else do not move it...
				}
			}

			// now, move the eagle
			if (birds_moved >= MovesToWait)
			{
				birds_moved = 0;
				Eagle();
			}
		}

	} while (1);
}

// move kite
void	MoveKite(int deltaX, int deltaY)
{
#ifndef Z80ALL
	Wait(WXY);
#endif
	OutCharVGA(KiteX, KiteY, EMPTY);
	KiteX += deltaX;
	KiteY += deltaY;
	OutCharVGA(KiteX, KiteY, KITE);
#ifndef Z80ALL
	Signal(WXY);
#endif
}

// Try to move the kite
// highest priority
void	TaskKite(void)
{
	do
	{
		// each 100 ms
		Wait(SemKite);

		if ((Key = CON_Status()) != 0)
		{
			switch (Key)
			{
				case UP:
					if (KiteY != 0 && IsEmpty(KiteX, KiteY - 1))
						MoveKite(0, -1);
					break;
				case DOWN:
					if (KiteY != Y_COUNT - 1 && IsEmpty(KiteX, KiteY + 1))
						MoveKite(0, 1);
					break;
				case LEFT:
					if (KiteX != 0 && IsEmpty(KiteX - 1, KiteY))
						MoveKite(-1, 0);
					break;
				case RIGHT:
					if (KiteX != X_COUNT - 1 && IsEmpty(KiteX + 1, KiteY))
						MoveKite(1, 0);
					break;
				case FASTER:
					if (MovesToWait > 1)
						MovesToWait --;
					break;
				case SLOWER:
					if (MovesToWait < 10)
						MovesToWait ++;
					break;
				case QUIT:
					ReportResult();
				default:
					break;
			}
		}
	} while (1);
}

// keeps FlyingBirds filled
// lowest priority
void	TaskStart(void)
{
	int	i, j;
	
	Init();

	do
	{
		Wait(SemBase); // wait until eagle captured bird or bird escaped

		if (BirdsAvailable > 0)
			do
			{
				// find a random, available bird in base
				i = RandBird();

				if (BirdsBase[i] == BASE_BIRD)
				{
					BirdsBase[i] = BASE_EMPTY;

					// find a free slot in FlyingBirds
					for (j = 0; j < FLYING_BIRDS_MAX_COUNT; j++)
					{
						if (FlyingBirds[j].status == BIRD_AVAILABLE)
						{
							FlyingBirds[j].status = BIRD_FLYING;
							FlyingBirds[j].x = i;
							FlyingBirds[j].y = Y_COUNT - 1;
							BirdsAvailable --;
							break;
						}
					}

					break;
				}
			} while (1);
	} while (1);
}

//here starts the execution
void main(void)
{
	fp = TaskStart;
	StartUp(0x1E0, (void*)fp, 20);	// boot RTM/Z80 and start TaskStart
}
