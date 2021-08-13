/*
 * RTM/Z80  -  a Real Time Monitor for Z80 computers
 *
 * Copyright (C) 2021 by Ladislau Szilagyi
 *
 * DEMO PROGRAM
 *
 * Two concurrent tasks play two different games:
 *
 * 1. Knight's tour: a sequence of moves of a knight on a chessboard such that he visits every square exactly once
 *		 and returns to the starting square
 * 2. Tower of Hanoi: you have three rods and a number of disks of different diameters, which can slide onto any rod.
 * 	The game starts with the disks stacked on one rod in order of decreasing size, the smallest at the top, 
 *	thus approximating a conical shape. The objective of the puzzle is to move the entire stack to the last rod,
 *	obeying the following 3 simple rules:
 *	- Only one disk may be moved at a time
 *	- Each move takes the upper disk from one of the stacks and placing it on top of another stack or an empty rod
 *	- No disk may be placed on top of a disk that is smaller than it
 *
 * The user can interrupt the games anytime to change the moves speed or quit
 *
 */
#include <stdio.h>
#include <string.h>

#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <rtclk.h>
#include <io.h>

struct Semaphore* Chess_Sem;
struct Semaphore* Hanoi_Sem;
struct Semaphore* IO_Sem;
void* TCB_Chess, *TCB_Hanoi;

void my_printf(char* s)
{
  CON_Write(s,strlen(s),IO_Sem);
  Wait(IO_Sem);
}

/* -----------------------------------------------VT100-------------------------------------------- */

/* escape sequences for VT100 compatible terminal */

#define ESC 27

char ClearScreen[5]={ESC,'[','2','J',0};
char SetYXPos[9]={ESC,'[',' ',' ',';',' ',' ','H',0};
/* 2,3 must be filled with Y coordinates, in decimal */
/* 5,6 must be filled with X coordinates, in decimal */

void SetYX(short y0, short y1, short x0, short x1, char* buf)
{
  SetYXPos[2]=(char)y0;
  SetYXPos[3]=(char)y1;
  SetYXPos[5]=(char)x0;
  SetYXPos[6]=(char)x1;
  strcpy(buf,SetYXPos);
}

/* -----------------------------------------------CHESS--------------------------------------------- */

void xrndseed(void);
short xrnd(void);

short FirstRun=1;

unsigned long ChessCnt=0;

/* Move pattern on basis of the change of x coordinates and y coordinates respectively */
short cx[8]={1,1,2,2,-1,-1,-2,-2};
short cy[8]={2,-2,1,-1,2,-2,1,-1};/* to maintain the knight's position */

/* the chess board */
short board[8*8];

short x,y,sx,sy;

char Column[8] = {'A','B','C','D','E','F','G','H'};
char Row[8] = {'1','2','3','4','5','6','7','8'};
char Moves[128];
char bufChess[40];

void PrintMoves(void)
{
  short i,j,index;

  for (i=0;i<64;i++)
    Moves[i*2]=0;
 
  for (i=0;i<8;i++)
    for (j=0;j<8;j++)
    {
      index=board[j*8+i]-1;
      if (index>=0)
      {
        Moves[index*2]=Column[j];
        Moves[index*2+1]=Row[i];
      }
    }

  for (i=0;i<64;i++)
  {
    if (Moves[i*2] != 0)
    {
      sprintf(bufChess, "\r\nMove nr.%d: Knight %c%c", i+1, Moves[i*2], Moves[i*2+1]);
      my_printf(bufChess);
    }
    else
      break;  
  }
}

void PrintLine1(char* buf)
{
  strcat(buf,"+--+--+--+--+--+--+--+--+");
  my_printf(buf);
}

void PrintLine2(char* buf)
{
  strcat(buf,"|  |  |  |  |  |  |  |  |");
  my_printf(buf);
}

void PrintBaseLine(char* buf)
{
  strcat(buf,"A  B  C  D  E  F  G  H");
  my_printf(buf);
}

