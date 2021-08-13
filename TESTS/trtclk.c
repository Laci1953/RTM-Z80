#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <rtclk.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

struct RTClkCB *K1,*K2,*K3;
struct Semaphore *S1,*S2,*S3,*S;
char buf[100];
void (*fp)(void);

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  Wait(S);
}

void Task10(void)
{
  C_printf("\r\n10 running...",S);
  Wait(S3);
  C_printf("\r\n10 : Timer K3",S);
  StartTimer(K3,S3,10,0);
  Wait(S3);
  C_printf("\r\n10 : Timer K3",S);
  DropTimer(K3);
  StopTask(GetCrtTask());
}

void Task50(void)
{
  C_printf("\r\n50 running...",S);
  Wait(S2);
  C_printf("\r\n50 : Timer K2",S);
  StartTimer(K2,S2,10,0);
  Wait(S2);
  C_printf("\r\n50 : Timer K2",S);
  DropTimer(K2);
  StopTask(GetCrtTask());
}

void Task200(void)
{
  short r;

  S=MakeSem();
  C_printf("\r\n200 running...",S);
  fp = Task50;
  RunTask(0x1E0, (void*)fp, 50);
  fp = Task10;
  RunTask(0x1E0, (void*)fp, 10);

  S1=MakeSem();
  S2=MakeSem();
  S3=MakeSem();

  K1=MakeTimer();
  K2=MakeTimer();
  K3=MakeTimer();

  StartTimer(K1,S1,10,0);
  StartTimer(K2,S2,10,0);
  StartTimer(K3,S3,10,0);

  Wait(S1);
  C_printf("\r\n200 : Timer K1",S);

  StartTimer(K1,S1,10,0);
  StopTimer(K1);

  StartTimer(K1,S1,20,1);

  r=10;
  do
  {
    Wait(S1);
    C_printf("\r\n200 : Timer K1",S);
    sprintf(buf,"\r\n200 : GetTicks=%d",GetTicks());
    C_printf(buf,S);
  } while (r-- > 0);

  StopTimer(K1);
  DropTimer(K1);

  StopTask(GetCrtTask());
}

void main(void)
{
  fp = Task200;
  StartUp(0x1E0, (void*)fp, 100);
}

