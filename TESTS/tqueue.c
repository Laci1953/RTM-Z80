#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <queue.h>
#include <mailbox.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

void (*fp)(void);

struct Queue *MtoS, *StoM;
short mm[3]= {1,2,3};
struct Semaphore* S;
char buf[100];

void C_printf(char* str, void* S)
{
  CON_Write(str, strlen(str), S);
  Wait(S);
}

void Code_TSlave(void)
{
  short p[3];
  short m=0x6789;
  
  ReadQ(MtoS, (void*)p);
  sprintf(buf,"\n\rSlave %x %x %x",p[0],p[1],p[2]);
  C_printf(buf,S);
  WriteQ(StoM, (void*)&m);
  ReadQ(MtoS, (void*)p);
  sprintf(buf,"\n\rSlave %x %x %x",p[0],p[1],p[2]);
  C_printf(buf,S);
  WriteQ(StoM, (void*)&m);
  ReadQ(MtoS, (void*)p);
  sprintf(buf,"\n\rSlave %x %x %x",p[0],p[1],p[2]);
  C_printf(buf,S);
  WriteQ(StoM, (void*)&m);
  ReadQ(MtoS, (void*)p);
  sprintf(buf,"\n\rSlave %x %x %x",p[0],p[1],p[2]);
  C_printf(buf,S);
  WriteQ(StoM, (void*)&m);
  ReadQ(MtoS, (void*)p);
  sprintf(buf,"\n\rSlave %x %x %x",p[0],p[1],p[2]);
  C_printf(buf,S);
  WriteQ(StoM, (void*)&m);
  ReadQ(MtoS, (void*)p);
  sprintf(buf,"\n\rSlave %x %x %x",p[0],p[1],p[2]);
  C_printf(buf,S);
  WriteQ(StoM, (void*)&m);
  ReadQ(MtoS, (void*)p);
  sprintf(buf,"\n\rSlave %x %x %x",p[0],p[1],p[2]);
  C_printf(buf,S);
  WriteQ(StoM, (void*)&m);
 
  StopTask(GetCrtTask());
}

void Code_Tmaster(void)
{
  short p;

  S=MakeSem();
  fp = Code_TSlave;
  RunTask(0x1E0, (void*)fp, 5);

  MtoS=MakeQ(3,2);
  StoM=MakeQ(1,2);

  WriteQ(MtoS, (void*)mm);
  ReadQ(StoM,&p); 
  sprintf(buf,"\n\rMaster %x",p);
  C_printf(buf,S);
  WriteQ(MtoS, (void*)mm);
  ReadQ(StoM,&p); 
  sprintf(buf,"\n\rMaster %x",p);
  C_printf(buf,S);
  WriteQ(MtoS, (void*)mm);
  ReadQ(StoM,&p); 
  sprintf(buf,"\n\rMaster %x",p);
  C_printf(buf,S);
  WriteQ(MtoS, (void*)mm);
  ReadQ(StoM,&p); 
  sprintf(buf,"\n\rMaster %x",p);
  C_printf(buf,S);
  WriteQ(MtoS, (void*)mm);
  ReadQ(StoM,&p); 
  sprintf(buf,"\n\rMaster %x",p);
  C_printf(buf,S);
  WriteQ(MtoS, (void*)mm);
  ReadQ(StoM,&p); 
  sprintf(buf,"\n\rMaster %x",p);
  C_printf(buf,S);
  WriteQ(MtoS, (void*)mm);
  ReadQ(StoM,&p); 
  sprintf(buf,"\n\rMaster %x",p);
  C_printf(buf,S);

  DropQ(MtoS);
  DropQ(StoM);

  ShutDown();
}

void main(void)
{
  fp = Code_Tmaster;
  StartUp(0x1E0, (void*)fp, 100);
}
