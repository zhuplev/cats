#define __my__release
//TODO:
//   more precise line and pos in error generation

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "parser.h"

#define charNumber 256
#define tmpBufSize 10240
#define errorCodesNumber 40

#define objCount 7
#define allAttrCount 6
#define priorityNumber 3

#define maxIntValue 9223372036854775807LL
INT64 getMaxIntValue() {return maxIntValue;} 
#define maxIntLen 19
size_t getMaxIntLen() {return maxIntLen;} 
#define maxFloatDigits 12
int getMaxFloatDigits() {return maxFloatDigits;} 
#define eps 1e-13
real getEps() {return eps;} 

enum attrKind {aName, aRange, aDigits, aChars, aLength, aLenRange};

enum attrValType {vIdent, vInt, vIntRange, vCharSet};
   
static char* objStr[objCount] = {"newline", "softline", "integer", "float",
   "string", "seq", "end"};

static char* attrStr[allAttrCount] = {"name", "range", "digits", 
   "chars", "length", "lenrange"};

static int attrByObj[objCount][allAttrCount] = {
   {0,0,0,0,0,0},{0,0,0,0,0,0},{1,1,0,0,0,0},
   {1,1,1,0,0,0},{1,0,0,1,0,1},{1,0,0,0,1,0},{0,0,0,0,0,0}
};

static int attrTypeByKind[allAttrCount] = {
   vIdent, vIntRange, vInt, vCharSet, vInt, vIntRange
};

enum tokenType {ttDelim, ttObject, ttAttrName, ttIdentifier, 
   ttInteger, ttCharSet};
/* Delimeters list is useless while all of it have length == 1.
enum delimeters {dlSemi, dlComma, dlEq, dlOpenR, dlCloseR, dlOpenSq, 
   dlCLoseSq, dlPlus, dlMinus, dlMul, dlDiv, dlDegree};*/
   
static const char* errorList[errorCodesNumber + 1] = { 
/*00*/   "",
/*01*/   "unknown token",
/*02*/   "too long integer constant",
/*03*/   "'}' expected",
/*04*/   "'{' expected",
/*05*/   "unexpected char after '\\'",
/*06*/   "tokenizer bug: unknown state",
/*07*/   "unexpected token",
/*08*/   "')' expected",
/*09*/   "operand expected",
/*10*/   "expression parser bug: ^ not expected",
/*11*/   "unknown attribute name",
/*12*/   "invalid charset",
/*13*/   "bug in array attrTypeByKind",
/*14*/   "this attribute is already defined",
/*15*/   "attibute is invalid for this object kind",
/*16*/   "invalid attibute list",
/*17*/   "object kind expected",
/*18*/   "end unexpected",
/*19*/   "object with this name already exists",
/*20*/   "no object with such name",
/*21*/   "integer object expected",
/*22*/   "end expected",
/*23*/   "trying to divide by zero",
/*24*/   "parser bug: unknown arithmetic operation",
/*25*/   "parser bug: unknown identifier",
/*26*/   "invalid sequence index",
/*27*/   "assinging object with already defined value",
/*28*/   "assinging int for non-int object",
/*29*/   "assinging number not in range",
/*30*/   "geting value from not defined object",
/*31*/   "geting value from not that type object",
/*32*/   "running seq autogen for non-seq object",
/*33*/   "getSeqLength is called fot non-seq object",
/*34*/   "data management bug",
/*35*/   "genRandInt called with illegal params",
/*36*/   "assinging string for non-string object",
/*37*/   "assigning string with invalid chars",
/*38*/   "assigning string of invalid length",
/*39*/   "invalid nubmer of digits after decimal point"
/*40*/   "assinging float for non-float object",
}; // error codes should start with 1

struct token
{
   int type;
   INT64 value;
   size_t line, pos;
   char* str;
};

static const char* buf;
static size_t bufSize, bufPos, line, pos;
static struct token* curToken;
static struct parseError* lastError;

#ifndef __my__release
   static char* buf1; 
#endif

static void genParseError(int errCode);

//------------------------------random numbers generation----------------------
#include "mt19937-64.inc"

static UINT64 nextRand()
{
   return genrand64_int64();
}

INT64 genRandInt(INT64 l, INT64 r)
{
   UINT64 x, mod;
   if (r < l) genParseError(35);
   x = nextRand();
   mod = (UINT64)(r-l)+1;
   return l + (x%mod);
}

real genRandFloat(INT64 l, INT64 r, int d)
{
   real d10, x;
   UINT64 len, tmp;
   int i, k;

   if (r <= l) return (real)l;
   len = r-l+1;
   if (!len) len--;
   
   k = 0; tmp = len;
   while (tmp) {k++; tmp /= 10;}
   if (k + d >= maxIntLen) d = maxIntLen-1-k;

   for (i = 1, d10 = 1; i <= d; i++) d10 *= 10;
   tmp = genRandInt(l*d10, r*d10);
   x = tmp / (real)d10;
   return x;
}

void setRandSeed(INT64 randseed)
{
   init_genrand64(randseed);
}

//------------------------------ work with memory procedures-------------------
void parseErrorDestructor(struct parseError* a)
{
   free(a);
}

static void tokenDestructor(struct token *a)
{
   if (!a) return;
   free(a->str);
   free(a);
}

void exprDestructor(struct expr* a)
{
   if (!a) return;
   if (a->varName) free(a->varName);
   if (a->op1) exprDestructor(a->op1);
   if (a->op2) exprDestructor(a->op2);
   free(a);
}

static void attrDestructor1(struct attr* a)
{
   if (!a) return;
   free(a->attrName); free(a->strVal); free(a->charSetStr);
   if (a->exVal1) {
      exprDestructor(a->exVal1);
      if (a->exVal2) exprDestructor(a->exVal2);
   }   
}

