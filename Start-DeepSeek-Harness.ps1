# DeepSeek Harness desktop launcher
$ErrorActionPreference = 'Stop'
$baseUrl = 'http://127.0.0.1:3080'
$root = Split-Path -Parent $PSCommandPath
$logDirectory = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$logFile = Join-Path $logDirectory 'dsh-web.log'
$errorLogFile = Join-Path $logDirectory 'dsh-web-error.log'

function Test-DshWeb {
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $baseUrl -TimeoutSec 2
    return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500)
  } catch { return $false }
}

if (-not (Test-DshWeb)) {
  $dsh = Join-Path $env:APPDATA 'npm\dsh.cmd'
  if (-not (Test-Path -LiteralPath $dsh)) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show('未找到 DeepSeek Harness。请先运行 install.ps1。', 'DeepSeek Harness') | Out-Null
    exit 1
  }
  Start-Process -FilePath $dsh -ArgumentList @('web') -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $errorLogFile
  $deadline = (Get-Date).AddSeconds(75)
  do {
    Start-Sleep -Milliseconds 750
    if (Test-DshWeb) { break }
  } while ((Get-Date) -lt $deadline)
}

if (-not (Test-DshWeb)) {
  Add-Type -AssemblyName PresentationFramework
  [System.Windows.MessageBox]::Show("DeepSeek Harness 未能在 75 秒内启动。`n请检查：`n$logFile`n$errorLogFile", 'DeepSeek Harness') | Out-Null
  exit 1
}

$browserCandidates = @(
  (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
  (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
  (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'),
  (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
  (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
if (-not $browserCandidates) { throw '未找到 Chrome 或 Microsoft Edge。' }
Start-Process -FilePath $browserCandidates[0] -ArgumentList @("--app=$baseUrl", '--new-window')
