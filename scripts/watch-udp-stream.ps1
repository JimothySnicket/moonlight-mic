# watch-udp-stream.ps1 — Watch UDP listeners during a stream attempt.
# Runs for 90 seconds, samples every 2 seconds.
# Outputs deltas — only new/disappeared listeners since last sample.
#
# No env vars — this script has no configurable parameters.

$end = (Get-Date).AddSeconds(90)
$prev = @{}

Write-Output "[start $(Get-Date -Format 'HH:mm:ss.fff')] watching UDP listeners on host"

while ((Get-Date) -lt $end) {
    $current = @{}
    $rows = & netstat -ano -p UDP 2>$null | Select-String '^\s*UDP\s+\S+'
    foreach ($row in $rows) {
        $line = $row.Line.Trim()
        $parts = $line -split '\s+'
        if ($parts.Count -ge 4) {
            $local = $parts[1]
            $pid_ = $parts[$parts.Count - 1]
            $current["$local|$pid_"] = $true
        }
    }

    # New listeners
    foreach ($k in $current.Keys) {
        if (-not $prev.ContainsKey($k)) {
            $now = Get-Date -Format 'HH:mm:ss.fff'
            Write-Output "[$now] +UDP $k"
        }
    }
    # Disappeared listeners
    foreach ($k in $prev.Keys) {
        if (-not $current.ContainsKey($k)) {
            $now = Get-Date -Format 'HH:mm:ss.fff'
            Write-Output "[$now] -UDP $k"
        }
    }

    $prev = $current
    Start-Sleep -Milliseconds 2000
}

Write-Output "[end $(Get-Date -Format 'HH:mm:ss.fff')] watch finished"
