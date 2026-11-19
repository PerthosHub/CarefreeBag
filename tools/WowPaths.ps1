# Gedeelde paden voor install.ps1 en wow-sync.ps1 (dot-source: . "$PSScriptRoot\WowPaths.ps1").
# Nieuwe pc met een ander pad? Voeg het hier toe.

$WowForeverCandidates = @(
	'C:\Games\World of Warcraft Forever\World of Warcraft\_forever_',  # desktop (ZOLDER)
	'C:\Games\World of Warcraft\_forever_'                             # laptop (LAPTOP)
)

$WowBackupCandidates = @(
	(Join-Path $env:USERPROFILE 'Mijn Drive\WoW-backup'),
	(Join-Path $env:USERPROFILE 'My Drive\WoW-backup'),
	'G:\Mijn Drive\WoW-backup',
	'G:\My Drive\WoW-backup'
)

function Get-WowProcess {
	Get-Process Wow -ErrorAction SilentlyContinue | Where-Object { $_.Path -match '\\_forever_\\' } | Select-Object -First 1
}

# De _forever_-map: eerst de draaiende Wow.exe, dan de bekende paden.
function Find-WowForever {
	$p = Get-WowProcess
	if ($p) { return (Split-Path -Parent $p.Path) }
	$WowForeverCandidates | Where-Object { Test-Path (Join-Path $_ 'Interface\AddOns') } | Select-Object -First 1
}

# De back-upmap in Google Drive (eerste die bestaat).
function Find-WowBackupDir {
	$WowBackupCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