void attrDestructor(struct attr* a)
{
   attrDestructor1(a); free(a);
}

void attrListDestructor(struct attr* attrList)
{
   int i;
   if (!attrList) return;
   for (i = 0; i < allAttrCount; i++) attrDestructor1(attrList + i);
   free(attrList);
}

static void objDestructor1(struct obj* a)
{
   if (!a) return;
   attrListDestructor(a->attrList);
   objRecordDestructor(a->rec);
}

void objDestructor(struct obj* a)
{
   objDestructor1(a);
   free(a);
}

void objRecordDestructor(struct objRecord* a)
{
   int i;
   if (!a) return;
   for (i = 0; i < a->n; i++) objDestructor1(a->seq + i);
   free(a->seq);
   free(a);
}

static void allocWithCopyStr(char** a, char* b)
{
   if (!b) {*a = 0; return;}
   *a = (char*)malloc(strlen(b) + 1);
   strcpy(*a,b);
}

static void allocWithCopyExpr(struct expr** a, struct expr* b)
{
   if (!b) {*a = 0; return;}
   *a = (struct expr*)malloc(sizeof(struct expr));
   (*a)->intConst = b->intConst;
   (*a)->opCode = b->opCode; 
   allocWithCopyStr(&((*a)->varName), b->varName);
   allocWithCopyExpr(&((*a)->op1), b->op1);
   allocWithCopyExpr(&((*a)->op2), b->op2);
}

static void copyObjToObj(struct obj* a, struct obj* b);

static void allocWithCopyObjRecord(struct objRecord** a, struct objRecord* b)
{
   int i;
   if (!b) {*a = 0; return;}
   *a = (struct objRecord*)malloc(sizeof(struct objRecord));
   (*a)->n = b->n;
   (*a)->parent = b->parent;
   (*a)->seq = (struct obj*)malloc(sizeof(struct obj) * b->n);
   for (i = 0; i < b->n; i++) copyObjToObj((*a)->seq + i, b->seq + i);
}

static void copyAttrToAttr(struct attr* a, struct attr* b);

static void allocWithCopyAttrList(struct attr** a, struct attr* b, int n)
{
   int i;
   if (!b) {*a = 0; return;}
   *a = (struct attr*)malloc(sizeof(struct attr) * n);
   for (i = 0; i < n; i++) copyAttrToAttr((*a) + i, b + i);
}

static void copyAttrToAttr(struct attr* a, struct attr* b)
{
   a->charNum = b->charNum;
   memcpy(&(a->valid), &(b->valid), charNumber);
   allocWithCopyStr(&(a->attrName), b->attrName);
   allocWithCopyStr(&(a->strVal), b->strVal);
   allocWithCopyStr(&(a->charSetStr), b->charSetStr);
   allocWithCopyExpr(&(a->exVal1), b->exVal1);
   allocWithCopyExpr(&(a->exVal2), b->exVal2);
}

static void copyObjToObj(struct obj* a, struct obj* b)
{
   a->objKind = b->objKind;
   a->parent = b->parent;
   allocWithCopyObjRecord(&(a->rec), b->rec);
   allocWithCopyAttrList(&(a->attrList), b->attrList, allAttrCount);
}

static void copyErrToErr(struct parseError* a, struct parseError* b)
{
   a->code = b->code; a->line = b->line; a->pos = b->pos;
}

////-------------------------------------utilities-------------------------------

int getAttrCount(int objKind)
{
   int i, res = 0;
   if (objKind < 0 || objKind > objCount) return 0;
   for (i = 0; i < allAttrCount; i++) if (attrByObj[objKind][i]) res++;
   return res;
}

static int isAlfa(char ch)
{
   return ('a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z');
}

static int isDigit(char ch)
{
   return ('0' <= ch && ch <= '9');
}

int isInCharSet(char ch, char* desc)
{
   int inv,i,j,lastChar,curChar,range,t,screen;
   size_t n = strlen(desc);
   if (n < 3) return -1;
   inv = (desc[0] == '!');
   if (inv) i = 1; else i = 0;
   if (desc[i] != '{' || desc[n-1] != '}') return -1;
   i++;
   lastChar = charNumber; range = 0;
   while (i < (int)n-1) {
      if (desc[i] == '\\') {
         screen = 1;
         if (i >= (int)n-2) return -1;
         if (desc[i+1] == '-' || desc[i+1] == '}' || desc[i+1] == '\\') {
            curChar = desc[i+1]; i += 2;
         } else if (isDigit(desc[i+1])) {
            j = 1; curChar = 0;
            while (i+j < (int)n-1 && isDigit(desc[i+j]) && 
               curChar*10+desc[i+j]-'0' < charNumber) {
                  curChar = curChar*10 + desc[i+j] - '0';
                  j++;
            }
            i += j;
         } else return -1;
      } else {curChar = desc[i]; i++; screen = 0;}
      if (curChar == '-' && !screen) {
         if (range != 0 || lastChar == charNumber) return -1;
         range = 1;
      } else {
         if (range == 1) {
            if (lastChar > curChar) {
               t = lastChar; lastChar = curChar; curChar = t;
            }
            for (j = lastChar; j <= curChar; j++)
               if ((int)ch == j) return 1-inv;
            range = 2;
         } else {
            if (range != 2 && lastChar == (int)ch) return 1-inv;
            lastChar = curChar;
            range = 0;
         }
      }
   } 
   if (range == 1) return -1;
   if (range != 2 && lastChar == (int)ch) return 1-inv;
   return inv;
}

