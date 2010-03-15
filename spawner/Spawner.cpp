#include "stdafx.h"
#include "ParseArgs.h"
#include <conio.h>

// это значение отсутствует в SDK
#define JOB_OBJECT_MSG_PROCESS_WRITE_LIMIT 11

#define TM_EXIT_PROCESS				"ExitProcess"
#define TM_ABNORMAL_EXIT_PROCESS	"AbnormalExitProcess"
#define TM_TIME_LIMIT_EXCEEDED		"TimeLimitExceeded"
#define TM_MEMORY_LIMIT_EXCEEDED	"MemoryLimitExceeded"
#define TM_WRITE_LIMIT_EXCEEDED		"WriteLimitExceeded"

#define COMPLETION_KEY		1
#define SECOND_COEFF		10000000
// 1 секунда, выраженная в 100-наносекундных интервалах 
#define BUFFER_SIZE			4096
#define FORMAT_MESSAGE_FAILED "Error: FormatMessage failed"

LPSTR	terminateReason,
		exceptionMessage;
DOUBLE	peakMemoryUsed, 
		executionTime,
		written;
DWORD	exitCode;
HANDLE 	hJob, 
		hIOCP,
		hOutputFile;

PROCESS_INFORMATION processInfo;

enum ConsoleTextColor { NormalColor, HighlitedColor };

void DumpToken(HANDLE hToken);
void DumpSid(PSID pxSid);

LPSTR GetWin32Error(LPSTR functionName)
{
	int err = GetLastError();

	LPSTR lpMsgBuf;
	if (!FormatMessage( 
		FORMAT_MESSAGE_ALLOCATE_BUFFER | 
		FORMAT_MESSAGE_FROM_SYSTEM | 
		FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		err,
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), 
		(LPTSTR) &lpMsgBuf,
		0,
		NULL))
	{
		return FORMAT_MESSAGE_FAILED;
	}

	size_t x = strlen(lpMsgBuf);
	if (x >= 2 && lpMsgBuf[x - 1] == 0x0A && lpMsgBuf[x - 2] == 0x0D)
	{
		lpMsgBuf[x - 2] = '\0';
	}
  
	static CHAR s[512];
	_snprintf(s, sizeof(s), "%s failed with error %d (%s)", functionName, err, lpMsgBuf);

	LocalFree(lpMsgBuf);
	
	return s;
}


void EnsureCloseHandle(HANDLE hObject)
{
	if (hObject != INVALID_HANDLE_VALUE)
	{
		CloseHandle(hObject);
	}
}


void SetConsoleTextColor(HANDLE hConsoleOutput, ConsoleTextColor c)
{
	WORD attributes;

	switch (c)
	{
		case HighlitedColor:
			attributes = FOREGROUND_BLUE | FOREGROUND_GREEN;
			break;
		default:
			attributes = FOREGROUND_BLUE | FOREGROUND_GREEN | FOREGROUND_RED;		
	};

	if (!SetConsoleTextAttribute(hConsoleOutput, attributes))
	{
		throw GetWin32Error("SetConsoleTextAttribute");			
	}
}


void CreateChildProcessWithLogon()
{
	STARTUPINFOW startupInfo;

	USES_CONVERSION;

	ZeroMemory(&startupInfo, sizeof(startupInfo));
	startupInfo.cb = sizeof(startupInfo);
	startupInfo.lpDesktop = L"";
	
	CHAR commandLine[4096];
	sprintf(commandLine, "\"%s\" %s ", application, parameters);
	
	CHAR currentDir[100];	
	GetCurrentDirectory(sizeof(currentDir), currentDir);

	if (!CreateProcessWithLogonW(A2W(userName), NULL, A2W(password), 0,  
			A2W(application), A2W(commandLine), CREATE_SUSPENDED | CREATE_SEPARATE_WOW_VDM,
			NULL, A2W(currentDir), &startupInfo, &processInfo))
	{
		throw GetWin32Error("CreateProcessWithLogon");
	}
}


