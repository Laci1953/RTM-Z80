#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

void (*fp)(void);
struct Semaphore* S;
struct TaskCB* t;
char buf[100];

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  Wait(S);
}

void Task200(void)
{
  C_printf("\r\n200 running...",S);
  Balloc(4);
  Balloc(1);
  Balloc(5);
  Balloc(3);
  C_printf("\r\n200 shut down...",S);
  ShutDown();
}

void Task50(void)
{
  C_printf("\r\n50 running...",S);
  Balloc(5);
  Balloc(4);
  Balloc(2);
  Balloc(5);
  Balloc(1);
  fp = Task200;
  t=RunTask(0x1E0, (void*)fp, 100);
  sprintf(buf,"\r\nTCB 200 = %xH", t);
  C_printf(buf,S);
  C_printf("\r\n50 stopping...",S);
  StopTask(GetCrtTask());
}

void Task10(void)
{
  S=MakeSem();
  C_printf("\r\n10 running...",S);
  Balloc(3);
  Balloc(3);
  Balloc(5);
  Balloc(2);
  fp = Task50;
  t=RunTask(0x1E0, (void*)fp, 50);
  sprintf(buf,"\r\nTCB 50 = %xH", t);
  C_printf(buf,S);
  C_printf("\r\n10 stopping...",S);
  StopTask(GetCrtTask());
}

void main(void)
{
  fp = Task10;
  StartUp(0x1E0, (void*)fp, 10);
}
