/*	Semaphores & Tasks */

struct Semaphore {
	void*	first;		/* list header */
	void*	last;
	short	Counter;
};

struct TaskCB {
	void* nextActive;
	void* prevActive;
	char AllocStatus; /* !=0 = allocated */
	char BlockSize; 
	char Priority;
	void* StackPointer; 
	void* first;	/*local semaphore*/
	void* last;
	short counter;
	char ID;	/* !=0 used to mark allocated blocks */
	void* nextTask;
	void* prevTask;
	void* WaitSem;
	char ROMBank; /* !=0 if task stored in 512KB EPROM */
	char StackWarning; /* set to 0xFF if stack space drops below 60H */ 
	/*local stack area */
};

short	GetHost(void);
short	IncTaskStack(short size);
short	StackLeft(void* tcb);
short	StartUp(short stack_size, void* StartAddr, short Prio);
void	ShutDown(void);
void*	GetTaskByID(short id);
short	GetTaskSts(void* TCB);
struct TaskCB*	RunTask(short stack_size, void* StartAddr, short Prio);
short	StopTask(struct TaskCB* task);
short	SetTaskPrio(void* TCB, short Prio);
short	GetTaskPrio(void* TCB);
struct TaskCB*   GetCrtTask(void);
void	Suspend(void);
short	Resume(struct TaskCB* taskTCB);
void*	GetTasksH();
void*	GetAllTasksH();

short	GetSemSts(void* SemAddr);
void*	MakeSem(void);
short	DropSem(void* SemAddr);
short	Signal(void* SemAddr);
short	Wait(void* SemAddr);
void*	ResetSem(void* SemAddr);

void	LowToUp100H(void* from, void* to);
void	UpToLow100H(void* from, void* to);
short   Save100H(void* source, void* dest_high);
short  _Load100H(void* dest, void* source_high);

struct TaskCB*	RunTask512(short stack_size, void* StartAddr, short Prio, short ROMBank);
