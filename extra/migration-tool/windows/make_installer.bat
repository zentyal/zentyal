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
Set PYTHON_PATH="C:\Python26"
Set PYTHON_EXE="%PYTHON_PATH%\python.exe"

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

Set GTK_RUNTIME="lib\site-packages\gtk-2.0\runtime"
Set GTK_ENGINES="lib\gtk-2.0\2.10.0\engines"
Set WIN_THEME="share\themes\MS-Windows"
Set ICON_THEME="share\icons\hicolor"
Set GTKRC_PATH="dist\etc\gtk-2.0"
Set PYWIN32="lib\site-packages\pywin32_system32"

md dist\share\themes
xcopy /S /I %PYTHON_PATH%\%GTK_RUNTIME%\%WIN_THEME% dist\%WIN_THEME%
md dist\%ICON_THEME%
copy %PYTHON_PATH%\%GTK_RUNTIME%\%ICON_THEME%\*.* dist\%ICON_THEME%\
md dist\%GTK_ENGINES%
copy %PYTHON_PATH%\%GTK_RUNTIME%\%GTK_ENGINES%\libwimp.dll dist\%GTK_ENGINES%\
:: copy %PYTHON_PATH%\%PYWIN32%\pywintypes26.dll dist\
md %GTKRC_PATH%
echo gtk-theme-name = "MS-Windows" > %GTKRC_PATH%\gtkrc

:: Generate .exe from python
if exist %PYTHON_EXE% goto path
python setup.py py2exe
xcopy /S dist\*.* %INSTALLER_TEMP%
goto end
:path
%PYTHON_EXE% setup.py py2exe
xcopy /S dist\*.* %INSTALLER_TEMP%
:end

cd %INSTALLER_TEMP%
%MAKENSIS_EXE% installer.nsi
move zentyal-migration-tool-*.exe ..

pause
