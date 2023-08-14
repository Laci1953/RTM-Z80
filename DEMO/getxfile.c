/*****************************************************

		      GETXFILE

	Receive files via XMODEM (115200 bauds)
 	   and write them on CP/M disk
	
	    Started as a CP/M program
       Boots the RTM/Z80 multitasking system
          and executes the following tasks:

		TaskGetFile
		TaskXmRecv
		TaskWriteFile	


	    Ladislau Szilagyi, August 2023

******************************************************/
#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <mailbox.h>
#include <io.h>

#include <sys.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

#define EOT 'D'- 0x40

void (*fp)(void);

struct MailBox* MB_ReceivePacks, *MB_SendRecords;
struct Semaphore* S;
char buf_Receive[129];
char buf_Send[129];
char* msgTitle="\r\nReceive files via XMODEM";
char* msgDirFull="\r\nDisk directory full!";
char* msgDiskFull="\r\nDisk full!";
char* msgOK="\r\nFile received & saved";
char* msgCAN="\r\nCANCELLED!";
char* msgFAIL="\r\nFAILED!";
char* msgDynMemFull="\r\nDynamic memory full!";
char* msgPleaseSend="\r\n...you have 30 secs to initiate sending the file via XMODEM...";
char* msgWantAnother="\r\nPress 'y/Y' to receive another file:";
char* msgWrongFileName="\r\nWrong file name!";
char* msgWrongDisk="\r\nWrong disk name!";
short status;
char* msgFile="\r\nSave file as (e.g. a:myfile.txt<CR>) : ";
char filename[11];
char buf[15];
short line_size, i;
char* ps, *pd;

void setname(char* name);
void cleanfcb(void);
void setdma(char* buf);
int createfile(void);
int writefile(void);
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

// gets packs via XMODEM and sends them to TaskGetFile via mailbox MB_ReceivePacks
// high priority task
void TaskXmRecv(void)
{
  status = XmRecv(MB_ReceivePacks);
  StopTask(GetCrtTask());
}

// gets records from TaskGetFile via mailbox MB_SendRecords & writes them to disk
// low priority task
void TaskWriteFile(void)
{
  cleanfcb();
  
  setdisk((short)(buf[0] - 'A' + 1));
  setname(filename);
  
  if (!createfile())
    FatalError(msgDirFull);

  setdma(buf_Send);

  do
  {
    GetMail(MB_SendRecords, buf_Send);

    if (buf_Send[128] == (char)EOT)
      break;

    if (!writefile())
      FatalError(msgDiskFull);
  }
  while (1);

  closefile();

  StopTask(GetCrtTask());
}

// Sets up mailboxes, asks file name, 
// starts TaskXmRecv (XMODEM task) & TaskWriteFile (CP/M disk file write task),
// gets packs from TaskXmRecv via MB_ReceivePacks 
// & sends them as records to TaskWriteFile via MB_SendRecords
// middle priority task (20)
void TaskGetFile(void)
{
  S = MakeSem();
  MB_ReceivePacks = MakeMB(129);
  MB_SendRecords = MakeMB(129);

  CON_Write(msgTitle, strlen(msgTitle), 0);

  do
  {
    if (!ReadParseFileName())
      continue;

    CON_Write(msgPleaseSend, strlen(msgPleaseSend), S);
    Wait(S);

    fp = TaskXmRecv;
    RunTask(0xE0, (void*)fp, 30);	// priority 30

    fp = TaskWriteFile;
    RunTask(0x1E0, (void*)fp, 10);	// priority 10

    do
    {
      GetMail(MB_ReceivePacks, buf_Receive);	// get packs

      if (!SendMail(MB_SendRecords, buf_Receive)) // send records to be written to disk
        FatalError(msgDynMemFull);

      if (buf_Receive[128] == (char)EOT)
        break;
    }
    while(1);

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
  fp = TaskGetFile;
  StartUp(0x1E0, (void*)fp, 20);	// priority 20
}

