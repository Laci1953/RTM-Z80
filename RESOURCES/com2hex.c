/* 	com2hex.c	(c) by bill beech, 2011

DESCRIPTION
	converts CPM80 command file (*.com) to intel hex format file (*.hex).

MODIFICATION HISTORY
	07 Jan 89 -- original
	22 May 08 -- modified for uniformity with other tools
	28 Sep 09 -- modified to allow any file name
	15 Dec 11 -- modified to convert .com to .hex
*/

#include	<stdio.h>
#include	<string.h>
#include	<stdlib.h>

#define	LEN	32

short next(FILE *, char *);

short main(short argc, char **argv)
    {
    char to[14], from[14], buf[LEN + 1];
    short addr = 0x100, chk, i, len;
    FILE *fp1, *fp2;

    if (argc != 2) {
	printf("com2hex: No file specified\n");
	exit(1);
    }
    strcpy(from,argv[1]);
    strcat(from,".com");
    if ((fp1 = fopen(from,"rb")) == NULL) {
        printf("com2hex: Source file %s not found\n", from);
  	exit(1);
    }
    strcpy(to,argv[1]);
    strcat(to,".hex");
    if ((fp2 = fopen(to,"w")) == NULL) {
        printf("com2hex: Could not create destination file %s\n", to);
  	exit(1);
    }
    while ((len = next(fp1,buf)) != EOF)
	{
	if (len) 
	    {
	    fprintf(fp2,":%02x%04x00", len, addr);
	    chk = 0;
	    chk -= len;
	    chk -= addr & 0xff;
	    chk -= addr >> 8;
	    for (i=0; i<len; i++)
	        {
	        fprintf(fp2,"%02x",buf[i] & 0xff);	
	        chk -= buf[i] & 0xff;
	        }
	    fprintf(fp2,"%02x\n",chk & 0xff);
	    }
	addr += LEN;
	}
    fprintf(fp2,":00000001FF\n");
    fclose(fp1);
    fclose(fp2);
    printf("Addr=%04x, SAVE %d %s.com\n", addr, ((addr-0x100) >> 8) + 1, argv[1]);
    return 0;
    }

short next(FILE *fp1,char *buf)
    {
    short i, ch, flag = 1;

    for (i=0; i<LEN; i++)
	{
	ch = fgetc(fp1);
	if (ch == EOF)
	    return EOF;
	if (ch > 0)
     	  flag = 0;
	buf[i] = ch;
	}
    if (flag)
	return 0;
    return LEN;
    }

