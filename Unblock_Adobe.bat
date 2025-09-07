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

:: 1) Enable and start Adobe Services
sc config "AGMService" start= auto
sc start "AGMService"
sc config "AGSService" start= auto
sc start "AGSService"
sc config "AdobeUpdateService" start= auto
sc start "AdobeUpdateService"
sc config "Adobe Genuine Monitor Service" start= auto
sc start "Adobe Genuine Monitor Service"
sc config "Adobe Genuine Software Integrity Service" start= auto
sc start "Adobe Genuine Software Integrity Service"

:: 2) Restore HOSTS file from backup
set HOSTS=%WINDIR%\System32\drivers\etc\hosts
if exist "%HOSTS%.bak_block" (
    copy /Y "%HOSTS%.bak_block" "%HOSTS%"
    echo Hosts file restored from backup.
) else (
    echo No backup found. Hosts file unchanged.
)

:: 3) Remove firewall rules (if exist)
netsh advfirewall firewall delete rule name="Block Adobe 1" >nul 2>&1
netsh advfirewall firewall delete rule name="Block Adobe 2" >nul 2>&1

echo.
echo [DONE] Adobe services and connections restored successfully.
echo.
pause
exit
