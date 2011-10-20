:::::::::::::::::::::::::::::::::::::::::::::::::::::
::
:: Kervin Pierre
:: kervin@blueprint-tech.com
:: 11JUN02
::
:: BAT file for building installer for passwdHk
::
:::::::::::::::::::::::::::::::::::::::::::::::::::::

@ECHO off

Set INSTALLER_TEMP=installer_temp
Set MAKENSIS_EXE="c:\program files\nsis\makensis.exe"
Set PYTHON_EXE="C:\Python26\python.exe"

mkdir %INSTALLER_TEMP%

copy AUTHORS.txt %INSTALLER_TEMP%
copy LICENSE.txt %INSTALLER_TEMP%
copy installer.nsi %INSTALLER_TEMP%
copy vcredist_x86.exe %INSTALLER_TEMP%
copy adsync\README.passwdHk.txt %INSTALLER_TEMP%
copy adsync\passwdhk.dll %INSTALLER_TEMP%
copy adsync\passwdhk64.dll %INSTALLER_TEMP%
copy adsync\setup-service.bat %INSTALLER_TEMP%
copy adsync\zentyal-service-launcher.exe %INSTALLER_TEMP%
copy gui\migration.xml %INSTALLER_TEMP%

:: Generate .exe from python
if exist %PYTHON_EXE% goto path
python setup.py py2exe
copy dist\*.* %INSTALLER_TEMP%
goto end
:path
%PYTHON_EXE% setup.py py2exe
copy dist\*.* %INSTALLER_TEMP%
:end

cd %INSTALLER_TEMP%
%MAKENSIS_EXE% installer.nsi
move zentyal-migration-tool-*.exe ..

pause
