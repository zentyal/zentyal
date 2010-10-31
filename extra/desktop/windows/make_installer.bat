:: Build script for Zentyal Desktop

set MAKENSIS_EXE="%programfiles%\NSIS\makensis.exe"

mkdir build
mkdir dist

copy zentyal-setup-user.pl build
xcopy /S /I /Y ZentyalDesktop build\ZentyalDesktop
xcopy /S /I /Y ..\common\ZentyalDesktop build\ZentyalDesktop

cd build
:: call pp --gui --icon ..\res\zentyal.ico -o zentyal-setup-user.exe zentyal-setup-user.pl
call pp -o zentyal-setup-user.exe zentyal-setup-user.pl

move zentyal-setup-user.exe ..\dist
cd ..

xcopy /S /I /Y templates dist\templates
xcopy /S /I /Y ..\common\templates dist\templates

xcopy /S /I /Y res dist\res
copy LICENSE.txt dist

copy *.nsi dist

cd dist
%MAKENSIS_EXE% zentyal-desktop-config.nsi
%MAKENSIS_EXE% zentyal-desktop.nsi
cd ..

move dist\zentyal-desktop-*.*.exe .
pause
