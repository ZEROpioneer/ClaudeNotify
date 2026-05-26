# ClaudeNotify background daemon
# Start: powershell -WindowStyle Hidden -File notify-daemon.ps1

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll", EntryPoint="GetWindowLongPtr")]
    public static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll", EntryPoint="SetWindowLongPtr")]
    public static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
    public const int GWL_EXSTYLE = -20;
    public const long WS_EX_NOACTIVATE = 0x08000000;
    public const long WS_EX_TOPMOST = 0x00000008;
}
"@

function Get-ColorFromName($name) {
    if ([string]::IsNullOrEmpty($name)) { return "#FF888888" }
    $hash = 0
    foreach ($c in $name.ToCharArray()) { $hash = ($hash * 31 + [int]$c) -band 0x7FFFFFFF }
    $hue = $hash % 360
    $r,$g,$b = 0,0,0
    $s = 0.65; $v = 0.85
    $hi = [Math]::Floor($hue / 60.0) % 6
    $f = $hue / 60.0 - [Math]::Floor($hue / 60.0)
    $p = $v * (1 - $s)
    $q = $v * (1 - $f * $s)
    $t = $v * (1 - (1 - $f) * $s)
    switch ($hi) {
        0 { $r=$v; $g=$t; $b=$p }
        1 { $r=$q; $g=$v; $b=$p }
        2 { $r=$p; $g=$v; $b=$t }
        3 { $r=$p; $g=$q; $b=$v }
        4 { $r=$t; $g=$p; $b=$v }
        5 { $r=$v; $g=$p; $b=$q }
    }
    return "#FF{0:X2}{1:X2}{2:X2}" -f [int]($r*255), [int]($g*255), [int]($b*255)
}