const char* errorMessageByCode(int errCode)
{
   if (errCode < 1 || errCode > errorCodesNumber) return 0;
   else return errorList[errCode];
}

struct parseError* getLastError()
{
   struct parseError* res;
   if (!lastError) return 0;
   res = (struct parseError*)malloc(sizeof(struct parseError));
   copyErrToErr(res, lastError);
   return res;
}

int wasError()
{
   return lastError != 0;
}

static void genParseError(int errCode)
{
   if (!lastError) {
      lastError = (struct parseError*)malloc(sizeof(struct parseError));
      lastError->code = errCode; lastError->line = line; lastError->pos = pos;
   } 
   #ifndef __my__release
   else printf("\nGenerating error while already have one\n");
   #endif
}

struct objWithData findObject(const char* name, struct recWithData rec, int goUp)
{
   int i;
   struct objWithData res;   
   while (rec.recPart) {
      for (i = 0; i < rec.recPart->n; i++) {
         if (attrByObj[rec.recPart->seq[i].objKind][aName]) 
            if (!strcmp(name, rec.recPart->seq[i].attrList[aName].strVal)) {
               res.objPart = &(rec.recPart->seq[i]);
               if (rec.pointerToData) {
                  res.pointerToData = &(rec.pointerToData->data[i]);
               }
               return res;
            }
      }
      if (!goUp) break;
      rec.recPart = rec.recPart->parent;
      if (rec.pointerToData) {
         rec.pointerToData = rec.pointerToData->parentData->parentData;
      }
   }
   res.objPart = 0; res.pointerToData = 0;
   return res;
}

//--------------------------------parse procedures-----------------------------
static int moveToNextChar()
{
   bufPos++;
   if (bufPos >= bufSize) return 1;
   if (buf[bufPos] == 10) {line++; pos = 0;} else pos++;
   return 0;
}

static int getDelimVal(char ch)
{
   switch (ch) {
      case ';': case ',': case '=': case '(': case ')': 
      case '[': case ']': case '+': case '-': case '*':
      case '/': case '^':
         return ch; break;
      default: return -1;
   }
}

static char* getSubString(const char* a, size_t i, size_t j)
{
   char* res;
   if (j < i) return 0;
   res = (char*)malloc(j-i+2);
   res[0] = 0; strncat(res,a+i,j-i+1);
   return res;
}

static struct token* newToken(size_t line, size_t pos, size_t i, size_t j)
{
   struct token *res = (struct token*)malloc(sizeof(struct token));
   res->line = line; res->pos = pos;
   res->str = getSubString(buf, i, j-1);
   return res;
}

static void moveToNextToken()
{
   int state = 0, ch, fin, i, ch1;
   size_t line1 = line, pos1 = pos, oldPos = bufPos, sc;
   
   if (curToken) tokenDestructor(curToken);
   curToken = 0;   
   if (bufPos >= bufSize) return;
   while (1) {
      ch = buf[bufPos];
      switch(state) {
         case 0:
            if (0 <= ch && ch <= ' ') {
               if (moveToNextChar()) return;
               oldPos = bufPos;
            } else if (isAlfa(ch) || ch == '_') {
               moveToNextChar(); state = 1;
            }
            else if (isDigit(ch)) state = 3; 
            else if (ch == '{') state = 4;
            else if (ch == '!') state = 5;
            else state = 2;
            break;
            
         case 1:
            fin = 0;
            if (isAlfa(ch) || ch == '_' || isDigit(ch)) {
               if (moveToNextChar()) fin = 1;
            } else fin = 1;
            if (fin) {
               curToken = newToken(line1, pos1, oldPos, bufPos);
               for (i = 0; i < objCount; i++)
                  if (bufPos-oldPos == strlen(objStr[i]) && 
                     !strncmp(buf+oldPos, objStr[i], bufPos-oldPos)) break;
               if (i < objCount) {
                  curToken->type = ttObject; curToken->value = i;
               } else {
                  for (i = 0; i < allAttrCount; i++)
                     if (bufPos-oldPos == strlen(attrStr[i]) && 
                        !strncmp(buf+oldPos, attrStr[i], bufPos-oldPos)) break;
                  if (i < allAttrCount) {
                     curToken->type = ttAttrName; curToken->value = i;
                  } else {
                     curToken->type = ttIdentifier; curToken->value = -1;
                  }
               }
               return;
            }
            break;
            
         case 2:
            i = getDelimVal(ch);            
            moveToNextChar();
            if (i != -1) {
               curToken = (struct token*)malloc(sizeof(struct token));
               curToken = newToken(line1, pos1, oldPos, bufPos);
               curToken->type = ttDelim; curToken->value = i;
               return;
            } else {genParseError(1)/*"unknown token"*/; return;}
            break;
         case 3:
            fin = 0;
            if (isDigit(ch)) {
               if (moveToNextChar()) fin = 1;
            } else fin = 1;
            if (fin) {
               curToken = newToken(line1,pos1,oldPos,bufPos);
               curToken->type = ttInteger; curToken->value = 0;
               if (bufPos - oldPos > maxIntLen) {genParseError(2); return;}
               //"too long integer constant"
               for (sc = oldPos; sc < bufPos; sc++) 
                  curToken->value = curToken->value*10 + buf[sc] - '0';
               return;
            }
            break;
         case 4:
            if (moveToNextChar()) {genParseError(3); return;} //"'}' expected"
            if (buf[bufPos] == '\\') state = 6;
            if (buf[bufPos] == '}') {
               moveToNextChar();
               curToken = newToken(line1,pos1,oldPos,bufPos);
               curToken->type = ttCharSet; curToken->value = 0;
               return;
            }
            break;
         case 5:
            if (moveToNextChar() || buf[bufPos] != '{') {
               genParseError(4); return; //"'{' expected"
            }
            state = 4;
            break;
         case 6:
            if (moveToNextChar()) {genParseError(3); return;} //"'{' expected"
            ch1 = buf[bufPos];
            if (ch1 == '\\' || ch1 == '-' || ch1 == '}' || isDigit(ch1)) 
               state = 4;
            else  {genParseError(5); return;} //"unexpected char after '\\'"
            break;
         default: 
            genParseError(6); //"tokenizer bug: unknown state"
            return;
      }
   }
}

