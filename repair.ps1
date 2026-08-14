# Repair an existing installation without reinstalling the core by default.
[CmdletBinding()]
param(
  [ValidateSet('None','blue-fantasy','dragon-heir','miku','minecraft','qq98','ths','trading','whale-song','xp')][string]$Skin,
  [switch]$SkipNativePickerPatch,
  [switch]$NoShortcut
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath
$params = @{ DesktopOnly = $true; Repair = $true }
if ($PSBoundParameters.ContainsKey('Skin')) { $params.Skin = $Skin }
if ($SkipNativePickerPatch) { $params.SkipNativePickerPatch = $true }
if ($NoShortcut) { $params.NoShortcut = $true }
& (Join-Path $root 'install.ps1') @params
exit $LASTEXITCODE