void CreateChildProcessAsUser()
{
	HANDLE hToken;
	STARTUPINFO startupInfo;

	if (!LogonUser(userName, NULL, password, LOGON32_LOGON_INTERACTIVE, LOGON32_PROVIDER_DEFAULT, 
		&hToken))
	{
		throw GetWin32Error("LogonUser");
	}

	CHAR commandLine[4096];
	sprintf(commandLine, "\"%s\" %s ", application, parameters);
		
	ZeroMemory(&startupInfo, sizeof(startupInfo));
	startupInfo.cb = sizeof(startupInfo);
	startupInfo.lpDesktop = "";

	if (!CreateProcessAsUser(hToken, application, commandLine, NULL, NULL, TRUE, 
		CREATE_SUSPENDED | CREATE_SEPARATE_WOW_VDM, NULL, NULL, &startupInfo, &processInfo))
	{
		throw GetWin32Error("CreateProcessAsUser");
	}	
}


void CreateChildProcess()
{
	STARTUPINFO startupInfo;

	ZeroMemory(&startupInfo, sizeof(startupInfo));
	startupInfo.cb = sizeof(startupInfo);
	startupInfo.lpDesktop = "";
	
	CHAR commandLine[4096];
	sprintf(commandLine, "\"%s\" %s ", application, parameters);

	if (!CreateProcess(application, commandLine, NULL, NULL, TRUE, 
			CREATE_SUSPENDED | CREATE_SEPARATE_WOW_VDM, NULL, NULL, &startupInfo, &processInfo))
	
	{
		throw GetWin32Error("CreateProcess");
	}
}



DWORD WINAPI RedirectOutput(HANDLE hChildStdoutRdDup) 
{ 
	DWORD dwRead, dwWritten; 
	CHAR chBuf[BUFFER_SIZE]; 
	HANDLE hStdout = GetStdHandle(STD_OUTPUT_HANDLE); 

	for (;;) 
	{ 
		if (!ReadFile(hChildStdoutRdDup, chBuf, BUFFER_SIZE, &dwRead, NULL) || dwRead == 0)
			break;

		SetConsoleTextColor(hStdout, HighlitedColor);
		__try
		{
			if (!hideOutput)
			{
				if (!WriteFile(hStdout, chBuf, dwRead, &dwWritten, NULL))
					break;				
			}
		}
		__finally
		{
			SetConsoleTextColor(hStdout, NormalColor);
		}

		if (hOutputFile != INVALID_HANDLE_VALUE)
		{
			if (!WriteFile(hOutputFile, chBuf, dwRead, &dwWritten, NULL))
				break;
		}	
	} 

	return 0;
} 


DWORD WINAPI CheckTimeAndWriteLimit(LPVOID lpParameter)
{
	DWORD t;	
	JOBOBJECT_BASIC_AND_IO_ACCOUNTING_INFORMATION bai;

	if (timeLimit == INFINITY_VALUE && 
		deadLine == INFINITY_VALUE && 
		writeLimit == INFINITY_VALUE)
		return 0;

	t = GetTickCount();
	while (1)
	{		
		if (!QueryInformationJobObject(hJob, JobObjectBasicAndIoAccountingInformation, &bai, sizeof(bai), NULL))
			break;
		
		if (bai.IoInfo.WriteTransferCount > (1024 * 1024) * writeLimit)
		{
			PostQueuedCompletionStatus(hIOCP, JOB_OBJECT_MSG_PROCESS_WRITE_LIMIT, COMPLETION_KEY, NULL);
			break;
		}

		if ((DOUBLE)bai.BasicInfo.TotalUserTime.QuadPart > SECOND_COEFF * timeLimit || 
			(GetTickCount() - t) > deadLine * 1000.0)
		{
			PostQueuedCompletionStatus(hIOCP, JOB_OBJECT_MSG_END_OF_PROCESS_TIME, COMPLETION_KEY, NULL);
			break;
		}

		Sleep(1);
	}
	return 0;
}