static int chkCurToken(char ch)
{
   return curToken && curToken->type == ttDelim && curToken->value == ch;
}

static int attrFind(char *name)
{
   int i;
   for (i = 0; i < allAttrCount; i++)
      if (!strcmp(attrStr[i], name)) return i;
   return -1;
}

static char* parseSingleToken(int tokenType)
{
   char* res;
   if (!curToken || curToken->type != tokenType) {
      genParseError(7); return 0; //"unexpected token"
   }
   res = (char*)malloc(strlen(curToken->str) + 1);
   strcpy(res,curToken->str);
   moveToNextToken();
   return res;
}

static getOpPriority(char op)
{
   switch (op) {
      case '+': case '-' : return 1;
      case '*': case '/' : return 2;
      case '^': return 3;
   }
   return 0;
}

static struct expr* parseExpression1(int priority, int isFirst, 
   struct objRecord* curSeq)
{
   struct expr *res, *op;
   struct obj* varObj;
   struct recWithData tmp;
   char ch;
   if (priority > priorityNumber) {
      switch (curToken->type) {
         case ttIdentifier:
            res = (struct expr*)malloc(sizeof(struct expr));
            res->op1 = res->op2 = 0; res->opCode = 0; 
            res->varName = (char*)malloc(strlen(curToken->str) + 1);
            strcpy(res->varName, curToken->str);
            
            tmp.pointerToData = 0; tmp.recPart = curSeq;
            varObj = findObject(res->varName, tmp, 1).objPart;
            if (!varObj) genParseError(20); //"no object with such name" 
            //"integer object expected" 
            if (!wasError() && varObj->objKind != oInteger) genParseError(21); 
            if (wasError()) {exprDestructor(res); return 0;}

            moveToNextToken(); 
            if (wasError()) {exprDestructor(res); return 0;}
            return res;
         case ttInteger:
            res = (struct expr*)malloc(sizeof(struct expr));
            res->op1 = res->op2 = 0; res->opCode = 0; res->varName = 0; 
            res->intConst = curToken->value;
            moveToNextToken(); 
            if (wasError()) {exprDestructor(res); return 0;}
            return res;
         case ttDelim:
            if (curToken->value == '(') {
               moveToNextToken();
               res = parseExpression1(1,1,curSeq);
               if (res && !chkCurToken(')')) {
                  genParseError(8); //"')' expected"
                  exprDestructor(res); return 0;
               }
               moveToNextToken(); return res;
            }
            // don't need "break" here
         default: 
            return 0;   
      }
   } else {
      op = parseExpression1(priority + 1, 1, curSeq);

      if (wasError()) {exprDestructor(op); return 0;}
      if (!op) {
         if (priority == getOpPriority('+') && isFirst && 
            (chkCurToken('+') || chkCurToken('-'))) { // unary operations
               op = (struct expr*)malloc(sizeof(struct expr));
               op->op1 = op->op2 = 0; op->opCode = 0; op->varName = 0; 
               op->intConst = 0;
         } else {
            if (priority == getOpPriority('+')) genParseError(9); 
            //"operand expected"
            return 0;
         }
      }
      
      if (chkCurToken('^')) {
         if (priority < getOpPriority('^')) {
            genParseError(10); //"expression parser bug: ^ not expected"
            exprDestructor(op); return 0;
         }
         res = (struct expr*)malloc(sizeof(struct expr));
         res->op1 = op; res->opCode = '^'; 
         res->varName = 0; res->intConst = 0;
         moveToNextToken();
         res->op2 = parseExpression1(priority, 0, curSeq);
         if (!res->op2) {exprDestructor(res->op2); return 0;}
         op = res;
      } else {
         while ((chkCurToken('+') || chkCurToken('-') || 
            chkCurToken('*') || chkCurToken('/')) && 
            getOpPriority((int)curToken->value) == priority) {
               ch = (char)curToken->value;
               res = (struct expr*)malloc(sizeof(struct expr));
               res->op1 = op; res->opCode = ch; 
               res->varName = 0; res->intConst = 0;
               moveToNextToken();
               res->op2 = parseExpression1(priority, 0, curSeq);
               if (!res->op2) {exprDestructor(res); return 0;}
               op = res;
         }
      }
      if (wasError()) {exprDestructor(op); return 0;}
      return op;
   }
}

static struct expr* parseExpression(struct objRecord* curSeq)
{
   return parseExpression1(1,1,curSeq);
}

static void parseIntRange(struct expr** ex1, struct expr** ex2, struct objRecord* curSeq)
{
   if (chkCurToken('[')) {
      moveToNextToken();
      *ex1 = parseExpression(curSeq);
      if (!*ex1 || !chkCurToken(',')) {
         exprDestructor(*ex1); *ex1 = *ex2 = 0; return;
      }
      moveToNextToken();
      *ex2 = parseExpression(curSeq);
      if (!*ex2 || !chkCurToken(']')) {
         exprDestructor(*ex1); exprDestructor(*ex2);
         *ex1 = *ex2 = 0; return;
      }
      moveToNextToken();
   } else {
      *ex1 = parseExpression(curSeq); *ex2 = 0;
   }
}

