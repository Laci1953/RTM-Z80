#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

void (*fp)(void);

void* T200,*T50,*T10;
short r;
struct Semaphore *S10,*S;

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  Wait(S);
}

void Task200(void)
{
  C_printf("\r\n200 running...",S);
  C_printf("\r\n200 suspending...",S);
  Suspend(); 
  Wait(S10);
  C_printf("\r\n200 stopping...",S);
  StopTask(GetCrtTask());
}

void Task50(void)
{
  C_printf("\r\n50 running...",S);
  fp = Task200;
  T200=(void*)RunTask(0x1E0, (void*)fp, 100);
  C_printf("\r\nResuming 200...",S);
  r=Resume(T200);
  Signal(S10);
  C_printf("\r\n50 stopping...",S);
  StopTask(GetCrtTask());
}

void Task10(void)
{
  S=MakeSem();
  S10=MakeSem();
  C_printf("\r\n10 running...",S);
  fp = Task50;
  T50=(void*)RunTask(0x1E0, (void*)fp, 50);
  C_printf("\r\nShutDown...",S);
  ShutDown();
}

void main(void)
{
  fp = Task10;
  T10=(void*)StartUp(0x1E0, (void*)fp, 10);
}
