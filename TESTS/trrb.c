#include <string.h>

#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>
#include <rtclk.h>

//undef if no real time clock sampling available
#define SAMPLING 1

#define COUNT 50000

void (*fp)(void);

void* S;

unsigned short n5=0;
unsigned short n3=0;
unsigned short n2=0;

void* T2;
void* T3;

char buf[30];

void FatalErr(void)
{
  CON_Write("!", 1, S);
  Wait(S);
  ShutDown();
}

void Task3(void)
{
  long x,y,z;

  x = 2000000;
  y = 1000000;

  do
  {
    z = x / y;
    if (z != (long)2) FatalErr();
    n3++;
  }
  while (1);
}

void Task2(void)
{
  long x,y,z;

  x = 4000000;
  y = 2000000;

  do
  {
    z = x / y;
    if (z != (long)2) FatalErr();
    n2++;
  }
  while (1);
}

void Task5(void)
{
  long x,y,z;

  RoundRobinON();
  S=MakeSem();
  fp = Task3;
  T3=RunTask(0x1E0, (void*)fp, 3);
  fp = Task2;
  T2=RunTask(0x1E0, (void*)fp, 2);

  x = 8000000;
  y = 4000000;

#ifdef SAMPLING
  StartSampling();
#endif

  do
  {
    z = x / y;
    if (z != (long)2) FatalErr();
    n5++;
  }
  while (n5 < COUNT);

#ifdef SAMPLING
  StopSampling();
#endif

  StopTask(T3);
  StopTask(T2);

  sprintf(buf,"\r\n T5 counted %u",COUNT);
  CON_Write(buf,strlen(buf),S);
  Wait(S);

  sprintf(buf,"\r\n T3 counted %u",n3);
  CON_Write(buf,strlen(buf),S);
  Wait(S);

  sprintf(buf,"\r\n T2 counted %u",n2);
  CON_Write(buf,strlen(buf),S);
  Wait(S);

  ShutDown();
}

void main(void)
{
  fp = Task5;
  StartUp(0x1E0, (void*)fp, 5);
}
