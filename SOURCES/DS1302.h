void	InitRTC(void); 	/* set 00:00:00 as current time, starts real time clock */
long	GetTime(void); 	/* gets current time */
			/* returns E = seconds, D = minutes, L = hours, H = 0 */
long	DeltaTime(long Start, long Stop);
			/* returns (Stop-Start) E = seconds, D = minutes, L = hours, H = 0 */
char*	TimeToStr(long Time);
			/* E = seconds, D = minutes, L = hours, H = 0 */
