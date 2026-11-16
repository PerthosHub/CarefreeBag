---
name: rond-af
description: Sluit een CarefreeBag-werkstap, feature of chat af. Gebruik dit wanneer Johan zegt dat iets klaar is, af mag, afgerond moet worden, of vraagt om te borgen, committen of pushen. Laat een reviewer meekijken, werkt CLAUDE.md/CHANGELOG bij, installeert de dev-versie, commit en pusht naar main (zonder release).
---

# RondAf (CarefreeBag)

Kort en vast. Geen release: dat is een aparte stap (zie "Uitbrengen" in `CLAUDE.md`).

## 1. Begrens
- Wat is af, wat bleef buiten scope, wat is nog open? Onduidelijk of iets "klaar" is: eerst vragen.
- `git status --short --branch`, `git diff`, `git diff --staged`. Neem niets mee wat niet bij deze stap hoort.

## 2. Frisse blik
Start een subagent (general-purpose) die **alleen de diff** krijgt, niet hoe die tot stand kwam. Opdracht: zoek echte fouten, let op
- globals / `ns`-regels (zie `CLAUDE.md`), `local` vs `ns.X` voor waarden die veranderen;
- per karakter (`CharEntry()`), twee karakters met dezelfde voornaam;
- elke nieuwe tekst in alle 8 talen (`Locales.lua`);
- WoW-API die per versie verschilt (retail / Forever / Classic), `pcall` waar Blizzard-functies kunnen ontbreken;
- ontbrekende test in `tests/scenarios/`.
Los op wat binnen scope valt; meld wat je laat liggen met reden. Vindt hij niets: zeg dat en ga door.

## 3. Docs
- `CLAUDE.md` → "Stand van zaken": wat er nu is, wat Johan nog in het spel moet testen, wat open is. Kort houden; verouderde regels inkorten.
- `CHANGELOG.md`: alleen als spelers iets merken, onder een kop voor de volgende versie (Engels, in spelerstaal).
- Lokaal geheugen met een projectregel? Verhuis die naar `CLAUDE.md`.

## 4. Checks
- `lua5.1 tests/run.lua`, `python3 tests/check_locales.py`, `python3 tests/check_globals.py` als ze lokaal bestaan.
- Niet lokaal (Windows zonder Lua/Python): zeg dat; GitHub Actions draait ze na de push.
- Lokale sessie: installeer de dev-versie (zie "Installeren op Johans pc" in `CLAUDE.md`), vergelijk de hashes en zeg wat Johan in het spel moet testen.

## 5. Commit en push
- Stage alleen bestanden van deze stap, bekijk de staged diff.
- `git -c user.name="Perthos" -c user.email="perthos@users.noreply.github.com" commit`, korte Engelse boodschap in projectstijl.
- **Geen** `Co-Authored-By`, `Claude-Session` of "Generated with Claude".
- Push naar `main` (`git push origin HEAD:main`, fast-forward). Op een andere branch (cloud): samenvoegen met `main`, of als dat niet kan bovenaan "Stand van zaken" op `main` de branchnaam en wat daar af is zetten.
- Kijk of de testrun groen wordt (`gh run list --workflow test.yml --limit 1`); rood: repareren of melden.

## 6. Overdracht (kort, met emoji)
Commit-hash, gepusht ja/nee, CI-uitslag, wat Johan in het spel moet testen, wat open blijft, de volgende stap. Release nodig? Vraag het, niet zelf doen.
