cls
@echo off
setlocal enabledelayedexpansion
color 0A

set Hinweis=Bitte lesen Sie unbedingt die Anleitungen zu diesem Skript, siehe ct.de/wimage.

rem --------- Optional: An die eigenen Verhaeltnisse anpassen -----------

rem Wenn das Skript Windows nach Abschluss der Sicherung herunterfahren soll,
rem setzen Sie die Variable der Variable "shutdown" von 0 auf 1.

set Shutdown=0

rem Pfad zum Ordner für das Skript selbst, vshadow.exe und das 
rem Reset-Image setzen, etwa d:\resetimage\
rem Ohne Anpassung verwendet das Skript den Ordner, in dem es liegt.
rem Keine Leerzeichen im Pfad! Mit abschließendem "\"!

set workdir=%~d0%~p0

rem --------- Optional: Zusätzliche Anpassungen nur für Windows 8.1 -----------

rem Dieses Skript kann das zuletzt erstellte Image als Wiederherstellungs-Image 
rem festlegen. Es wird dann wiederhergestellt, wenn Sie in den PC-Einstellungen
rem unter Update/Wiederherstellung den Punkt "Alles entfernen und Windows neu
rem installieren" auswählen. Wenn Sie das wollen, ändern Sie den Wert der Variable 
rem "Reset" von 0 auf 1.
rem DIESE OPTION FUNKTIONIERT NUR UNTER WINDOWS 8.1!

set Reset=0

rem Dieses Skript kann das zuletzt erstellte Image als Auffrischungs-Image 
rem festlegen. Es wird dann wiederhergestellt, wenn Sie in den PC-Einstellungen
rem unter Update/Wiederherstellung den Punkt "PC ohne Auswirkungen auf die Dateien
rem auffrischen" auswählen. Wenn Sie das wollen, ändern Sie den Wert der Variable 
rem "Refresh" von 0 auf 1. ACHTUNG: Es wird dann ein weiteres Image erzeugt, das 
rem Aktivieren dieser Option kostet also zusätzlichen Platz auf dem Zielmedium!
rem DIESE OPTION FUNKTIONIERT NUR UNTER WINDOWS 8.1!

set Refresh=0

rem Dieses Skript wird an verschiedenen Stellen von pause-Statements unterbrochen. 
rem Dies dient der Übersicht und ist notwendig für die interaktion mit dem Anwender.
rem Gleichzeitig stören diese Statements, wenn das Skript als Task aus der Aufgaben-
rem planung aufgerufen wird - das Skript wird dann einfach nicht beendetr.

set task=0

rem Wenn das Skript als Taks läuft, dann will man trotzdem wissen welche Fehler ggf. 
rem auftreten. Dann sollte das logging in eine Datei aktiviert sein. Standardmäßig
rem wird die ausgabe bei aktiviertem Logging in ct-WIMage-x64.log neben die .bat 
rem geschrieben.

set logging=1
if %logging%==1 (
  set logdir=%workdir%
  set log=%logdir%ct-WIMage.log
  echo Logfile=%log%
)

rem ---------------- Optik anpassen --------------

cls
color 0F
set farbtmp=
for /f "tokens=3" %%b in ('reg query ^"HKLM^\Software^\Microsoft^\Windows NT^\CurrentVersion^" /v ^"ReleaseID^" 2^>nul') do set farbtmp=%%b >nul 2>nul
if "%farbtmp%."=="." goto start

