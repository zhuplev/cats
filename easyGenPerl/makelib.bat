call h2xs -Afn FormalInput
copy parser.c FormalInput\parser.c
copy parser.h FormalInput\parser.h
copy mt19937-64.c FormalInput\mt19937-64.c
call h2xs -Oan FormalInput
copy typemap FormalInput\typemap
perl addFirstLine.pl FormalInput\manifest typemap
copy FormalInput.xs FormalInput\FormalInput.xs
cd FormalInput
perl Makefile.PL
nmake
nmake install