void PrintBoard(void)
{
  if (FirstRun)
  {
    SetYX('0','1','0','2',bufChess);
    PrintLine1(bufChess);
    SetYX('0','2','0','1',bufChess);
    strcat(bufChess,"8");
    PrintLine2(bufChess);
    SetYX('0','3','0','2',bufChess);
    PrintLine1(bufChess);
    SetYX('0','4','0','1',bufChess);
    strcat(bufChess,"7");
    PrintLine2(bufChess);
    SetYX('0','5','0','2',bufChess);
    PrintLine1(bufChess);
    SetYX('0','6','0','1',bufChess);
    strcat(bufChess,"6");
    PrintLine2(bufChess);
    SetYX('0','7','0','2',bufChess);
    PrintLine1(bufChess);
    SetYX('0','8','0','1',bufChess);
    strcat(bufChess,"5");
    PrintLine2(bufChess);
    SetYX('0','9','0','2',bufChess);
    PrintLine1(bufChess);
    SetYX('1','0','0','1',bufChess);
    strcat(bufChess,"4");
    PrintLine2(bufChess);
    SetYX('1','1','0','2',bufChess);
    PrintLine1(bufChess);
    SetYX('1','2','0','1',bufChess);
    strcat(bufChess,"3");
    PrintLine2(bufChess);
    SetYX('1','3','0','2',bufChess);
    PrintLine1(bufChess);
    SetYX('1','4','0','1',bufChess);
    strcat(bufChess,"2");
    PrintLine2(bufChess);
    SetYX('1','5','0','2',bufChess);
    PrintLine1(bufChess);
    SetYX('1','6','0','1',bufChess);
    strcat(bufChess,"1");
    PrintLine2(bufChess);
    SetYX('1','7','0','2',bufChess);
    PrintLine1(bufChess);
    SetYX('1','8','0','3',bufChess);
    PrintBaseLine(bufChess);
    SetYX('2','0','0','8',bufChess);
    strcat(bufChess,"Knight's tour");
    my_printf(bufChess);
  }
  else
  {
    Wait(Chess_Sem);
    SetYX('0','2','0','1',bufChess);
    strcat(bufChess,"8");
    PrintLine2(bufChess);
    Wait(Chess_Sem);
    SetYX('0','4','0','1',bufChess);
    strcat(bufChess,"7");
    PrintLine2(bufChess);
    Wait(Chess_Sem);
    SetYX('0','6','0','1',bufChess);
    strcat(bufChess,"6");
    PrintLine2(bufChess);
    Wait(Chess_Sem);
    SetYX('0','8','0','1',bufChess);
    strcat(bufChess,"5");
    PrintLine2(bufChess);
    Wait(Chess_Sem);
    SetYX('1','0','0','1',bufChess);
    strcat(bufChess,"4");
    PrintLine2(bufChess);
    Wait(Chess_Sem);
    SetYX('1','2','0','1',bufChess);
    strcat(bufChess,"3");
    PrintLine2(bufChess);
    Wait(Chess_Sem);
    SetYX('1','4','0','1',bufChess);
    strcat(bufChess,"2");
    PrintLine2(bufChess);
    Wait(Chess_Sem);
    SetYX('1','6','0','1',bufChess);
    strcat(bufChess,"1");
    PrintLine2(bufChess);
  }
}

short LineToY(register line)
{
  return (8-line)*2;
}

short ColumnToX(register column)
{
  return (column*3)+3;
}

MarkLineCol(register line, register col)
{
  register y,x;

  y=LineToY(line);
  x=ColumnToX(col);

  SetYX((short)('0'+(y/10)),(short)('0'+(y%10)),(short)('0'+(x/10)),(short)('0'+(x%10)),bufChess);
  strcat(bufChess,"K");
  my_printf(bufChess);
}

UnMarkLineCol(register line, register col)
{
  register y,x;

  y=LineToY(line);
  x=ColumnToX(col);

  SetYX((short)('0'+(y/10)),(short)('0'+(y%10)),(short)('0'+(x/10)),(short)('0'+(x%10)),bufChess);
  strcat(bufChess," ");
  my_printf(bufChess);
}

/* Warnsdorff algorithm code by Uddalak Bhaduri */

/* function restricts the knight to remain within the 8x8 chessboard */
short limits(short x, short y)
{
  if((x>=0 && y>=0) && (x<8 && y<8))
    return 1;

  return 0;
}

/* checks whether a square is empty or not */
short isempty(short x, short y)
{
  if((limits(x,y)) && (board[y*8+x]<0))
    return 1;

  return 0;
}

/* returns the number of empty squares */
short getcount(short x, short y)
{
  short i,count=0;

  for(i=0;i<8;++i)
    if(isempty((x+cx[i]),(y+cy[i])))
      count++;

  return count;
}

