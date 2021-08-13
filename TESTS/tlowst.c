#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>

#include <string.h>

struct Semaphore* SNX;

void (*fp)(void);
struct Semaphore* S;

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  Wait(S);
}

void Task50(void)
{
  short n;
  short a[20];

  for (n=0; n<20; n++)
    a[n] = 1;

  for (n=0; n<50; n++)
    Signal(SNX);

  StopTask(GetCrtTask());
}

void Task200(void)
{
  short n;

  S=MakeSem();
  C_printf("\r\n200 running...",S);
  SNX=MakeSem();
  fp = Task50;
  RunTask(0x60, (void*)fp, 50);

  for (n=0; n<50; n++)
    Wait(SNX);

  StopTask(GetCrtTask());
}

void main(void)
{
  fp = Task200;
  StartUp(0x1E0, (void*)fp, 100);
}
