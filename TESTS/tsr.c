#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

void (*fp)(void);

void* T200;
struct Semaphore* S;

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  Wait(S);
}

void Task200(void)
{
  C_printf("\r\n200 running...",S);
  T200 = GetCrtTask();
  C_printf("\r\n200 suspending...",S);
  Suspend(); 
  C_printf("\r\n200 stopping...",S);
  StopTask(GetCrtTask());
}

void Task50(void)
{
  C_printf("\r\n50 running...",S);
  fp = Task200;
  RunTask(0x1E0, (void*)fp, 100);
  C_printf("\r\nResuming 200...",S);
  Resume(T200);
  C_printf("\r\n50 stopping...",S);
  StopTask(GetCrtTask());
}

void Task10(void)
{
  S=MakeSem();
  C_printf("\r\n10 running...",S);
  fp = Task50;
  RunTask(0x1E0, (void*)fp, 50);
  C_printf("\r\n10 stopping...",S);
  StopTask(GetCrtTask());
}

void main(void)
{
  fp = Task10;
  StartUp(0x1E0, (void*)fp, 10);
}
