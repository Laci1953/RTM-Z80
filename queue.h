struct Queue {
	void** WP;	/* write pointer */
	void** RP;	/* read pointer */
	void* BufStart; /* buffer start addr */
	void* BufEnd;	/* buffer end addr */
	char BallocSize;/* Balloc size */
	short BatchSize; /* number of bytes to be moved */
	struct Semaphore ReadS; /* semaphore for read */
	struct Semaphore WriteS; /* semaphore for write */
};

short	GetQSts(void* queue);
void*	MakeQ(short batch_size, short batches_count);
short	DropQ(struct Queue* queue);
short	WriteQ(struct Queue* queue, void* info);
short	ReadQ(struct Queue* queue, void* buf);

