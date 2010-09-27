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
copy README.passwdHk.txt %INSTALLER_TEMP%
copy LICENSE.txt %INSTALLER_TEMP%
copy ebox-adsync.nsi %INSTALLER_TEMP%
copy passwdHk.reg %INSTALLER_TEMP%
copy Release\passwdhk.dll %INSTALLER_TEMP%
copy ebox_adsync_config\Release\ebox_adsync_config.exe %INSTALLER_TEMP%
copy setup-service.bat %INSTALLER_TEMP%
copy ebox-service-launcher.exe %INSTALLER_TEMP%
copy vcredist_x86.exe %INSTALLER_TEMP%

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
%MAKENSIS_EXE% ebox-adsync.nsi
move zentyal-adsync-*.exe ..

pause
