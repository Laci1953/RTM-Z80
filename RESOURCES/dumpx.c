#include <conio.h>
#include <stdio.h>

void puthex1(char nibble)
{
	nibble &= 0x0F;
	putchar(nibble < 10 ? '0' + nibble : 'A' + nibble - 10);
}

void puthex2(char byte)
{
	puthex1(byte >> 4);
	puthex1(byte);
}

void puthex4(int word)
{
	puthex2(word >> 8);
	puthex2(word);
}

void error(char* txt)
{
	puts(txt);
	exit(1);
}

main(int argc, char* argv[])
{
	int	i,		/* Counter */
		offset;		/* Offset in file */
	FILE	*fp;		/* Channel for file */
	unsigned char	buffer[16];	/* Buffer for input file */

	/* Check right number of parameters */

	if(argc != 2)
	{
		puts("\nUsage: dumpx fname");
		return 1;
	}

	/* Open file in binary mode */
	if((fp = fopen((argv[1]),"rb")) == NULL)
		error("Can't open file");

	/* Initialize variables */
	offset=0;

	/* Start */
	while(fread(buffer, 16, 1, fp) == 1)
	{
		/* Print offset */
		puthex4(offset); putchar(' '); putchar(':'); putchar(' ');

		/* Print data in hexadecimal format */
		for(i = 0; i < 16; ++i)
		{
			puthex2(buffer[i]); putchar(' ');
		}

		/* Separator */
		putchar(':'); putchar(' ');

		/* Print data in ascii format */
		for(i = 0; i < 16; ++i)
		{
			if((buffer[i] > 31) && (buffer[i] < 128))
				putchar(buffer[i]);
			else
				putchar('.');
		}

		/* End of line */
		putchar('\n');

		/* Update offset */
		offset += 16;
	}

	fclose(fp);
	return 0;
}

