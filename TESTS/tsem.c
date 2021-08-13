#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

struct Semaphore* S1, *S200,*S;

void (*fp)(void);

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  Wait(S);
}

void Task1(void)
{
  Signal(S200);
  StopTask(GetCrtTask());
}

void Task10(void)
{
  fp = Task1;
  RunTask(0x1E0, (void*)fp, 1);
  Wait(S1);
  StopTask(GetCrtTask());
}

void Task50(void)
{
  fp = Task10;
  RunTask(0xE0, (void*)fp, 10);
  Wait(S1);
  StopTask(GetCrtTask());
}

void Task200(void)
{
  RoundRobinOFF();
  S=MakeSem();
  C_printf("\r\n200 running...",S);
  S1=MakeSem();
  S200=MakeSem();
  fp = Task50;
  RunTask(0x100, (void*)fp, 50);
  Wait(S200);
  C_printf("\r\n200 resumed from WAIT...",S);
  Signal(S1);
  Signal(S1);
  C_printf("\r\n200 stopping...",S);

  StopTask(GetCrtTask());
}

void main(void)
{
  fp = Task200;
  StartUp(0x1E0, (void*)fp, 100);
}
