#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>

#include <stdio.h>
#include <string.h>

#define TASK200	0x4000

void C_printf(char*);

void main(void)
{
  C_printf("\r\n50 running...");
  Balloc(5);	/* 200H */
  Balloc(4);	/* 100H */
  Balloc(5);	/* 200H */
  Balloc(1);	/* 20H */
  RunTask512(0x1E0, (void*)TASK200, 100, 2);
  C_printf("\r\n50 stopping...");
  StopTask(GetCrtTask());
}

void C_printf(char* str)
{
  CON_Write(str, strlen(str), 0);
}