void WaitForProcessTerminate(LPSTR *message)
{
	DWORD dwNumBytes, dwKey;
    LPOVERLAPPED completedOverlapped;  
	static CHAR buf[1024];

	*message = NULL;
	do
	{			
		if (!GetQueuedCompletionStatus(hIOCP, &dwNumBytes, &dwKey, &completedOverlapped, INFINITE))
		{
			throw GetWin32Error("GetQueuedCompletionStatus");
		}

		switch (dwNumBytes)
		{
			case JOB_OBJECT_MSG_NEW_PROCESS:
				break;
			case JOB_OBJECT_MSG_END_OF_PROCESS_TIME:
				*message = TM_TIME_LIMIT_EXCEEDED;
				TerminateJobObject(hJob, 0);
				break;
			case JOB_OBJECT_MSG_PROCESS_WRITE_LIMIT:	
				*message = TM_WRITE_LIMIT_EXCEEDED;
				TerminateJobObject(hJob, 0);
				break;
			case JOB_OBJECT_MSG_EXIT_PROCESS:
				*message = TM_EXIT_PROCESS;
				break;
			case JOB_OBJECT_MSG_ABNORMAL_EXIT_PROCESS:
				*message = TM_ABNORMAL_EXIT_PROCESS;
				break;
			case JOB_OBJECT_MSG_PROCESS_MEMORY_LIMIT:
				*message = TM_MEMORY_LIMIT_EXCEEDED;
				TerminateJobObject(hJob, 0);
				break;
		};		

	} while (!(*message));

	WaitForSingleObject(processInfo.hProcess, 10000);	 
	Sleep(100);
}


void SetJobRestrictions()
{	
	JOBOBJECT_EXTENDED_LIMIT_INFORMATION joeli; 
	memset(&joeli, 0, sizeof(joeli));
	joeli.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION;

	if (memoryLimit != INFINITY_VALUE)
	{		
		joeli.ProcessMemoryLimit = (int)(memoryLimit * (1024 * 1024));
		joeli.BasicLimitInformation.LimitFlags |= JOB_OBJECT_LIMIT_PROCESS_MEMORY;
	}

	if (!SetInformationJobObject(hJob, JobObjectExtendedLimitInformation, &joeli, sizeof(joeli)))	
	{
		throw GetWin32Error("SetInformationJobObject");
	}
	
	if (securityLevel == 1)
	{
		JOBOBJECT_BASIC_UI_RESTRICTIONS buir;
		buir.UIRestrictionsClass = JOB_OBJECT_UILIMIT_ALL; 
		if (!SetInformationJobObject(hJob, JobObjectBasicUIRestrictions, &buir, sizeof(buir)))
		{
			throw GetWin32Error("SetInformationJobObject");
		}
	}
}


void CollectJobStatistics()
{
	JOBOBJECT_BASIC_AND_IO_ACCOUNTING_INFORMATION bai;	
	if (!QueryInformationJobObject(hJob, JobObjectBasicAndIoAccountingInformation, &bai, sizeof(bai), NULL))
	{
		throw GetWin32Error("QueryInformationJobObject");
	}

	executionTime = (DOUBLE)bai.BasicInfo.TotalUserTime.QuadPart / SECOND_COEFF;
	written = (DOUBLE)bai.IoInfo.WriteTransferCount / (1024 * 1024);

	JOBOBJECT_EXTENDED_LIMIT_INFORMATION xli;
	if (!QueryInformationJobObject(hJob, JobObjectExtendedLimitInformation, &xli, sizeof(xli), NULL))
	{
		throw GetWin32Error("QueryInformationJobObject");
	}
		
	peakMemoryUsed = (ULONG)xli.PeakJobMemoryUsed;
}


