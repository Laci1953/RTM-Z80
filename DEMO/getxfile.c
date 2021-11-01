/*
	Copyright (C) 2021 by Ladislau Szilagyi
*/
#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <mailbox.h>
#include <io.h>

#include <sys.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

/* #define MM	1 */	/* define-it for the 64KB RAM memory module */
			/* undefine-it for the 512KB RAM memory module */

#define EOT 'D'- 0x40
#define SUB 0x1A

#ifdef MM
#define MAX_LEN	0xDF00
#else
#define MAX_LEN 0x6FF
#endif

void (*fp)(void);

struct MailBox* MB;
struct Semaphore* S;
char buf[257];
char* msgOK="\r\nFile received & saved";
char* msgCAN="\r\nCAN";
char* msgFAIL="\r\nFAIL";
char* msgTooBig="\r\nFile too big!";
char* msgPleaseSend="\r\nPlease send a file in the next 30 sec...";
char* msgWantAnother="\r\nPress 'y' to receive another file:";
char* msgDisk="\r\nSelect disk (a,b,c,d,e,f,g,h):";
char* msgWrongDisk="\r\nWrong disk!";
short status;
char* file="\r\nFile name (without extension, up to 8 chars):";
char* ext="\r\nFile name extension (up to 3 chars):";
char filename[9];
char fileext[4];
short nB128;
char* pUpRAM, *p;
short line_size;

void setname(char* name, short len);
void setext(char* ext, short len);

void cleanfcb(void);
void setdma(char* buf);
void openfile(void);
void closefile(void);
void setdisk(short n);

void to_upper(char* s)
{
    line_size=strlen(s);

    while (line_size-- > 0)
    {
      if (isalpha(*s))
      {
        if (islower(*s))
          *s=toupper(*s);
      }
      s++;
    }
}

void TaskXmRecv(void)
{
  status = XmRecv(MB);
  StopTask(GetCrtTask());
}

void Task(void)
{
  S=MakeSem();
  MB=MakeMB(129);

  CON_Write(msgDisk, strlen(msgDisk), 0);

  CON_Read(buf, 1, S);
  Wait(S);

  if (buf[0] < 'a' || buf[0] > 'h')
  {
    CON_Write(msgWrongDisk, strlen(msgWrongDisk), S);
    Wait(S);
    StopTask(GetCrtTask());
  }

  setdisk((short)(buf[0] - 'a' + 1));

  do
  {
    CON_Write(msgPleaseSend, strlen(msgPleaseSend), S);
    Wait(S);

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

#ifdef MM
      LowToUp100H((void*)buf, (void*)pUpRAM);
#else
      Save100H((void*)buf, (void*)pUpRAM);
#endif

#ifdef MM
      pUpRAM += 256;
#else
      pUpRAM += 1;
#endif

      if (pUpRAM >= (char*)MAX_LEN)
      {
        CON_Write(msgTooBig, strlen(msgTooBig), S);
        Wait(S);
        StopTask(GetCrtTask());
      }

      nB128=0;
    }
    while(1==1);

    if (nB128==1) /* half buffer contains data */
    {
      buf[128] = SUB;

#ifdef MM
      LowToUp100H((void*)buf, (void*)pUpRAM);
#else
      Save100H((void*)buf, (void*)pUpRAM);
#endif

#ifdef MM
      pUpRAM += 128;
#else
      pUpRAM += 1;	/* but nB128 = 1 */
#endif
    }

    if (pUpRAM >= (char*)MAX_LEN)
    {
      CON_Write(msgTooBig, strlen(msgTooBig), S);
      Wait(S);
      StopTask(GetCrtTask());
    }

    if (status==-1)
    {
      CON_Write(msgCAN,5,S);
      Wait(S);
      StopTask(GetCrtTask());
    }

    if (status==-2)
    {
      CON_Write(msgFAIL,6,S);
      Wait(S);
      StopTask(GetCrtTask());
    }

    CON_Write(file, strlen(file), 0);

    CON_Read(filename, 8, S);
    Wait(S);

    to_upper(filename);

    CON_Write(ext, strlen(ext), 0);

    CON_Read(fileext, 3, S);
    Wait(S);
    
    to_upper(fileext);

    cleanfcb();
  
    setname(filename, strlen(filename));
    setext(fileext, strlen(fileext));

    openfile();

    p=(char*)0;

    do
    {
#ifdef MM
      UpToLow100H(p, buf);
#else
      Load100H(buf, p);
#endif

      setdma(buf);

      writefile();

#ifdef MM
      p=p+128;

      if (p==pUpRAM)
        break;
#else
      if ((p==pUpRAM-1) && (nB128==1))
        break;
#endif

      setdma(buf+128);

      writefile();

#ifdef MM
      p=p+128;
#else
      p=p+1;
#endif
    }
    while (p!=pUpRAM);

    closefile();

    CON_Write(msgWantAnother, strlen(msgWantAnother),0);

    CON_Read(buf, 1, S);
    Wait(S);

    if (isalpha(buf[0]))
    {
      if (islower(buf[0]))
        buf[0]=toupper(buf[0]);
    }

    if (buf[0] != 'Y')
      break;
  }
  while (1==1);

  StopTask(GetCrtTask());
}

void main(void)
{
  fp = Task;
  StartUp(0x1E0, (void*)fp, 10);
}

