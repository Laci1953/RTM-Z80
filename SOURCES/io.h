void CON_Write(void* buf, char len, void* SemAddr);
void CON_Read(void* buf, char len, void* SemAddr);
void WriteB(void* buf, char len, void* SemAddr);
void ReadB(void* buf, char len, void* SemAddr, void* Timer, short TimeOut);
short GetCountB(void);
void Reset_RWB(void);
char CON_Status(void);
short CTRL_C(void);
short XmRecv(struct MailBox* MB);
short XmSend(struct MailBox* MB);
short LPT_Print(char* buf, short len);
char PS2_Status(void);

