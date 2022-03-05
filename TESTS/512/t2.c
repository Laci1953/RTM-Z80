#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

void C_printf(char*);

void main(void)
{
  IncTaskStack(0x3E0);
  C_printf("\r\n200 running...");
  Balloc(4);	/* 100H */
  Balloc(1);	/* 20H */
  Balloc(5);	/* 200H */
  Balloc(3);	/* 80H */
  C_printf("\r\n200 stopping...");
  StopTask(GetCrtTask());
}

void C_printf(char* str)
{
  CON_Write(str, strlen(str), 0);
}
