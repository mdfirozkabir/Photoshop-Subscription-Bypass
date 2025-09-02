
# Full Adobe Restore Script
# This script will try to restore Adobe services, hosts file, and firewall rules

# 1. Enable Adobe Services if present
$services = @(
    "AGMService",
    "AGSService",
    "AdobeUpdateService",
    "Adobe Genuine Monitor Service",
    "Adobe Genuine Software Integrity Service"
)

foreach ($svc in $services) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        Set-Service -Name $svc -StartupType Automatic
        Start-Service -Name $svc
    }
}

# 2. Remove hosts file entries (backup first)
$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$backupPath = "$hostsPath.bak_restore"
if (-not (Test-Path $backupPath)) {
    Copy-Item $hostsPath $backupPath -Force
}

(Get-Content $hostsPath) | Where-Object {$_ -notmatch "adobe"} | Set-Content $hostsPath

# 3. Remove firewall rules
$fwRules = Get-NetFirewallRule | Where-Object {$_.DisplayName -like "Block Adobe*"}
foreach ($rule in $fwRules) {
    Remove-NetFirewallRule -Name $rule.Name
}

Write-Host "Adobe services restored, hosts cleaned, firewall rules removed."
