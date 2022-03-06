#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <mailbox.h>
#include <io.h>

#include <sys.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

void (*fp)(void);

struct Semaphore* W;

char text[81] = "\r\n111111111122222222223333333344444444555555";

char buf[256];

void Task(void)
{
  W=MakeSem();

  strcpy(buf,text);

  Save100H(buf,(void*)0);
  Save100H(buf,(void*)0x700);

  buf[0] = 0;

  Load100H(buf,(void*)0);
  CON_Write(buf, strlen(text), W);
  Wait(W);

  buf[0] - 0;

  Load100H(buf,(void*)0x700);
  CON_Write(buf, strlen(text), W);
  Wait(W);

  ShutDown();
}

void main(void)
{
  fp = Task;
  StartUp(0x1E0, (void*)fp, 10);
}
