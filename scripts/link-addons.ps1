<#
.SYNOPSIS
Junctions each addons/* folder of this checkout into the game's Interface\AddOns folder,
so edits go live after /reload.

.DESCRIPTION
Safe to run again: a junction that already points at this checkout is left alone, and one
that points somewhere else (another checkout or worktree) is re-pointed. A real folder or
file with an addon's name is never touched; the script stops and names it.

.PARAMETER AddOnsPath
The beta's Interface\AddOns folder, for example
"C:\Program Files (x86)\World of Warcraft\_beta_\Interface\AddOns".

.EXAMPLE
.\scripts\link-addons.ps1 -AddOnsPath "C:\Program Files (x86)\World of Warcraft\_beta_\Interface\AddOns"
#>
param(
	[Parameter(Mandatory = $true)]
	[string]$AddOnsPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $AddOnsPath -PathType Container)) {
	throw "AddOns folder not found: $AddOnsPath"
}
$AddOnsPath = (Resolve-Path -LiteralPath $AddOnsPath).ProviderPath
$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\addons')).ProviderPath

function Get-FullPath([string]$Path) {
	return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

foreach ($addon in Get-ChildItem -LiteralPath $source -Directory) {
	$link = Join-Path $AddOnsPath $addon.Name
	$target = Get-FullPath $addon.FullName

	if (Test-Path -LiteralPath $link) {
		$item = Get-Item -LiteralPath $link -Force
		if ($item.LinkType -ne 'Junction') {
			throw "$link exists and is not a junction. Move it out of the way, then run this again."
		}
		if ((Get-FullPath ([string]$item.Target)) -eq $target) {
			Write-Output "ok       $($addon.Name) -> $target"
			continue
		}
		# rmdir on a junction removes only the link, never what it points at.
		cmd /c rmdir "$link"
		if ($LASTEXITCODE -ne 0) { throw "Could not remove the old junction $link" }
		$verb = 'relinked'
	}
	else {
		$verb = 'linked  '
	}

	cmd /c mklink /J "$link" "$target" | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "mklink /J failed for $link" }
	Write-Output "$verb $($addon.Name) -> $target"
}
