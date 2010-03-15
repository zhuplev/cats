#include "stdafx.h"
#include "ParseArgs.h"

BOOL	runAs, 
		hideReport, 
		hideOutput,
		dumpProcessToken;	
CHAR	application[1024], 
		parameters[1024], 
		userName[1024], 
		password[1024], 
		reportFile[1024],	
		inputFile[1024],
		outputFile[1024];
ULONG	securityLevel;
DOUBLE	timeLimit, 
		deadLine, 
		memoryLimit, 
		writeLimit;

int argc;
CHAR **argv;

BOOL FindArg(LPCSTR arg)
{	
	size_t x = strlen(arg);

	for (int i = 1; i < argc; i++)
	{
		if (*argv[i] == '/' || *argv[i] == '-')
		{
			if (!strncmp((argv[i] + 1), arg, x) && (argv[i][x + 1] == ':' || argv[i][x + 1] == '\0'))
				return TRUE;
		}
		else break;
	}
	return FALSE;
}


LPSTR ArgValue(LPCSTR arg)
{
	size_t x = strlen(arg);

	for (int i = 1; i < argc; i++)
	{
		if (*argv[i] == '/' || *argv[i] == '-')
		{
			if (!strncmp((argv[i] + 1), arg, x) && (argv[i][x + 1] == ':'))
				return (argv[i] + x + 2);
		}
		else break;
	}
	return NULL;
}


void ReadEnvironmentVariables()
{
	CHAR buffer[1024];

	memoryLimit = INFINITY_VALUE;
	timeLimit = INFINITY_VALUE;
	deadLine = INFINITY_VALUE;
	writeLimit = INFINITY_VALUE;
	securityLevel = 0; 
	strcpy(userName, "");
	strcpy(password, "");	
	runAs = 0;
	hideReport = 0;
	hideOutput = 0;
	strcpy(reportFile, "");
	strcpy(outputFile, "");

	if (GetEnvironmentVariable("SP_RUNAS", buffer, sizeof(buffer)))
	{
		runAs = atoi(buffer);
	}

	if (GetEnvironmentVariable("SP_HIDE_REPORT", buffer, sizeof(buffer)))
	{
		hideReport = atoi(buffer);
	}

	if (GetEnvironmentVariable("SP_HIDE_OUTPUT", buffer, sizeof(buffer)))
	{
		hideOutput = atoi(buffer);
	}
	
	if (GetEnvironmentVariable("SP_SECURITY_LEVEL", buffer, sizeof(buffer)))
	{
		securityLevel = atoi(buffer);
	}

	if (GetEnvironmentVariable("SP_TIME_LIMIT", buffer, sizeof(buffer)))
	{
		timeLimit = atof(buffer);
	}

	if (GetEnvironmentVariable("SP_MEMORY_LIMIT", buffer, sizeof(buffer)))
	{
		memoryLimit = atof(buffer);
	}

	if (GetEnvironmentVariable("SP_WRITE_LIMIT", buffer, sizeof(buffer)))
	{
		writeLimit = atof(buffer);
	}

	if (GetEnvironmentVariable("SP_DEADLINE", buffer, sizeof(buffer)))
	{
		deadLine = atof(buffer);
	}

	if (GetEnvironmentVariable("SP_USER", buffer, sizeof(buffer)))
	{
		strcpy(userName, buffer);
	}

	if (GetEnvironmentVariable("SP_PASSWORD", buffer, sizeof(buffer)))
	{
		strcpy(password, buffer);
	}

	if (GetEnvironmentVariable("SP_REPORT_FILE", buffer, sizeof(buffer)))
	{
		strcpy(reportFile, buffer);
	}

	if (GetEnvironmentVariable("SP_OUTPUT_FILE", buffer, sizeof(buffer)))
	{
		strcpy(outputFile, buffer);
	}

	if (GetEnvironmentVariable("SP_INPUT_FILE", buffer, sizeof(buffer)))
	{
		strcpy(outputFile, buffer);
	}
}


void ParseArguments(int argc_, CHAR *argv_[])
{
	ReadEnvironmentVariables();

	argc = argc_;
	argv = argv_;

	LPCSTR s;
	if ((s = ArgValue("ml")))
		memoryLimit = atof(s);

	if ((s = ArgValue("tl")))
		timeLimit = atof(s);

	if ((s = ArgValue("d")))
		deadLine = atof(s);

	if ((s = ArgValue("wl")))
		writeLimit = atof(s);

	if ((s = ArgValue("s")))
		securityLevel = atoi(s);

	if ((s = ArgValue("hr")))
		hideReport = atoi(s);

	if ((s = ArgValue("ho")))
		hideOutput = atoi(s);

	if ((s = ArgValue("runas")))
		runAs = atoi(s);

	if ((s = ArgValue("u")))
        strcpy(userName, s);

	if ((s = ArgValue("p")))
		strcpy(password, s);

	if ((s = ArgValue("sr")))
		strcpy(reportFile, s);

	if ((s = ArgValue("so")))
		strcpy(outputFile, s);

	if ((s = ArgValue("i")))
		strcpy(inputFile, s);

	dumpProcessToken = FindArg("dump");

	for (int i = 1; i < argc; i++)
	{
		if (*argv[i] != '/' && *argv[i] != '-')
			break;
	}

	application[0] = '\0';
	if (i < argc)
	{
		strcpy(application, argv[i]);
	}
    
	parameters[0] = '\0';
	for (i++; i < argc; i++)
	{
		if (strlen(parameters))
		{
			strcat(parameters, " ");
		}
		strcat(parameters, argv[i]);					
	}
}
	