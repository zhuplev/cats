rem Spawner.exe -u:acm3 -p:acm3 -ml:20 -d:5 %comspec% /C dir """F:/public"""
SET SP_USER=acm3
SET SP_PASSWORD=acm3
SET SP_RUNAS=0
SET SP_WRITE_LIMIT=10
SET SP_MEMORY_LIMIT=10
SET SP_DEADLINE=20
SET SP_REPORT_FILE=report.txt
SET SP_OUTPUT_FILE=output.txt
SET SP_HIDE_REPORT=1
SET SP_HIDE_OUTPUT=1
SET SP_SECURITY_LEVEL=1

Spawner.exe "C:\Program Files\Borland\Delphi7\Bin\dcc32.exe"
