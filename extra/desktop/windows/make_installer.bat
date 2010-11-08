:: Build script for Zentyal Desktop

set MAKENSIS_EXE="%programfiles%\NSIS\makensis.exe"
set LIBPERL=C:\strawberry\perl\lib\auto
::set EXTRAMODULES=ZentyalDesktop/UserCorner.pm ZentyalDesktop/Zarafa.pm ZentyalDesktop/VoIP.pm ZentyalDesktop/Samba.pm ZentyalDesktop/Mail.pm ZentyalDesktop/Jabber.pm

mkdir build dist

copy zentyal-desktop.ini dist
copy zentyal-user-reset.bat dist
copy zentyal-setup-user.pl build
xcopy /S /I /Y ZentyalDesktop build\ZentyalDesktop
::xcopy /S /I /Y ..\common\ZentyalDesktop\*.* build\ZentyalDesktop

cd build

:: The two following lines are for debug and release build, uncomment only one of them
call pp -o zentyal-setup-user.exe zentyal-setup-user.pl --link %LIBPERL%\Socket\Socket.dll
::call pp --gui --icon ..\res\zentyal.ico -o zentyal-setup-user.exe zentyal-setup-user.pl --link %LIBPERL%\Socket\Socket.dll

move zentyal-setup-user.exe ..\dist
cd ..

xcopy /S /I /Y templates dist\templates
::xcopy /S /I /Y ..\common\templates\*.* dist\templates

xcopy /S /I /Y res dist\res
copy LICENSE.txt dist

copy *.nsi dist

cd dist
%MAKENSIS_EXE% zentyal-desktop-config.nsi
%MAKENSIS_EXE% zentyal-desktop.nsi
cd ..

move dist\zentyal-desktop-*.*.exe .
pause