static struct attr* parseAttr(struct objRecord* curSeq)
{
   struct attr* res;
   int i, j, k;
   
   if (!curToken || curToken->type != ttAttrName) return 0;
   res = (struct attr*)malloc(sizeof(struct attr)); 
   memset(res,0,sizeof(struct attr));
   res->attrName = (char*)malloc(strlen(curToken->str) + 1); 
   strcpy(res->attrName, curToken->str);
   moveToNextToken();
   if (!chkCurToken('=')) {attrDestructor(res); return 0;}
   moveToNextToken();

   i = attrFind(res->attrName);
   if (i < 0) {
      genParseError(11); //"unknown attribute name"
      attrDestructor(res); return 0;
   }
   
   if (!curToken) return 0;
   switch (attrTypeByKind[i]) {
      case vIdent:
         res->strVal = parseSingleToken(ttIdentifier);
         if (!res->strVal) {attrDestructor(res); return 0;}
         break;
      case vInt:
         res->exVal1 = parseExpression(curSeq);
         if (!res->exVal1) {attrDestructor(res); return 0;}
         break;
      case vIntRange:
         parseIntRange(&res->exVal1, &res->exVal2, curSeq);
         if (!res->exVal1) {attrDestructor(res); return 0;}
         break;
      case vCharSet:
         res->strVal = parseSingleToken(ttCharSet);
         if (!res->strVal) {attrDestructor(res); return 0;}
         if (isInCharSet(0, res->strVal) < 0) {
            genParseError(12); //"invalid charset"
            attrDestructor(res); return 0;
         }
         res->charNum = 0;
         memset(res->valid, 0, sizeof(res->valid));
         for (j = 0; j < charNumber; j++) {
            res->valid[j] = isInCharSet(j, res->strVal);
            if (res->valid[j]) res->charNum++;
         }   
         res->charSetStr = (char*)malloc(res->charNum+1);
         res->charSetStr[res->charNum] = 0; k = 0;
         for (j = 0; j < charNumber; j++) 
            if (res->valid[j]) res->charSetStr[k++] = j;
         break;
      default: 
         genParseError(13); //"bug in array attrTypeByKind"
         attrDestructor(res); return 0;
   }
   if (wasError()) {attrDestructor(res); return 0;}
   return res;
}

static struct attr* parseAttrList(int objKind, struct objRecord* curSeq)
{
   //it should eat semicolons too
   struct attr *res = 0, *curAttr;
   int bad = 0, i, n = 0;
   int vis[allAttrCount]; memset(vis,0,sizeof(vis));
   
   res = (struct attr*)malloc(allAttrCount * sizeof(struct attr));
   memset(res, 0, allAttrCount * sizeof(struct attr));
   
   while (curAttr = parseAttr(curSeq)) {
      i = attrFind(curAttr->attrName);
      if (vis[i]) {
         genParseError(14); //"this attribute is already defined"
         attrDestructor(curAttr); curAttr = 0;
         bad = 1; break;
      }
      if (!attrByObj[objKind][i]) {
         genParseError(15); //"attibute is invalid for this object kind"
         attrDestructor(curAttr); curAttr = 0;
         bad = 1; break;
      }
      vis[i] = 1; n++;
      copyAttrToAttr(&(res[i]), curAttr);
      attrDestructor(curAttr);
      
      if (chkCurToken(',')) {
         bad = 1; moveToNextToken();
      } else bad = 0;
   }
   
   if (wasError()) {attrListDestructor(res); return 0;}
   if (n < getAttrCount(objKind)) bad = 1;
   if (bad) {
      attrListDestructor(res);
      genParseError(16); //"invalid attibute list"
      return 0;
   }
   if (!curToken || chkCurToken(';')) {
      if (curToken) moveToNextToken(); 
      return res;
   } else {attrListDestructor(res); return 0;}
}

static struct objRecord* parseObjRecord1(struct objRecord* parent);

static struct obj* parseNextObject(struct objRecord* curSeq)
{
   int objKind;
   struct obj* res;
   struct attr* attrList;
   char* name;
   struct recWithData tmp;
   
   if (!curToken) return 0;
   if (curToken->type != ttObject) {
      genParseError(17); //"object kind expected"
      return 0;
   }
   objKind = (int)curToken->value; moveToNextToken();

   attrList = parseAttrList(objKind, curSeq);
   
   if (attrList) {
      name = attrList[aName].strVal;
      if (name) { // if name doesn't exist, than it's unnamed objKind
         tmp.pointerToData = 0; tmp.recPart = curSeq;
         if (findObject(name, tmp, 0).objPart) {
            attrListDestructor(attrList);
            genParseError(19); //"object with this name already exists"
            return 0;
         }
      }
   }
   
   if (attrList || objKind == oEnd || 
      objKind == oNewLine || objKind == oSoftLine) {
         res = (struct obj*)malloc(sizeof(struct obj));
         res->attrList = attrList; res->objKind = objKind;
         if (objKind == oSeq) {
            res->rec = parseObjRecord1(curSeq);
            if (!res->rec) {objDestructor(res); return 0;}
         } else res->rec = 0;
         if (wasError()) {objDestructor(res); return 0;}
         //res->parent = curSeq;  <- curSeq will reallocate anyway
         return res;              
   }

   genParseError(16); // "invalid attribute list"
   return 0;
}

static struct objRecord* parseObjRecord1(struct objRecord* parent)
{
   struct obj* curObj;
   struct objRecord *res, *tmp;
   int wasEnd = 0;
   int i;
   res = (struct objRecord*)malloc(sizeof(struct objRecord));
   res->n = 0; res->seq = 0; res->parent = parent;
   
