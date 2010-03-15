#include "stdafx.h"

#define SE_MIN_WELL_KNOWN_PRIVILEGE       (2L)
#define SE_CREATE_TOKEN_PRIVILEGE         (2L)
#define SE_ASSIGNPRIMARYTOKEN_PRIVILEGE   (3L)
#define SE_LOCK_MEMORY_PRIVILEGE          (4L)
#define SE_INCREASE_QUOTA_PRIVILEGE       (5L)
#define SE_UNSOLICITED_INPUT_PRIVILEGE    (6L)
#define SE_TCB_PRIVILEGE                  (7L)
#define SE_SECURITY_PRIVILEGE             (8L)
#define SE_TAKE_OWNERSHIP_PRIVILEGE       (9L)
#define SE_LOAD_DRIVER_PRIVILEGE          (10L)
#define SE_SYSTEM_PROFILE_PRIVILEGE       (11L)
#define SE_SYSTEMTIME_PRIVILEGE           (12L)
#define SE_PROF_SINGLE_PROCESS_PRIVILEGE  (13L)
#define SE_INC_BASE_PRIORITY_PRIVILEGE    (14L)
#define SE_CREATE_PAGEFILE_PRIVILEGE      (15L)
#define SE_CREATE_PERMANENT_PRIVILEGE     (16L)
#define SE_BACKUP_PRIVILEGE               (17L)
#define SE_RESTORE_PRIVILEGE              (18L)
#define SE_SHUTDOWN_PRIVILEGE             (19L)
#define SE_DEBUG_PRIVILEGE                (20L)
#define SE_AUDIT_PRIVILEGE                (21L)
#define SE_SYSTEM_ENVIRONMENT_PRIVILEGE   (22L)
#define SE_CHANGE_NOTIFY_PRIVILEGE        (23L)
#define SE_REMOTE_SHUTDOWN_PRIVILEGE      (24L)
#define SE_UNDOCK_PRIVILEGE               (25L)
#define SE_SYNC_AGENT_PRIVILEGE           (26L)
#define SE_ENABLE_DELEGATION_PRIVILEGE    (27L)
#define SE_MAX_WELL_KNOWN_PRIVILEGE       (SE_ENABLE_DELEGATION_PRIVILEGE)

#define SATYPE_USER     1
#define SATYPE_GROUP    2
#define SATYPE_PRIV     3

#define DUMP_TOKEN  1
#define DUMP_HEX    2

#define BUFSIZE 4096

ULONG   PID;
DWORD   fMe = 0;

char* ImpLevels[] = { "Anonymous", "Identity", "Impersonation", "Delegation" };

void DumpSid(PSID pxSid)
{
    PISID pSid = (PISID)pxSid;
    int i, j =0;

    printf("  S-%d-", pSid->Revision);
    for (i = 0; i < 6; i++ )
    {
        if (j)
        {
            printf("%x", pSid->IdentifierAuthority.Value[i]);
        }
        else
        {
            if (pSid->IdentifierAuthority.Value[i])
            {
                j = 1;
                printf("%x", pSid->IdentifierAuthority.Value[i]);
            }
        }
        if (i == 4)
        {
            j = 1;
        }
    }
    for (i = 0; i < pSid->SubAuthorityCount; i++ )
    {
        printf((fMe & DUMP_HEX ? "-%x" : "-%lu"), pSid->SubAuthority[i]);
    }
}


void DumpSidAttr(PSID_AND_ATTRIBUTES pSA, int SAType)
{
    DumpSid(pSA->Sid);

    if (SAType == SATYPE_GROUP)
    {
        printf("\tAttributes - ");
        if (pSA->Attributes & SE_GROUP_MANDATORY)
        {
            printf("Mandatory ");
        }
        if (pSA->Attributes & SE_GROUP_ENABLED_BY_DEFAULT)
        {
            printf("Default ");
        }
        if (pSA->Attributes & SE_GROUP_ENABLED)
        {
            printf("Enabled ");
        }
        if (pSA->Attributes & SE_GROUP_OWNER)
        {
            printf("Owner ");
        }
        if (pSA->Attributes & SE_GROUP_LOGON_ID)
        {
            printf("LogonId ");
        }
    }
}


