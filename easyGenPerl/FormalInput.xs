#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <parser.h>

#include "const-c.inc"

typedef struct parseError ParseError;

MODULE = FormalInput	PACKAGE = FormalInput

PROTOTYPES: DISABLE

INCLUDE: const-xs.inc

ParseError *
parserValidate(buf)
   const char* buf

const char* 
errorMessageByCode(errCode)
   int errCode 

int
getErrCode(a)
   ParseError* a

size_t
getErrLine(a)
   ParseError* a

size_t
getErrPos(a)
   ParseError* a
