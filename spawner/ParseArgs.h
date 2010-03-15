#define INFINITY_VALUE 1.0e300

extern BOOL runAs, 
	hideReport, 
	hideOutput,
	dumpProcessToken;	
extern CHAR	application[1024], 
		parameters[1024], 
		userName[1024], 
		password[1024], 
		reportFile[1024],	
		inputFile[1024],
		outputFile[1024];
extern ULONG securityLevel;
extern DOUBLE timeLimit, 
	deadLine, 
	memoryLimit, 
	writeLimit;

void ParseArguments(int argc_, CHAR *argv_[]);