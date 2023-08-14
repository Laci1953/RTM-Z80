/*
 * RTM/Z80  -  a Real Time Monitor for Z80 computers
 *
 * Copyright (C) 2021 by Ladislau Szilagyi
 *
 * MERGE SORT DEMO PROGRAM
 * 
 */

#include <stdio.h>
#include <string.h>

#include <dlist.h>
#include <balloc.h>
#include <rtsys.h>
#include <io.h>
#include <rtclk.h>

int	xrnd(void);
void	xrndseed(void);

/* number of elements in array */
#define MAX 1000

/* number of tasks */
#define THREAD_MAX 4

/* array of size MAX */
short a[MAX];

/* task selector */
short part = 0;

char*	no_dyn_mem = "\nDynamic memory full, quitting...";
char*	no_stack = "\nStack too small, quitting...";
short	ret;
char 	buf[30];
void	(*fp)(void);

struct Semaphore* S1, *S2, *S3, *S4, *SW;
void* 	S[4];

long ts,te;
short TicsPerSec;
short i;

/* Print from RTM/Z80 */
void my_print(char* msg)
{
	CON_Write(msg, strlen(msg), SW);
	Wait(SW);
}

void QUIT(void)
{
	my_print(no_dyn_mem);
	ShutDown();
}

void STACK(void)
{
	my_print(no_stack);
	ShutDown();
}

/* merge function for merging two parts */
void merge(short low, short mid, short high)
{
	short *L, *R, LS, RS;
	short* left;
	short* right;
	short k = low;

	/* n1 is size of left part and n2 is size of right part */
	short n1 = mid - low + 1, n2 = high - mid, i, j;

	/* allocate two temporary arrays */

	if (StackLeft(GetCrtTask()) < 20)
		STACK();

	LS=BallocS(mid - low + 1 + 6);
	L=Balloc(LS+1);
	if (!L)
		QUIT();

	RS=BallocS(high - mid + 6);
	R=Balloc(RS+1);
	if (!R)
		QUIT();

	left=L+3;
	right=R+3;

	/* storing values in left part */
	for (i = 0; i < n1; i++)
		left[i] = a[i + low];

	/* storing values in right part */
	for (i = 0; i < n2; i++)
		right[i] = a[i + mid + 1];

	i = j = 0;

	/* merge left and right in ascending order */
	while (i < n1 && j < n2) 
	{
		if (left[i] <= right[j])
			a[k++] = left[i++];
		else
			a[k++] = right[j++];
	}

	/* insert remaining values from left */
	while (i < n1) {
		a[k++] = left[i++];
	}

	/* insert remaining values from right */
	while (j < n2) {
		a[k++] = right[j++];
	}

	Bdealloc(L,LS+1);
	Bdealloc(R,RS+1);
}

/* merge sort function */
void merge_sort(short low, short high)
{
	/* calculating mid point of array */
	short mid = low + (high - low) / 2;

	if (StackLeft(GetCrtTask()) < 20)
		STACK();

	if (low < high) 
	{
		/* calling first half */
		merge_sort(low, mid);

		/* calling second half */
		merge_sort(mid + 1, high);

		/* merging the two halves */
		merge(low, mid, high);
	}
}

/* merge sort task function for multi-tasking */
void merge_sort_t(void)
{
	/* which part out of 4 parts */
	short task_part = part++;

	/* calculating low and high */
	short low = task_part * (MAX / 4);
	short high = (task_part + 1) * (MAX / 4) - 1;

	/* evaluating mid point */
	short mid = low + (high - low) / 2;
	if (low < high) {
		merge_sort(low, mid);
		merge_sort(mid + 1, high);
		merge(low, mid, high);
	}

	Signal(S[task_part]);
	StopTask(GetCrtTask());
}

/* Function to print an array */
void printArray(short A[], short size)
{
	for (i = 0; i < size; i++)
        {
	  sprintf(buf, "%d ", A[i]);
          my_print(buf);
	}
}

void Create4T(void)
{
	xrndseed();

	for (i=0; i < MAX; i++)
		a[i] = xrnd();

	/* prepare semaphores */
	SW = MakeSem();

	S1 = MakeSem();
	S2 = MakeSem();
	S3 = MakeSem();
	S4 = MakeSem();

	S[0]=S1;
	S[1]=S2;
	S[2]=S3;
	S[3]=S4;

	if (GetHost())
	  TicsPerSec=200;
	else
	  TicsPerSec=100;

	my_print("\r\nGiven array is\r\n");
	printArray(a, MAX);

	ts=GetTicks();

	/* creating 4 tasks */
	fp = merge_sort_t;
	if (!RunTask(0x1E0, (void*)fp, 4))
		QUIT();	
	if (!RunTask(0x1E0, (void*)fp, 3))
		QUIT();	
	if (!RunTask(0x1E0, (void*)fp, 2))
		QUIT();	
	if (!RunTask(0x1E0, (void*)fp, 1))
		QUIT();	

	/* wait for each task completion */
	Wait(S1);
	Wait(S2);
	Wait(S3);
	Wait(S4);
	
	/* merging the final 4 parts */
	merge(0, (MAX / 2 - 1) / 2, MAX / 2 - 1);
	merge(MAX / 2, MAX/2 + (MAX-1-MAX/2)/2, MAX - 1);
	merge(0, (MAX - 1)/2, MAX - 1);

	te=GetTicks();

	my_print("\r\nSorted array is\r\n");
	printArray(a, MAX);

	sprintf(buf, "\r\nElapsed time: %ld seconds", (te-ts)/TicsPerSec);
        my_print(buf);

	DropSem(S1);
	DropSem(S2);
	DropSem(S3);
	DropSem(S4);
	DropSem(SW);

	ShutDown();
}

void main(void)
{
	fp = Create4T;
	StartUp(0x1E0, (void*)fp, 10);
}

