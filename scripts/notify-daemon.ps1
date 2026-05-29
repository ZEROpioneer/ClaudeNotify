# ClaudeNotify background daemon
# Watches trigger files and spawns notify.ps1 processes in parallel
# Start: powershell -WindowStyle Hidden -File notify-daemon.ps1

$queueDir = Join-Path $env:USERPROFILE ".claude\notify-queue"
$notifyScript = Join-Path $env:USERPROFILE ".claude\notify.ps1"

# Write PID file
$pidFile = Join-Path $env:USERPROFILE ".claude\notify-daemon.pid"
[System.IO.File]::WriteAllText($pidFile, $PID.ToString())

# Ensure queue dir exists
if (-not (Test-Path $queueDir)) {
    New-Item -ItemType Directory -Path $queueDir -Force | Out-Null
}

# Clean stale trigger files from previous run
Get-ChildItem $queueDir -Filter "*.json" -ErrorAction SilentlyContinue | Remove-Item -Force

# Reset counter file (stale values from killed processes would offset popups off-screen)
$counterFile = "$env:USERPROFILE\.claude\notify-counter.txt"
"0" | Set-Content $counterFile -Force

function Invoke-Notification($type, $projectDir, $sessionId) {
    $argList = @(
        '-NoProfile', '-WindowStyle', 'Hidden',
        '-File', $notifyScript,
        '-Type', $type,
        '-ProjectDir', $projectDir
    )
    if ($sessionId) {
        $argList += @('-SessionId', $sessionId)
    }
    Start-Process -WindowStyle Hidden -FilePath powershell -ArgumentList $argList
}

# Main loop: FileSystemWatcher + drain backlog
$watcher = [System.IO.FileSystemWatcher]::new($queueDir, "*.json")
$watcher.IncludeSubdirectories = $false

while ($true) {
    # Drain any backlog (files created while we were dispatching previous batch)
    $files = Get-ChildItem $queueDir -Filter "*.json" -ErrorAction SilentlyContinue | Sort-Object CreationTime
    if ($files) {
        foreach ($f in $files) {
            try {
                $json = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                Invoke-Notification -Type $json.type -ProjectDir $json.projectDir -SessionId $json.sessionId
            } catch {
                Add-Content "$env:USERPROFILE\.claude\notify-error.log" -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') daemon-backlog: $_"
            }
            Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    # Wait for new trigger files
    $result = $watcher.WaitForChanged("Created", 1000)
    if ($result.TimedOut) { continue }

    Start-Sleep -Milliseconds 50
    $path = Join-Path $queueDir $result.Name
    if (-not (Test-Path $path)) { continue }

    try {
        $json = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        Invoke-Notification -Type $json.type -ProjectDir $json.projectDir -SessionId $json.sessionId
    } catch {
        Add-Content "$env:USERPROFILE\.claude\notify-error.log" -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') daemon-watcher: $_"
    }

    Remove-Item $path -Force -ErrorAction SilentlyContinue
}
