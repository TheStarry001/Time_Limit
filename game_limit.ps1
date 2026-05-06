<#
.SYNOPSIS
    Game bandwidth limiter — reads config.json every 60s and enforces QoS throttling.
    Edit config.json anytime; changes take effect without restarting the script.
.DESCRIPTION
    Uses Windows NetQosPolicy to throttle bandwidth by process name.
    Must run as Administrator.
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir "config.json"
$LogPath    = Join-Path $ScriptDir "limit_log.txt"

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts $Message" | Out-File -Append -FilePath $LogPath -Encoding UTF8
}

# Return the matching schedule object if current time falls within any schedule, otherwise $null
function Get-ActiveSchedule {
    param($Now, $Schedules)

    foreach ($s in $Schedules) {
        $dow = $Now.DayOfWeek
        $dayOk = switch ($s.repeat) {
            "daily"   { $true }
            "weekday" { $dow -ge 'Monday' -and $dow -le 'Friday' }
            "weekend" { $dow -eq 'Saturday' -or $dow -eq 'Sunday' }
            default   { $false }
        }
        if (-not $dayOk) { continue }

        $start = [datetime]::ParseExact($s.start, "HH:mm", $null)
        $end   = [datetime]::ParseExact($s.end, "HH:mm", $null)
        $startTime = $Now.Date.AddHours($start.Hour).AddMinutes($start.Minute)
        $endTime   = $Now.Date.AddHours($end.Hour).AddMinutes($end.Minute)

        if ($endTime -le $startTime) {
            # Overnight schedule (e.g. 23:00–01:00)
            if ($Now -ge $startTime -or $Now -lt $endTime) { return $s }
        } else {
            if ($Now -ge $startTime -and $Now -lt $endTime) { return $s }
        }
    }
    return $null
}

Write-Log "========== Game limit monitor started =========="

while ($true) {
    try {
        $config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $now = Get-Date
        $managedNames = @($config.rules | ForEach-Object { $_.name })

        foreach ($rule in $config.rules) {
            $active = Get-ActiveSchedule -Now $now -Schedules $rule.schedule
            $existing = Get-NetQosPolicy -Name $rule.name -ErrorAction SilentlyContinue

            if ($active) {
                $bps = [int64]$active.speed_kbps * 1000

                if ($existing) {
                    if ($existing.ThrottleRateActionBitsPerSecond -ne $bps) {
                        Set-NetQosPolicy -Name $rule.name -ThrottleRateActionBitsPerSecond $bps
                        Write-Log "[UPDATE] $($rule.name) throttled to $($active.speed_kbps) kbps ($($active.start)-$($active.end))"
                    }
                } else {
                    New-NetQosPolicy -Name $rule.name `
                        -AppPathNameMatchCondition $rule.exe `
                        -ThrottleRateActionBitsPerSecond $bps | Out-Null
                    Write-Log "[THROTTLE] $($rule.name) throttled to $($active.speed_kbps) kbps ($($active.start)-$($active.end))"
                }
            } else {
                if ($existing) {
                    Remove-NetQosPolicy -Name $rule.name -Confirm:$false
                    Write-Log "[UNTHROTTLE] $($rule.name) policy removed"
                }
            }
        }

        # Remove stale policies for rules no longer in config
        $allPolicies = Get-NetQosPolicy -ErrorAction SilentlyContinue
        foreach ($p in $allPolicies) {
            if ($p.Name -in $managedNames) { continue }
            if ($p.AppPathNameMatchCondition -and $p.ThrottleRateActionBitsPerSecond -gt 0) {
                Remove-NetQosPolicy -Name $p.Name -Confirm:$false
                Write-Log "[CLEANUP] stale policy removed: $($p.Name)"
            }
        }
    } catch {
        Write-Log "[ERROR] $_"
    }

    Start-Sleep -Seconds 60
}
