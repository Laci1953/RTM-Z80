#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

void (*fp)(void);
struct Semaphore* S;
struct TaskCB* t;
char buf[10];

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  if (!S)
    return;
  Wait(S);
}

void Task200(void)
{
  IncTaskStack(0x3E0);
  C_printf("\r\n200 running...",0);
  Balloc(4);	/* 100H */
  Balloc(1);	/* 20H */
  Balloc(5);	/* 200H */
  Balloc(3);	/* 80H */
  C_printf("\r\n200 stopping...",0);
  StopTask(GetCrtTask());
}

void Task50(void)
{
  C_printf("\r\n50 running...",0);
  Balloc(5);	/* 200H */
  Balloc(4);	/* 100H */
  Balloc(5);	/* 200H */
  Balloc(1);	/* 20H */
  fp = Task200;
  t=RunTask(0x1E0, (void*)fp, 100);
  C_printf("\r\n50 stopping...",0);
  StopTask(GetCrtTask());
}

void Task10(void)
{
  RoundRobinOFF();
  S=MakeSem();
  ResetSem(S);
  C_printf("\r\n10 running...",S);
  SetTaskPrio(GetCrtTask(),15);
  sprintf(buf, "Pri=%d", GetTaskPrio(GetCrtTask()));
  C_printf(buf,S);
  Balloc(3);	/* 80H */
  Balloc(5);	/* 200H */
  Balloc(2);	/* 40H */
  fp = Task50;
  t=RunTask(0x1E0, (void*)fp, 50);
  C_printf("\r\nShutDown...",S);
  ShutDown();
}

void main(void)
{
  fp = Task10;
  StartUp(0x1E0, (void*)fp, 10);
}