void Run(HANDLE hInputFile)
{ 	
	SECURITY_ATTRIBUTES saAttr; 	
	HANDLE
		hChildStdoutRd, 
		hChildStdoutWr = INVALID_HANDLE_VALUE, 
		hChildStdoutRdDup = INVALID_HANDLE_VALUE,
		hSaveStdout,
		hSaveStdin,
		hRedirectThread,
		hCheckTimeAndWriteLimitThread;	

	processInfo.hThread = INVALID_HANDLE_VALUE;
	processInfo.hProcess = INVALID_HANDLE_VALUE;	
	__try
	{
		// Set the bInheritHandle flag so pipe handles are inherited.  
		saAttr.nLength = sizeof(SECURITY_ATTRIBUTES); 
		saAttr.bInheritHandle = TRUE; 
		saAttr.lpSecurityDescriptor = NULL; 

		hChildStdoutRd = INVALID_HANDLE_VALUE;
		__try
		{
			// Create a pipe for the child process's STDOUT.  
			if (!CreatePipe(&hChildStdoutRd, &hChildStdoutWr, &saAttr, 0)) 
			{
				throw GetWin32Error("CreatePipe");			
			}

			// Save the handle to the current STDOUT and STDIN.
			hSaveStdout = GetStdHandle(STD_OUTPUT_HANDLE);
			hSaveStdin = GetStdHandle(STD_INPUT_HANDLE);
			__try
			{
				// Set a write handle to the pipe to be STDOUT. 
				if (!SetStdHandle(STD_OUTPUT_HANDLE, hChildStdoutWr)) 
				{
					throw GetWin32Error("SetStdHandle ouputFile");
				}

				if (hInputFile != INVALID_HANDLE_VALUE)
				{
					if (!SetStdHandle(STD_INPUT_HANDLE, hInputFile)) 
					{
						throw GetWin32Error("SetStdHandle inputFile");
					}
				}

				// Create noninheritable read handle and close the inheritable read 
				// handle. 
				if(!DuplicateHandle(GetCurrentProcess(), hChildStdoutRd,
					GetCurrentProcess(), &hChildStdoutRdDup, 0, FALSE,
					DUPLICATE_SAME_ACCESS))
				{
					throw GetWin32Error("DuplicateHandle");
				}

				if (strlen(userName) && runAs)
					CreateChildProcessWithLogon();
				else if (strlen(userName))
					CreateChildProcessAsUser();
				else
					CreateChildProcess();
			}
			__finally
			{
				// After process creation, restore the saved STDOUT.
				if (!SetStdHandle(STD_OUTPUT_HANDLE, hSaveStdout))
				{
					throw GetWin32Error("SetStdHandle hSaveStdout");
				}
				if (!SetStdHandle(STD_INPUT_HANDLE, hSaveStdin))
				{
					throw GetWin32Error("SetStdHandle hSaveStdin");
				}
			}
		}
		__finally
		{
			// Close the write end of the pipe before reading from the 
			// read end of the pipe.  
			EnsureCloseHandle(hChildStdoutWr);

			EnsureCloseHandle(hChildStdoutRd);
		}			

		hJob = INVALID_HANDLE_VALUE;
		hIOCP = INVALID_HANDLE_VALUE;
		hRedirectThread = INVALID_HANDLE_VALUE;
		hCheckTimeAndWriteLimitThread = INVALID_HANDLE_VALUE;
		hOutputFile = INVALID_HANDLE_VALUE;
		__try
		{
			hJob = CreateJobObject(NULL, NULL);
			
			SetJobRestrictions();
			if (!AssignProcessToJobObject(hJob, processInfo.hProcess))
			{
				throw GetWin32Error("AssignProcessToJobObject");
			}

			if (!(hIOCP = CreateIoCompletionPort(INVALID_HANDLE_VALUE, NULL, 1, 1)))
			{
				throw GetWin32Error("CreateIoCompletionPort");
			}

			JOBOBJECT_ASSOCIATE_COMPLETION_PORT joacp; 
			joacp.CompletionKey = (PVOID)COMPLETION_KEY; 
			joacp.CompletionPort = hIOCP; 
			if (!SetInformationJobObject(hJob, JobObjectAssociateCompletionPortInformation, &joacp, sizeof(joacp)))
			{
				throw GetWin32Error("SetInformationJobObject");
			}

			hRedirectThread = CreateThread(NULL, 0, RedirectOutput, hChildStdoutRdDup, NULL, NULL);	
			hCheckTimeAndWriteLimitThread = CreateThread(NULL, 0, CheckTimeAndWriteLimit, NULL, NULL, NULL);

			if (strlen(outputFile))
			{
				hOutputFile = CreateFile(outputFile, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
				if (hOutputFile == INVALID_HANDLE_VALUE)
				{			
					throw GetWin32Error("CreateFile");				
				}
			}	

			if (ResumeThread(processInfo.hThread) == -1)
			{
				throw GetWin32Error("ResumeThread");
			}

			WaitForProcessTerminate(&terminateReason);	
			
			TerminateThread(hRedirectThread, 0);
			TerminateThread(hCheckTimeAndWriteLimitThread, 0);
			
			if (!GetExitCodeProcess(processInfo.hProcess, (ULONG *)&exitCode))
			{
				throw GetWin32Error("GetExitCodeProcess");			
			}

			CollectJobStatistics();			
		}
		__finally
		{			
			if (hJob != INVALID_HANDLE_VALUE)
				TerminateJobObject(hJob, 0);
			EnsureCloseHandle(hJob);
			EnsureCloseHandle(hIOCP);	
			EnsureCloseHandle(hRedirectThread);
			EnsureCloseHandle(hCheckTimeAndWriteLimitThread);
			EnsureCloseHandle(hOutputFile);
		}
	}
	__finally
	{
		// если произошло исключение, уничтожим процесс и задание
		if (processInfo.hProcess != INVALID_HANDLE_VALUE)
			TerminateProcess(processInfo.hProcess, 0);
		
		EnsureCloseHandle(hChildStdoutRdDup);
		EnsureCloseHandle(processInfo.hThread);
		EnsureCloseHandle(processInfo.hProcess);	
	}
} 


LPSTR ExitCodeToString(DWORD code)
{	
	switch (code)
	{
		case STATUS_ACCESS_VIOLATION:
			return "AccessViolation";
		case STATUS_ARRAY_BOUNDS_EXCEEDED:
			return "ArrayBoundsExceeded";
		case STATUS_BREAKPOINT:
			return "Breakpoint";
		case STATUS_CONTROL_C_EXIT:
			return "Control_C_Exit";
		case STATUS_DATATYPE_MISALIGNMENT:
			return "DatatypeMisalignment";
		case STATUS_FLOAT_DENORMAL_OPERAND:
			return "FloatDenormalOperand";
		case STATUS_FLOAT_INEXACT_RESULT:
			return "FloatInexactResult";
		case STATUS_FLOAT_INVALID_OPERATION:
			return "FloatInvalidOperation";
		case STATUS_FLOAT_MULTIPLE_FAULTS:
			return "FloatMultipleFaults";
		case STATUS_FLOAT_MULTIPLE_TRAPS:
			return "FloatMultipleTraps";
		case STATUS_FLOAT_OVERFLOW:
			return "FloatOverflow";
		case STATUS_FLOAT_STACK_CHECK:
			return "FloatStackCheck";
		case STATUS_FLOAT_UNDERFLOW:
			return "FloatUnderflow";
		case STATUS_GUARD_PAGE_VIOLATION:
			return "GuardPageViolation";
		case STATUS_ILLEGAL_INSTRUCTION:
			return "IllegalInstruction";
		case STATUS_IN_PAGE_ERROR:
			return "InPageError";
		case STATUS_INVALID_DISPOSITION:
			return "InvalidDisposition";
		case STATUS_INTEGER_DIVIDE_BY_ZERO:
			return "IntegerDivideByZero";
		case STATUS_INTEGER_OVERFLOW:
			return "IntegerOverflow";
		case STATUS_NONCONTINUABLE_EXCEPTION:
			return "NoncontinuableException";
		case STATUS_PRIVILEGED_INSTRUCTION:
			return "PrivilegedInstruction";
		case STATUS_REG_NAT_CONSUMPTION:
			return "RegNatConsumption";
		case STATUS_SINGLE_STEP:
			return "SingleStep";
		case STATUS_STACK_OVERFLOW:
			return "StackOverflow";
	}

	return NULL;
}

void GenerateReport(HANDLE hFile, BOOL convertToOEM)
{
    CHAR currentUser[256], 
		exitStatus[256],
		userName_[256],
		timeLimit_[256],
		deadLine_[256],
		memoryLimit_[256],
		writeLimit_[256],
		parameters_[512],
		terminateReason_[512],
		exceptionMessage_[512],
		buffer[4096];
	double peakMemoryUsed_;
	LPSTR createProcessMethod;
	DWORD nbw;

	if (strlen(userName))
	{
		strcpy(userName_, userName);
	}
	else
	{
		int sz = sizeof(currentUser);
		GetUserName(currentUser, (ULONG *)&sz);
		sprintf(userName_, "%s", currentUser);
	}		

	strcpy(timeLimit_, "Infinity");
	strcpy(deadLine_, "Infinity");
	strcpy(memoryLimit_, "Infinity");
	strcpy(writeLimit_, "Infinity");

	if (timeLimit != INFINITY_VALUE)
		sprintf(timeLimit_, "%f (sec)", timeLimit);

	if (deadLine != INFINITY_VALUE)
		sprintf(deadLine_, "%f (sec)", deadLine);
		
	if (memoryLimit != INFINITY_VALUE)
		sprintf(memoryLimit_, "%f (Mb)", memoryLimit);

	if (writeLimit != INFINITY_VALUE)
		sprintf(writeLimit_, "%f (Mb)", writeLimit);

	if (strlen(userName) && runAs)
		createProcessMethod = "RunAs service";
	else if (strlen(userName))
		createProcessMethod = "CreateProcessAsUser";
	else 
		createProcessMethod = "CreateProcess";
	
	strcpy(parameters_, "<none>");
	if (strlen(parameters))
		strcpy(parameters_, parameters);

	strcpy(terminateReason_, "<none>");
	if (terminateReason)
		strcpy(terminateReason_, terminateReason);

	strcpy(exceptionMessage_, "<none>");
	if (exceptionMessage)
		strcpy(exceptionMessage_, exceptionMessage);

	peakMemoryUsed_ = (double)peakMemoryUsed / (1024 * 1024);

	sprintf(exitStatus, "%d", exitCode);
	if (ExitCodeToString(exitCode))
		strcpy(exitStatus, ExitCodeToString(exitCode));
	
	sprintf(buffer, 
		"\n--------------- Spawner report ---------------\n"
		"Application:           %s\n"
		"Parameters:            %s\n" 
		"SecurityLevel:         %d\n"
		"CreateProcessMethod:   %s\n"
		"UserName:              %s\n"
		"UserTimeLimit:         %s\n"
		"DeadLine:              %s\n"
		"MemoryLimit:           %s\n"
		"WriteLimit:            %s\n"
		"----------------------------------------------\n"
		"UserTime:              %f (sec)\n"
		"PeakMemoryUsed:        %f (Mb)\n"
		"Written:               %f (Mb)\n"
		"TerminateReason:       %s\n"
		"ExitStatus:            %s\n"
		"----------------------------------------------\n"
		"SpawnerError:          %s\n",
		application, parameters_, securityLevel, createProcessMethod, userName_,
		timeLimit_, deadLine_, memoryLimit_, writeLimit_, executionTime,
		peakMemoryUsed_, written, terminateReason_, exitStatus, exceptionMessage_);

	if (convertToOEM)
	{
		CharToOem(buffer, buffer);
	}

	WriteFile(hFile, buffer, (DWORD)strlen(buffer), &nbw, NULL);
}


void DumpProcessToken()
{
	HANDLE hToken;

	hToken = INVALID_HANDLE_VALUE;
	__try
	{
		if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken))
		{
			throw GetWin32Error("OpenProcessToken");
		}
		DumpToken(hToken);
	}
	__finally
	{
		EnsureCloseHandle(hToken);
	}
}


