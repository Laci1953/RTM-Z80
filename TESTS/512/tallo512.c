#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <mailbox.h>
#include <io.h>
#include <ballo512.h>

#include <sys.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

void (*fp)(void);
struct Semaphore* W;
char *p1,*p2;
char b1,b2;
char buf[100];

void Task(void)
{
  W=MakeSem();
  p1 = alloc512(0x4000-6, &b1);
  p2 = alloc512(0x4000-6, &b2);
  set512bank(b1);
  strcpy(p1,"\r\n11111111111111111111");
  set512bank(b2);
  strcpy(p2,"\r\n22222222222222222222");
  set512bank(b1);
  strcpy(buf,p1);
  CON_Write(buf,strlen(buf),W);
  Wait(W);
  set512bank(b2);
  strcpy(buf,p2);
  CON_Write(buf,strlen(buf),W);
  Wait(W);
  ShutDown();
}

void main(void)
{
  fp = Task;
  StartUp(0x1E0, (void*)fp, 10);
}
