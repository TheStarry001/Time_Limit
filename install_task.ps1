<#
.SYNOPSIS
    Registers a scheduled task to run game_limit.ps1 at system startup as Administrator.
    Must run as Administrator.
#>

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetFile = Join-Path $ScriptDir "game_limit.ps1"
$TaskName   = "GameLimitMonitor"

# Remove existing task if present
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed old task: $TaskName"
}

# Create scheduled task: run at startup as SYSTEM
$Action  = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -File `"$TargetFile`""

$Trigger = New-ScheduledTaskTrigger -AtStartup

$Principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartOnIdle:$false `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Force | Out-Null

Write-Host "Task '$TaskName' registered successfully. Runs at system startup."
Write-Host "Target script: $TargetFile"
