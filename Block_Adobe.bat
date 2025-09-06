@echo off
:: ============================
:: Full Adobe Block Script (.bat)
:: Auto-Run as Administrator
:: ============================

:: Relaunch as Admin if not already
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator access...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo === Full Adobe Cleanup & Block ===
echo.

:: 1) Stop Adobe services
sc stop "AGMService"
sc stop "AGSService"
sc stop "AdobeUpdateService"
sc stop "Adobe Genuine Monitor Service"
sc stop "Adobe Genuine Software Integrity Service"

sc config "AGMService" start= disabled
sc config "AGSService" start= disabled
sc config "AdobeUpdateService" start= disabled
sc config "Adobe Genuine Monitor Service" start= disabled
sc config "Adobe Genuine Software Integrity Service" start= disabled

:: 2) Kill Adobe processes
taskkill /F /IM "Creative Cloud.exe" /T
taskkill /F /IM "CCXProcess.exe" /T
taskkill /F /IM "Adobe Desktop Service.exe" /T
taskkill /F /IM "AdobeIPCBroker.exe" /T
taskkill /F /IM "Adobe CEF Helper.exe" /T
taskkill /F /IM "CoreSync.exe" /T

:: 3) Disable Adobe scheduled tasks
schtasks /Change /TN "\Adobe Acrobat Update Task" /Disable >nul 2>&1
schtasks /Change /TN "\AdobeGCInvoker-1.0" /Disable >nul 2>&1
schtasks /Change /TN "\AdobeAAMUpdater-1.0" /Disable >nul 2>&1

:: 4) Clear temp/cache folders
rd /s /q "%LOCALAPPDATA%\Adobe\OOBE"
rd /s /q "%LOCALAPPDATA%\Adobe\SLCache"
rd /s /q "%APPDATA%\Adobe"
rd /s /q "%PROGRAMDATA%\Adobe"
rd /s /q "%TEMP%"
md "%TEMP%"

:: 5) Add HOSTS entries to block Adobe servers
set HOSTS=%WINDIR%\System32\drivers\etc\hosts
copy "%HOSTS%" "%HOSTS%.bak_block" >nul 2>&1
(
echo 127.0.0.1 ic.adobe.io
echo 127.0.0.1 lm.licenses.adobe.com
echo 127.0.0.1 na1r.services.adobe.com
echo 127.0.0.1 genuine.adobe.com
echo 127.0.0.1 cc-api-data.adobe.io
echo 127.0.0.1 prod.adobegenuine.com
) >> "%HOSTS%"

:: 6) Firewall rules to block Adobe programs
netsh advfirewall firewall add rule name="Block Adobe 1" dir=out program="C:\Program Files\Adobe\*" action=block enable=yes
netsh advfirewall firewall add rule name="Block Adobe 2" dir=out program="C:\Program Files (x86)\Common Files\Adobe\*" action=block enable=yes

echo.
echo [DONE] Adobe processes/services blocked permanently.
echo.
pause
exit
