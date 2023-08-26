struct RTClkCB {
  struct ListElement link;
  short Counter;
  struct Semaphore* pSem;
  short CounterCopy; /* 0 = no repeat */
};

short GetTimerSts(void* Timer);
void* MakeTimer(void);
void* StartTimer(struct RTClkCB* Timer, struct Semaphore* pSem, short Ticks, char Repeat);
short DropTimer(struct RTClkCB* Timer);
short StopTimer(struct RTClkCB* Timer);
long GetTicks(void);
void RoundRobinON(void);
void RoundRobinOFF(void);
