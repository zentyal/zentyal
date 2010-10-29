cd res
"c:\Archivos de programa\NSIS\makensis.exe" config.nsi
"c:\Archivos de programa\NSIS\makensis.exe" install.nsi
move Config.exe ../bin/
move Install.exe ../bin/
cd ..
