#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

void watson(void);

void (*fp)(void);

struct TaskCB* t;
struct Semaphore *SN,*S200,*S50,*S10;
short TaskNRuns=0;

char bufN[100];
char buf200[100];

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  Wait(S);
}

void TaskN(void)
{
  TaskNRuns++;

  sprintf(bufN,"\r\nN running for the %d time",TaskNRuns);
  C_printf(bufN,SN);

  Signal(S200);

  StopTask(GetCrtTask());
}

void Task200(void)
{
  short n=250;

  C_printf("\r\n200 running...",S200);

  Balloc(1);
  Balloc(2);

  do
  {
    fp=TaskN;
    t=RunTask(0x1E0, (void*)fp, 110);

    if (t)
      Wait(S200);

    sprintf(buf200,"\r\nTCB N = %xH", t);
    C_printf(buf200,S200);
  }
  while (n-- > 0);

  C_printf("\r\n200 stopping...",S200);

  Signal(S50);

  StopTask(GetCrtTask());
}

void Task50(void)
{
  C_printf("\r\n50 running...",S50);

  Balloc(2);
  Balloc(3);
  Balloc(1);

  fp = Task200;
  RunTask(0x1E0, (void*)fp, 100);

  Wait(S50);

  C_printf("\r\n50 stopping...",S50);

  Signal(S10);

  StopTask(GetCrtTask());
}

void Task10(void)
{
  SN=MakeSem();
  S200=MakeSem();
  S50=MakeSem();
  S10=MakeSem();

  C_printf("\r\n10 running...",S10);

  Balloc(0);
  Balloc(1);
  Balloc(2);

  fp = Task50;
  RunTask(0x1E0, (void*)fp, 50);

  Wait(S10);

  C_printf("\r\nShutDown...",S10);

  /*watson();*/
  ShutDown();
}

void main(void)
{
  fp = Task10;
  StartUp(0x1E0, (void*)fp, 10);
}
