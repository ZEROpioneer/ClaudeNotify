param(
    [string]$Type = "stop",
    [string]$ProjectDir = "",
    [string]$SessionId = ""
)

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

$sessionName = ""
if ($ProjectDir -ne "" -and $SessionId -ne "") {
    # Normalize bash path to Windows path (/d/project → D:\project)
    $pd = $ProjectDir
    if ($pd -match '^/[a-zA-Z]/') {
        $pd = $pd -replace '^/([a-zA-Z])/', '$1:\'
        $pd = $pd -replace '/', '\'
    }
    $namesFile = Join-Path $pd ".claude\session-names.json"
    if (Test-Path $namesFile) {
        try {
            $json = Get-Content $namesFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $val = $json.$SessionId
            if ($val) { $sessionName = $val }
        } catch { }
    }
}

if ($Type -eq "permission") {
    $title = "Claude Code"
    $message = "需要你的权限确认 — 请选择 Yes 或 No"
    $iconChar = [char]0x003F
    $startColor = "#FFf59e0b"
    $endColor = "#FFef4444"
    $soundPath = "$env:SystemRoot\Media\Windows Notify.wav"
    $durationSec = 8
} else {
    $title = "Claude Code"
    $message = "任务已完成"
    $iconChar = [char]0x2713
    $startColor = "#FF10b981"
    $endColor = "#FF3b82f6"
    $soundPath = "$env:SystemRoot\Media\Windows Ding.wav"
    $durationSec = 5
}

$subtitle = if ($sessionName -ne "") { $sessionName } else { "" }
$nameColor = Get-ColorFromName $sessionName

$workArea = [System.Windows.SystemParameters]::WorkArea
$windowWidth = 320
$windowHeight = if ($subtitle -ne "") { 105 } else { 90 }
$margin = 20
$left = $workArea.Right - $windowWidth - $margin

# 共享计数器：获取弹窗位置编号（Mutex 保护原子操作）
$stateMutex = New-Object System.Threading.Mutex($false, "Global\ClaudeNotifyState")
$stateMutex.WaitOne()
$stateFile = "$env:USERPROFILE\.claude\notify-counter.txt"
$counter = 0
if (Test-Path $stateFile) { $counter = [int](Get-Content $stateFile -Raw) }
$myIndex = [Math]::Max(0, $counter)
$counter++
Set-Content $stateFile -Value $counter
$stateMutex.ReleaseMutex()

$top = $workArea.Bottom - $windowHeight - $margin - ($myIndex * ($windowHeight + 8))

[xml]$xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Width="$windowWidth" Height="$windowHeight"
    WindowStyle="None" AllowsTransparency="True"
    Background="Transparent" Topmost="True"
    ShowInTaskbar="False"
    Left="$left" Top="$top"
    Opacity="0">
    <Border CornerRadius="6" BorderThickness="1.8">
        <Border.BorderBrush>
            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                <GradientStop Color="$startColor" Offset="0"/>
                <GradientStop Color="$endColor" Offset="1"/>
            </LinearGradientBrush>
        </Border.BorderBrush>
        <Border CornerRadius="4" Background="#E80a0a0f">
            <Border.Effect>
                <DropShadowEffect BlurRadius="8" ShadowDepth="0" Color="#000000" Opacity="0.5"/>
            </Border.Effect>
            <Grid Margin="16,12">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border Grid.Column="0" Width="36" Height="36" CornerRadius="18" Margin="0,0,12,0"
                        Background="#FF151525" BorderBrush="$nameColor" BorderThickness="1"
                        Opacity="0.7">
                    <TextBlock Text="$iconChar" FontSize="18" Foreground="$nameColor"
                              HorizontalAlignment="Center" VerticalAlignment="Center"
                              FontFamily="Segoe UI"/>
                </Border>
                <StackPanel Grid.Column="1" VerticalAlignment="Center">
                    <TextBlock Text="$title" FontSize="11" FontWeight="SemiBold"
                              Foreground="#FF7777aa" FontFamily="Segoe UI" Margin="0,0,0,2"/>
                    <TextBlock Text="$subtitle" FontSize="10" Foreground="$nameColor"
                              FontFamily="Microsoft YaHei" Margin="0,0,0,4"
                              x:Name="SubtitleBlock"/>
                    <TextBlock Text="$message" FontSize="13" Foreground="#FFd0d0f0"
                              FontFamily="Microsoft YaHei" TextWrapping="Wrap"/>
                </StackPanel>
            </Grid>
        </Border>
    </Border>
    <Window.Triggers>
        <EventTrigger RoutedEvent="Window.Loaded">
            <BeginStoryboard>
                <Storyboard>
                    <DoubleAnimation Storyboard.TargetProperty="Opacity"
                                     From="0" To="1" Duration="0:0:0.25"/>
                    <DoubleAnimation Storyboard.TargetProperty="Opacity"
                                     From="1" To="0"
                                     BeginTime="0:0:$($durationSec - 0.5)"
                                     Duration="0:0:0.5"/>
                </Storyboard>
            </BeginStoryboard>
        </EventTrigger>
    </Window.Triggers>
</Window>
"@

if ($subtitle -eq "") {
    $nsmgr = New-Object System.Xml.XmlNamespaceManager($xaml.NameTable)
    $nsmgr.AddNamespace("ns", "http://schemas.microsoft.com/winfx/2006/xaml/presentation")
    $nsmgr.AddNamespace("x", "http://schemas.microsoft.com/winfx/2006/xaml")
    $node = $xaml.SelectSingleNode("//ns:*[@x:Name='SubtitleBlock']", $nsmgr)
    if ($node) { $node.SetAttribute("Visibility", "Collapsed") }
}

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$window.ShowActivated = $false
$window.Topmost = $true

$window.Add_SourceInitialized({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
    $hwnd = $helper.Handle
    $style = [Win32]::GetWindowLongPtr($hwnd, [Win32]::GWL_EXSTYLE)
    $newStyle = $style.ToInt64() -bor [Win32]::WS_EX_NOACTIVATE -bor [Win32]::WS_EX_TOPMOST
    [Win32]::SetWindowLongPtr($hwnd, [Win32]::GWL_EXSTYLE, [IntPtr]$newStyle)
})

$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromSeconds($durationSec)
$timer.Add_Tick({
    $timer.Stop()
    $window.Close()
})

$frame = New-Object System.Windows.Threading.DispatcherFrame
$window.Add_Closed({ $frame.Continue = $false })
$window.Add_Loaded({ $timer.Start() })

$window.Show() | Out-Null

# 窗口已显示，异步播放提示音（不阻塞）
try {
    $sound = New-Object Media.SoundPlayer $soundPath
    $sound.Play()
} catch { }

try {
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
} finally {
    # 弹窗关闭，递减计数器（finally 确保崩溃也执行）
    $stateMutex.WaitOne()
    $counter = 0
    if (Test-Path $stateFile) { $counter = [int](Get-Content $stateFile -Raw) }
    if ($counter -gt 0) { $counter-- }
    Set-Content $stateFile -Value $counter
    $stateMutex.ReleaseMutex()
}
