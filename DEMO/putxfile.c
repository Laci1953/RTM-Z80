/*****************************************************

		      PUTXFILE

	Send CP/M files via XMODEM (115200 bauds)
	
	    Started as a CP/M program
       Boots the RTM/Z80 multitasking system
          and executes the following tasks:

		TaskXmSend
		TaskReadFile	


	    Ladislau Szilagyi, August 2023

******************************************************/
#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <mailbox.h>
#include <rtclk.h>
#include <io.h>

#include <sys.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

#define EOT 'D'- 0x40

void (*fp)(void);

void* TCB;
struct MailBox* MB_ReceiveRecords;
struct Semaphore* S;
struct RTClkCB* T;
char buf_Send[129];
char* msgTitle="\r\nSends files via XMODEM";
char* msgNoFile="\r\nFile not found!";
char* msgOK="\r\nFile sent";
char* msgCAN="\r\nCANCELLED!";
char* msgFAIL="\r\nFAILED!";
char* msgDynMemFull="\r\nDynamic memory full!";
char* msgPleaseReceive="\r\n...you have 30 secs to initiate receiving the file via XMODEM...";
char* msgWantAnother="\r\nPress 'y/Y' to send another file:";
char* msgWrongFileName="\r\nWrong file name!";
char* msgWrongDisk="\r\nWrong disk name!";
short status;
char* msgFile="\r\nSend file (e.g. a:myfile.txt<CR>) : ";
char filename[11];
char buf[15];
short line_size, i;
char* ps, *pd;

void setname(char* name);
void cleanfcb(void);
void setdma(char* buf);
int openfile(void);
int readfile(void);
void closefile(void);
void setdisk(short n);

// fatal error
void FatalError(char* msg)
{
  CON_Write(msg, strlen(msg), S);
  Wait(S);
  ShutDown();
}

// convert string to uppercase
void to_upper(char* s)
{
  line_size = strlen(s);

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

// check valid char for filename
// returns 0 if not valid
int Check(char c)
{
  if (c == '*' ||
      c == '?' ||
      c == '<' ||
      c == '>' ||
      c == ',' ||
      c == ';' ||
      c == ':' ||
      c == '=' ||
      c == '[' ||
      c == ']' ||
      c == '%' ||
      c == '|' ||
      c == '(' ||
      c == ')' ||
      c == '/' ||
      c == '\\')
    return 0;

  return 1;
}

// parse d:filename[.ext]
// returns 0 if syntax error
int ReadParseFileName(void)
{
  CON_Write(msgFile, strlen(msgFile), 0);

  CON_Read(buf, 14, S);
  Wait(S);

  to_upper(buf);

  if (buf[1] != ':' || buf[2] == '.')
  {
    CON_Write(msgWrongFileName, strlen(msgWrongFileName), 0);
    return 0;
  }
    
  if (buf[0] < 'A' || buf[0] > 'H')
  {
    CON_Write(msgWrongDisk, strlen(msgWrongDisk), 0);
    return 0;
  }

  for (i = 0; i < 11; i++)
    filename[i] = ' ';

  ps = buf + 2;
  pd = filename;

  for (i = 0; i < 8 ;i++)
  {
    if (*ps == 0)
      goto done;

    if (*ps == '.')
      break;

    if (!Check(*ps))
    {
      CON_Write(msgWrongFileName, strlen(msgWrongFileName), 0);
      return 0;
    }

    *pd++ = *ps++;
  }

  if (*ps == '.')
  {
    ps++;

    pd = filename + 8;

    for (i = 0; i < 3; i++)
    {
      if (*ps == 0)
        break;

      if (!Check(*ps))
      {
        CON_Write(msgWrongFileName, strlen(msgWrongFileName), 0);
        return 0;
      }

      *pd++ = *ps++;
    }
  }
  else if (*ps != 0)
  {
    CON_Write(msgWrongFileName, strlen(msgWrongFileName), 0);
    return 0;
  }

done:
  if (filename[0] == ' ')
  {
    CON_Write(msgWrongFileName, strlen(msgWrongFileName), 0);
    return 0;
  }

  return 1;
}

// display outcome
void DisplayStatus(void)
{
  if (status == -1)
    FatalError(msgCAN);
  else if (status == -2)
    FatalError(msgFAIL);
  else
    CON_Write(msgOK, strlen(msgOK), 0);
}

// receives records from TaskReadFile via mailbox MB_ReceiveRecords and sends them via XMODEM
// high priority task
void TaskXmSend(void)
{
  status = XmSend(MB_ReceiveRecords);

  if (status == -1)	// if CANCELED
  {
    StopTask(TCB);
    FatalError(msgCAN);
  }

  StopTask(GetCrtTask());
}

// Sets up mailbox, timer, asks file name, 
// starts TaskXmSend (XMODEM task),
// reads file records 
// & sends them via MB_ReceiveRecords to TaskXmSend
// middle priority task (20)
void TaskReadFile(void)
{
  S = MakeSem();
  T = MakeTimer();
  MB_ReceiveRecords = MakeMB(129);

  CON_Write(msgTitle, strlen(msgTitle), 0);

  do
  {
    if (!ReadParseFileName())
      continue;

    CON_Write(msgPleaseReceive, strlen(msgPleaseReceive), S);
    Wait(S);

    fp = TaskXmSend;
    RunTask(0xE0, (void*)fp, 30);	// priority 30

    cleanfcb();
  
    setdisk((short)(buf[0] - 'A' + 1));
    setname(filename);
  
    if (!openfile())
      FatalError(msgNoFile);

    setdma(buf_Send);

    StartTimer(T, S, 6000, 0);	// wait 30 secs
    Wait(S);

    do
    {
      StartTimer(T, S, 10, 0);	// wait 50 ms
      Wait(S);

      if (!readfile())
        break;

      buf_Send[128] = 0;

      if (!SendMail(MB_ReceiveRecords, buf_Send))
        FatalError(msgDynMemFull);
    }
    while (1);

    buf_Send[128] = EOT;

    if (!SendMail(MB_ReceiveRecords, buf_Send))
      FatalError(msgDynMemFull);

    closefile();

    DisplayStatus();

    CON_Write(msgWantAnother, strlen(msgWantAnother), 0);
    CON_Read(buf, 1, S);
    Wait(S);

    if (buf[0] != 'y' && buf[0] != 'Y') 
      break;
  }
  while (1);

  StopTask(GetCrtTask());
}

// system start-up
void main(void)
{
  fp = TaskReadFile;
  TCB = StartUp(0x1E0, (void*)fp, 20);	// priority 20
}

