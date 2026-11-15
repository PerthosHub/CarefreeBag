# CarefreeBag – handleiding voor Claude

Bag-addon voor WoW Forever (retail-client, interface 16001). Laadt ook in retail, MoP Classic,
TBC Anniversary en Classic Era. Eigenaar: Johan (praat Nederlands, ADHD: korte, scanbare
antwoorden met emoji). Code-commentaar is Nederlands, teksten in het spel zijn Engels + vertalingen.

## Bestanden (laadvolgorde = `CarefreeBag.toc`)
| Bestand | Wat |
|---|---|
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

## Gedeelde namen via `ns` (belangrijk)
Standaard WoW-manier: elk bestand begint met `local ADDON, ns = ...` (de addon-tabel die WoW aan alle bestanden geeft).
- Alleen binnen één bestand nodig? Gewoon `local`.
- Nodig in andere bestanden? Maak het als `ns.Naam` (`function ns.Scan()`, `ns.main = ...`).
- Functies, constanten en tabellen die na het maken niet meer veranderen: in latere bestanden bovenaan `local Scan = ns.Scan` (staat onder "uit eerdere bestanden").
- Waarden die later nog veranderen (`ns.DB`, `ns.main`, `ns.Refresh`, `ns.searchText`, ...) altijd als `ns.X` lezen, nooit in een local kopiëren.
- Geen `setfenv`: Blizzard-templates met mixins (bijv. `Vector2DMixin`) werken dan niet meer. Dat ging mis in een eerdere opsplitsing.
- `python3 tests/check_globals.py` controleert dat er geen globals worden geschreven en dat niemand een `ns`-naam als global leest.

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
- `lua5.1 tests/run.lua`, `python3 tests/check_locales.py` en `python3 tests/check_globals.py` (alle drie moeten slagen).
- `tests/run.lua`: alle scenario's in `tests/scenarios/`, elk in een schone omgeving met de nagebootste WoW-API (`tests/mock.lua`, `LoadAddon()` leest de `.toc`).
- Een scenario met `-- flavors: classic retail` als eerste regel draait per WoW-versie (`FLAVOR`).
- GitHub Actions draait de tests bij elke push; de release-workflow test eerst en brengt alleen uit als alles slaagt.

## Installeren op Johans pc (desktop-app gekoppeld)
- Doel: `C:\Games\World of Warcraft Forever\World of Warcraft\_forever_\Interface\AddOns\CarefreeBag\`.
- Kopieer naar een **nieuwe** map onder `/mnt/user-data/outputs/<uniek>/`, zet `## Version: x.y.z-dev` in de .toc, `device_commit_files` met `force`, en **controleer daarna met `md5sum`** (een oud pad gaf ooit een oude versie door).
- Nieuwe bestanden in de .toc worden sinds patch 9.0.1 ook met `/reload` geladen.
- De nagebootste WoW (`tests/mock.lua`) ziet niet alles (bijv. Blizzard-templates). Laat Johan na grote verbouwingen altijd eerst zelf in het spel testen vóór een release.
- SavedVariables staan in `...\_forever_\WTF\Account\<id>\SavedVariables\CarefreeBag.lua` (wordt pas bij `/reload` of uitloggen geschreven).

## Uitbrengen
1. `CHANGELOG.md` bijwerken, `VERSION` in `Core.lua`.
2. Commit als `git -c user.name="Perthos" -c user.email="perthos@users.noreply.github.com"`; push naar `main`.
3. GitHub-release maken met tag `vX.Y.Z` (via de browser: `releases/new?tag=vX.Y.Z&target=main&title=CarefreeBag%20X.Y.Z`).
4. De workflow test, pakt in en uploadt naar CurseForge (project 1803698) en Wago (n6VYpWNd). Controleer het log op "Success".
5. CurseForge keurt elk bestand handmatig goed (meestal binnen een paar uur).
- API-sleutels staan alleen in GitHub secrets (`CF_API_KEY`, `WAGO_API_TOKEN`); vraag Johan nooit om ze.

## Stand van zaken (bijwerken na elke sessie)
- 1.5.0 is nog **niet** uitgebracht. Bankpaneel (tassen en bank van een ander karakter) is door Johan in het spel getest: werkt. Nog te testen: de opsplitsing in het algemeen en mail "zonder vragen".
- Volgende stap: UI-verbeteringen (Johan geeft per chat aan welke).
- Nog niet gedaan: Warband-bank (retail), een verwijderd karakter uit de lijst halen.
- Johans karakters (Forever): main en bank alt hebben dezelfde voornaam. Echte namen staan niet in de repo.
