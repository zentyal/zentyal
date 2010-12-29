:::::::::::::::::::::::::::::::::::::::::
::
:: Kervin Pierre, 11JUN02
:: kervin@blueprint-tech.com
:: Florida Tech, Information Technology
::
:: Test script for passwdHk DLL
::
:::::::::::::::::::::::::::::::::::::::::

@ECHO OFf
Set OUTFILE="C:\TEMP\passwd.txt"

echo user='%1' pass='%2' >> %OUTFILE%