set ESC=
set weiss=%esc%[97m
set gruen=%esc%[92m
set rot=%esc%[91m
set gelb=%esc%[93m

rem ------------- Ende der Anpassungen -----------

:start

echo.%gelb%
echo ************************************
echo *** Willkommen bei c't-wimage v3 ***
echo ************************************
echo.
echo %hinweis%%weiss%
echo.
if %logging%==1 (
echo %date%-%time% Start logging into logfile %log%
echo %date%-%time% Start c't-wimage >> %log%
)

set description=
set operation=*** Befehlszeilen-Argumente pruefen ***
:parseargs
if "%1"=="" goto endargs
rem hilfe erwuenscht?
if /i "%1"=="/?" goto hilfe
if /i "%1"=="-?" goto hilfe
if /i "%1"=="/h" goto hilfe
if /i "%1"=="-h" goto hilfe
if /i "%1"=="--h" goto hilfe
if /i "%1"=="/help" goto hilfe
if /i "%1"=="-help" goto hilfe
if /i "%1"=="--help" goto hilfe
rem Beschreibung für das Image gewünscht?
set option=0
if /i "%1"=="/d" set option=1
if /i "%1"=="-d" set option=1
if %option%==1 (
  set description="%~2"
  shift /1
  shift /1
  goto parseargs
)
rem Image als Wiederherstellungs-Image festlegen?
if /i "%1"=="/reset" set option=1
if /i "%1"=="-reset" set option=1
if %option%==1 (
  set Reset=1
  shift /1
  goto parseargs
)
rem Image als Auffrischungs-Image festlegen?
if /i "%1"=="/refresh" set option=1
if /i "%1"=="-refresh" set option=1
if %option%==1 (
  set Refresh=1
  shift /1
  goto parseargs
)
rem Nach dem Sichern herunterfahren?
if /i "%1"=="/s" set option=1
if /i "%1"=="-s" set option=1
if /i "%1"=="/shutdown" set option=1
if /i "%1"=="-shutdown" set option=1
if %option%==1 (
  set Shutdown=1
  shift /1
  goto parseargs
)
rem Läuft in task
if /i "%1"=="/t" set option=1
if /i "%1"=="-t" set option=1
if /i "%1"=="/task" set option=1
if /i "%1"=="-task" set option=1
if %option%==1 (
  set task=1
  shift /1
  goto parseargs
)
rem Logging gewünscht?
set option=0
if /i "%1"=="/l" set option=1
if /i "%1"=="-l" set option=1
if /i "%1"=="/log" set option=1
if /i "%1"=="-log" set option=1
if %option%==1 (
  set logging=1 
  set log=%~d0%~p0%~2
  rem dir/file check missing
  echo %log%
  shift /1
  shift /1
  goto parseargs
)
color %rot%
echo *** Unbekanntes Befehlszeilen-Argument: %1 ***
echo.
goto hilfe
:endargs

echo %weiss%*** Einige Pruefungen vorab ... ***%gruen%
echo.

set operation=*** Skript braucht mindestens Windows 8.1 ***
for /f "tokens=3" %%a in ('reg query ^"HKLM^\SOFTWARE^\Microsoft^\Windows NT^\CurrentVersion^" /v ^"currentversion^"') do set version=%%a
if %version% lss 6.3 goto fehler1

set operation=*** Reset und Refresh ab Windows 10 deaktivieren ***
for /f "tokens=4" %%a in ('reg query ^"HKLM^\SOFTWARE^\Microsoft^\Windows NT^\CurrentVersion^" /v ^"ProductName^"') do set version=%%a
if errorlevel 1 goto fehler1
if not "%version%" == "8.1" (
  set Reset=0
  set Refresh=0
)

set operation=*** Dieses Skript ist nur fuer 64-Bit-Windows ***
if not exist "%ProgramFiles(x86)%" goto fehler1

set operation=*** Skript muss mit Administratorrechten laufen ***
whoami /groups | find "S-1-16-12288" > nul
if errorlevel 1 goto fehler1

set operation=*** Arbeitsverzeichnis darf nicht auf dem Windows-Laufwerk liegen ***
if /i %workdir:~0,2% equ %systemdrive% goto fehler1

set operation=*** vshadow.exe muss im Sources-Unterordner liegen ***
set vshadow=sources\vshadowx64.exe
if not exist %workdir%%vshadow% goto fehler1

set operation=*** Bei Bedarf übrig gebliebene Schattenkopie löschen ***
call %workdir%sources\vshadowtemp.cmd >nul 2>nul
if "%SHADOW_ID_1%." neq "." %workdir%%vshadow% -ds=%SHADOW_ID_1% >nul 2>nul
type nul

set operation=*** Im Arbeitsverzeichnis muss ein Ordner "Sources" liegen ***
if not exist %workdir%sources goto fehler1

set operation=*** In der Install.wim sollen nicht mehr als 1000 Images enthalten sein ***
set action=append-image 
if not exist %workdir%sources\install.wim (
  set action=capture-image /compress:max
) else (
  set letztenummer=1
  for /f "tokens=1,2* delims=: " %%L in ('%windir%\system32\dism /get-wiminfo /wimfile:%workdir%sources\install.wim') do (
    if "%%L"=="Index" set /a letztenummer=%%M
  )
  if !letztenummer! gtr 1000 goto fehler1
)

set operation=*** Sofern vorhanden: ct-WIMage.ini verwenden ***
if exist %workdir%sources\ct-WIMage.ini set action=%action% /ConfigFile:%workdir%sources\ct-WIMage.ini
if errorlevel 1 goto fehler2

set operation=*** Ab Windows 10 1607 Dism-Option /EA verwenden ***
for /f "tokens=3" %%a in ('reg query ^"HKLM^\SOFTWARE^\Microsoft^\Windows NT^\CurrentVersion^" /v ^"CurrentBuild^" 2^>nul') do set /a build=%%a
if %build% geq 14393 set action=%action% /EA
if errorlevel 1 goto fehler2

set operation=*** c't-WIMage funktioniert nicht, wenn eine WSL-1-Distribution installiert ist ***
for /f "usebackq tokens=3" %%a in (`reg query HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss /s 2^>nul ^| findstr /i "flags" 2^>nul`) do if "%%a"=="0x7" set wsl=1 >nul 2>nul
if "%wsl%."=="1." goto fehler2

echo %weiss%*** Keine Probleme gefunden, jetzt geht es los ***%gruen%
echo.

echo %weiss%*** Vorbereitungen ... ***%gruen%
set operation=*** RunOnce-Schluessel hinzufuegen zum Restaurieren von WinRE nach Wiederherstellung ***
reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce /f /v "enablewinre" /d "reagentc /enable" >nul 2>nul
if errorlevel 1 goto fehler2

set operation=*** Windows RE auf Windows-Partition verschieben ***
reagentc /disable >nul 2>nul
if errorlevel 1 goto fehler2

set operation=*** Freien Laufwerksbuchstaben fuer Schattenkopie suchen ***
echo.
echo %weiss%%operation%%gruen%
echo.
for %%l in (P Q R S T U V W X Y Z D E F G H I J K L M N O) do (  
  set sklw=%%l
  mountvol %%l: /L >nul
  if errorlevel 1 (
    subst | findstr /B "%%l:" >nul
    if errorlevel 1 (
      net use %%l: >nul 2>&1
      if errorlevel 1 goto weiter
    )
  )
)
goto fehler2
:weiter
echo.
echo Verwende %sklw%:

echo.
set operation=*** Schattenkopie der Windows-Partition erzeugen ***
echo.
echo %weiss%%operation%%gruen%
%workdir%%vshadow% -p -script=%workdir%sources\vshadowtemp.cmd %systemdrive% >nul 2>nul
if errorlevel 1 goto fehler2
call %workdir%sources\vshadowtemp.cmd >nul 2>nul
if errorlevel 1 goto fehler2
%workdir%%vshadow% -el=%SHADOW_ID_1%,%sklw%:
if errorlevel 1 goto fehler2

echo.
echo.
set operation=*** Image erstellen/anhaengen ***
echo %weiss%%operation%%gruen%

for /f "tokens=3" %%a in ('dir %systemdrive% /-c ^| findstr /i "Verzeichnis(se)"') do set frei=%%a
set frei=%frei:~0,-9%
if "%frei%."=="." set frei=0
if /i %frei% geq 20 (set scratchdir=) else (set scratchdir=/scratchdir:%workdir%)

echo.%weiss%
echo Es kann ziemlich lange dauern, bis die Fortschrittsanzeige erscheint.
echo Nach Erreichen der 100 Prozent kann es wieder dauern, bis es weiter geht.
echo.%gruen% 
for /f "tokens=4 delims=] " %%i in ('ver') do set wos=%%i
for /f "tokens=3,4,5" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "ProductName" 2^>nul') do set edition=%%a %%b %%c
for /f "tokens=2 delims==" %%G in ('wmic os get localdatetime /value') do set datetime=%%G
if %description%.==. set description="%datetime:~6,2%.%datetime:~4,2%.%datetime:~0,4% %datetime:~8,2%:%datetime:~10,2% %edition% Build %wos% auf %computername%"
%windir%\system32\dism /%action% /imagefile:%workdir%sources\install.wim /capturedir:%sklw%: /name:"%date% %time:~0,5% %computername% %edition%" /description:%description% /checkintegrity /verify %scratchdir%
if errorlevel 1 goto fehler2

echo.
set operation=*** Schattenkopie wieder entfernen ***
echo.
echo %weiss%%operation%%gruen%
%workdir%%vshadow% -ds=%SHADOW_ID_1%
if errorlevel 1 goto fehler2

set operation=*** Windows das frische Image bekanntmachen ***
if not "%reset%" equ "1" goto next1
echo.
echo.
echo %weiss%%operation%%gruen%
set lastindex=0
for /f "tokens=*" %%L in ('%windir%\system32\dism /get-wiminfo /wimfile:%workdir%sources\install.wim ^| find "Index"') do (
  set counter=%%L
  set lastindex=!counter:~8,-1!
)
if %lastindex% equ 0 goto fehler2
reagentc /setosimage /path %workdir%sources\install.wim /index %lastindex%
if errorlevel 1 goto fehler2
:next1

set operation=*** Backup-Liste erzeugen ***
%windir%\system32\dism /english /get-wiminfo /wimfile:%workdir%sources\install.wim > %workdir%Backupliste.txt
if errorlevel 1 goto fehler2

echo.
echo %weiss%*** Aufraeumen ***%gruen%
set operation=*** Windows RE wieder an alte Stelle zurückverschieben ***
reagentc /enable >nul 2>nul
if errorlevel 1 goto fehler2

set operation=*** RunOnce-Schluessel wieder loeschen ***
reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce /v "enablewinre" /f >nul 2>nul

set operation=*** Und nun doch das Refresh-Image erzeugen ***
if not "%refresh%" equ "1" goto next2
echo. 
echo.
echo %weiss%%operation%%gruen%
recimg /createimage %workdir%sources
if errorlevel 1 goto fehler2
:next2

echo.
echo.
echo %weiss%*** Fertig! ***%gruen%
if %logging%==1 (
echo %date%-%time% Finished script >> %log%
)
if "%shutdown%" equ "1" shutdown -s -t 0
echo.
if %task%==0 (
pause
) else (
exit
)
goto :eof

rem Bedingung nicht erfüllt
:fehler1
set text=Folgende Bedingung wurde nicht erfuellt: 
goto Fehlerausgabe

rem Fehler bei der Durchfuehrung
:fehler2
set text=Operation fehlgeschlagen:
goto Fehlerausgabe

:fehlerausgabe
if "%farbtmp%."=="." color 0C
echo. %rot%
echo %text%
echo.
echo %rot%%operation%%gruen%
if %logging%==1 (
echo %date%-%time% %operation% >> %log%
)
echo.
echo %weiss%%hinweis%%gruen%
echo.
echo Raeume hinter mir auf...
reagentc /enable >nul 2>nul
reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce /v "enablewinre" /f >nul 2>nul
%workdir%%vshadow% -ds=%SHADOW_ID_1% >nul 2>nul
echo Aufraeumen fertig.
if %task%==0 (
pause
) else (
exit
)
goto :eof

rem Abbruch durch Benutzer
:abbruch
echo %weiss%Abbruch durch Benutzer%gruen%
if %task%==0 (
pause
) else (
exit
)
goto :eof

:hilfe
echo.
echo %~nx0 ergaenzt die Datei Install.wim durch ein weiteres Image. 
echo Fehlt die Datei, wird eine neue erzeugt.
echo.
echo %~nx0 versteht folgende Befehlszeilen-Argumente:
echo   /D "Beschreibung" - "Beschreibung" als Beschreibung der Sicherung speichern
echo   /Reset            - Das neue Image als Wiederherstellungs-Image festlegen
echo   /Refresh          - Das neue Image als Auffrischungs-Image festlegen
echo   /S                - Windows nach Abschluss der Sicherung herunterfahren
echo   /Shutdown         - Windows nach Abschluss der Sicherung herunterfahren
echo   /T                - Skript als Task ohne User Interaktion ausführen
echo   /Task             - Skript als Task ohne User Interaktion ausführen
echo.
echo %~nx0 muss mit Administratorrechten gestartet werden!
echo.
echo %weiss%%Hinweis%%gruen%
echo.
if %task%==0 (
pause
) else (
exit
)
goto :eof
;
REM Erstellt 2014-2021 von Axel Vahldiek/c't
REM mailto: axv@ct.de

REM Danke an die Nutzer tdklaus, fredo61 und Benini aus dem c't-Forum für ihre Ideen, 
REM die hier ins Skript miteingeflossen sind, sowie an alle anderen, die hier
REM mitgeholfen haben!