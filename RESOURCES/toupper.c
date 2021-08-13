/* Converts a text file contents to uppercase chars */
/* May be used to obtain a ZSID compatible .SYM file */
/* Max line width = 132 */
/* Compile with switch -I (e.g. -IJ0: ) */

#include <sys.h>
#include <stdio.h>
#include <conio.h>
#include <ctype.h>
#include <string.h>

FILE* in_sym;
FILE* out_sym;
char buffer[132];
int line_size;
char* s;

int main(int argc, char*argv[])
{
  if (argc != 3)
  {
    printf("Invalid parameters!\r\nUsage is: toupper out_file in_file\r\n");
    exit(0);
  }

  if (!(in_sym=fopen(argv[2], "r")))
  {
    printf("Cannot open input file!\r\n");
    exit(0);
  }

  if (!(out_sym=fopen(argv[1], "w")))
  {
    printf("Cannot open output file!\r\n");
    exit(0);
  }

  while (s=fgets(buffer, 132, in_sym))
  {
    line_size=strlen(s);

    while (line_size-- > 0)
    {
      if (isalpha(*s))
      {
        if (islower(*s))
          *s=toupper(*s);
      }
      s++;
    }

    fputs(buffer, out_sym);
  }

  fclose(in_sym);
  fclose(out_sym);

  exit(1);
}
