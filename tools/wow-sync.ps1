# WoW-instellingen (WTF) wisselen tussen desktop en laptop via Google Drive.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\wow-sync.ps1 backup
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\wow-sync.ps1 restore [-DryRun] [-From <zip>]
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\wow-sync.ps1 check
#
# backup : zip van WTF + Interface\AddOns naar de back-upmap, naam wow-backup_<datum>_<tijd>_<PC>.zip
# restore: eerst een back-up van deze pc, dan WTF uit de nieuwste back-up van de ANDERE pc (of -From).
#          Config.wtf (grafisch, resolutie) blijft van deze pc. Addons worden niet gekopieerd
#          (die komen via CurseForge / tools\install.ps1); wel een lijstje met verschillen.
# check  : één regel als er een nieuwere back-up van de andere pc is dan je laatste terugzetting.
# WoW moet dicht zijn voor backup en restore (WoW schrijft WTF bij afsluiten).
param(
	[Parameter(Position = 0)][ValidateSet('backup', 'restore', 'check')][string]$Action = 'check',
	[string]$From,
	[switch]$DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'WowPaths.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem

$pc = $env:COMPUTERNAME.ToUpper()
$forever = Find-WowForever
$backupDir = Find-WowBackupDir
if (-not $forever) { Write-Output 'wow-sync: geen WoW Forever-map gevonden op deze pc.'; exit ($(if ($Action -eq 'check') { 0 } else { 1 })) }
if (-not $backupDir) { Write-Output 'wow-sync: geen back-upmap gevonden (Mijn Drive\WoW-backup). Staat Google Drive aan?'; exit ($(if ($Action -eq 'check') { 0 } else { 1 })) }
$marker = Join-Path $forever 'WTF\wow-sync.txt'

# Alle back-ups met pc en tijd uit de naam
function Get-Backups {
	Get-ChildItem $backupDir -Filter 'wow-backup_*.zip' | ForEach-Object {
		if ($_.Name -match '^wow-backup_(\d{4}-\d{2}-\d{2})_(\d{4})_(.+)\.zip$') {
			[pscustomobject]@{
				File = $_
				Time = [datetime]::ParseExact("$($Matches[1]) $($Matches[2])", 'yyyy-MM-dd HHmm', $null)
				Pc   = $Matches[3].ToUpper()
			}
		}
	} | Sort-Object Time -Descending
}

function Assert-WowClosed {
	if (Get-WowProcess) { Write-Output 'wow-sync: WoW draait nog. Sluit WoW eerst af (anders schrijft WoW de instellingen weer over).'; exit 1 }
}

function Invoke-Backup {
	Assert-WowClosed
	$out = Join-Path $backupDir ("wow-backup_{0}_{1}.zip" -f (Get-Date -Format 'yyyy-MM-dd_HHmm'), $pc)
	if (Test-Path $out) { Write-Output "wow-sync: $out bestaat al, wacht een minuut."; exit 1 }
	$files = @()
	foreach ($d in 'WTF', 'Interface\AddOns') { $p = Join-Path $forever $d; if (Test-Path $p) { $files += Get-ChildItem $p -Recurse -File } }
	$zip = [IO.Compression.ZipFile]::Open($out, 'Create')
	try {
		foreach ($f in $files) {
			$rel = $f.FullName.Substring($forever.Length + 1) -replace '\\', '/'
			[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $rel)
		}
	} finally { $zip.Dispose() }
	$z = [IO.Compression.ZipFile]::OpenRead($out); $n = $z.Entries.Count; $z.Dispose()
	if ($n -ne $files.Count) { Write-Output "wow-sync: FOUT, zip heeft $n van $($files.Count) bestanden: $out"; exit 1 }
	Write-Output ("wow-sync: back-up gemaakt: {0} ({1} bestanden, {2:N0} MB)" -f $out, $n, ((Get-Item $out).Length / 1MB))
}

# Addon-mappen met versie uit de .toc
function Get-ZipAddons($z) {
	$h = @{}
	foreach ($e in $z.Entries) {
		$p = $e.FullName -replace '\\', '/'
		if ($p -match '^Interface/AddOns/([^/]+)/\1(_[A-Za-z]+)?\.toc$' -and -not $h[$Matches[1]]) {
			$name = $Matches[1]
			$r = New-Object IO.StreamReader($e.Open()); $t = $r.ReadToEnd(); $r.Close()
			$h[$name] = if ($t -match '(?m)^## Version:\s*(.+?)\s*$') { $Matches[1] } else { '?' }
		}
	}
	$h
}
function Get-LocalAddons {
	$h = @{}
	Get-ChildItem (Join-Path $forever 'Interface\AddOns') -Directory | ForEach-Object {
		$toc = Get-ChildItem $_.FullName -File | Where-Object { $_.Name -match '^' + [regex]::Escape($_.Directory.Name) + '(_[A-Za-z]+)?\.toc$' } | Select-Object -First 1
		if ($toc) { $t = Get-Content $toc.FullName -Raw; $h[$_.Name] = if ($t -match '(?m)^## Version:\s*(.+?)\s*$') { $Matches[1] } else { '?' } }
	}
	$h
}

function Invoke-Restore {
	if (-not $DryRun) { Assert-WowClosed }
	if ($From) { $zipFile = Get-Item $From }
	else {
		$other = Get-Backups | Where-Object { $_.Pc -ne $pc } | Select-Object -First 1
		if (-not $other) { Write-Output "wow-sync: geen back-up van een andere pc gevonden in $backupDir."; exit 1 }
		$zipFile = $other.File
	}
	Write-Output "wow-sync: terugzetten uit $($zipFile.Name)$(if ($DryRun) { ' (DryRun: er verandert niets)' })"
	if (-not $DryRun) { Invoke-Backup }

	$wtf = Join-Path $forever 'WTF'
	$z = [IO.Compression.ZipFile]::OpenRead($zipFile.FullName)
	try {
		$n = 0; $bad = @()
		foreach ($e in $z.Entries) {
			$p = $e.FullName -replace '\\', '/'
			if ($p -notlike 'WTF/*' -or $p.EndsWith('/') -or $p -eq 'WTF/Config.wtf' -or $p -eq 'WTF/wow-sync.txt') { continue }
			$target = [IO.Path]::GetFullPath((Join-Path $forever ($p -replace '/', '\')))
			if (-not $target.StartsWith($wtf + '\', [StringComparison]::OrdinalIgnoreCase)) { $bad += $p; continue }
			$n++
			if ($DryRun) { continue }
			New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
			[IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
			if ((Get-Item $target).Length -ne $e.Length) { $bad += $p }
		}
		Write-Output "wow-sync: $n WTF-bestanden $(if ($DryRun) { 'zouden worden' } else { 'zijn' }) teruggezet (Config.wtf van deze pc blijft)."
		if ($bad.Count) { Write-Output "wow-sync: FOUT bij: $($bad -join ', ')"; exit 1 }

		# Verschil in addons (alleen melden)
		$there = Get-ZipAddons $z; $here = Get-LocalAddons
		$missing = $there.Keys | Where-Object { -not $here.ContainsKey($_) } | Sort-Object
		$extra = $here.Keys | Where-Object { -not $there.ContainsKey($_) } | Sort-Object
		$diff = $there.Keys | Where-Object { $here.ContainsKey($_) -and $here[$_] -ne $there[$_] } | Sort-Object
		if ($missing) { Write-Output "wow-sync: addons die hier ontbreken (installeer via CurseForge/git): $($missing -join ', ')" }
		if ($extra) { Write-Output "wow-sync: addons alleen op deze pc: $($extra -join ', ')" }
		if ($diff) { Write-Output ("wow-sync: andere versie: " + (($diff | ForEach-Object { "$_ (hier $($here[$_]), daar $($there[$_]))" }) -join ', ')) }
	} finally { $z.Dispose() }

	if (-not $DryRun) {
		Set-Content -Path $marker -Encoding UTF8 -Value "$($zipFile.Name)`r`n$(Get-Date -Format 'yyyy-MM-dd HH:mm')"
		Write-Output 'wow-sync: klaar. Start WoW en kijk of je instellingen kloppen.'
	}
}

function Invoke-Check {
	$all = Get-Backups
	$other = $all | Where-Object { $_.Pc -ne $pc } | Select-Object -First 1
	if (-not $other) { return }
	$since = [datetime]::MinValue
	$mine = $all | Where-Object { $_.Pc -eq $pc } | Select-Object -First 1
	if ($mine) { $since = $mine.Time }
	if (Test-Path $marker) {
		$restored = (Get-Content $marker -TotalCount 1)
		$r = $all | Where-Object { $_.File.Name -eq $restored } | Select-Object -First 1
		if ($r -and $r.Time -gt $since) { $since = $r.Time }
	}
	if ($other.Time -gt $since) {
		Write-Output ("wow-sync: er is een nieuwere WoW-back-up van {0} ({1:dd-MM HH:mm}). Terugzetten (WoW dicht): tools\wow-sync.ps1 restore" -f $other.Pc, $other.Time)
	}
}

switch ($Action) {
	'backup' { Invoke-Backup }
	'restore' { Invoke-Restore }
	'check' { Invoke-Check }
}
