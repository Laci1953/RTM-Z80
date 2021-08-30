/* Reads a text file from the upper 64KB RAM */
/* text range : 0 to argv[1] (hexa) */
/* and stores-it to a file */

#define ONCPM	1

#include <sys.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef ONCPM
FILE* out_file;
#endif

char buffer[257];
int range;

void* p;

void ReadFromUpRAM(void* p, char* buf);
#ifndef ONCPM
void type(char* buf);
#endif

#ifdef ONCPM
int main(int argc, char*argv[])
#else
void main(void)
#endif
{
#ifdef ONCPM
  if (argc != 3)
  {
    printf("Invalid parameters!\r\nUsage is: uptofile range out_file\r\n");
    exit(0);
  }

  sscanf(argv[1], "%x", &range);

  if (!(out_file=fopen(argv[2], "w")))
  {
    printf("Cannot open output file!\r\n");
    exit(0);
  }
#else
  range=0xc200;
#endif

  p=0;

  do
  {
    ReadFromUpRAM(p, buffer); /* read 256 bytes */
    buffer[256]=0;

#ifdef ONCPM
    fputs(buffer, out_file);
#else
    type(buffer);
#endif

    p = (char*)p + 256; 
  }
  while ( (char*)p < (char*)range );

#ifdef ONCPM
  fclose(out_file);

  exit(1);
#endif
}
