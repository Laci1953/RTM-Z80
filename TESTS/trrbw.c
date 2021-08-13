#include <dlist.h>
#include <rtsys.h>
#include <io.h>
#include <rtclk.h>

#include <string.h>

void (*fp)(void);

void *S,*S2,*S3,*S5;
void *Timer;
char* m2="2";
char* m3="3";
char* m5="5";

void Task2(void)
{
  unsigned short n;
  do
  {
    for (n=0;n<0xff;n++)
      n=n;
    CON_Write(m2,strlen(m2),0/*S2*/);
    /*Wait(S2);*/
  } while (1);
}

void Task3(void)
{
  unsigned short n;
  do
  {
    for (n=0;n<0xff;n++)
      n=n;
    CON_Write(m3,strlen(m3),0/*S3*/);
    /*Wait(S3);*/
  } while (1);
}

void Task5(void)
{
  unsigned short n;
  do
  {
    for (n=0;n<0xff;n++)
      n=n;
    CON_Write(m5,strlen(m5),0/*S5*/);
    /*Wait(S5);*/
  } while (1);
}

void Task(void)
{
  RoundRobinON();
  S=MakeSem();
  S2=MakeSem();
  S3=MakeSem();
  S5=MakeSem();
  Timer=MakeTimer();
  fp = Task5;
  RunTask(0x60, (void*)fp, 5);
  fp = Task3;
  RunTask(0x60, (void*)fp, 3);
  fp = Task2;
  RunTask(0x60, (void*)fp, 2);
  StartTimer(Timer,S,200,1);
  do
  {
    Wait(S);
    if (CTRL_C())
      ShutDown();
  } while (1);
}

void main(void)
{
  fp = Task;
  StartUp(0x60, (void*)fp, 10);
}
