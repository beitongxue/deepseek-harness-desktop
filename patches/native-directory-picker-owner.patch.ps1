#requires -Version 5.1
[CmdletBinding()]
param(
  [string]$DshRoot = (Join-Path $env:APPDATA 'npm\node_modules\@deepseek-ai\dsh'),
  [switch]$Restore
)

$ErrorActionPreference = 'Stop'
$marker = 'codex: dsh-desktop native picker owner patch'
$workerCandidates = @(
  (Join-Path $DshRoot 'node_modules\@deepseek-ai\dsh-host-directory-picker-native\lib\worker.cjs'),
  (Join-Path $env:APPDATA 'npm\node_modules\@deepseek-ai\dsh\node_modules\@deepseek-ai\dsh-host-directory-picker-native\lib\worker.cjs')
) | Select-Object -Unique
$worker = $workerCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $worker) { throw "未找到 dsh-host-directory-picker-native 的 worker.cjs。检查路径：$DshRoot" }

function Get-LatestBackup([string]$Path) {
  Get-ChildItem -LiteralPath (Split-Path -Parent $Path) -Filter ((Split-Path -Leaf $Path) + '.codex-backup-*') -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

if ($Restore) {
  $backup = Get-LatestBackup $worker
  if (-not $backup) { Write-Host '未找到原生目录选择器补丁备份，跳过恢复。'; exit 0 }
  Copy-Item -LiteralPath $backup.FullName -Destination $worker -Force
  Write-Host "已恢复原生目录选择器：$worker <- $($backup.FullName)"
  exit 0
}

$content = [System.IO.File]::ReadAllText($worker)
if ($content.Contains($marker)) {
  Write-Host "原生目录选择器补丁已存在：$worker"
  exit 0
}

$threadAnchor = 'const getCurrentThreadId = kernel32.func("__stdcall", "GetCurrentThreadId", "uint32", []);'
$ownerBinding = 'const getForegroundWindow = user32.func("__stdcall", "GetForegroundWindow", "void *", []);'
$required = @(
  $threadAnchor,
  'show: () => method(dialog, SLOT_SHOW, protoShow)(null),',
  'const shown = dialog.show();'
)
foreach ($anchor in $required) {
  if (-not $content.Contains($anchor)) {
    throw "worker.cjs 结构与已验证版本不一致，未执行修改。缺少锚点：$anchor"
  }
}

$backupPath = "$worker.codex-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
Copy-Item -LiteralPath $worker -Destination $backupPath -Force

$updated = $content
$threadReplacement = $threadAnchor + "`r`n`t// " + $marker + "`r`n`t" + $ownerBinding
$updated = $updated.Replace($threadAnchor, $threadReplacement)
$updated = $updated.Replace(
  'currentThreadId: () => getCurrentThreadId(),',
  "currentThreadId: () => getCurrentThreadId(),`r`n`t`tforegroundWindow: () => getForegroundWindow(),"
)
$updated = $updated.Replace(
  'show: () => method(dialog, SLOT_SHOW, protoShow)(null),',
  'show: (owner = null) => method(dialog, SLOT_SHOW, protoShow)(owner),'
)
$updated = $updated.Replace(
  'const shown = dialog.show();',
  'const shown = dialog.show(bindings.foregroundWindow());'
)

$verification = @(
  $ownerBinding,
  'foregroundWindow: () => getForegroundWindow(),',
  'show: (owner = null) => method(dialog, SLOT_SHOW, protoShow)(owner),',
  'const shown = dialog.show(bindings.foregroundWindow());'
)
foreach ($item in $verification) {
  if (-not $updated.Contains($item)) { throw "补丁生成后校验失败：$item" }
}
[System.IO.File]::WriteAllText($worker, $updated, [System.Text.UTF8Encoding]::new($false))
Write-Host "已应用原生目录选择器置前补丁：$worker"
Write-Host "原始文件备份：$backupPath"