/* calculates the minimum degree(count) of unvisited square among its neighbours and assigns the counter to that square */
short progress(void)
{
  short start,count,i,flag=-1,c,min=(8+1),nx,ny;

  Wait(Chess_Sem);

  start = xrnd()%8;

  for(count=0;count<8;++count)
  {
    i=(start+count)%8;
    nx=x+cx[i];
    ny=y+cy[i];

    if((isempty(nx,ny))&&(c=getcount(nx,ny))<min)
    {
      flag=i;
      min=c;
    }
  }

  if(min==8+1)
    return 0;

  nx=x+cx[flag];
  ny=y+cy[flag];

  board[ny*8+nx]=board[y*8+x]+1;

  MarkLineCol(nx,ny);
  ChessCnt++;

  x=nx;
  y=ny;

  return 1;
}

/* checks its neighbouring squares */
/* If the knight ends on a square that is one knight's move from the beginning square, then tour is closed */
short neighbour(void)
{
  short i;

  for(i=0;i<8;++i)
    if(((x+cx[i])==sx)&&((y+cy[i])==sy))
      return 1;

  return 0;
}

/* generates the legal moves using warnsdorff's heuristics */
short generate()
{
  short i,j;

   for(i=0;i<8;i++)
     for(j=0;j<8;j++)
       board[i*8+j]=-1;/* filling up the chessboard matrix with -1's */

  if (!FirstRun)
    PrintBoard();

  FirstRun=0;

  sx=x=0;
  sy=y=0;

  board[y*8+x]=1; /* initial position */
  MarkLineCol(x,y);
  ChessCnt++;

  for(i=0;i<8*8-1;++i)
    if(!progress())
      return 0;

  if(!neighbour())
    return 0;

  return 1;
}

void Chess(void)
{
  xrndseed();

  while(!generate());

  SetYX('2','1','1','2',bufChess);
  strcat(bufChess,"DONE!");
  my_printf(bufChess);

  StopTask(TCB_Chess);
}

/* -----------------------------------------------CHESS--------------------------------------------- */

/* -----------------------------------------------HANOI--------------------------------------------- */
#define	MAX_N_disks 13

short size[3][MAX_N_disks]; 	/* disk_size=1,2,...N_disks */
short count[3]; 		/* how many disks on the peg = 1,2,...N_disks */
short N_disks;
unsigned long HanoiCnt=0;
char bufHanoi[60];

void SetDiskPos(short layer, short peg)
{
  short y0,y1,x0,x1;
  short y,x;

  y=34-layer;
  x=2+layer+26*peg;

  y0=(short)('0'+(y/10));
  y1=(short)('0'+(y%10));
  x0=(short)('0'+(x/10));
  x1=(short)('0'+(x%10));

  SetYX(y0,y1,x0,x1,bufHanoi);
}

void DrawDisk(short len)
{
  char buf[30];
  short n;

  for (n=0; n<len; n++)
    buf[n]='*';

  buf[n]=0;
  strcat(bufHanoi,buf);
  my_printf(bufHanoi);
}

void EraseDisk(short len)
{
  char buf[30];
  short n;

  for (n=0; n<len; n++)
    buf[n]=' ';

  buf[n]=0;
  strcat(bufHanoi,buf);
  my_printf(bufHanoi);
}

/* Set cursor at the peg's top disk first char
   p = 0,1,2
*/
void GetTopPos(short p)
{
  short y0,y1,x0,x1;
  short y,x;
  short index;

  index=count[p]-1;

  y=34-index;
  x=15-size[p][index]+26*p;

  y0=(short)('0'+(y/10));
  y1=(short)('0'+(y%10));
  x0=(short)('0'+(x/10));
  x1=(short)('0'+(x%10));

  SetYX(y0,y1,x0,x1,bufHanoi);
}

void move(short frompeg, short topeg)
{
  short index;
  short sz;

  GetTopPos(frompeg);
  index=count[frompeg]-1;
  sz=size[frompeg][index];
  EraseDisk((2*sz)-1);
  count[frompeg]--;

  index=count[topeg];
  size[topeg][index]=sz;
  count[topeg]++;
  GetTopPos(topeg);
  DrawDisk((2*sz)-1);
  
  HanoiCnt++;
}

void towers(short num, short frompeg, short topeg, short auxpeg)
{
  if (num == 1)
  {
    Wait(Hanoi_Sem);
    move(frompeg, topeg);
    return;
  }

  towers(num - 1, frompeg, auxpeg, topeg);
  Wait(Hanoi_Sem);
  move(frompeg, topeg);
  towers(num - 1, auxpeg, topeg, frompeg);
}

void InitDisks(void)
{
  short n;

  N_disks=MAX_N_disks;

  count[0]=N_disks;
  count[1]=0;
  count[2]=0;

  for (n=0; n<N_disks; n++)
    size[0][n]=N_disks-n;

  for (n=0; n<N_disks; n++)
  {
    SetDiskPos(n, 0);
    DrawDisk((2*N_disks)-1-(2*n));
  }

  SetYX('3','6','0','8',bufHanoi);
  strcat(bufHanoi,"Tower of Hanoi");
  my_printf(bufHanoi);
}

