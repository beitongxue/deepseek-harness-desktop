#requires -Version 5.1
param(
  [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'DeepSeek-Harness-Desktop'),
  [ValidateSet('Auto','Install','Skip')][string]$HarnessMode = 'Auto',
  [ValidateSet('Auto','Install','Skip')][string]$WebUiMode = 'Auto',
  [ValidateSet('None','blue-fantasy','dragon-heir','miku','minecraft','qq98','ths','trading','whale-song','xp')][string]$Skin,
  [switch]$DesktopOnly,
  [switch]$Repair,
  [switch]$NoShortcut,
  [switch]$SkipNativePickerPatch
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSCommandPath
. (Join-Path $projectRoot 'scripts\Common.ps1')
$versions = Get-VersionManifest $projectRoot
$normalizedInstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)
$normalizedProjectRoot = [System.IO.Path]::GetFullPath($projectRoot)
$installPrefix = $normalizedInstallRoot.TrimEnd('\') + '\'
$projectPrefix = $normalizedProjectRoot.TrimEnd('\') + '\'
if ($normalizedInstallRoot.TrimEnd('\') -ieq $normalizedProjectRoot.TrimEnd('\') -or
    $normalizedProjectRoot.StartsWith($installPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
    $normalizedInstallRoot.StartsWith($projectPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "InstallRoot 不能是源码目录本身，也不能位于源码目录内或包含源码目录：$normalizedInstallRoot"
}
$InstallRoot = $normalizedInstallRoot
if (-not $PSBoundParameters.ContainsKey('Skin')) { $Skin = [string]$versions.defaultSkin }
if ($Repair -and -not $DesktopOnly) {
  if ($HarnessMode -eq 'Auto') { $HarnessMode = 'Install' }
  if ($WebUiMode -eq 'Auto') { $WebUiMode = 'Install' }
}
if ($DesktopOnly) { $HarnessMode = 'Skip'; $WebUiMode = 'Skip' }

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Require-Node {
  $node = Get-CommandPath 'node.exe'
  if (-not $node) { throw "未找到 node.exe。请先安装 Node.js $($versions.minimumNodeMajor) 或更高版本。" }
  $text = (& $node --version).Trim()
  if ($text -notmatch '^v(\d+)') { throw "无法读取 Node.js 版本：$text" }
  if ([int]$Matches[1] -lt [int]$versions.minimumNodeMajor) { throw "当前 Node.js 为 $text；需要 Node.js $($versions.minimumNodeMajor) 或更高版本。" }
  return $node
}
function Get-NpmCommand {
  $npm = Get-CommandPath 'npm.cmd'
  if (-not $npm) { $npm = Join-Path $env:ProgramFiles 'nodejs\npm.cmd' }
  if (-not (Test-Path -LiteralPath $npm)) { throw '未找到 npm.cmd，请确认 Node.js 安装完整。' }
  return $npm
}
function Get-DshVersion([string]$DshCommand) {
  try { return ((& $DshCommand --version 2>$null).Trim()) } catch { return 'unknown' }
}
function Test-WebUiInstalled {
  return (Test-Path -LiteralPath (Join-Path (Get-WebProfileRoot) 'node_modules\@linxin666\dsh-web-ui-all\package.json'))
}
function Get-DshRoot([string]$DshCommand) {
  $commandDirectory = Split-Path -Parent $DshCommand
  $candidate = Join-Path $commandDirectory 'node_modules\@deepseek-ai\dsh'
  if (Test-Path -LiteralPath $candidate) { return $candidate }
  return (Join-Path $env:APPDATA 'npm\node_modules\@deepseek-ai\dsh')
}
function Ensure-Harness {
  $existing = Get-DshCommandPath
  if ($HarnessMode -eq 'Skip') {
    if (-not $existing) { throw '已选择跳过 DeepSeek Harness 安装，但没有找到 dsh.cmd。' }
    return $existing
  }
  if ($HarnessMode -eq 'Auto' -and $existing -and -not $Repair) {
    Write-Host "复用已有 DeepSeek Harness：$existing" -ForegroundColor DarkGray
    return $existing
  }
  $null = Require-Node
  $npm = Get-NpmCommand
  Write-Step "安装 DeepSeek Harness $($versions.dsh)"
  & $npm install --global --no-fund --no-audit "@deepseek-ai/dsh@$($versions.dsh)"
  if ($LASTEXITCODE -ne 0) { throw "DeepSeek Harness 安装失败，退出码：$LASTEXITCODE" }
  $result = Get-DshCommandPath
  if (-not $result) { throw '安装后未找到 dsh.cmd。请确认 npm global bin 目录已加入 PATH。' }
  return $result
}
function Ensure-WebUi([string]$DshCommand) {
  if ($WebUiMode -eq 'Skip') {
    if (-not (Test-WebUiInstalled)) { throw '已选择跳过 Web UI 安装，但当前 web profile 中没有 @linxin666/dsh-web-ui-all。' }
    return
  }
  if ($WebUiMode -eq 'Auto' -and (Test-WebUiInstalled) -and -not $Repair) {
    Write-Host '复用已有 Web UI profile。' -ForegroundColor DarkGray
    return
  }
  Write-Step "安装 Web UI $($versions.webUi)"
  & $DshCommand plugin --profile web add "@linxin666/dsh-web-ui-all@$($versions.webUi)"
  if ($LASTEXITCODE -ne 0) { throw "Web UI 安装失败，退出码：$LASTEXITCODE" }
}
function Ensure-Skin([string]$DshCommand) {
  if ($Skin -eq 'None') { return $null }
  $name = Get-SkinPackageName $Skin
  $installed = Join-Path (Get-WebProfileRoot) "node_modules\@linxin666\dsh-client-ui-skin-$Skin\package.json"
  $local = Get-StableSkinPath $Skin
  $localExistedBefore = Test-Path -LiteralPath (Join-Path $local 'package.json')

  # Always materialize the stable local package before writing a link dependency.
  # Otherwise an existing package in node_modules could leave a dangling link
  # on a fresh machine or after a partial cleanup.
  if (-not $localExistedBefore) {
    $source = Get-InstalledSkinSource $Skin
    if (-not $source) { throw "未找到皮肤 $Skin。请先安装 @linxin666/dsh-web-ui-all，或使用 -Skin None。" }
    $local = Ensure-LocalSkinPackage $Skin
  }
  if (-not (Test-Path -LiteralPath (Join-Path $local 'package.json'))) {
    throw "皮肤包已准备但 package.json 不存在：$local"
  }
  if (-not (Test-Path -LiteralPath $installed)) {
    Write-Step "注册皮肤 $name"
    & $DshCommand plugin --profile web add $local
    if ($LASTEXITCODE -ne 0) { throw "皮肤安装失败，退出码：$LASTEXITCODE" }
  }
  # 皮肤由全局 managed patch 激活；不要再次把它加入 profile bundles。
  $spec = "link:$local"
  Ensure-WebProfilePackage -Name $name -Spec $spec -RemoveBundle | Out-Null
  return [pscustomobject]@{
    Name = $name
    LocalPath = $local
    LocalCreated = (-not $localExistedBefore)
    Spec = $spec
  }
}function Get-SkinPatch([string]$SkinName) {
  if ($SkinName -eq 'None') { return '# no default skin enabled by this installation' }
  return ((
    '- insert:',
    ('    - id: ui-skin-' + $SkinName),
    ('      name: ''' + (Get-SkinPackageName $SkinName) + '''')
  ) -join "`r`n")
}
function Apply-Configuration {
  $backupRoot = Join-Path $env:USERPROFILE '.dsh\backups\deepseek-harness-desktop'
  $legacySkin = '(?ms)^# dsh-skin managed block\. The package is provided by the upstream dsh-web-ui project\.[\r\n]+.*?(?=^\s*$|\z)'
  $global = Update-ManagedTextBlock -Path (Join-Path $env:USERPROFILE '.dsh\cordis.patch.yml') -Marker 'deepseek-harness-desktop:skin' -Block (Get-SkinPatch $Skin) -BackupRoot $backupRoot -LegacyPattern $legacySkin

  # DSH requires every profile overlay to parse as a top-level YAML array.
  # Keep [] when the profile contains only comments/our managed block; do not add
  # a second YAML document or inject entries into a user's existing array.
  $profilePath = Join-Path (Get-WebProfileRoot) 'cordis.patch.yml'
  $before = if (Test-Path -LiteralPath $profilePath) { Read-Utf8Text $profilePath } else { '' }
  $managedPattern = '(?ms)^# BEGIN deepseek-harness-desktop:web-profile\r?\n.*?^# END deepseek-harness-desktop:web-profile\r?\n?'
  $base = [regex]::Replace($before, $managedPattern, '')
  $nonComment = [regex]::Replace($base, '(?m)^\s*#.*(?:\r?\n|$)', '')
  if ([string]::IsNullOrWhiteSpace($nonComment) -and $base -notmatch '(?m)^\s*\[\]\s*$') {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $profilePath) | Out-Null
    [System.IO.File]::WriteAllText($profilePath, "[]`r`n`r`n$before", [System.Text.UTF8Encoding]::new($false))
  }
  $legacyProfile = '(?m)^# This is intentionally an empty profile patch layer\.[\r\n]+# The skin selection is managed in ~/.dsh/cordis\.patch\.yml\.[\r\n]+'
  $profile = Update-ManagedTextBlock -Path $profilePath -Marker 'deepseek-harness-desktop:web-profile' -Block '# profile patch intentionally contains no entries; the global managed block selects the skin.' -BackupRoot $backupRoot -LegacyPattern $legacyProfile
  return @($global, $profile)
}
function Apply-NativePatch([string]$DshCommand) {
  if ($SkipNativePickerPatch) { return $null }
  $patch = Join-Path $InstallRoot 'patches\native-directory-picker-owner.patch.ps1'
  if (-not (Test-Path -LiteralPath $patch)) { throw "未找到原生目录选择器补丁：$patch" }
  try { $result = & $patch -DshRoot (Get-DshRoot $DshCommand) -PassThru }
  catch { throw "原生目录选择器补丁失败：$($_.Exception.Message)" }
  $record = $result | Where-Object { $_ -and $_.PSObject.Properties['Path'] } | Select-Object -Last 1
  if (-not $record) { throw '原生目录选择器补丁未返回可记录的结果。' }
  return $record
}
function Validate-Profile([string]$DshCommand) {
  Write-Step '验证 web profile 配置'
  $output = @(& $DshCommand --profile web --dump-config 2>&1)
  if ($LASTEXITCODE -ne 0) {
    $tail = ($output | Select-Object -Last 12) -join "`n"
    throw "web profile 验证失败：`n$tail"
  }
  if ($Skin -ne 'None') {
    $skinPath = Join-Path (Get-WebProfileRoot) "node_modules\@linxin666\dsh-client-ui-skin-$Skin\package.json"
    if (-not (Test-Path -LiteralPath $skinPath)) { throw "配置引用了皮肤，但皮肤包不存在：$skinPath" }
  }
}
function New-Shortcut {
  $desktop = [Environment]::GetFolderPath('Desktop')
  $shortcutPath = Join-Path $desktop 'DeepSeek Harness.lnk'
  $vbsPath = Join-Path $InstallRoot 'Start DeepSeek Harness.vbs'
  $iconPath = Join-Path $InstallRoot 'assets\DeepSeek Harness.ico'
  try {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
    $shortcut.Arguments = '"' + $vbsPath + '"'
    $shortcut.WorkingDirectory = $InstallRoot
    $shortcut.IconLocation = "$iconPath,0"
    $shortcut.Description = 'DeepSeek Harness 桌面窗口'
    $shortcut.Save()
    return $shortcutPath
  } catch {
    Write-Warning "创建桌面快捷方式失败：$($_.Exception.Message)"
    return $null
  }
}

if ($env:OS -ne 'Windows_NT') { throw '此安装包只支持 Windows。' }
New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'Start-DeepSeek-Harness.ps1') -Destination $InstallRoot -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'Start DeepSeek Harness.vbs') -Destination $InstallRoot -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'Start DeepSeek Harness.cmd') -Destination $InstallRoot -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'patches') -Destination $InstallRoot -Recurse -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets') -Destination $InstallRoot -Recurse -Force

Write-Step '准备 DeepSeek Harness'
$dshCommand = Ensure-Harness
Write-Host "使用 dsh：$dshCommand" -ForegroundColor DarkGray
Ensure-WebUi $dshCommand
$skinInfo = Ensure-Skin $dshCommand
$configChanges = @(Apply-Configuration)
$nativePatch = Apply-NativePatch $dshCommand
Validate-Profile $dshCommand

$shortcut = $null
if (-not $NoShortcut) { $shortcut = New-Shortcut }
$state = [ordered]@{
  schemaVersion = 2
  installedAt = (Get-Date).ToString('o')
  projectRoot = $projectRoot
  installRoot = $InstallRoot
  dshCommand = $dshCommand
  dshVersion = (Get-DshVersion $dshCommand)
  requestedDshVersion = [string]$versions.dsh
  webUiVersion = [string]$versions.webUi
  port = [int]$versions.defaultPort
  skin = $Skin
  skinPackage = if ($skinInfo) { $skinInfo.Name } else { $null }
  localSkinPath = if ($skinInfo) { $skinInfo.LocalPath } else { $null }
  localSkinCreated = if ($skinInfo) { [bool]$skinInfo.LocalCreated } else { $false }
  webProfileRoot = (Get-WebProfileRoot)
  shortcut = $shortcut
  nativePatch = $nativePatch
  configChanges = @($configChanges)
  configBackups = @($configChanges | Where-Object { $_.Backup } | ForEach-Object { $_.Backup })
}
Save-JsonFile -Path (Get-InstallStatePath $InstallRoot) -Value $state

Write-Host "`n安装/接入完成。" -ForegroundColor Green
Write-Host "桌面安装目录：$InstallRoot"
Write-Host "Web profile：$(Get-WebProfileRoot)"
Write-Host "DSH 版本：$($state.dshVersion)"
Write-Host "Web UI 版本：$($state.webUiVersion)"
Write-Host "默认皮肤：$Skin"
if ($shortcut) { Write-Host "桌面快捷方式：$shortcut" }
Write-Host '启动：双击快捷方式，或运行 Start-DeepSeek-Harness.ps1。'
