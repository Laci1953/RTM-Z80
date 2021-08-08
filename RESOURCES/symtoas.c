/* Converts a .SYM file to a .AS file */

#include <sys.h>
#include <stdio.h>
#include <conio.h>
#include <ctype.h>
#include <string.h>

FILE* in_sym;
FILE* out_as;
char inbuf[32];
char outbuf[32];
char value[5];
char sym[28];
char* i, *o;
short n;

int main(int argc, char*argv[])
{
  if (argc != 3)
  {
    printf("Invalid parameters!\r\nUsage is: symtoas file.as file.sym\r\n");
    exit(0);
  }

  if (!(in_sym=fopen(argv[2], "r")))
  if (!(in_sym=fopen("TWATSON.SYM","r")))
  {
    printf("Cannot open .SYM file!\r\n");
    exit(0);
  }

  if (!(out_as=fopen(argv[1], "w")))
  if (!(out_as=fopen("WWW.AS","w")))
  {
    printf("Cannot open .AS file!\r\n");
    exit(0);
  }

  while (i=fgets(inbuf, 31, in_sym))
  {
    for (n=0; n<4; n++)
      value[n] = *i++;

    value[4]=0;
    i++;

    o = outbuf;

    strcpy(o, "GLOBAL ");
    o = o + strlen(o);

    n=0;
    do
      sym[n++] = *i++;
    while (*i != 0x0A);

    sym[n] = 0;

    strcat(o, sym);
    strcat(o, "\n");

    fputs(outbuf, out_as); /* write "GLOBAL sym" */

    o = outbuf;
    strcpy(o, sym);

    strcat(o, " EQU 0");
    strcat(o, value);
    strcat(o, "H\n");

    fputs(outbuf, out_as); /* write "sym EQU 0vvvvH" */
  }

  fclose(in_sym);
  fclose(out_as);

  exit(1);
}
