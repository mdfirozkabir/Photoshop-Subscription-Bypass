<#
.SYNOPSIS
  All-in-one Adobe Cleanup & Blocker (FULL).
  - Creates a restore point
  - Stops Adobe-related background processes
  - Attempts uninstall via winget (if available)
  - Disables common Adobe services & scheduled tasks
  - Cleans TEMP folders
  - Updates hosts to block Adobe servers
  - Creates firewall rules to block Adobe executables (outbound)
USAGE: Run as Administrator in an elevated PowerShell window.
       Right-click the file -> Run with PowerShell (Admin) OR
       Open PowerShell (Admin) and run: & 'C:\path\to\Full_Adobe_Block.ps1'
WARNING: Blocking Adobe servers may break licensing, updates, or violate Adobe's Terms.
         Use at your own risk. Create a full system backup first.
#>

#region Helpers
function Assert-Admin {
  $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Please run PowerShell as Administrator." -ForegroundColor Yellow
    exit 1
  }
}
function Try-Run($ScriptBlock, $What) {
  try {
    & $ScriptBlock
    Write-Host "[OK] $What"
  } catch {
    Write-Host "[SKIP] $What : $($_.Exception.Message)" -ForegroundColor DarkYellow
  }
}
#endregion

Assert-Admin
Write-Host "`n=== Full Adobe Cleanup & Blocker ===`n" -ForegroundColor Cyan

# 1) Create a System Restore Point (if enabled)
Try-Run { Checkpoint-Computer -Description "Pre-Full-Adobe-Block" -RestorePointType "MODIFY_SETTINGS" } "Created system restore point (if supported)"

# 2) Stop common Adobe processes (non-destructive)
$procNames = @(
  "Creative Cloud",
  "Adobe Desktop Service",
  "CCXProcess",
  "AGMService",
  "AGSService",
  "AdobeIPCBroker",
  "Adobe CEF Helper",
  "AdobeNotificationClient",
  "AdobeCrashDaemon",
  "AdobeUpdateService",
  "CoreSync"
)
$running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $procNames -contains $_.ProcessName }
foreach ($p in $running) {
  Try-Run { Stop-Process -Id $p.Id -Force } "Stopped process: $($p.ProcessName)"
}

# 3) Stop & set common Adobe services to Disabled
$serviceNames = @("Adobe Genuine Software Integrity Service","Adobe Genuine Monitor Service","AdobeUpdateService","AGMService","AGSService","CoreSyncService")
foreach ($s in $serviceNames) {
  $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
  if ($svc) {
    Try-Run { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue } "Stopped service: $s"
    Try-Run { Set-Service -Name $s -StartupType Disabled } "Disabled service startup: $s"
  }
}

# 4) Uninstall via winget (if available)
$targets = @("Adobe Creative Cloud","Adobe Genuine Service","Adobe Photoshop")
$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
  foreach ($name in $targets) {
    Try-Run { $null = winget list --name $name } "Checked presence for $name"
    $found = winget list --name $name | Select-String $name -SimpleMatch -ErrorAction SilentlyContinue
    if ($found) {
      Write-Host "Attempting to uninstall: $name"
      Try-Run { winget uninstall --name $name --silent --accept-source-agreements --accept-package-agreements } "Uninstalled (winget) $name"
    } else {
      Write-Host "Not found via winget: $name"
    }
  }
} else {
  Write-Host "[i] winget not found. Uninstall manually via Settings > Apps > Installed apps." -ForegroundColor Yellow
}

# 5) Disable common Adobe scheduled tasks (if present)
$taskNames = @("\Adobe Acrobat Update Task","\AdobeGCInvoker-1.0","\AdobeAAMUpdater-1.0")
foreach ($t in $taskNames) {
  $query = schtasks /Query /TN $t /FO LIST 2>$null
  if ($LASTEXITCODE -eq 0) {
    Try-Run { schtasks /Change /TN $t /Disable | Out-Null } "Disabled scheduled task: $t"
  }
}

# 6) Remove common Adobe folders (cache/temp)
$pathsToClean = @(
  "$env:LOCALAPPDATA\Adobe\OOBE\*",
  "$env:LOCALAPPDATA\Adobe\SLCache\*",
  "$env:APPDATA\Adobe\*",
  "$env:PROGRAMDATA\Adobe\*",
  "$env:TEMP\*",
  "$env:WINDIR\Temp\*"
)
foreach ($p in $pathsToClean) {
  Try-Run { Remove-Item -Path $p -Recurse -Force -ErrorAction Stop } "Cleared: $p"
}

# 7) Startup entries information
try {
  $startup = Get-CimInstance Win32_StartupCommand | Where-Object { $_.Caption -match "Adobe|Creative Cloud|CCX|CoreSync" }
  if ($startup) {
    Write-Host "`n[i] Found startup entries:"
    $startup | ForEach-Object { Write-Host " - $($_.Caption) [$($_.Command)]" }
    Write-Host "`nPlease review Task Manager -> Startup and disable the Adobe entries shown above." -ForegroundColor Yellow
  } else {
    Write-Host "No Adobe startup entries found."
  }
} catch {
  Write-Host "[SKIP] Enumerating startup entries: $($_.Exception.Message)" -ForegroundColor DarkYellow
}

# 8) Modify hosts file to block Adobe servers
$hostsPath = "$env:WINDIR\System32\Drivers\etc\hosts"
$adobeHosts = @(
  "127.0.0.1 ic.adobe.io",
  "127.0.0.1 lm.licenses.adobe.com",
  "127.0.0.1 na1r.services.adobe.com",
  "127.0.0.1 genuine.adobe.com",
  "127.0.0.1 cc-api-data.adobe.io",
  "127.0.0.1 prod.adobegenuine.com"
)
Try-Run { 
  $backup = "$hostsPath.adobe_backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
  Copy-Item -Path $hostsPath -Destination $backup -Force
  foreach ($line in $adobeHosts) { Add-Content -Path $hostsPath -Value $line }
} "Added Adobe hosts entries (backup created)"
Write-Host "[i] Hosts updated. Backup at: $backup" -ForegroundColor Yellow

# 9) Firewall rules to block Adobe executables/outbound
$adobePaths = @(
  "C:\Program Files\Common Files\Adobe\OOBE\PDApp\*",
  "C:\Program Files (x86)\Common Files\Adobe\*",
  "C:\Program Files\Adobe\*"
)
foreach ($ap in $adobePaths) {
  Try-Run { New-NetFirewallRule -DisplayName "Block Adobe Outbound $ap" -Direction Outbound -Program $ap -Action Block -Profile Any -ErrorAction SilentlyContinue } "Created firewall rule for: $ap"
}

Write-Host "`n[Done] Full cleanup & block finished. Creative Cloud popups and connections should be blocked." -ForegroundColor Green
