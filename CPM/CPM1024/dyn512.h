void	Init512Banks(void);
char*	alloc512(short Size, char* BankPointer);
void	free512(char* Buf, char Bank);
void	setRAMbank(char b);
void	setROMbank(char b);
int	GetTotalFree();
