:: Build script for Zentyal Desktop

@echo off

set MAKENSIS_EXE="%programfiles%\NSIS\makensis.exe"

mkdir build
mkdir dist

copy zentyal-setup-user.pl build
xcopy /s ZentyalDesktop build
xcopy /s ../common/ZentyalDesktop build

cd build
pp -o zentyal-setup-user.exe zentyal-setup-user.pl
move zentyal-setup-user.exe ../dist
cd ..

xcopy /s templates dist
xcopy /s ../common/templates dist

xcopy /s res dist

copy *.nsi dist

cd dist
%MAKENSIS_EXE% zentyal-desktop-config.nsi
%MAKENSIS_EXE% zentyal-desktop.nsi
cd ..

move dist/zentyal-desktop-*.*.exe .

pause
