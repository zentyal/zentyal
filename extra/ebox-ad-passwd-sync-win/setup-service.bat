:: BAT file for writing .ini config file for XYNTService
:: and installing the service

@echo off

set INST_PATH=%*

set INI="%INST_PATH%\ebox-service-launcher.ini"

echo [Settings] > %INI%
echo ServiceName = Zentyal Password Synchronizer >> %INI%
echo CheckProcessSeconds = 30 >> %INI%
echo [Process0] >> %INI%
echo CommandLine = %INST_PATH%\ebox-pwdsync-service.exe >> %INI%
echo WorkingDir = %INST_PATH% >> %INI%
echo PauseStart = 1000 >> %INI%
echo PauseEnd = 1000 >> %INI%
echo UserInterface = No >> %INI%
echo Restart = Yes >> %INI%
echo UserName = >> %INI%
echo Domain = >> %INI%
echo Password = >> %INI%

cd %INST_PATH%
ebox-service-launcher -i
