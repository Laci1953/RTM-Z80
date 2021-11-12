#include <stdio.h>
#include <string.h>
#include <dyn512.h>

void myproc(char* p1, char bank1, char* p2, char bank2)
{
  setRAMbank(bank1);
  printf("\r\n%s",p1);
  setRAMbank(bank2);
  strcpy(p2, "String2");
}