CHAR*  GetPrivName(PLUID pPriv)
{
    switch (pPriv->LowPart)
    {
        case SE_CREATE_TOKEN_PRIVILEGE:
            return(SE_CREATE_TOKEN_NAME);
        case SE_ASSIGNPRIMARYTOKEN_PRIVILEGE:
            return(SE_ASSIGNPRIMARYTOKEN_NAME);
        case SE_LOCK_MEMORY_PRIVILEGE:
            return(SE_LOCK_MEMORY_NAME);
        case SE_INCREASE_QUOTA_PRIVILEGE:
            return(SE_INCREASE_QUOTA_NAME);
        case SE_UNSOLICITED_INPUT_PRIVILEGE:
            return(SE_UNSOLICITED_INPUT_NAME);
        case SE_TCB_PRIVILEGE:
            return(SE_TCB_NAME);
        case SE_SECURITY_PRIVILEGE:
            return(SE_SECURITY_NAME);
        case SE_TAKE_OWNERSHIP_PRIVILEGE:
            return(SE_TAKE_OWNERSHIP_NAME);
        case SE_LOAD_DRIVER_PRIVILEGE:
            return(SE_LOAD_DRIVER_NAME);
        case SE_SYSTEM_PROFILE_PRIVILEGE:
            return(SE_SYSTEM_PROFILE_NAME);
        case SE_SYSTEMTIME_PRIVILEGE:
            return(SE_SYSTEMTIME_NAME);
        case SE_PROF_SINGLE_PROCESS_PRIVILEGE:
            return(SE_PROF_SINGLE_PROCESS_NAME);
        case SE_INC_BASE_PRIORITY_PRIVILEGE:
            return(SE_INC_BASE_PRIORITY_NAME);
        case SE_CREATE_PAGEFILE_PRIVILEGE:
            return(SE_CREATE_PAGEFILE_NAME);
        case SE_CREATE_PERMANENT_PRIVILEGE:
            return(SE_CREATE_PERMANENT_NAME);
        case SE_BACKUP_PRIVILEGE:
            return(SE_BACKUP_NAME);
        case SE_RESTORE_PRIVILEGE:
            return(SE_RESTORE_NAME);
        case SE_SHUTDOWN_PRIVILEGE:
            return(SE_SHUTDOWN_NAME);
        case SE_DEBUG_PRIVILEGE:
            return(SE_DEBUG_NAME);
        case SE_AUDIT_PRIVILEGE:
            return(SE_AUDIT_NAME);
        case SE_SYSTEM_ENVIRONMENT_PRIVILEGE:
            return(SE_SYSTEM_ENVIRONMENT_NAME);
        case SE_CHANGE_NOTIFY_PRIVILEGE:
            return(SE_CHANGE_NOTIFY_NAME);
        case SE_REMOTE_SHUTDOWN_PRIVILEGE:
            return(SE_REMOTE_SHUTDOWN_NAME);
        default:
            return("Unknown Privilege");
    }
}


void DumpLuidAttr(PLUID_AND_ATTRIBUTES pLA, int LAType)
{
    printf("0x%x%08x", pLA->Luid.HighPart, pLA->Luid.LowPart);
    printf(" %-32s", GetPrivName(&pLA->Luid));

    if (LAType == SATYPE_PRIV)
    {
        printf("  Attributes - ");
        if (pLA->Attributes & SE_PRIVILEGE_ENABLED)
        {
            printf("Enabled ");
        }

        if (pLA->Attributes & SE_PRIVILEGE_ENABLED_BY_DEFAULT)
        {
            printf("Default ");
        }
    }

}


void DumpToken(HANDLE hToken)
{
    PTOKEN_USER         pTUser;
    PTOKEN_GROUPS       pTGroups;
    PTOKEN_PRIVILEGES   pTPrivs;
    PTOKEN_PRIMARY_GROUP    pTPrimaryGroup;
    TOKEN_STATISTICS    TStats;
    ULONG               cbRetInfo;
    int                 status;
    DWORD               i;

    pTUser = (PTOKEN_USER)malloc(256);
    status = GetTokenInformation(hToken, TokenUser, pTUser, 256, &cbRetInfo);
    if (!status)
    {
        printf("FAILED querying token, %#x\n", status);
        return;
    }

    printf("User\n  ");
    DumpSidAttr(&pTUser->User, SATYPE_USER);

    printf("\nGroups");
    pTGroups = (PTOKEN_GROUPS)malloc(4096);
    status = GetTokenInformation(   hToken,
                                        TokenGroups,
                                        pTGroups,
                                        4096,
                                        &cbRetInfo);

    for (i = 0; i < pTGroups->GroupCount ; i++ )
    {
        printf("\n %02d ", i);
        DumpSidAttr(&pTGroups->Groups[i], SATYPE_GROUP);
    }

    pTPrimaryGroup  = (PTOKEN_PRIMARY_GROUP)malloc(128);
    status = GetTokenInformation(hToken, TokenPrimaryGroup, pTPrimaryGroup, 128, &cbRetInfo);

    printf("\nPrimary Group\n  ");
    DumpSid(pTPrimaryGroup->PrimaryGroup);

    printf("\nPrivileges");
    pTPrivs = (PTOKEN_PRIVILEGES)malloc(4096);
    status = GetTokenInformation(hToken, TokenPrivileges, pTPrivs, 4096, &cbRetInfo);

    for (i = 0; i < pTPrivs->PrivilegeCount ; i++ )
    {
        printf("\n %02d ", i);
        DumpLuidAttr(&pTPrivs->Privileges[i], SATYPE_PRIV);
    }

    status = GetTokenInformation(hToken, TokenStatistics, &TStats, sizeof(TStats), &cbRetInfo);

    printf("\n\nAuth ID  %x:%x\n", TStats.AuthenticationId.HighPart, TStats.AuthenticationId.LowPart);
    printf("TokenId     %x:%x\n", TStats.TokenId.HighPart, TStats.TokenId.LowPart);
    printf("TokenType   %s\n", TStats.TokenType == TokenPrimary ? "Primary" : "Impersonation");
    printf("Imp Level   %s\n", ImpLevels[ TStats.ImpersonationLevel ]);
}

