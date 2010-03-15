#include <stdio.h>
#include <conio.h>
#include <windows.h>
#include <math.h>

#define SECOND_FACTOR 10000000


LPSTR GetWin32Error()
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
        return "FormatMessage failed";
    }

    size_t x = strlen(lpMsgBuf);
    if (x >= 2 && lpMsgBuf[x - 1] == 0x0A && lpMsgBuf[x - 2] == 0x0D)
    {
        lpMsgBuf[x - 2] = '\0';
    }
  
    static CHAR s[512];
    _snprintf(s, sizeof(s), "%s", lpMsgBuf);

    CharToOem(s, s);

    LocalFree(lpMsgBuf);
    
    return s;
}


void FileCreateTest()
{
    HANDLE hFile;
    hFile = CreateFile("F:\\Protected\\hack", GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
    if (hFile == INVALID_HANDLE_VALUE)
    {           
        printf("ok: F:\\Protected\\hack create (%s)\n", GetWin32Error());
    }
    else
    {
        printf("failed: F:\\Protected\\hack create\n");
        CloseHandle(hFile);
    }

    hFile = CreateFile("F:\\Public\\hack", GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
    if (hFile == INVALID_HANDLE_VALUE)
    {           
        printf("failed: F:\\Public\\hack create (%s)\n", GetWin32Error());
    }
    else
    {
        printf("ok: F:\\Public\\hack create\n");
        CloseHandle(hFile);
    }

}


void GetDesktopWindowTest()
{
    HWND hWnd;
    hWnd = GetDesktopWindow();
    if (!hWnd)
    {           
        printf("ok: GetDesktopWindow (%s)\n", GetWin32Error());
    }
    else
    {
        printf("failed: GetDesktopWindow\n");
    }
}


#define WRITE_BUFFER 1024*1024*10

void FileFloodTest()
{
   
    HANDLE hFile;
    DWORD nbw;
    LPSTR buffer;
    buffer = (LPSTR)malloc(WRITE_BUFFER);
    memset(buffer, '.', WRITE_BUFFER);
    hFile = CreateFile("flood.txt", GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
    if (hFile == INVALID_HANDLE_VALUE)
    {           
        printf("file create error (%s)\n", GetWin32Error());
    }
    for (int i = 0; i < 10; i++)
        WriteFile(hFile, buffer, WRITE_BUFFER, &nbw, NULL);
    CloseHandle(hFile);    
    free(buffer);
}


char dummy1[1024*1024*5];
char dummy2[1024*1024*5];

void MemoryLimitTest()
{
    LPSTR dummy2;
//    dummy2 = (LPSTR)malloc(1024*1024*10);
}
   

void StackOverflowTest()
{
    StackOverflowTest();
}


void IntegerDivizionByZeroTest()
{
    int a = 1;
    a /= 0;        
}


void AccessViolationTest()
{
    char *m = NULL;
    *m = 0x01;
}


void DeleteBootIniTest()
{
    if (!DeleteFile("C:\\boot.ini"))
    {
        printf("ok: delete c:\\boot.ini (%s)\n", GetWin32Error());
    }
    else
    {
        printf("failed: delete c:\\boot.ini");
    }
}


void ConsoleFloodTest()
{
    while (1)
    {
        printf("1");
    }
}


int main()
{
//    FileCreateTest();
//    GetDesktopWindowTest();
//    FileFloodTest();
//    MemoryLimitTest();
//    IntegerDivizionByZeroTest();
//    AccessViolationTest();    
    StackOverflowTest();
//    DeleteBootIniTest();
//    ConsoleFloodTest();
    
    return 0;
}