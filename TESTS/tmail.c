#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <mailbox.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

void (*fp)(void);

struct MailBox* MailTo50;
struct MailBox* MailFrom50;
struct Semaphore* S;

char buf[256];

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  Wait(S);
}

void Task50(void)
{
  C_printf("\r\n50 running...",S);
  GetMail(MailTo50, buf);
  C_printf(buf,S);
  strcpy(buf, "\r\nMessage from Task50");
  SendMail(MailFrom50, buf);
  StopTask(GetCrtTask());
}

void Task200(void)
{
  S=MakeSem();
  C_printf("\r\n200 running...",S);
  fp = Task50;
  RunTask(0x1E0, (void*)fp, 50);
  C_printf("\r\nMakeMB...",S);
  MailTo50=MakeMB(0xFF-7);
  MailFrom50=MakeMB(30);
  strcpy(buf, "\r\n123456789012345678901234567890123456789012345678901234567890\
12345678901234567890123456789012345678901234567890\
1234567890123456789012345678901234567890123456789012345xyz");
  C_printf("\r\nSendMail...",S);
  SendMail(MailTo50, buf);
  C_printf("\r\nGetMail...",S);
  GetMail(MailFrom50, buf);
  C_printf(buf,S);
  DropMB(MailTo50);
  DropMB(MailFrom50);
  C_printf("\r\n200 stopping...",S);
  StopTask(GetCrtTask());
}

void main(void)
{
  fp = Task200;
  StartUp(0x1E0, (void*)fp, 100);
}
