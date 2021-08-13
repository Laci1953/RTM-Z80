#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <rtclk.h>
#include <io.h>

#include <string.h>

struct RTClkCB *K1,*K2,*K3;
struct Semaphore *S,*S1,*S2,*S3;
char* msg1="message1";
char* msg2="message2";
char* msg3="message3";
char* msg4="message4";
char buf[10];

void watson(void);

void (*fp)(void);

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  Wait(S);
}

void Task200(void)
{
  S=MakeSem();
  C_printf("\r\n200 running...",S);

  S1=MakeSem();
  S2=MakeSem();
  S3=MakeSem();

  K1=MakeTimer();
  K2=MakeTimer();
  K3=MakeTimer();

  StartTimer(K1,S1,1000,0);
  StartTimer(K2,S2,2000,0);
  StartTimer(K3,S3,3000,0);

  CON_Read(buf,9,S);
  CON_Write(msg1,strlen(msg1),S);
  CON_Write(msg2,strlen(msg2),S);
  CON_Write(msg3,strlen(msg3),S);
  CON_Write(msg4,strlen(msg4),S);

  StopTask(GetCrtTask());
}

void main(void)
{
  fp = Task200;
  StartUp(0x1E0, (void*)fp, 100);
  watson();
}
