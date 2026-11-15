# CarefreeBag – handleiding voor Claude

Bag-addon voor WoW Forever (retail-client, interface 16001). Laadt ook in retail, MoP Classic,
TBC Anniversary en Classic Era. Eigenaar: Johan (praat Nederlands, ADHD: korte, scanbare
antwoorden met emoji). Code-commentaar is Nederlands, teksten in het spel zijn Engels + vertalingen.

## Bestanden (laadvolgorde = `CarefreeBag.toc`)
| Bestand | Wat |
|---|---|
| `Env.lua` | Gedeelde omgeving voor alle bestanden (zie hieronder). Altijd als eerste. |
| `Locales.lua` | Vertalingen `ns.L.nl/de/fr/es/pt/it/ru`. Engels = de tekst in `T("...")`. |
| `Core.lua` | Versie, `T()`, `Log()`, `Defaults()`, kant-en-klare groepen (`PRESETS`), namen, `CharEntry()`/`CS()`/`Assign()`/`Hidden()`. |
| `Data.lua` | Tassen uitlezen (`Scan`, `MakeEntry`), indeling (`SectionOf`), onthouden per karakter (`SnapBags`/`SnapBank`), tooltip "waar heb je dit nog meer". |
| `BagWindow.lua` | Het tassenvenster: knoppen, menu's, `Layout()`, `Refresh`, slepen. Grootste bestand. |
| `BankPanel.lua` | Paneel naast de tassen: bank + tassen/bank van andere karakters (alleen bekijken). |
| `Blizzard.lua` | Tassen openen/vervangen (bindings, hooks), aan/uit, andere tassen-addons herkennen. |
| `Chores.lua` | Stapels samenvoegen, Auto Sell bij de vendor. |
| `Mail.lua` | Post naar alts per groep (vraag Ja/Overslaan, of "zonder vragen"). |
| `Options.lua` | Optievenster, minimapknop. |
| `Start.lua` | Events (`driver`), `/cfb`-commando's. |

## Gedeelde omgeving (belangrijk)
Elk bestand begint met `local _, ns = ...` en `setfenv(1, ns.Env("Naam1", ...))`.
- Namen die een bestand **op het hoogste niveau** maakt, zet je in die `ns.Env(...)`-lijst. Ze zijn dan in alle bestanden bruikbaar.
- Een niet-genoemde naam vullen geeft een fout ("is not declared"): zo vallen typfouten meteen op.
- Echte WoW-globals schrijf je via `_G` (`_G.CarefreeBagDB`, `_G.SLASH_CAREFREEBAG1`).
- Binnen functies gewoon `local` gebruiken.

## Opgeslagen gegevens (`CarefreeBagDB`, account-breed)
- `chars[sleutel]`: **per karakter**. Sleutel = volledige naam + "-" + realm (Forever: "Thrall Frostwolf-Realm"; nooit alleen de voornaam, twee karakters kunnen dezelfde voornaam hebben).
  - `assign[itemID] = groepsleutel` (geleerd door slepen), `hidden[itemID]`, `seen`, `manual`
  - `cats` (eigen groepen: `key, name, preset?, mailTo?, mailAuto?`), `order`, `sort`, `collapsed`
  - `snap = { name, class, bags = {...}, bank = {...}, bagsTime, bankTime }` voor het bankpaneel/tooltip
  - `legacy = true`: oude voornaam-sleutel van vóór 1.5.0, niet tonen
- Account-breed: `lang`, `enabled`, `autoSell`, `fixedOn` (vaste groepen aan/uit), `boeMail`, `boeMailAuto`, `maxCols`, `showSort`, `pos`, `log`, `lastError`.
- `cats`/`order`/`sort`/`assign`/`hidden` op het hoogste niveau = sjabloon van vóór 1.3.0; nieuwe karakters beginnen daarmee. Niet meer wijzigen.

## Vaste afspraken
- **Elke tekst in alle 8 talen tegelijk** (en, nl + 6 in `Locales.lua`). Controle: `python3 tests/check_locales.py`.
- Gedrag dat per karakter hoort, ook echt per karakter (`CharEntry()`), nooit over `DB.chars` heen lopen om bij alle karakters iets te wissen.
- Test altijd met **twee karakters met dezelfde voornaam** als het om karakterdata gaat.
- Stijl: standaard Blizzard-rood (`RedButton`), korte hover-teksten, niets wat het venster laat verspringen.
- Forever blokkeert `ReloadUI()` voor addons: gebruik de `/reload`-macroknop (`AskReload`).
- Menu's hangen aan `UIParent` met de klikvanger (`NewMenu`/`ShowMenu`), anders vallen ze achter vensters met `SetToplevel`.

## Testen
- `lua5.1 tests/run.lua`: alle scenario's in `tests/scenarios/`, elk in een schone omgeving met de nagebootste WoW-API (`tests/mock.lua`, `LoadAddon()` leest de `.toc`).
- Een scenario met `-- flavors: classic retail` als eerste regel draait per WoW-versie (`FLAVOR`).
- GitHub Actions draait de tests bij elke push; de release-workflow test eerst en brengt alleen uit als alles slaagt.

## Installeren op Johans pc (desktop-app gekoppeld)
- Doel: `C:\Games\World of Warcraft Forever\World of Warcraft\_forever_\Interface\AddOns\CarefreeBag\`.
- Kopieer naar een **nieuwe** map onder `/mnt/user-data/outputs/<uniek>/`, zet `## Version: x.y.z-dev` in de .toc, `device_commit_files` met `force`, en **controleer daarna met `md5sum`** (een oud pad gaf ooit een oude versie door).
- Nieuwe bestanden in de .toc worden sinds patch 9.0.1 ook met `/reload` geladen.
- SavedVariables staan in `...\_forever_\WTF\Account\<id>\SavedVariables\CarefreeBag.lua` (wordt pas bij `/reload` of uitloggen geschreven).

## Uitbrengen
1. `CHANGELOG.md` bijwerken, `VERSION` in `Core.lua`.
2. Commit als `git -c user.name="Perthos" -c user.email="perthos@users.noreply.github.com"`; push naar `main`.
3. GitHub-release maken met tag `vX.Y.Z` (via de browser: `releases/new?tag=vX.Y.Z&target=main&title=CarefreeBag%20X.Y.Z`).
4. De workflow test, pakt in en uploadt naar CurseForge (project 1803698) en Wago (n6VYpWNd). Controleer het log op "Success".
5. CurseForge keurt elk bestand handmatig goed (meestal binnen een paar uur).
- API-sleutels staan alleen in GitHub secrets (`CF_API_KEY`, `WAGO_API_TOKEN`); vraag Johan nooit om ze.
