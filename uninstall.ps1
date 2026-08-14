[CmdletBinding()]
param(
  [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'DeepSeek-Harness-Desktop'),
  [switch]$RestoreConfig,
  [switch]$RemoveWebUi,
  [switch]$RemoveHarness
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSCommandPath
. (Join-Path $projectRoot 'scripts\Common.ps1')

$defaultInstallRoot = Join-Path $env:LOCALAPPDATA 'DeepSeek-Harness-Desktop'
$statePath = Get-InstallStatePath $InstallRoot
$state = Read-JsonFile $statePath
$shortcutPath = if ($state -and $state.PSObject.Properties['shortcut'] -and $state.shortcut) { [string]$state.shortcut } else { $null }
$globalPatch = Join-Path $env:USERPROFILE '.dsh\cordis.patch.yml'
$profileRoot = if ($state -and $state.PSObject.Properties['webProfileRoot'] -and $state.webProfileRoot) { [string]$state.webProfileRoot } else { Get-WebProfileRoot }
$profilePatch = Join-Path $profileRoot 'cordis.patch.yml'

function Resolve-ExistingPath([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\')
}
function Test-SafeInstallRoot([string]$Path) {
  $resolved = Resolve-ExistingPath $Path
  if (-not $resolved) { return $false }
  $allowed = @($defaultInstallRoot)
  if ($state -and $state.PSObject.Properties['installRoot'] -and $state.installRoot) { $allowed += [string]$state.installRoot }
  foreach ($candidate in $allowed) {
    $candidateResolved = Resolve-ExistingPath $candidate
    if ($candidateResolved -and $resolved -ieq $candidateResolved.TrimEnd('\')) { return $true }
  }
  return $false
}
function Restore-RecordedConfigs {
  $restored = 0
  if ($state -and $state.PSObject.Properties['configChanges'] -and $state.configChanges) {
    foreach ($change in @($state.configChanges)) {
      if ($change -and $change.PSObject.Properties['Backup'] -and $change.Backup -and $change.PSObject.Properties['Path'] -and $change.Path -and (Test-Path -LiteralPath ([string]$change.Backup))) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent ([string]$change.Path)) | Out-Null
        Copy-Item -LiteralPath ([string]$change.Backup) -Destination ([string]$change.Path) -Force
        Write-Host "已恢复配置备份：$($change.Path) <- $($change.Backup)"
        $restored++
      }
    }
  } elseif ($state -and $state.PSObject.Properties['configBackups'] -and $state.configBackups) {
    Write-Warning '安装状态只有旧版 configBackups，无法可靠判断每个备份对应的目标文件；未自动恢复。请手动选择备份。'
  }
  return $restored
}
function Remove-ManagedConfigs {
  $changed = 0
  if (Remove-ManagedTextBlock -Path $globalPatch -Marker 'deepseek-harness-desktop:skin') { $changed++ }
  if (Remove-ManagedTextBlock -Path $profilePatch -Marker 'deepseek-harness-desktop:web-profile') { $changed++ }
  return $changed
}
function Get-NpmCommand {
  $npm = Get-CommandPath 'npm.cmd'
  if (-not $npm) { $npm = Join-Path $env:ProgramFiles 'nodejs\npm.cmd' }
  if (-not (Test-Path -LiteralPath $npm)) { return $null }
  return $npm
}
function Remove-WebUiPackages {
  $webUiName = '@linxin666/dsh-web-ui-all'
  $skinName = $null
  if ($state -and $state.PSObject.Properties['skin'] -and $state.skin -and [string]$state.skin -ne 'None') { $skinName = Get-SkinPackageName ([string]$state.skin) }
  $changed = $false
  if (Remove-WebProfileDependency -Name $webUiName -RemoveBundle) { $changed = $true }
  if ($skinName -and (Remove-WebProfileDependency -Name $skinName -RemoveBundle)) { $changed = $true }
  $nodeModules = Join-Path $profileRoot 'node_modules'
  $relativePaths = @('@linxin666\dsh-web-ui-all')
  if ($state -and $state.PSObject.Properties['skin'] -and $state.skin -and [string]$state.skin -ne 'None') { $relativePaths += ('@linxin666\dsh-client-ui-skin-' + [string]$state.skin) }
  foreach ($relative in $relativePaths) {
    $path = Join-Path $nodeModules $relative
    if (Test-Path -LiteralPath $path) {
      Remove-Item -LiteralPath $path -Recurse -Force
      Write-Host "已删除 Web UI 包目录：$path"
      $changed = $true
    }
  }
  if ($changed) { Write-Host '已从 web profile 移除安装器管理的 Web UI 依赖。' }
  else { Write-Host '未发现可移除的安装器管理 Web UI 依赖。' }
}
function Remove-ManagedLocalSkin {
  if (-not $state -or -not $state.PSObject.Properties['localSkinCreated'] -or -not $state.localSkinCreated -or -not $state.PSObject.Properties['localSkinPath'] -or -not $state.localSkinPath) { return }
  $path = [string]$state.localSkinPath
  $resolved = Resolve-ExistingPath $path
  if (-not $resolved) { return }
  $skin = if ($state.PSObject.Properties['skin']) { [string]$state.skin } else { '' }
  $expected = Resolve-ExistingPath (Join-Path $env:USERPROFILE ('.dsh\local-plugins\dsh-client-ui-skin-' + $skin))
  if (-not $expected -or $resolved -ine $expected) { Write-Warning "拒绝删除非预期的本地皮肤路径：$path"; return }
  $pkg = Read-JsonFile (Get-WebProfilePackagePath)
  $name = if ($skin -and $skin -ne 'None') { Get-SkinPackageName $skin } else { $null }
  $referenced = $false
  if ($name -and $pkg -and $pkg.PSObject.Properties['dependencies'] -and $pkg.dependencies -and $pkg.dependencies.PSObject.Properties[$name]) { $referenced = $true }
  if ($referenced) { Write-Warning "本地皮肤仍被 web profile 引用，保留：$path"; return }
  Remove-Item -LiteralPath $resolved -Recurse -Force
  Write-Host "已删除安装器创建的本地皮肤包：$resolved"
}

function Restore-NativePatch {
  if (-not $state -or -not $state.PSObject.Properties['nativePatch'] -or -not $state.nativePatch) { return }
  $record = $state.nativePatch
  if (-not $record.PSObject.Properties['AlreadyPatched'] -or [bool]$record.AlreadyPatched) { return }
  if (-not $record.PSObject.Properties['Backup'] -or -not $record.Backup -or -not (Test-Path -LiteralPath ([string]$record.Backup))) {
    Write-Warning '安装器曾记录 native patch，但没有可验证的精确备份，跳过自动恢复。'
    return
  }
  $patchScript = Join-Path $InstallRoot 'patches\native-directory-picker-owner.patch.ps1'
  if (-not (Test-Path -LiteralPath $patchScript)) {
    Write-Warning "未找到 native patch 恢复脚本：$patchScript"
    return
  }
  $dshRoot = Join-Path $env:APPDATA 'npm\node_modules\@deepseek-ai\dsh'
  if ($state.PSObject.Properties['dshCommand'] -and $state.dshCommand) {
    $candidate = Join-Path (Split-Path -Parent ([string]$state.dshCommand)) 'node_modules\@deepseek-ai\dsh'
    if (Test-Path -LiteralPath $candidate) { $dshRoot = $candidate }
  }
  try {
    & $patchScript -DshRoot $dshRoot -Restore -BackupPath ([string]$record.Backup)
    Write-Host '已恢复 native 目录选择器补丁的精确备份。'
  } catch { Write-Warning "native patch 恢复失败：$($_.Exception.Message)" }
}
if ($RestoreConfig) {
  $count = Restore-RecordedConfigs
  if ($count -eq 0) { Write-Warning '没有可恢复的精确配置备份，将仅移除本安装器的 managed block。'; [void](Remove-ManagedConfigs) }
} else {
  [void](Remove-ManagedConfigs)
}

if ($shortcutPath -and (Test-Path -LiteralPath $shortcutPath)) {
  Remove-Item -LiteralPath $shortcutPath -Force
  Write-Host "已删除快捷方式：$shortcutPath"
} else {
  Write-Host '未删除快捷方式：安装状态中没有可验证的快捷方式记录。' -ForegroundColor DarkGray
}

$installedLauncher = Join-Path $InstallRoot 'Start-DeepSeek-Harness.ps1'
if (Test-Path -LiteralPath $installedLauncher) {
  try { & $installedLauncher -Stop -NoBrowser 2>$null } catch { Write-Warning "停止运行中的服务失败：$($_.Exception.Message)" }
}

Restore-NativePatch
if ($RemoveWebUi) {
  Remove-WebUiPackages
  Remove-ManagedLocalSkin
}

if ($RemoveHarness) {
  $npm = Get-NpmCommand
  if ($npm) {
    & $npm uninstall --global --no-fund --no-audit '@deepseek-ai/dsh'
    if ($LASTEXITCODE -ne 0) { Write-Warning "DeepSeek Harness 卸载退出码：$LASTEXITCODE" }
    else { Write-Host '已卸载全局 DeepSeek Harness CLI。' }
  } else { Write-Warning '未找到 npm.cmd，跳过 DeepSeek Harness CLI 卸载。' }
}

if (Test-Path -LiteralPath $InstallRoot) {
  if (-not (Test-SafeInstallRoot $InstallRoot)) { throw "出于安全原因，拒绝递归删除未在安装状态中登记的目录：$InstallRoot" }
  $resolvedInstallRoot = (Resolve-Path -LiteralPath $InstallRoot).Path.TrimEnd('\')
  $resolvedProjectRoot = (Resolve-Path -LiteralPath $projectRoot).Path.TrimEnd('\')
  if ($resolvedInstallRoot -ieq $resolvedProjectRoot) { throw '拒绝删除源码目录；请使用源码目录之外的 InstallRoot。' }
  Remove-Item -LiteralPath $resolvedInstallRoot -Recurse -Force
  Write-Host "已删除桌面封装安装目录：$resolvedInstallRoot"
}
Write-Host '卸载完成。默认不会删除 ~/.dsh 中的登录凭据、会话或工作空间数据。' -ForegroundColor Green
