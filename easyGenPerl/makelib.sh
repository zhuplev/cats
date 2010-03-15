rm -rf FormalInput
h2xs -Afn FormalInput
cp parser.c FormalInput/parser.c
cp parser.h FormalInput/parser.h
cp mt19937-64.inc FormalInput/mt19937-64.inc
h2xs -Oan FormalInput
cp typemap FormalInput/typemap
perl addFirstLine.pl FormalInput/manifest typemap
cp FormalInput.xs FormalInput/FormalInput.xs
cd FormalInput
perl Makefile.PL
make
make install
