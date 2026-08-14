#requires -Version 5.1
[CmdletBinding()]
param(
  [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'DeepSeek-Harness-Desktop'),
  [switch]$RemoveHarness
)

$ErrorActionPreference = 'Stop'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'DeepSeek Harness.lnk'
$globalPatch = Join-Path $env:USERPROFILE '.dsh\cordis.patch.yml'
$profilePatch = Join-Path $env:USERPROFILE '.dsh\profiles\web\cordis.patch.yml'
$backupRoot = Join-Path $env:USERPROFILE '.dsh\backups\deepseek-harness-desktop'

function Restore-LatestBackup([string]$Destination, [string]$Label, [string]$Leaf) {
  if (-not (Test-Path -LiteralPath $backupRoot)) { return $false }
  $backup = Get-ChildItem -LiteralPath $backupRoot -Filter "*$Label-$Leaf" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $backup) { return $false }
  Copy-Item -LiteralPath $backup.FullName -Destination $Destination -Force
  Write-Host "已恢复：$Destination <- $($backup.FullName)"
  return $true
}

$patchScript = Join-Path $InstallRoot 'patches\native-directory-picker-owner.patch.ps1'
if (Test-Path -LiteralPath $patchScript) {
  try {
    & $patchScript -DshRoot (Join-Path $env:APPDATA 'npm\node_modules\@deepseek-ai\dsh') -Restore
  } catch {
    Write-Warning "原生目录选择器补丁恢复失败：$($_.Exception.Message)"
  }
}

if (Test-Path -LiteralPath $globalPatch) { [void](Restore-LatestBackup $globalPatch 'global' 'cordis.patch.yml') }
if (Test-Path -LiteralPath $profilePatch) { [void](Restore-LatestBackup $profilePatch 'web-profile' 'cordis.patch.yml') }
if (Test-Path -LiteralPath $shortcutPath) { Remove-Item -LiteralPath $shortcutPath -Force; Write-Host "已删除快捷方式：$shortcutPath" }

if ($RemoveHarness) {
  $npm = (Get-Command npm.cmd -ErrorAction SilentlyContinue).Source
  if ($npm) {
    & $npm uninstall --global --no-fund --no-audit '@deepseek-ai/dsh'
    if ($LASTEXITCODE -ne 0) { Write-Warning "DeepSeek Harness 卸载退出码：$LASTEXITCODE" }
  } else { Write-Warning '未找到 npm.cmd，跳过 DeepSeek Harness CLI 卸载。' }
}

if (Test-Path -LiteralPath $InstallRoot) {
  $resolvedInstallRoot = (Resolve-Path -LiteralPath $InstallRoot).Path
  $resolvedExpected = (Join-Path $env:LOCALAPPDATA 'DeepSeek-Harness-Desktop')
  if ($resolvedInstallRoot.TrimEnd('\\') -ieq $resolvedExpected.TrimEnd('\\')) {
    Remove-Item -LiteralPath $resolvedInstallRoot -Recurse -Force
    Write-Host "已删除安装目录：$resolvedInstallRoot"
  }
}
Write-Host '卸载完成。默认不会删除 ~/.dsh 中的登录凭据、会话或工作空间数据。' -ForegroundColor Green
