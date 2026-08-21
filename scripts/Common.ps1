# Shared helpers for DeepSeek Harness Desktop scripts.
Set-StrictMode -Version Latest

function Get-ProjectRoot {
  return (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
}

function Get-VersionManifest {
  param([string]$ProjectRoot = (Get-ProjectRoot))
  $path = Join-Path $ProjectRoot 'versions.json'
  if (-not (Test-Path -LiteralPath $path)) { throw "未找到版本清单：$path" }
  try { return (Read-Utf8Text $path | ConvertFrom-Json) }
  catch { throw "版本清单不是有效 JSON：$path；$($_.Exception.Message)" }
}

function Get-CommandPath {
  param([Parameter(Mandatory)][string]$Name)
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) { return $null }
  if ($command.Path) { return [string]$command.Path }
  if ($command.Source -and (Test-Path -LiteralPath $command.Source)) { return [string]$command.Source }
  return $null
}

function Get-NpmGlobalBin {
  [CmdletBinding()]
  param([string]$NpmCommand)
  $fallback = Join-Path $env:APPDATA 'npm'
  if ([string]::IsNullOrWhiteSpace($NpmCommand)) {
    $NpmCommand = Get-CommandPath 'npm.cmd'
    if (-not $NpmCommand) {
      $candidate = Join-Path $env:ProgramFiles 'nodejs\npm.cmd'
      if (Test-Path -LiteralPath $candidate) { $NpmCommand = $candidate }
    }
  }
  $prefix = $null
  $exitCode = -1
  if ($NpmCommand -and (Test-Path -LiteralPath $NpmCommand)) {
    try {
      $prefix = ((@(& $NpmCommand prefix --global 2>$null) | Select-Object -First 1) -as [string]).Trim()
      $exitCode = $LASTEXITCODE
    } catch { }
  }
  if ($exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($prefix)) {
    try { return [System.IO.Path]::GetFullPath($prefix) } catch { return $prefix }
  }
  return $fallback
}

