#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <stdio.h>
#include <string.h>
#include <io.h>

void (*fp)(void);

void* S;

unsigned short n5=0;
unsigned short n3=0;
unsigned short n2=0;

void* T2;
void* T3;

char buf[30];

void Task3(void)
{
  do 
    n3++;
  while (T3 != 0);
}

void Task2(void)
{
  do 
    n2++;
  while (T2 != 0);
}

void Task5(void)
{
  RoundRobinON();
  S=MakeSem();
  fp = Task3;
  T3=RunTask(0x1E0, (void*)fp, 3);
  fp = Task2;
  T2=RunTask(0x1E0, (void*)fp, 2);

  do 
    n5++;
  while (n5 != 50000);

  StopTask(T3);
  StopTask(T2);

  sprintf(buf,"\r\n T5 counted %u",50000);
  CON_Write(buf,strlen(buf),S);
  Wait(S);

  sprintf(buf,"\r\n T3 counted %u",n3);
  CON_Write(buf,strlen(buf),S);
  Wait(S);

  sprintf(buf,"\r\n T2 counted %u",n2);
  CON_Write(buf,strlen(buf),S);
  Wait(S);

  ShutDown();
}

void main(void)
{
  fp = Task5;
  StartUp(0x1E0, (void*)fp, 5);
}
