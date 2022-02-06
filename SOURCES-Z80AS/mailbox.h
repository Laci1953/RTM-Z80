struct MailBox {
	struct Semaphore MBSem;
	struct ListHeader MBListH;
	char MsgSize;	/* real size of message, without sizeof(bElement) */
	char BallocSize;	/* Balloc size */
};

#define MAX_MSG_SIZE 0xFF - 6

short GetMBSts(void* MBox);
void* MakeMB(short MesageSize);
short DropMB(struct MailBox* MBox);
short SendMail(struct MailBox* MBox, void* Msg);
short GetMail(struct MailBox* MBox, void* DestBuffer);
