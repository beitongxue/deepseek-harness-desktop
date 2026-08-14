#requires -Version 5.1
[CmdletBinding()]
param(
  [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'DeepSeek-Harness-Desktop'),
  [switch]$SkipNativePickerPatch
)

$ErrorActionPreference = 'Stop'
$DshVersion = '0.1.0-rc.6'
$WebUiVersion = '0.1.12'
$repoRoot = Split-Path -Parent $PSCommandPath
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Require-Command([string]$Name, [string]$Hint) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) { throw "$Name 未找到。$Hint" }
  return $command.Source
}
function Backup-File([string]$Path, [string]$Label = 'config') {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $backupRoot = Join-Path $env:USERPROFILE '.dsh\backups\deepseek-harness-desktop'
  New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
  $leaf = Split-Path -Leaf $Path
  $backup = Join-Path $backupRoot "$timestamp-$Label-$leaf"
  Copy-Item -LiteralPath $Path -Destination $backup -Force
  Write-Host "已备份：$backup" -ForegroundColor DarkGray
}

Write-Step '检查 Windows 与 Node.js'
if ($env:OS -ne 'Windows_NT') { throw '此安装包只支持 Windows。' }
$nodeCommand = Require-Command 'node.exe' '请先安装 Node.js 22 或更高版本，并重新运行安装程序。'
$nodeVersionText = (& $nodeCommand --version).Trim()
if ($nodeVersionText -notmatch '^v(\d+)') { throw "无法读取 Node.js 版本：$nodeVersionText" }
$nodeMajor = [int]$Matches[1]
if ($nodeMajor -lt 22) { throw "当前 Node.js 为 $nodeVersionText；本安装包要求 Node.js 22 或更高版本。" }
$npmCommand = (Get-Command 'npm.cmd' -ErrorAction SilentlyContinue).Source
if (-not $npmCommand) { $npmCommand = Join-Path $env:ProgramFiles 'nodejs\npm.cmd' }
if (-not (Test-Path -LiteralPath $npmCommand)) { throw 'npm.cmd 未找到，请确认 Node.js 安装完整。' }

Write-Step "安装 DeepSeek Harness $DshVersion"
& $npmCommand install --global --no-fund --no-audit "@deepseek-ai/dsh@$DshVersion"
if ($LASTEXITCODE -ne 0) { throw "DeepSeek Harness 安装失败，退出码：$LASTEXITCODE" }
$dshCommand = Join-Path $env:APPDATA 'npm\dsh.cmd'
if (-not (Test-Path -LiteralPath $dshCommand)) { throw "安装后未找到：$dshCommand" }

Write-Step "安装 Web UI / 皮肤插件 $WebUiVersion"
& $dshCommand plugin --profile web add "@linxin666/dsh-web-ui-all@$WebUiVersion"
if ($LASTEXITCODE -ne 0) { throw "Web UI / 皮肤插件安装失败，退出码：$LASTEXITCODE" }

Write-Step '复制桌面启动器与补丁到用户安装目录'
New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot 'Start-DeepSeek-Harness.ps1') -Destination $InstallRoot -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'Start DeepSeek Harness.vbs') -Destination $InstallRoot -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'Start DeepSeek Harness.cmd') -Destination $InstallRoot -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'patches') -Destination $InstallRoot -Recurse -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'assets') -Destination $InstallRoot -Recurse -Force

Write-Step '写入安全的用户配置模板'
$globalPatch = Join-Path $env:USERPROFILE '.dsh\cordis.patch.yml'
$webProfileRoot = Join-Path $env:USERPROFILE '.dsh\profiles\web'
$profilePatch = Join-Path $webProfileRoot 'cordis.patch.yml'
$profilePackage = Join-Path $webProfileRoot 'package.json'
New-Item -ItemType Directory -Force -Path $webProfileRoot | Out-Null
Backup-File $globalPatch 'global'
Backup-File $profilePatch 'web-profile'
Copy-Item -LiteralPath (Join-Path $repoRoot 'config\skin.cordis.patch.yml') -Destination $globalPatch -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'config\web-profile.cordis.patch.yml') -Destination $profilePatch -Force
if (-not (Test-Path -LiteralPath $profilePackage)) {
  Set-Content -LiteralPath $profilePackage -Value '{"name":"dsh-profile-web","private":true}' -Encoding UTF8
}

if (-not $SkipNativePickerPatch) {
  Write-Step '应用 Windows 原生目录选择器置前补丁'
  & (Join-Path $InstallRoot 'patches\native-directory-picker-owner.patch.ps1') -DshRoot (Join-Path $env:APPDATA 'npm\node_modules\@deepseek-ai\dsh')
  if ($LASTEXITCODE -ne 0) { throw "原生目录选择器补丁应用失败，退出码：$LASTEXITCODE" }
} else {
  Write-Warning '已跳过原生目录选择器补丁；选择工作空间窗口可能仍被主窗口遮挡。'
}

Write-Step '创建桌面快捷方式'
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'DeepSeek Harness.lnk'
$vbsPath = Join-Path $InstallRoot 'Start DeepSeek Harness.vbs'
$iconPath = Join-Path $InstallRoot 'assets\DeepSeek Harness.ico'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
$shortcut.Arguments = '"' + $vbsPath + '"'
$shortcut.WorkingDirectory = $InstallRoot
$shortcut.IconLocation = "$iconPath,0"
$shortcut.Description = 'DeepSeek Harness 桌面窗口'
$shortcut.Save()

Write-Host "`n安装完成。" -ForegroundColor Green
Write-Host "桌面快捷方式：$shortcutPath"
Write-Host "安装目录：$InstallRoot"
Write-Host '提示：首次启动可能需要等待 npm/DeepSeek Harness 服务初始化。'