   while (curObj = parseNextObject(res)) {
      if (curObj->objKind == oEnd) {
         if (!parent) {genParseError(18); break;} //"end unexpected"
         else {objDestructor(curObj); wasEnd = 1; break;}
      }
      res->n++; 
      tmp = (struct objRecord*)malloc(sizeof(struct objRecord));
      tmp->seq = malloc(res->n * sizeof(struct obj));
      for (i = 0; i < res->n - 1; i++) {
         copyObjToObj(tmp->seq + i, res->seq + i);
         tmp->seq[i].parent = tmp;
      }
      tmp->parent = res->parent; tmp->n = res->n;      
      res->n--; objRecordDestructor(res);
      copyObjToObj(tmp->seq + tmp->n - 1, curObj);
      tmp->seq[tmp->n - 1].parent = tmp;
      res = tmp;
      objDestructor(curObj); 
   }

   if (!wasEnd && parent) genParseError(22); //"end expected"
      
   if (wasError()) {objRecordDestructor(res); return 0;}
   return res;   
}

struct objRecord* parseObjRecord()
{
   return parseObjRecord1(0);
}

//-----------------------------data processing procedures----------------------
struct recWithData mallocRecord(struct recWithData info, int isRoot)
{
   int i;
   if (!info.recPart->n) {info.pointerToData = 0; return info;}
   if (isRoot) {
      info.pointerToData = (struct recordData*)malloc(sizeof(struct recordData));
      info.pointerToData->parentData = 0;
   }   
   info.pointerToData->data = 
      (struct objData*)malloc(info.recPart->n * sizeof(struct objData));
   for (i = 0; i < info.recPart->n; i++) {
      info.pointerToData->data[i].value = 0; 
      info.pointerToData->data[i].parentData = info.pointerToData;
   }
   return info;
}

static void getIntLR(struct objWithData info, INT64* l, INT64* r)
{
   *l = evaluate(info.objPart->attrList[aRange].exVal1, info);
   if (info.objPart->attrList[aRange].exVal2)
      *r = evaluate(info.objPart->attrList[aRange].exVal2, info);
   else *r = *l;   
}

INT64 getFloatDig(struct objWithData info)
{
   return evaluate(info.objPart->attrList[aDigits].exVal1, info);
}

INT64 getIntValue(struct objWithData info)
{
   if (info.objPart->objKind != oInteger) {genParseError(31); return 0;}
   if (!info.pointerToData->value) {genParseError(30); return 0;}
   return *((INT64*)info.pointerToData->value);
}

real getFloatValue(struct objWithData info)
{
   if (info.objPart->objKind != oFloat) {genParseError(31); return 0;}
   if (!info.pointerToData->value) {genParseError(30); return 0;}
   return *((real*)info.pointerToData->value);
}

char* getStrValue(struct objWithData info)
{
   if (info.objPart->objKind != oString) {genParseError(31); return 0;}
   if (!info.pointerToData->value) {genParseError(30); return 0;}
   return (char*)(info.pointerToData->value);
}

void setIntValue(struct objWithData info, const INT64 value)
{
   INT64 l, r;
   if (info.objPart->objKind != oInteger) {genParseError(28); return;}
   if (!info.pointerToData->value) {
      getIntLR(info, &l, &r);
      if (value < l || value > r) {genParseError(29); return;}
      info.pointerToData->value = malloc(sizeof(value));
      memcpy(info.pointerToData->value, &value, sizeof(value));
   } else genParseError(27);
}

void setFloatValue(struct objWithData info, const real value)
{
   INT64 l, r;
   real tmp;
   int i, d;
   if (info.objPart->objKind != oFloat) {genParseError(40); return;}
   if (!info.pointerToData->value) {
      getIntLR(info, &l, &r); // it just takes "range" attribute
      d = (int)evaluate(info.objPart->attrList[aDigits].exVal1, info);
      if (value < l || value > r) {genParseError(29); return;}
      if (d < 0 || d > maxFloatDigits) {genParseError(39); return;}
      tmp = value - floorl(value);
      for (i = 0; i < d; i++) {
         tmp = tmp*10; tmp = tmp - floorl(tmp);
      }
      if (fabsl(tmp) > eps) {genParseError(39); return;}
      info.pointerToData->value = malloc(sizeof(value));
      memcpy(info.pointerToData->value, &value, sizeof(value));
   } else genParseError(27);
}

void setStrValue(struct objWithData info, const char* value)  
{
   size_t i, n;   
   INT64 l, r;
   if (info.objPart->objKind != oString) {genParseError(36); return;}
   if (!info.pointerToData->value) {
      n = strlen(value);
      l = evaluate(info.objPart->attrList[aLenRange].exVal1, info);
      r = evaluate(info.objPart->attrList[aLenRange].exVal2, info);
      if (wasError()) return;
      if (n < l || n > r) {
         genParseError(38); return;
      }
      for (i = 0; i < n; i++) 
         if (!info.objPart->attrList[aChars].valid[value[i]]) {
            genParseError(37); return;
         }
      info.pointerToData->value = malloc(n + 1);
      memcpy(info.pointerToData->value, value, n + 1);
   } else genParseError(27);
}

void autoGenInt(struct objWithData info)
{
   INT64 l, r, tmp;
   if (info.objPart->objKind != oInteger) {genParseError(28); return;}
   if (!info.pointerToData->value) {
      getIntLR(info, &l, &r);
      if (wasError()) return;
      tmp = genRandInt(l, r);
      info.pointerToData->value = malloc(sizeof(tmp));
      memcpy(info.pointerToData->value, &tmp, sizeof(tmp));
   }
}

