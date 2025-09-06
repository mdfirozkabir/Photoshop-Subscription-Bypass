@echo off
:: ============================
:: Full Adobe Unblock Script (.bat)
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
echo === Restoring Adobe Services ===
echo.

:: 1) Enable services back
sc config "AGMService" start= auto
sc config "AGSService" start= auto
sc config "AdobeUpdateService" start= auto
sc config "Adobe Genuine Monitor Service" start= auto
sc config "Adobe Genuine Software Integrity Service" start= auto

net start "AGMService"
net start "AGSService"
net start "AdobeUpdateService"
net start "Adobe Genuine Monitor Service"
net start "Adobe Genuine Software Integrity Service"

:: 2) Restore HOSTS file from backup
set HOSTS=%WINDIR%\System32\drivers\etc\hosts
if exist "%HOSTS%.bak_block" (
    copy /Y "%HOSTS%.bak_block" "%HOSTS%"
    echo Hosts file restored.
)

:: 3) Remove firewall rules
netsh advfirewall firewall delete rule name="Block Adobe 1"
netsh advfirewall firewall delete rule name="Block Adobe 2"

echo.
echo [DONE] Adobe services and connections restored.
echo.
pause
exit
