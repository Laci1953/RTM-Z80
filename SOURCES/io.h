void CON_Write(void* buf, char len, void* SemAddr);
void CON_Read(void* buf, char len, void* SemAddr);
void WriteB(void* buf, char len, void* SemAddr);
void ReadB(void* buf, char len, void* SemAddr, void* Timer, short TimeOut);
short GetCountB(void);
void Reset_RWB(void);
short CTRL_C(void);
