#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

#define TASK50	0x4000

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
  t=RunTask512(0x1E0, (void*)TASK50, 50, 1);
  C_printf("\r\nShutDown...",S);
  ShutDown();
}

void main(void)
{
  fp = Task10;
  StartUp(0x1E0, (void*)fp, 10);
}
