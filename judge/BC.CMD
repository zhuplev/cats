echo on
DEL *.tmp
DEL *.obj
DEL *.exe

echo %1.bas > bc.tmp
echo %1.obj >> bc.tmp
echo %1.map >> bc.tmp
c:\cats\judge\basic\bc < bc.tmp

echo %1.obj > link.tmp
echo %1.exe >> link.tmp
echo %1.map >> link.tmp
echo c:\cats\judge\basic\bcom45.lib >> link.tmp
c:\cats\judge\basic\link < link.tmp
IF NOT EXIST %1.exe (EXIT 1)
ECHO Success
EXIT 0

