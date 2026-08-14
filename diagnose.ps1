# Diagnose an existing DeepSeek Harness Desktop installation.
[CmdletBinding()]
param(
  [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'DeepSeek-Harness-Desktop'),
  [switch]$Json,
  [switch]$FailOnError
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSCommandPath
. (Join-Path $projectRoot 'scripts\Common.ps1')
$versions = Get-VersionManifest $projectRoot
$dsh = Get-DshCommandPath
$profile = Get-WebProfileRoot
$pkgPath = Get-WebProfilePackagePath
$statePath = Get-InstallStatePath $InstallRoot
$state = Read-JsonFile $statePath
$skin = if ($state -and $state.PSObject.Properties['skin'] -and $state.skin) { [string]$state.skin } else { [string]$versions.defaultSkin }
$skinName = if ($skin -eq 'None') { $null } else { Get-SkinPackageName $skin }
$skinPath = if ($skinName) { Join-Path $profile "node_modules\@linxin666\dsh-client-ui-skin-$skin\package.json" } else { $null }
$webUiPath = Join-Path $profile 'node_modules\@linxin666\dsh-web-ui-all\package.json'
$nativePath = Join-Path $env:APPDATA 'npm\node_modules\@deepseek-ai\dsh\node_modules\@deepseek-ai\dsh-host-directory-picker-native\lib\worker.cjs'
if ($state -and $state.PSObject.Properties['nativePatch'] -and $state.nativePatch -and $state.nativePatch.PSObject.Properties['Path'] -and $state.nativePatch.Path) { $nativePath = [string]$state.nativePatch.Path }
$port = [int]$versions.defaultPort
$portListening = $false
$portOwner = $null
$netCommand = Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue
if ($netCommand) {
  $connections = @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
  $portListening = ($connections.Count -gt 0)
  if ($connections.Count -gt 0) { $portOwner = (@($connections | Select-Object -ExpandProperty OwningProcess -Unique) -join ', ') }
} else {
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $async = $client.BeginConnect('127.0.0.1', $port, $null, $null)
    $portListening = $async.AsyncWaitHandle.WaitOne(500)
    if ($portListening -and $client.Connected) { $portOwner = 'unknown' }
    $client.Close()
  } catch { $portListening = $false }
}
$dshVersion = $null
if ($dsh) { try { $dshVersion = ((& $dsh --version 2>$null).Trim()) } catch { $dshVersion = 'error' } }
$pkg = if (Test-Path -LiteralPath $pkgPath) { Read-JsonFile $pkgPath } else { $null }
$webVersion = if (Test-Path -LiteralPath $webUiPath) { [string](Read-JsonFile $webUiPath).version } else { $null }
$items = [ordered]@{
  installRoot = $InstallRoot
  installRootExists = (Test-Path -LiteralPath $InstallRoot)
  dshCommand = $dsh
  dshVersion = $dshVersion
  requestedDshVersion = [string]$versions.dsh
  webProfile = $profile
  webProfilePackage = $pkgPath
  webUiInstalled = (Test-Path -LiteralPath $webUiPath)
  webUiVersion = $webVersion
  skin = $skin
  skinPackage = $skinName
  skinInstalled = if ($skinPath) { Test-Path -LiteralPath $skinPath } else { $true }
  nativePickerPath = $nativePath
  nativePickerPatched = if (Test-Path -LiteralPath $nativePath) { (Select-String -LiteralPath $nativePath -Pattern 'codex: dsh-desktop native picker owner patch' -SimpleMatch -Quiet) } else { $false }
  globalPatch = (Join-Path $env:USERPROFILE '.dsh\cordis.patch.yml')
  profilePatch = (Join-Path $profile 'cordis.patch.yml')
  port = $port
  portListening = $portListening
  portOwner = $portOwner
  stateFile = $statePath
  shortcut = if ($state -and $state.PSObject.Properties['shortcut']) { [string]$state.shortcut } else { $null }
}
$errors = @()
if (-not $items.dshCommand) { $errors += '未找到 dsh.cmd' }
if (-not $items.webUiInstalled) { $errors += '未找到 @linxin666/dsh-web-ui-all' }
if (-not $items.skinInstalled) { $errors += "未找到皮肤包：$skinName" }
if (-not (Test-Path -LiteralPath $items.globalPatch)) { $errors += '未找到全局 Cordis patch 文件' }
if (-not (Test-Path -LiteralPath $items.profilePatch)) { $errors += '未找到 web profile Cordis patch 文件' }
if ($Json) {
  [ordered]@{ ok = ($errors.Count -eq 0); errors = $errors; data = $items } | ConvertTo-Json -Depth 10
} else {
  Write-Host 'DeepSeek Harness Desktop 诊断' -ForegroundColor Cyan
  $items.GetEnumerator() | ForEach-Object { Write-Host ("{0}: {1}" -f $_.Key, $_.Value) }
  if ($errors.Count -eq 0) { Write-Host '诊断通过。' -ForegroundColor Green }
  else { Write-Host '发现问题：' -ForegroundColor Red; $errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red } }
}
if ($FailOnError -and $errors.Count -gt 0) { exit 1 }