void autoGenFloat(struct objWithData info)
{
   INT64 l, r, d;
   real tmp;
   if (info.objPart->objKind != oFloat) {genParseError(28); return;}
   if (!info.pointerToData->value) {
      getIntLR(info, &l, &r);
      d = evaluate(info.objPart->attrList[aDigits].exVal1, info);
      if (wasError()) return;
      tmp = genRandFloat(l, r, d);
      info.pointerToData->value = malloc(sizeof(tmp));
      memcpy(info.pointerToData->value, &tmp, sizeof(tmp));
   }
}

void autoGenStr(struct objWithData info)
{
   INT64 l, r, tmp;
   size_t i;
   char* res;
   if (info.objPart->objKind != oString) {genParseError(36); return;}
   if (!info.pointerToData->value) {
      l = evaluate(info.objPart->attrList[aLenRange].exVal1, info);
      r = evaluate(info.objPart->attrList[aLenRange].exVal2, info);
      if (wasError()) return;
      tmp = genRandInt(l, r);
      res = (char*)malloc(tmp+1);      
      for (i = 0; i < tmp; i++) {
         res[i] = info.objPart->attrList[aChars].charSetStr
            [genRandInt(0, info.objPart->attrList[aChars].charNum - 1)];
      }      
      res[tmp] = 0;
      info.pointerToData->value = res;
   }
}

int getSeqLen(struct objWithData info)
{
   if (info.objPart->objKind != oSeq) genParseError(33);
   return evaluate(info.objPart->attrList[aLength].exVal1, info);
}

void autoGenSeq(struct objWithData info)
{
   struct recWithData rnd;
   int i, n;
   n = evaluate(info.objPart->attrList[aLength].exVal1, info);
   if (wasError()) return;
   if (info.objPart->objKind != oSeq) {genParseError(32); return;}
   byIndex(info, n);      
   for (i = 0; i < n; i++) {
      rnd.pointerToData = &(((struct recordData*)(info.pointerToData->value))[i]);
      rnd.recPart = info.objPart->rec;
      autoGenRecord(rnd);      
   }   
}

void autoGenRecord(struct recWithData info)
{
   int i;
   int objk;
   struct objWithData tmp;
   if (!info.pointerToData->data) {
      info = mallocRecord(info, 0);
   }
   for (i = 0; i < info.recPart->n; i++) {
      tmp.objPart = &(info.recPart->seq[i]);
      tmp.pointerToData = &(info.pointerToData->data[i]);
      objk = (info.recPart->seq[i]).objKind;
      if (objk != oSeq && tmp.pointerToData->value) continue;
      switch (objk) {
         case oInteger: autoGenInt(tmp); break;
         case oFloat: autoGenFloat(tmp); break;
         case oString: autoGenStr(tmp); break;
         case oSeq: autoGenSeq(tmp); break;
      }   
   }
}

INT64 evaluate(struct expr* e, struct objWithData info)
{
   INT64 res;
   INT64 i, val1, val2;
   struct recWithData rnd;
   struct objWithData tmp;
   if (e->op1) {
      val1 = evaluate(e->op1, info); val2 = evaluate(e->op2, info);
      switch (e->opCode) {
         case '+': res = val1 + val2; break;
         case '-': res = val1 - val2; break;
         case '*': res = val1 * val2; break;
         case '/': 
            if (!val2) genParseError(23);
            res = val1 / val2; break;
         case '^': 
            res = 1;
            for (i = 1; i <= val2; i++) res *= val1;
            break;
         default:
            genParseError(24);
      }
   } else if (e->varName) {
      rnd.pointerToData = info.pointerToData->parentData;
      rnd.recPart = info.objPart->parent;
      tmp = findObject(e->varName, rnd, 1);
      if (!tmp.objPart) genParseError(25);
      res = getIntValue(tmp);
   } else res = e->intConst;
   return res;
}

struct objWithData byName(struct recWithData info, const char* name)
{
   struct recordData* data = info.pointerToData;
   struct objRecord* a = info.recPart;
//   if (!data) genParseError(34);
   return findObject(name, info, 0);
}

struct recWithData byIndex(struct objWithData info, int index)
{
   struct objData* data = info.pointerToData;
   struct obj* a = info.objPart;
   struct recWithData res;
   struct recordData* d, *tmp;
   int n = (int)evaluate(a->attrList[aLength].exVal1, info);
   int i;
   res.pointerToData = 0; res.recPart = 0;
   if (wasError()) return res;
   if (index < 1 || index > n) {genParseError(26); return res;}
   if (!data->value) {
      data->value = malloc(n * sizeof(struct recordData));
      d = (struct recordData*)(data->value);
      for (i = 0; i < n; i++) {
         tmp = (struct recordData*)malloc(sizeof(struct recordData));
         memcpy(&(d[i]), tmp, sizeof(struct recordData));
         d[i].data = 0; d[i].parentData = data;
      }
   }
   res.recPart = a->rec;
   //take 1-indexed value
   res.pointerToData = &(((struct recordData*)(data->value))[index-1]);
   if (!res.pointerToData->data) res = mallocRecord(res, 0);
   return res;
}

void destroySeqData(struct objWithData info)
{
   struct recWithData rnd;
   int i, n;
   if (info.objPart->objKind != oSeq) {genParseError(32); return;}
   n = (int)evaluate(info.objPart->attrList[aLength].exVal1, info);
   if (wasError()) return;
   if (!info.pointerToData || !info.pointerToData->value) return;
   for (i = 0; i < n; i++) {
      rnd.pointerToData = &(((struct recordData*)(info.pointerToData->value))[i]);
      rnd.recPart = info.objPart->rec;
      destroyRecData(rnd);
   }   
}