int _tmain(int argc, _TCHAR* argv[])
{
	HANDLE
		hReportFile = INVALID_HANDLE_VALUE,
		hStdout,
		hInputFile = INVALID_HANDLE_VALUE;

	try
	{
		SetConsoleTextColor(GetStdHandle(STD_OUTPUT_HANDLE), NormalColor);		

		ParseArguments(argc, argv);

		if (dumpProcessToken)
		{
			DumpProcessToken();
			return 0;
		}

		if (!strlen(application))
		{
			printf("Missing application name");
			return 1;
		}

		if (strlen(reportFile))
		{
			hReportFile = CreateFile(reportFile, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
			if (hReportFile == INVALID_HANDLE_VALUE)
			{
				throw GetWin32Error("CreateFile reportFile");
			}
		}
		if (strlen(inputFile))
		{
			SECURITY_ATTRIBUTES saAttr;
			// Set the bInheritHandle flag so pipe handles are inherited.
			saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
			saAttr.bInheritHandle = TRUE;
			saAttr.lpSecurityDescriptor = NULL;

			hInputFile = CreateFile(inputFile, GENERIC_READ, 0, &saAttr, OPEN_EXISTING, 0, NULL);
			if (hInputFile == INVALID_HANDLE_VALUE)
			{
				throw GetWin32Error("CreateFile inputFile");
			}
		}

		Run(hInputFile);
	}
	catch (LPSTR msg)
	{		
		exceptionMessage = msg;		
	}

	if (hReportFile != INVALID_HANDLE_VALUE)
		GenerateReport(hReportFile, FALSE);			
		
	if (!hideReport)
	{
		hStdout = GetStdHandle(STD_OUTPUT_HANDLE);
		SetConsoleTextColor(hStdout, NormalColor);	
		GenerateReport(hStdout, TRUE);
	}

	EnsureCloseHandle(hReportFile);
	EnsureCloseHandle(hInputFile);

	return 0;
}

