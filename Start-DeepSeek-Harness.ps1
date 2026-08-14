# DeepSeek Harness desktop launcher.
# Supports start, status and stop without requiring a browser-specific install path.
[CmdletBinding()]
param(
  [string]$BaseUrl,
  [int]$Port = 0,
  [int]$TimeoutSec = 75,
  [switch]$Status,
  [switch]$Stop,
  [switch]$NoBrowser,
  [switch]$ShowErrorDialog
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath
$logDirectory = Join-Path $root 'logs'
try {
  New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
} catch {
  $logDirectory = Join-Path $env:LOCALAPPDATA 'DeepSeek-Harness-Desktop\logs'
  New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
}
$logFile = Join-Path $logDirectory 'dsh-web.log'
$errorLogFile = Join-Path $logDirectory 'dsh-web-error.log'
$pidFile = Join-Path $logDirectory 'dsh-web.pid'
$configuredPort = $Port
$statePath = Join-Path $root 'install-state.json'
if ($configuredPort -le 0 -and (Test-Path -LiteralPath $statePath)) {
  try {
    $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($state.PSObject.Properties['port'] -and [int]$state.port -gt 0) { $configuredPort = [int]$state.port }
  } catch { }
}
if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  if ($configuredPort -le 0) { $configuredPort = 3180 }
  $BaseUrl = "http://127.0.0.1:$configuredPort"
} elseif ($configuredPort -le 0) {
  try {
    $configuredPort = ([Uri]$BaseUrl).Port
  } catch { }
}
if ($configuredPort -le 0) { $configuredPort = 3180 }
function Show-Failure([string]$Message) {
  Write-Error $Message
  if ($ShowErrorDialog) {
    try {
      Add-Type -AssemblyName PresentationFramework
      [System.Windows.MessageBox]::Show($Message, 'DeepSeek Harness') | Out-Null
    } catch { }
  }
}
function Test-DshWeb {
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $BaseUrl -TimeoutSec 2
    return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500)
  } catch { return $false }
}
function Get-TrackedProcess {
  if (-not (Test-Path -LiteralPath $pidFile)) { return $null }
  $raw = (Get-Content -LiteralPath $pidFile -Raw).Trim()
  $trackedPid = 0
  if (-not [int]::TryParse($raw, [ref]$trackedPid)) { return $null }
  $process = Get-Process -Id $trackedPid -ErrorAction SilentlyContinue
  if (-not $process) { Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue }
  return $process
}
function Get-CommandPath([string]$Name) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) { return $null }
  if ($command.Path) { return [string]$command.Path }
  if ($command.Source -and (Test-Path -LiteralPath $command.Source)) { return [string]$command.Source }
  return $null
}
function Get-DshCommand {
  $path = Join-Path $env:APPDATA 'npm\dsh.cmd'
  if (Test-Path -LiteralPath $path) { return $path }
  return (Get-CommandPath 'dsh.cmd')
}
function Get-Browser {
  $candidates = @(
    (Get-CommandPath 'chrome.exe'),
    (Get-CommandPath 'msedge.exe'),
    (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
    (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe')
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
  return ($candidates | Select-Object -First 1)
}

if ($Status) {
  $tracked = Get-TrackedProcess
  if (Test-DshWeb) {
    if ($tracked) { Write-Host "DeepSeek Harness 正在运行：$BaseUrl（PID $($tracked.Id)）" -ForegroundColor Green }
    else { Write-Host "DeepSeek Harness 正在运行：$BaseUrl（非本启动器记录的进程）" -ForegroundColor Green }
    exit 0
  }
  Write-Host "DeepSeek Harness 未运行：$BaseUrl" -ForegroundColor Yellow
  exit 1
}
if ($Stop) {
  $process = Get-TrackedProcess
  if ($process) {
    Stop-Process -Id $process.Id -Force
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    Write-Host "已停止 DeepSeek Harness 启动进程：$($process.Id)"
  } elseif (Test-DshWeb) {
    Write-Warning '服务仍在运行，但没有找到本启动器记录的 PID；为避免误杀其他实例，未强制终止。'
    exit 2
  } else {
    Write-Host 'DeepSeek Harness 当前未运行。'
  }
  exit 0
}

if (-not (Test-DshWeb)) {
  $dsh = Get-DshCommand
  if (-not $dsh) { Show-Failure '未找到 dsh.cmd。请先运行 install.ps1 或 install.ps1 -DesktopOnly。'; exit 1 }
  $existing = Get-TrackedProcess
  if (-not $existing) {
    try {
      $commandLine = '"{0}" web --port {1}' -f $dsh, $configuredPort
      $process = Start-Process -FilePath $env:ComSpec -ArgumentList @('/d', '/c', $commandLine) -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $errorLogFile -PassThru
      Set-Content -LiteralPath $pidFile -Value $process.Id -Encoding ASCII
    } catch {
      Show-Failure "启动 dsh web 失败：$($_.Exception.Message)`n日志：$errorLogFile"
      exit 1
    }
  }
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  do {
    Start-Sleep -Milliseconds 750
    if (Test-DshWeb) { break }
  } while ((Get-Date) -lt $deadline)
}

if (-not (Test-DshWeb)) {
  $tail = if (Test-Path -LiteralPath $errorLogFile) { (Get-Content -LiteralPath $errorLogFile -Tail 15) -join "`n" } else { '(没有错误日志)' }
  Show-Failure "DeepSeek Harness 未能在 $TimeoutSec 秒内启动。`n错误日志：$errorLogFile`n$tail"
  exit 1
}

Write-Host "DeepSeek Harness 已启动：$BaseUrl" -ForegroundColor Green
if ($NoBrowser) { exit 0 }
$browser = Get-Browser
if ($browser) {
  Start-Process -FilePath $browser -ArgumentList @("--app=$BaseUrl", '--new-window')
} else {
  Write-Warning '未找到 Chrome 或 Microsoft Edge，改用系统默认浏览器。'
  Start-Process -FilePath $BaseUrl
}
