struct ListHeader {
	void* first;
	void* last;
};
struct ListElement {
	void* next;
	void* prev;
	/* data */
};

void*  FirstFromL(void* ListHeader);
void*  NextFromL(void* ListHeader, void* CrtElement);
