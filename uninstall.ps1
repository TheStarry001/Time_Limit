<#
.SYNOPSIS
    Removes all QoS throttle policies and deletes the scheduled task.
    Must run as Administrator.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "config.json"
$TaskName   = "GameLimitMonitor"

# 1. Remove QoS policies declared in config.json
Write-Host "Removing QoS throttle policies..."
if (Test-Path $ConfigPath) {
    $config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($rule in $config.rules) {
        $existing = Get-NetQosPolicy -Name $rule.name -ErrorAction SilentlyContinue
        if ($existing) {
            Remove-NetQosPolicy -Name $rule.name -Confirm:$false
            Write-Host "  Removed: $($rule.name)"
        } else {
            Write-Host "  Skipped (not found): $($rule.name)"
        }
    }
}

# Extra cleanup: remove any remaining app-path throttle policies
$allPolicies = Get-NetQosPolicy -ErrorAction SilentlyContinue
foreach ($p in $allPolicies) {
    if ($p.AppPathNameMatchCondition -and $p.ThrottleRateActionBitsPerSecond -gt 0) {
        Remove-NetQosPolicy -Name $p.Name -Confirm:$false
        Write-Host "  Cleaned up stale policy: $($p.Name)"
    }
}

# 2. Delete scheduled task
Write-Host "Removing scheduled task..."
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "  Deleted task: $TaskName"
} else {
    Write-Host "  Task not found: $TaskName"
}

Write-Host "Uninstall complete."
