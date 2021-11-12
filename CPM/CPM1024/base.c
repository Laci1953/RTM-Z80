#include <stdio.h>
#include <string.h>
#include <dyn512.h>

char *pBuf1, *pBuf2;
char bank1, bank2;

#define myproc		0x4000
#define ROM_myproc	2	/* 3'rd 16KB ROM, offset 8000H */

void (*fnc)(char*,char,char*,char);

void main(void)
{
  Init512Banks();
  pBuf1=alloc512(100, &bank1);
  pBuf2=alloc512(100, &bank2);
  setRAMbank(bank1);
  strcpy(pBuf1, "This is string1");
  fnc=(void(*)(char*))myproc;
  setROMbank(ROM_myproc);
  (*fnc)(pBuf1,bank1,pBuf2,bank2);
  setRAMbank(bank2);
  printf("\r\n%s",pBuf2);
  free512(pBuf1,bank1);
  free512(pBuf2,bank2);
}
