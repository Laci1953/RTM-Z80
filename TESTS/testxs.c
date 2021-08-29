/*
	Copyright (C) 2021 by Ladislau Szilagyi
*/
#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <mailbox.h>
#include <io.h>

#include <string.h>

#define EOT 'D'- 0x40

void (*fp)(void);

struct MailBox* MB;
struct Semaphore* S;
char buf[129];
char* msgOK="\r\nOK";
char* msgCAN="\r\nCAN";
char* msgFAIL="\r\nFAIL";
short status;

void Task(void)
{
  S=MakeSem();
  MB=MakeMB(129);

  strcpy(buf,"12345678901234567890123456789012345678901234567890123456789\
0123456789012345678901234567890123456789012345678901234567890abcdef\r\n");
  buf[128]=0;
  SendMail(MB,buf);
  strcpy(buf,"12345678901234567890123456789012345678901234567890123456789\
0123456789012345678901234567890123456789012345678901234567890abcdef\r\n");
  buf[128]=0;
  SendMail(MB,buf);
  strcpy(buf,"12345678901234567890123456789012345678901234567890123456789\
0123456789012345678901234567890123456789012345678901234567890abcdef\r\n");
  buf[128]=0;
  SendMail(MB,buf);
  strcpy(buf,"12345678901234567890123456789012345678901234567890123456789\
0123456789012345678901234567890123456789012345678901234567890abcdef\r\n");
  buf[128]=EOT;
  SendMail(MB,buf);

  status = XmSend(MB);

  if (status==1)
  {
    CON_Write(msgOK,4,S);
    Wait(S);
  }

  if (status==-1)
  {
    CON_Write(msgCAN,5,S);
    Wait(S);
  }

  if (status==-2)
  {
    CON_Write(msgFAIL,6,S);
    Wait(S);
  }

  StopTask(GetCrtTask());
}

void main(void)
{
  fp = Task;
  StartUp(0xE0, (void*)fp, 10);
}

