#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>

#include <string.h>

struct Semaphore* S10, *S50, *S10W, *S50W, *S200W;

void (*fp)(void);

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  Wait(S);
}

void Task10(void)
{
  S10W=MakeSem();
  C_printf("\r\n10 running...",S10W);
  Signal(S10);
  C_printf("\r\n10 stopping...",S10W);
  DropSem(S10W);
  StopTask(GetCrtTask());
}

void Task50(void)
{
  S10=MakeSem();
  S50W=MakeSem();
  C_printf("\r\n50 running...",S50W);
  fp = Task10;
  RunTask(0x1E0, (void*)fp, 10);
  Wait(S10);
  Signal(S50);
  C_printf("\r\n50 stopping...",S50W);
  DropSem(S10);
  DropSem(S50W);
  StopTask(GetCrtTask());
}

void Task200(void)
{
  S50=MakeSem();
  S200W=MakeSem();
  C_printf("\r\n200 running...",S200W);
  fp = Task50;
  RunTask(0x1E0, (void*)fp, 50);
  Wait(S50);
  C_printf("\r\n200 stopping...",S200W);
  DropSem(S50);
  DropSem(S200W);
  StopTask(GetCrtTask());
}

void main(void)
{
  fp = Task200;
  StartUp(0x1E0, (void*)fp, 100);
}

