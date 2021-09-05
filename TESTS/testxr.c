/*
	Copyright (C) 2021 by Ladislau Szilagyi
*/
#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <mailbox.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

#define EOT 'D'- 0x40
#define SUB 0x1A

void (*fp)(void);

struct MailBox* MB;
struct Semaphore* S;
char buf[257];
char* msgOK="\r\nOK";
char* msgCAN="\r\nCAN";
char* msgFAIL="\r\nFAIL";
short status;
short nB128;
char* pUpRAM, *p;
char msgCount[40];

void TaskXmRecv(void)
{
  status = XmRecv(MB);
  StopTask(GetCrtTask());
}

void Task(void)
{
  S=MakeSem();
  MB=MakeMB(129);

  fp = TaskXmRecv;
  RunTask(0xE0, (void*)fp, 20);

  pUpRAM=(char*)0;
  nB128=0;

  do
  {
    GetMail(MB,buf);

    if (buf[128] == EOT)
      break;

    nB128=1;

    GetMail(MB,buf+128);

    if (buf[256] == EOT)
      break;

    LowToUp100H((void*)buf, (void*)pUpRAM);

    pUpRAM += 256;
    nB128=0;
  }
  while(1==1);

  if (nB128==1) /* half buffer contains data */
  {
    buf[128] = SUB;
    LowToUp100H((void*)buf, (void*)pUpRAM);
    pUpRAM += 128;
  }

  if (status==1)
  {
    CON_Write(msgOK,4,S);
    Wait(S);
    sprintf(msgCount, "\r\n%x bytes written to upper RAM\r\n", pUpRAM);
    CON_Write(msgCount,strlen(msgCount),S);
    Wait(S);
  }
  else
  {
    if (status==-1)
    {
      CON_Write(msgCAN,5,S);
      Wait(S);
    }
    else
    {
      /* status==-2 */
      CON_Write(msgFAIL,6,S);
      Wait(S);
    }
  }

  p=(char*)0;

  do
  {
    UpToLow100H(p, buf);
    CON_Write(buf,128,S);
    Wait(S);
    p=p+128;
    if (p==pUpRAM)
      break;
    CON_Write(buf+128,128,S);
    Wait(S);
    p=p+128;
  }
  while (p!=pUpRAM);

  StopTask(GetCrtTask());
}

void main(void)
{
  fp = Task;
  StartUp(0x1E0, (void*)fp, 10);
}

