# Installeert CarefreeBag (dev-versie) in de AddOns-map van WoW Forever op deze pc.
# Gebruik: powershell -NoProfile -ExecutionPolicy Bypass -File tools\install.ps1 [-Quiet]
# Zoekt zelf de map: eerst de draaiende Wow.exe, dan de bekende paden (desktop/laptop).
param([switch]$Quiet)
$ErrorActionPreference = 'Stop'

$src = Split-Path -Parent $PSScriptRoot

# 1. WoW Forever-map vinden
$forever = $null
$proc = Get-Process Wow -ErrorAction SilentlyContinue | Where-Object { $_.Path -match '\\_forever_\\' } | Select-Object -First 1
if ($proc) { $forever = Split-Path -Parent $proc.Path }
if (-not $forever) {
	$candidates = @(
		'C:\Games\World of Warcraft Forever\World of Warcraft\_forever_',  # desktop
		'C:\Games\World of Warcraft\_forever_'                             # laptop
	)
	$forever = $candidates | Where-Object { Test-Path (Join-Path $_ 'Interface\AddOns') } | Select-Object -First 1
}
if (-not $forever) {
	Write-Output 'CFB install: geen WoW Forever-map gevonden op deze pc, niets geinstalleerd.'
	exit 0
}
$dst = Join-Path $forever 'Interface\AddOns\CarefreeBag'

# 2. Versie uit Core.lua (ns.VERSION = "x.y.z")
$m = Select-String -Path (Join-Path $src 'Core.lua') -Pattern 'ns\.VERSION\s*=\s*"([^"]+)"' | Select-Object -First 1
$version = if ($m) { $m.Matches[0].Groups[1].Value + '-dev' } else { 'dev' }

# 3. Bestanden: .toc, *.lua, media\ (niet tests, .git, .github, .claude)
$files = @(Get-ChildItem $src -File -Filter '*.lua') + @(Get-Item (Join-Path $src 'CarefreeBag.toc'))
$media = Join-Path $src 'media'
if (Test-Path $media) { $files += Get-ChildItem $media -File -Recurse }

New-Item -ItemType Directory -Force $dst | Out-Null
$copied = 0
foreach ($f in $files) {
	$rel = $f.FullName.Substring($src.Length + 1)
	$target = Join-Path $dst $rel
	New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
	if ($f.Name -eq 'CarefreeBag.toc') {
		$text = [IO.File]::ReadAllText($f.FullName) -replace '## Version: .*', "## Version: $version"
		if (-not (Test-Path $target) -or [IO.File]::ReadAllText($target) -ne $text) { [IO.File]::WriteAllText($target, $text); $copied++ }
		continue
	}
	if (-not (Test-Path $target) -or (Get-FileHash $f.FullName).Hash -ne (Get-FileHash $target).Hash) {
		Copy-Item $f.FullName $target -Force; $copied++
	}
}

# 4. Controle met hashes
$bad = @()
foreach ($f in $files) {
	if ($f.Name -eq 'CarefreeBag.toc') { continue }
	$target = Join-Path $dst ($f.FullName.Substring($src.Length + 1))
	if (-not (Test-Path $target) -or (Get-FileHash $f.FullName).Hash -ne (Get-FileHash $target).Hash) { $bad += $f.Name }
}
if ($bad.Count -gt 0) {
	Write-Output "CFB install: FOUT, verschilt na kopieren: $($bad -join ', ')"
	exit 1
}
if ($copied -gt 0 -or -not $Quiet) {
	$extra = if ($proc) { ' WoW draait: /reload om te laden.' } else { '' }
	Write-Output "CFB install: $version in $dst ($copied bestand(en) bijgewerkt, hashes ok).$extra"
}