void Hanoi(void)
{
  towers(N_disks, 0, 1, 2);

  SetYX('3','7','1','2',bufHanoi);
  strcat(bufHanoi,"DONE!");
  my_printf(bufHanoi);

  StopTask(TCB_Hanoi);
}

/* -----------------------------------------------HANOI--------------------------------------------- */

void (*fp)(void);

char* Wellcome="\r\nRTM/Z80 Demo program\r\nShowing two concurrent games being played: Chess Knight's tour & Tower of Hanoi";
char* ScreenWarning="\r\nPlease extend the VT100 compatible window size to at least 48 rows x 80 columns";
char* Ctrl_C_notice="\r\nPlease press ENTER to start!\r\n(you will be able to vary the speed by pressing CTRL_C)";
char* Ctrl_C_event="Please enter your choice (0=faster, 1=slower, 2=quit):";

struct Semaphore* Timer_Sem;

char Speed[2];
short Pause, MinPause, TicsPerSec;
struct RTClkCB* Timer;
unsigned long ts,te;
char bufMain[100];

void ReportAndQuit(void)
{
  SetYX('4','1','0','1',bufMain);
  my_printf(bufMain);
  te=GetTicks();
  sprintf(bufMain, "\r\nHanoi Towers moves (so far): %ld", HanoiCnt);
  my_printf(bufMain);
  sprintf(bufMain, "\r\nChess moves (so far): %ld", ChessCnt);
  my_printf(bufMain);
  PrintMoves();
  sprintf(bufMain, "\r\nTime elapsed: %ld seconds", ((unsigned long)(te-ts)/TicsPerSec));
  my_printf(bufMain);
  ShutDown();
}

void MainTask(void)
{
  IO_Sem = MakeSem();
  Chess_Sem = MakeSem();
  Hanoi_Sem = MakeSem();
  Timer_Sem = MakeSem();
  Timer = MakeTimer();

  my_printf(Wellcome);
  my_printf(ScreenWarning);

  if (GetHost())
  {
    Pause=200;
    MinPause=10;
    TicsPerSec=200;
  }
  else
  {
    Pause=100;
    MinPause=5;
    TicsPerSec=100;
  }

  my_printf(Ctrl_C_notice);

  CON_Read(Speed,1,IO_Sem);
  Wait(IO_Sem);

  ts=GetTicks();

  my_printf("\033[2J");	/* clear screen */

  PrintBoard(); /* print Chess board */
  InitDisks(); /* init Hanoi */

  fp = Chess;
  TCB_Chess = RunTask(0x7E0, (void*)fp, 6);

  fp = Hanoi;
  TCB_Hanoi = RunTask(0x7E0, (void*)fp, 5);

  StartTimer(Timer, Timer_Sem, Pause, 1);

  do
  {
    Wait(Timer_Sem);
    
    if (GetTaskSts(TCB_Chess))
      Signal(Chess_Sem);

    Wait(Timer_Sem);

    if (GetTaskSts(TCB_Hanoi))
      Signal(Hanoi_Sem);

    if (!GetTaskSts(TCB_Chess) && !GetTaskSts(TCB_Hanoi))
      ReportAndQuit();
 
    if (CTRL_C())
    {
      StopTimer(Timer);

      StartTimer(Timer, Timer_Sem, Pause*2, 0); /* wait 2 seconds */
      Wait(Timer_Sem);

      SetYX('4','1','0','1',bufMain);

      strcat(bufMain,Ctrl_C_event);
      my_printf(bufMain);

      CON_Read(Speed,1,IO_Sem);
      Wait(IO_Sem);

      SetYX('4','1','0','1',bufMain);
      strcat(bufMain,"\033[2K");	/* erase line */
      my_printf(bufMain);

      if (Speed[0] == '2')
      {
        StopTask(TCB_Chess);
        StopTask(TCB_Hanoi);
        ReportAndQuit();
      }

      if (Speed[0] == '0')
      {
        Pause=Pause/2;

	/* limit the speed */
        if (Pause<MinPause)
          Pause=MinPause;
      }
      else
        Pause=Pause*2;

      StartTimer(Timer, Timer_Sem, Pause, 1);
    }
  } while (1==1);
}

void main(void)
{
  fp = MainTask;
  StartUp(0x1E0, (void*)fp, 10);
}