function Test-PathContainsDirectory {
  param([AllowEmptyString()][string]$PathValue, [Parameter(Mandatory)][string]$Directory)
  $needle = $Directory.Trim().Trim('"').TrimEnd('\')
  if ([string]::IsNullOrWhiteSpace($needle)) { return $false }
  return @($PathValue -split ';' | Where-Object {
    $_ -and $_.Trim().Trim('"').TrimEnd('\') -ieq $needle
  }).Count -gt 0
}

function Ensure-NpmGlobalBinOnPath {
  [CmdletBinding()]
  param([switch]$Persist, [string]$NpmGlobalBin = (Get-NpmGlobalBin))
  if ([string]::IsNullOrWhiteSpace($NpmGlobalBin)) { return $null }
  try { $NpmGlobalBin = [System.IO.Path]::GetFullPath($NpmGlobalBin) } catch { }
  if (-not (Test-PathContainsDirectory -PathValue ([string]$env:Path) -Directory $NpmGlobalBin)) {
    $env:Path = if ([string]::IsNullOrWhiteSpace($env:Path)) { $NpmGlobalBin } else { "$NpmGlobalBin;$env:Path" }
  }
  $persisted = $false
  if ($Persist) {
    try {
      $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
      if (-not (Test-PathContainsDirectory -PathValue ([string]$userPath) -Directory $NpmGlobalBin)) {
        $updatedUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $NpmGlobalBin } else { "$userPath;$NpmGlobalBin" }
        [Environment]::SetEnvironmentVariable('Path', $updatedUserPath, 'User')
      }
      $persisted = $true
    } catch {
      Write-Warning "无法写入用户 PATH；桌面启动器仍会为 DSH 临时补充 $NpmGlobalBin。$($_.Exception.Message)"
    }
  }
  return [pscustomobject]@{ Path = $NpmGlobalBin; Persisted = $persisted }
}

function Get-PnpmCommandPath {
  $npmGlobalBin = Get-NpmGlobalBin
  $candidates = @(
    (Join-Path $npmGlobalBin 'pnpm.cmd'),
    (Get-CommandPath 'pnpm.cmd'),
    (Get-CommandPath 'pnpm')
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
  return ($candidates | Select-Object -First 1)
}
function Get-DshCommandPath {
  $candidates = @(
    (Join-Path $env:APPDATA 'npm\dsh.cmd'),
    (Get-CommandPath 'dsh.cmd'),
    (Get-CommandPath 'dsh')
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
  return ($candidates | Select-Object -First 1)
}

function Get-WebProfileRoot {
  return (Join-Path $env:USERPROFILE '.dsh\profiles\web')
}

function Get-WebProfilePackagePath {
  return (Join-Path (Get-WebProfileRoot) 'package.json')
}

function Get-InstallStatePath {
  param([string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'DeepSeek-Harness-Desktop'))
  return (Join-Path $InstallRoot 'install-state.json')
}

function Get-FileSha256 {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-Utf8Text {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}
function Save-JsonFile {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Value)
  $parent = Split-Path -Parent $Path
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  $json = $Value | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Read-JsonFile {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  try { return (Read-Utf8Text $Path | ConvertFrom-Json) }
  catch { throw "JSON 文件无效：$Path；$($_.Exception.Message)" }
}

function Ensure-ObjectProperty {
  param([Parameter(Mandatory)]$Object, [Parameter(Mandatory)][string]$Name, $DefaultValue)
  if ($null -eq $Object) { throw "无法在空对象上创建属性：$Name" }
  $property = $Object.PSObject.Properties[$Name]
  if (-not $property) {
    $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $DefaultValue
  } elseif ($null -eq $property.Value) {
    $property.Value = $DefaultValue
  }
  return $Object.$Name
}

function Ensure-WebProfilePackage {
  param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Spec,
    [switch]$AddBundle,
    [switch]$RemoveBundle
  )
  $profileRoot = Get-WebProfileRoot
  New-Item -ItemType Directory -Force -Path $profileRoot | Out-Null
  $path = Get-WebProfilePackagePath
  if (Test-Path -LiteralPath $path) {
    $pkg = Read-JsonFile $path
  } else {
    $pkg = [pscustomobject]@{ name = 'dsh-profile-web'; private = $true; dependencies = [pscustomobject]@{}; dsh = [pscustomobject]@{ profile = [pscustomobject]@{ bundles = @() } } }
  }
  Ensure-ObjectProperty $pkg 'name' 'dsh-profile-web' | Out-Null
  Ensure-ObjectProperty $pkg 'private' $true | Out-Null
  $deps = Ensure-ObjectProperty $pkg 'dependencies' ([pscustomobject]@{})
  if (-not $deps) { $deps = [pscustomobject]@{}; $pkg.dependencies = $deps }
  if (-not $deps.PSObject.Properties[$Name]) {
    $deps | Add-Member -MemberType NoteProperty -Name $Name -Value $Spec
  } else {
    $deps.PSObject.Properties[$Name].Value = $Spec
  }
  $dsh = Ensure-ObjectProperty $pkg 'dsh' ([pscustomobject]@{})
  $profile = Ensure-ObjectProperty $dsh 'profile' ([pscustomobject]@{})
  $bundles = Ensure-ObjectProperty $profile 'bundles' @()
  $bundles = @($bundles | Where-Object { $_ -and $_ -ne $Name })
  if ($AddBundle) { $bundles += $Name }
  $profile.bundles = @($bundles | Select-Object -Unique)
  Save-JsonFile -Path $path -Value $pkg
  return $pkg
}

function Remove-WebProfileDependency {
  param(
    [Parameter(Mandatory)][string]$Name,
    [switch]$RemoveBundle
  )
  $path = Get-WebProfilePackagePath
  if (-not (Test-Path -LiteralPath $path)) { return $false }
  $pkg = Read-JsonFile $path
  $changed = $false
  $deps = $pkg.PSObject.Properties['dependencies']
  if ($deps -and $deps.Value -and $deps.Value.PSObject.Properties[$Name]) {
    $deps.Value.PSObject.Properties.Remove($Name)
    $changed = $true
  }
  $dsh = $pkg.PSObject.Properties['dsh']
  if ($RemoveBundle -and $dsh -and $dsh.Value) {
    $profile = $dsh.Value.PSObject.Properties['profile']
    if ($profile -and $profile.Value) {
      $bundlesProperty = $profile.Value.PSObject.Properties['bundles']
      if ($bundlesProperty) {
        $old = @($bundlesProperty.Value)
        $new = @($old | Where-Object { $_ -and $_ -ne $Name })
        if (($old -join "`n") -ne ($new -join "`n")) { $bundlesProperty.Value = $new; $changed = $true }
      }
    }
  }
  if ($changed) { Save-JsonFile -Path $path -Value $pkg }
  return $changed
}

function Update-ManagedTextBlock {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Marker,
    [Parameter(Mandatory)][string]$Block,
    [string]$BackupRoot = (Join-Path $env:USERPROFILE '.dsh\backups\deepseek-harness-desktop'),
    [string]$LegacyPattern
  )
  $old = if (Test-Path -LiteralPath $Path) { Read-Utf8Text $Path } else { '' }
  $begin = "# BEGIN $Marker"
  $end = "# END $Marker"
  $pattern = '(?ms)^' + [regex]::Escape($begin) + '\r?\n.*?^' + [regex]::Escape($end) + '\r?\n?'
  $updated = [regex]::Replace($old, $pattern, '')
  if ($LegacyPattern) { $updated = [regex]::Replace($updated, $LegacyPattern, '') }
  $cleanBlock = $Block.TrimEnd()
  $managed = "$begin`r`n$cleanBlock`r`n$end`r`n"
  $updated = ($updated.TrimEnd() + "`r`n`r`n" + $managed).TrimStart()
  $backup = $null
  if ($old -ne $updated -and (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    $leaf = Split-Path -Leaf $Path
    $safeMarker = ($Marker -replace '[^A-Za-z0-9._-]', '-')
    $backup = Join-Path $BackupRoot "$(Get-Date -Format yyyyMMdd-HHmmss-fff)-managed-$safeMarker-$leaf"
    $suffix = 0
    while (Test-Path -LiteralPath $backup) { $suffix++; $backup = Join-Path $BackupRoot "$(Get-Date -Format yyyyMMdd-HHmmss-fff)-managed-$safeMarker-$suffix-$leaf" }
    Copy-Item -LiteralPath $Path -Destination $backup -Force
  }
  if ($old -ne $updated) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [System.IO.File]::WriteAllText($Path, $updated, [System.Text.UTF8Encoding]::new($false))
  }
  return [pscustomobject]@{ Changed = ($old -ne $updated); Backup = $backup; Path = $Path; Marker = $Marker }
}

function Remove-ManagedTextBlock {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Marker)
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $old = Read-Utf8Text $Path
  $begin = "# BEGIN $Marker"
  $end = "# END $Marker"
  $pattern = '(?ms)^' + [regex]::Escape($begin) + '\r?\n.*?^' + [regex]::Escape($end) + '\r?\n?'
  $updated = [regex]::Replace($old, $pattern, '')
  if ($old -ne $updated) {
    if ([string]::IsNullOrWhiteSpace($updated)) { Remove-Item -LiteralPath $Path -Force }
    else { [System.IO.File]::WriteAllText($Path, $updated.Trim() + "`r`n", [System.Text.UTF8Encoding]::new($false)) }
    return $true
  }
  return $false
}

function Get-SkinPackageName {
  param([Parameter(Mandatory)][string]$Skin)
  return "@linxin666/dsh-client-ui-skin-$Skin"
}

function Get-InstalledSkinSource {
  param([Parameter(Mandatory)][string]$Skin)
  $path = Join-Path (Get-WebProfileRoot) "node_modules\@linxin666\dsh-skins\skins\$Skin"
  if (Test-Path -LiteralPath (Join-Path $path 'package.json')) { return $path }
  return $null
}

function Get-StableSkinPath {
  param([Parameter(Mandatory)][string]$Skin)
  return (Join-Path $env:USERPROFILE ".dsh\local-plugins\dsh-client-ui-skin-$Skin")
}

function Ensure-LocalSkinPackage {
  param([Parameter(Mandatory)][string]$Skin)
  $source = Get-InstalledSkinSource $Skin
  if (-not $source) { throw "未找到 Web UI 自带的皮肤资源：$Skin。请确认 @linxin666/dsh-web-ui-all 已安装，或使用 -Skin None。" }
  $target = Get-StableSkinPath $Skin
  $sourceVersion = (Read-Utf8Text (Join-Path $source 'package.json') | ConvertFrom-Json).version
  $targetVersion = $null
  if (Test-Path -LiteralPath (Join-Path $target 'package.json')) { $targetVersion = (Read-Utf8Text (Join-Path $target 'package.json') | ConvertFrom-Json).version }
  if ($sourceVersion -ne $targetVersion) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
  }
  return $target
}