void destroyRecData(struct recWithData info)
{
   struct objWithData tmp;
   int i;
   if (!info.pointerToData) return;
   for (i = 0; i < info.recPart->n; i++) 
      tmp.objPart = &(info.recPart->seq[i]);
      tmp.pointerToData = &(info.pointerToData->data[i]);
      if (tmp.pointerToData) {
         switch ((info.recPart->seq[i]).objKind) {
            case oInteger: case oFloat: case oString:
               free(tmp.pointerToData->value); 
               break;
            case oSeq: 
               destroySeqData(tmp); 
               break;
        }
     }   
}

//-----------------------------initialize & finalize --------------------------
void initialize(const char* buf1) 
{
   lastError = 0; 
   buf = buf1;
   bufPos = pos = 0; line = 1;
   bufSize = strlen(buf);
   moveToNextToken();
}

void finalize() 
{
   if (curToken) tokenDestructor(curToken);   
   parseErrorDestructor(lastError);
}

//-----------------------------for CATS web-server-----------------------------
struct parseError* parserValidate(const char* buf)
{
   struct parseError* res;
   initialize(buf);
   parseObjRecord();
   if (wasError()) {
      res = (struct parseError*)malloc(sizeof(struct parseError));
      copyErrToErr(res, lastError);
   } else res = 0;
   finalize();
   return res;
}

int getErrCode(struct parseError* a) {return a->code;}
size_t getErrLine(struct parseError* a) {return a->line;}
size_t getErrPos(struct parseError* a) {return a->pos;}


// begin of "#ifndef __my__release" - begin of debug and test code
#ifndef __my__release

static void debugPrintExpr(struct expr* ex)
{
   if (!ex->opCode) {
      if (ex->varName) printf("%s",ex->varName);
      else printf("%I64d",ex->intConst);
   } else {
      printf("(");
      debugPrintExpr(ex->op1);
      printf(") %c (",ex->opCode);
      debugPrintExpr(ex->op2);
      printf(")");
   }
}

static void debugReadFile(char* name) 
{
   char tmp[tmpBufSize];
   size_t bufSize = 0;
   FILE* input = fopen(name, "r");
   buf1 = 0;
   while (fgets(tmp, tmpBufSize, input)) {
      size_t tmpLen = strlen(tmp);
      size_t oldSize = bufSize;
      if (!bufSize) bufSize++;
      bufSize += tmpLen;
      buf1 = realloc(buf1, bufSize);
      buf1[oldSize] = 0;
      strcat(buf1, tmp);
   } 
   fclose(input);
}

static void debugObjKindPrint(int objKind)
{
   switch(objKind) {
      case 0: printf("newline"); break;
      case 1: printf("softline"); break;
      case 2: printf("integer"); break;
      case 3: printf("float"); break;
      case 4: printf("string"); break;
      case 5: printf("seq"); break;
      case 6: printf("end"); break;
      default: printf("BAD OBJECT!");
   }
}

static void debugCharSetPrint(char* s)
{
   int i;
   for (i = 0; i < 256; i++) if (isInCharSet(i, s)) printf("%d ",i);
}

static void debugPrintobjRecord(struct objRecord* a, int indent)
{
   int i,j,k;
   struct obj* co;
   
   if (lastError) {
      if (a) printf("Error, but objRecord is not destroyed\n");
      printf("Error: %s. Line %d, pos %d\n", errorMessageByCode(lastError->code),
         lastError->line, lastError->pos);
      return;
   }
   
   for (k = 0; k < a->n; k++) {
      for (j = 0; j < indent; j++) printf(" ");
      co = &(a->seq[k]);
      debugObjKindPrint(co->objKind); printf(" ");
      for (i = 0; i < allAttrCount; i++) if (co->attrList[i].attrName) {
         if (i) printf(", ");
         printf("%s=",co->attrList[i].attrName);
         if (co->attrList[i].strVal) {
            if (!strncmp(co->attrList[i].attrName,"chars",5)) 
               debugCharSetPrint(co->attrList[i].strVal);
            else printf("%s",co->attrList[i].strVal);
         }   
         else if (co->attrList[i].exVal2) {
            printf("[");
            debugPrintExpr(co->attrList[i].exVal1);
            printf(",");
            debugPrintExpr(co->attrList[i].exVal2);
            printf("]");
         } else if (co->attrList[i].exVal1) 
            debugPrintExpr(co->attrList[i].exVal1);
         else printf("!!!!!!!");
      }
      printf("\n");
      if (co->rec) {
         debugPrintobjRecord(co->rec, indent + 3);
         for (j = 0; j < indent; j++) printf(" ");
         printf("end\n");
      }
   }
}

int main()
{
   size_t i; 
   struct obj* co;
   struct objRecord* os;
   
   debugReadFile("format.txt");
   initialize(buf1);
   
   //Test buffer
   /*for (i = 0; i < bufSize; i++) putc(buf[i],stdout);
   printf("\n\n");*/
      
   //Tokenizer
   /*printf("Tokens:\n--------------------\n");
   while (1) {
      ct = curToken;
      if (!ct) break;
      printf("type:%d\t value:%d\t line:%d\t pos:%d\t str:\"%s\" \n",
         ct->type,ct->value,ct->line,ct->pos,ct->str);
      moveToNextToken();
   }
   printf("\n\n");
   finalize();*/
   
   //getNextObject
   //initialize("format.txt");
   
   os = parseObjRecord();
   debugPrintobjRecord(os,0);
   
   //printf("\n\n");   
   finalize(); 
   free(buf1);
}

#endif
// end of "#ifndef __my__release" - end of debug and test code
