#ifdef __BORLANDC__
   #define INT64 __int64
   #define UINT64 unsigned __int64
#else
   #define INT64 long long
   #define UINT64 unsigned long long
#endif
#define real long double

enum objKind {oNewLine, oSoftLine, oInteger, oFloat, oString, oSeq, oEnd};

struct expr
{
   char opCode;
   INT64 intConst;
   char* varName;
   struct expr *op1,*op2;
};

struct attr
{
   char* attrName;
   char* strVal;
   struct expr *exVal1, *exVal2; 
   int charNum;
   char valid[256];
   char* charSetStr;
};

struct obj 
{
   int objKind;
   struct attr* attrList;
   struct objRecord *rec, *parent;
   //size_t parentNumber;
};

struct objData
{
   struct recordData* parentData;
   void* value;
};

struct recordData
{
   struct objData *data, *parentData;
};


struct objRecord
{
   int n;
   struct obj* seq;
   struct objRecord* parent;
};

struct recWithData
{
   struct objRecord* recPart;
   struct recordData* pointerToData;
};

struct objWithData
{
   struct obj* objPart;
   struct objData* pointerToData;
};

struct parseError
{
   size_t line, pos;
   int code;
};

//arithmetcis utilities
INT64 genRandInt(INT64 l, INT64 r); 
void setRandSeed(INT64 randseed);
real genRandFloat(INT64 l, INT64 r, int d);
size_t getMaxIntLen(); 

// all destructors free memory for object and it's internal structures
void exprDestructor(struct expr* a); 
void attrDestructor(struct attr* a); 
void objDestructor(struct obj* a); 
void objRecordDestructor(struct objRecord* a);
void parseErrorDestructor(struct parseError* a); 

// utilities
int isInCharSet(char ch, char* desc); // return positive integer if in, 
                                      // negative if error, zero if not in
struct parseError* getLastError(); // (!) copy global structure to result, 
int wasError();
const char* errorMessageByCode(int errCode); 
struct objWithData findObject(const char* name, struct recWithData rec, int goUp);
int getSeqLen(struct objWithData info);

// important functions
void initialize(const char* buf);
void finalize(); 
struct objRecord* parseObjRecord(); // (!)

// mainly for cats web-server
struct parseError* parserValidate(const char* buf);
int getErrCode(struct parseError* a);
size_t getErrLine(struct parseError* a);
size_t getErrPos(struct parseError* a);

struct recWithData mallocRecord(struct recWithData info, int isRoot);
INT64 evaluate(struct expr* e, struct objWithData info);

INT64 getFloatDig(struct objWithData info);
INT64 getIntValue(struct objWithData info);
real getFloatValue(struct objWithData info);
char* getStrValue(struct objWithData info); // just a pointer, no copy

void setIntValue(struct objWithData info, const INT64 value);  
void setFloatValue(struct objWithData info, const real value);  
void setStrValue(struct objWithData info, const char* value); // copy value

struct recWithData byIndex(struct objWithData info, int index);  
struct objWithData byName(struct recWithData info, const char* name);

void autoGenRecord(struct recWithData info); 
void autoGenSeq(struct objWithData info); 
void autoGenInt(struct objWithData info); 
void autoGenFloat(struct objWithData info); 
void autoGenStr(struct objWithData info);

void destroyRecData(struct recWithData info);
void destroySeqData(struct objWithData info); 

// user should destroy stuctures, returned by procedures marked with (!),
// user should also destroy all data by destroy...Data procedures
