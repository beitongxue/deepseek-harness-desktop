# Static checks for the Windows installer and launcher.
#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

$scriptFiles = @(Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse |
  Where-Object { $_.FullName -notmatch '[\\/]node_modules[\\/]' })
foreach ($file in $scriptFiles) {
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
  if ($parseErrors.Count -gt 0) {
    $messages = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
    throw "PowerShell 语法错误：$($file.FullName)：$messages"
  }
}

$manifestPath = Join-Path $root 'versions.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($name in @('dsh', 'webUi', 'defaultSkin', 'minimumNodeMajor', 'defaultPort')) {
  if (-not $manifest.PSObject.Properties[$name] -or $null -eq $manifest.$name) {
    throw "versions.json 缺少字段：$name"
  }
}
if ([int]$manifest.minimumNodeMajor -lt 18) { throw 'minimumNodeMajor 不合理。' }
if ([int]$manifest.defaultPort -lt 1 -or [int]$manifest.defaultPort -gt 65535) { throw 'defaultPort 不在有效范围内。' }

$requiredFiles = @(
  'install.ps1',
  'repair.ps1',
  'uninstall.ps1',
  'diagnose.ps1',
  'Start-DeepSeek-Harness.ps1',
  'scripts/Common.ps1',
  'patches/native-directory-picker-owner.patch.ps1',
  'config/skin.cordis.patch.yml',
  'config/web-profile.cordis.patch.yml'
)
foreach ($relative in $requiredFiles) {
  $path = Join-Path $root $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "缺少必要文件：$path" }
}

$profileTemplate = Get-Content -LiteralPath (Join-Path $root 'config/web-profile.cordis.patch.yml') -Raw -Encoding UTF8
if ($profileTemplate -notmatch '(?m)^\s*\[\]\s*$') { throw 'web profile patch 模板必须包含顶层 YAML 数组 []。' }
foreach ($launcher in @('Start DeepSeek Harness.cmd', 'Start DeepSeek Harness.vbs')) {
  $text = Get-Content -LiteralPath (Join-Path $root $launcher) -Raw -Encoding UTF8
  if ($text.Contains('`r`n')) { throw "启动文件包含字面量 `r`n：$launcher" }
}

Write-Host "静态检查通过：$($scriptFiles.Count) 个 PowerShell 文件。" -ForegroundColor Green