function Show-Notification {
    param($Type, $ProjectDir, $SessionId)

    $sessionName = ""
    if ($ProjectDir -and $SessionId) {
        $namesFile = Join-Path $ProjectDir ".claude\session-names.json"
        if (Test-Path $namesFile) {
            try {
                $json = Get-Content $namesFile -Raw -Encoding UTF8 | ConvertFrom-Json
                $val = $json.$SessionId
                if ($val) { $sessionName = $val }
            } catch { $null = $_ }
        }
    }

    if ($Type -eq "permission") {
        $title = "Claude Code"
        $message = "Permission required - choose Yes or No"
        $iconChar = [char]0x003F
        $startColor = "#FFf59e0b"
        $endColor = "#FFef4444"
        $soundPath = "$env:SystemRoot\Media\Windows Notify.wav"
        $durationSec = 8
    } elseif ($Type -eq "notification") {
        $title = "Claude Code"
        $message = "Waiting for your input"
        $iconChar = [char]0x276F
        $startColor = "#FF8b5cf6"
        $endColor = "#FF3b82f6"
        $soundPath = "$env:SystemRoot\Media\Windows Ding.wav"
        $durationSec = 6
    } else {
        $title = "Claude Code"
        $message = "Task completed"
        $iconChar = [char]0x2713
        $startColor = "#FF10b981"
        $endColor = "#FF3b82f6"
        $soundPath = "$env:SystemRoot\Media\Windows Ding.wav"
        $durationSec = 5
    }

    $subtitle = if ($sessionName) { $sessionName } else { "" }
    $nameColor = Get-ColorFromName $sessionName

    $workArea = [System.Windows.SystemParameters]::WorkArea
    $windowWidth = 320
    $windowHeight = if ($subtitle) { 105 } else { 90 }
    $margin = 20
    $left = $workArea.Right - $windowWidth - $margin
    $top = $workArea.Bottom - $windowHeight - $margin

    # Outer border (gradient)
    $outerBorder = New-Object System.Windows.Controls.Border
    $outerBorder.CornerRadius = New-Object System.Windows.CornerRadius(6)
    $outerBorder.BorderThickness = New-Object System.Windows.Thickness(1.8)
    $outerBorder.Width = $windowWidth
    $outerBorder.Height = $windowHeight

    $gradient = New-Object System.Windows.Media.LinearGradientBrush
    $gradient.StartPoint = New-Object System.Windows.Point(0, 0)
    $gradient.EndPoint = New-Object System.Windows.Point(1, 1)
    $gradient.GradientStops.Add((New-Object System.Windows.Media.GradientStop(
        [System.Windows.Media.ColorConverter]::ConvertFromString($startColor), 0)))
    $gradient.GradientStops.Add((New-Object System.Windows.Media.GradientStop(
        [System.Windows.Media.ColorConverter]::ConvertFromString($endColor), 1)))
    $outerBorder.BorderBrush = $gradient

    # Inner border (dark background)
    $innerBorder = New-Object System.Windows.Controls.Border
    $innerBorder.CornerRadius = New-Object System.Windows.CornerRadius(4)
    $innerBorder.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E80a0a0f")

    $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
    $shadow.BlurRadius = 8; $shadow.ShadowDepth = 0
    $shadow.Color = [System.Windows.Media.Colors]::Black; $shadow.Opacity = 0.5
    $innerBorder.Effect = $shadow

    # Main grid
    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Object System.Windows.Thickness(16, 12, 16, 12)

    $col1 = New-Object System.Windows.Controls.ColumnDefinition
    $col1.Width = "Auto"
    $col2 = New-Object System.Windows.Controls.ColumnDefinition
    $col2.Width = "*"
    $grid.ColumnDefinitions.Add($col1)
    $grid.ColumnDefinitions.Add($col2)

    # Icon circle
    $iconBorder = New-Object System.Windows.Controls.Border
    $iconBorder.Width = 36; $iconBorder.Height = 36
    $iconBorder.CornerRadius = New-Object System.Windows.CornerRadius(18)
    $iconBorder.Margin = New-Object System.Windows.Thickness(0, 0, 12, 0)
    $iconBorder.Background = "#FF151525"
    $iconBorder.BorderBrush = $nameColor
    $iconBorder.BorderThickness = New-Object System.Windows.Thickness(1)
    $iconBorder.Opacity = 0.7

    $iconText = New-Object System.Windows.Controls.TextBlock
    $iconText.Text = $iconChar
    $iconText.FontSize = 18
    $iconText.Foreground = $nameColor
    $iconText.HorizontalAlignment = "Center"
    $iconText.VerticalAlignment = "Center"
    $iconText.FontFamily = "Segoe UI"
    $iconBorder.Child = $iconText

    [System.Windows.Controls.Grid]::SetColumn($iconBorder, 0)
    $grid.Children.Add($iconBorder)

    # Text stack
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.VerticalAlignment = "Center"

    $titleText = New-Object System.Windows.Controls.TextBlock
    $titleText.Text = $title
    $titleText.FontSize = 11
    $titleText.FontWeight = "SemiBold"
    $titleText.Foreground = "#FF7777aa"
    $titleText.FontFamily = "Segoe UI"
    $titleText.Margin = New-Object System.Windows.Thickness(0, 0, 0, 2)
    $stack.Children.Add($titleText)

    if ($subtitle) {
        $subText = New-Object System.Windows.Controls.TextBlock
        $subText.Text = $subtitle
        $subText.FontSize = 10
        $subText.Foreground = $nameColor
        $subText.FontFamily = "Microsoft YaHei"
        $subText.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)
        $stack.Children.Add($subText)
    }

    $msgText = New-Object System.Windows.Controls.TextBlock
    $msgText.Text = $message
    $msgText.FontSize = 13
    $msgText.Foreground = "#FFd0d0f0"
    $msgText.FontFamily = "Microsoft YaHei"
    $msgText.TextWrapping = "Wrap"
    $stack.Children.Add($msgText)

    [System.Windows.Controls.Grid]::SetColumn($stack, 1)
    $grid.Children.Add($stack)

    $innerBorder.Child = $grid
    $outerBorder.Child = $innerBorder

    # Window
    $dummyGrid = New-Object System.Windows.Controls.Grid
    $dummyGrid.Children.Add($outerBorder)

    $window = New-Object System.Windows.Window
    $window.Content = $dummyGrid
    $window.Width = $windowWidth
    $window.Height = $windowHeight
    $window.Left = $left
    $window.Top = $top
    $window.WindowStyle = "None"
    $window.AllowsTransparency = $true
    $window.Background = "Transparent"
    $window.Topmost = $true
    $window.ShowInTaskbar = $false
    $window.ShowActivated = $false
    $window.Opacity = 0

    $window.Add_SourceInitialized({
        $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
        $hwnd = $helper.Handle
        $style = [Win32]::GetWindowLongPtr($hwnd, [Win32]::GWL_EXSTYLE)
        $newStyle = $style.ToInt64() -bor [Win32]::WS_EX_NOACTIVATE -bor [Win32]::WS_EX_TOPMOST
        [Win32]::SetWindowLongPtr($hwnd, [Win32]::GWL_EXSTYLE, [IntPtr]$newStyle)
    })

    $window.Add_Loaded({
        # Fade in
        $animIn = New-Object System.Windows.Media.Animation.DoubleAnimation(0, 1, [TimeSpan]::FromSeconds(0.25))
        $window.BeginAnimation([System.Windows.Window]::OpacityProperty, $animIn)
        # Fade out after duration
        $animOut = New-Object System.Windows.Media.Animation.DoubleAnimation(1, 0, [TimeSpan]::FromSeconds(0.5))
        $animOut.BeginTime = [TimeSpan]::FromSeconds($durationSec - 0.5)
        $window.BeginAnimation([System.Windows.Window]::OpacityProperty, $animOut)

        # Close timer
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds($durationSec)
        $timer.Add_Tick({ $frame.Continue = $false })
        $timer.Start()
    })

    $frame = New-Object System.Windows.Threading.DispatcherFrame
    $window.Add_Closed({ $frame.Continue = $false })

    $window.Show() | Out-Null

    try {
        $sound = New-Object Media.SoundPlayer $soundPath
        $sound.Play()
    } catch { $null = $_ }

    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
    $window.Close()
}

# Write PID file for install script to find and kill old instances
$pidFile = Join-Path $env:USERPROFILE ".claude\notify-daemon.pid"
[System.IO.File]::WriteAllText($pidFile, $PID.ToString())

$queueDir = Join-Path $env:USERPROFILE ".claude\notify-queue"
if (-not (Test-Path $queueDir)) {
    New-Item -ItemType Directory -Path $queueDir -Force | Out-Null
}

# Clean stale trigger files from previous run
Get-ChildItem $queueDir -Filter "*.json" -ErrorAction SilentlyContinue | Remove-Item -Force

# Main loop: poll directory for trigger files
while ($true) {
    $files = Get-ChildItem $queueDir -Filter "*.json" -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        Start-Sleep -Milliseconds 50
        try {
            $json = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            Show-Notification -Type $json.type -ProjectDir $json.projectDir -SessionId $json.sessionId
        } catch { $null = $_ }
        Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
}
