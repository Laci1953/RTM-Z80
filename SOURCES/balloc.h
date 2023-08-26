struct bElement {
	void* next;
	void* prev;
	char Status; /* 0 = available, CrtID = allocated */
	char Size; /* 0=10H to 9=2000H */
	/* data */
};

#define B_H_SIZE 6	/* sizeof(struct bElement) */

short InitBMem(void* buddy_memory);
void* Balloc(short Size); /* 0 <= Size <= 9 */
short Bdealloc(void* bElement, short Size); /* 0 <= Size <= 9 */
void* Lists(void);
short BallocS(short Size);
short GetMaxFree(void);
short GetTotalFree(void);
void* GetOwnerTask(void* block);
void* Extend(void* block);
