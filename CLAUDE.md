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

## Waar werken: lokaal (voorkeur) of cloud
- **Lokaal** (Claude desktop-app → Code → omgeving "Local", map `C:\Dev\CarefreeBag`): Claude kan installeren in de AddOns-map en de browser bedienen (browserpaneel van de app of de Claude-extensie in Edge). Gebruik dit voor alles met testen in het spel, CurseForge/Wago-pagina's of releases.
- **Cloud** (omgeving niet "Local"): alleen code en GitHub, geen browser, geen toegang tot Johans pc. Zeg dat meteen als een taak dat nodig heeft.
- Lokaal op Windows zijn `lua5.1`/`python3` misschien niet geïnstalleerd: dan draait GitHub Actions de tests na de push (controleer het resultaat).

## Installeren op Johans pc
- Doel: `C:\Games\World of Warcraft Forever\World of Warcraft\_forever_\Interface\AddOns\CarefreeBag\`.
- **Lokale sessie:** kopieer de addon-bestanden (`.toc`, `*.lua`, `media/`; niet `tests/`, `.git`, `.github`) naar het doel, zet daar `## Version: x.y.z-dev` in de .toc en vergelijk daarna de hashes (bijv. `Get-FileHash`) met de bron.
- **Gewone Claude-chat met gekoppelde pc:** kopieer naar een **nieuwe** map onder `/mnt/user-data/outputs/<uniek>/`, zet `## Version: x.y.z-dev` in de .toc, `device_commit_files` met `force`, en **controleer daarna met `md5sum`** (een oud pad gaf ooit een oude versie door).
- Nieuwe bestanden in de .toc worden sinds patch 9.0.1 ook met `/reload` geladen.
- De nagebootste WoW (`tests/mock.lua`) ziet niet alles (bijv. Blizzard-templates). Laat Johan na grote verbouwingen altijd eerst zelf in het spel testen vóór een release.
- SavedVariables staan in `...\_forever_\WTF\Account\<id>\SavedVariables\CarefreeBag.lua` (wordt pas bij `/reload` of uitloggen geschreven).

## Uitbrengen
1. `CHANGELOG.md` bijwerken, `VERSION` in `Core.lua`.
2. Commit als `git -c user.name="Perthos" -c user.email="perthos@users.noreply.github.com"`; push naar `main`.
   **Geen** `Co-Authored-By`-, `Claude-Session`- of "Generated with Claude"-regels in commits, releases of PR's (Johans wens).
   De changelog op GitHub/CurseForge/Wago komt uit `CHANGELOG.md` (`.pkgmeta` → `manual-changelog`), niet uit de commits.
3. GitHub-release maken met tag `vX.Y.Z` (via de browser: `releases/new?tag=vX.Y.Z&target=main&title=CarefreeBag%20X.Y.Z`).
4. De workflow test, pakt in en uploadt naar CurseForge (project 1803698) en Wago (n6VYpWNd). Controleer het log op "Success".
5. CurseForge keurt elk bestand handmatig goed (meestal binnen een paar uur).
- API-sleutels staan alleen in GitHub secrets (`CF_API_KEY`, `WAGO_API_TOKEN`); vraag Johan nooit om ze.

## Einde van elke sessie (Johans afspraak)
- Volg de skill `rond-af` (`.claude/skills/rond-af/SKILL.md`): review, docs, checks, commit, push, overdracht.
- "Stand van zaken" hieronder bijwerken, committen op de sessie-branch én naar `main` pushen (`git push origin HEAD:main`, fast-forward). Een nieuwe chat begint vanaf `main`.
- Pushen naar `main` brengt niets uit: dat gebeurt pas met een release-tag.

## Stand van zaken (bijwerken na elke sessie)
- **1.5.0 uitgebracht** (2026-11-15), alles door Johan in het spel getest: bankpaneel, opsplitsing, mail "zonder vragen" per groep, eenmalige mailvraag "voortaan altijd zonder vragen?" (`DB.mailAlwaysAuto`: nil = nog niet gevraagd, optie in Algemeen), optievenster vast links naast de tassen (`ns.PlaceConfig`, één tegelijk met het bankpaneel), bankpaneel-titel "Your bank" / "Bank of X" / "Bags of X" met "(you)".
- Releasen kan ook met `gh release create vX.Y.Z --target main` (gh is lokaal ingelogd).
- **1.5.1 uitgebracht** (2026-11-15), door Johan in het spel getest: nieuw geloot item knippert zolang de tas open is (ook als je het al had), tot hover; meer looten = weer knipperen (`openCounts`/`freshIDs` in `BagWindow.lua`).
- Ook in 1.5.1: zoeken vanaf 2 tekens stopt het knipperen; hits op bank/alts = getal + gloed op knop Bank & alts, paneel opent vanzelf (eigen bank, dan alts: tassen, dan bank) en gaat dicht bij lege zoekbalk (`ns.OnSearch`, `Hits`/`FirstHit` in `BankPanel.lua`); tas dicht = zoeken leeg; Escape in lege zoekbalk = tas dicht; bankpaneel: ronde klasse-iconen links (gekozen = kleur + gouden gloed, rest grijs), Bags/Bank als tekst met icoon (gekozen = questlog-gloed), "Free slots" (`snap.bagsFree/bagsSlots/bankFree/bankSlots`). Johan vond auto-focus op de zoekbalk vervelend: niet doen. Papieren tabbladen (backdrop) zagen er niet goed uit: niet opnieuw proberen.
- **1.6.0 uitgebracht** (2026-11-15), door Johan in het spel getest: `Loot.lua`: tassen vol en loot past niet → paneel naast het lootvenster met de duurste loot die niet past vs. de goedkoopste stapel in je tassen (vendor of AH na 5%, hoogste van de twee), groen/rood verschil. Knop "Destroy & loot" (klik = hardware-event, nodig voor `DeleteCursorItem`), daarna `LootSlot` zodra het vak vrij is; "Skip" = niet meer vragen tot `LOOT_CLOSED`. Nooit voorgesteld: items zonder prijs, Quest, Keys, Hidden. Questloot telt als altijd meer waard. Triggers: `LOOT_OPENED`, `LOOT_SLOT_CLEARED`, `UI_ERROR_MESSAGE` = `ERR_INV_FULL`. Beroepstassen en reagent-tas tellen alleen als vrij voor passende items. Test: `tests/scenarios/09_loot_full_bags.lua`.
  - Door Johan in het spel getest: paneel en prijzen werken. Daarop toegevoegd: "Keep this item" / "Keep this group" in het paneel (per karakter: `ch.keep[itemID]`, `ch.keepGroups[groepsleutel]`, via `ns.Kept()`/`ns.KeptGroups()`), daarna meteen het volgende goedkoopste item. Opties: kolom "Keep" per groep (niet bij Quest/Keys/Auto Sell/Other; Johan: daar staan items die weg mogen, dus ook geen "Always keep group"-knop). Knoppen heten "Always keep item/group". Opties: "Advanced settings" onderaan, ingeklapt (`config.advOpen`, per sessie), met bag width en "Items kept when bags are full: N" + "Clear" (uitleg bij hover). Mail per groep: envelop (`r.mailBtn`) + ontvanger (`r.mailInfo`, groen "Auto") in de rij; klik opent `r.mailPop` (NewMenu) met `r.mail` (naamveld) en `r.mailAuto`. Optievenster 520 breed. Tooltip-regel bij bewaarde items.
  - Bug gevonden in het spel: weggooien uit de reagent-tas (Medium Leather, Tin Ore) maakte geen plek voor gewone loot. Nu `CanHold(bag, itemID, reagent)`: alleen items voorstellen uit een tas waar de loot in mag (gewone tas / juiste beroepstas / reagent-tas alleen voor reagents). Vulbalk telt de reagent-tas apart ("Reagents x/y"). Tests 10 en 11.
  - Nog in het spel checken: Keep-knoppen en optiekolom (layout), werkt `DeleteCursorItem` vanuit de knop op Forever, staat het paneel goed naast `LootFrame` (ook met autoloot), BoP-loot (bind-popup).
- **1.6.1** (2026-11-15), door Johan in het spel getest: item van buiten de tassen (aan je karakter, bank) op "+", een item, het venster of de vulbalk = naar een vrij vakje (`FromBags`: vakje op slot = uit de tas; `StoreCursorItem`). Test 12; de mock zet `isLocked` als `CURSOR` uit de tas komt (`CURSOR.outside` = van buiten).
- **1.7.0 in de maak** (op `main`, nog niet uitgebracht; GitHub-issues #1, #2, #3). Johan moet nog in het spel testen:
  - #3 goud: `snap.money` (bij elke snapshot en `PLAYER_MONEY`), onderaan het bankpaneel "You/<naam>: … All characters: …", ook in de tooltip van het klasse-icoon.
  - #2 mail: alles verstuurd → `ns.MailFinish()`: paneel naar `UIParent` (zelfde plek), `CloseMail()`, verslag (`ns.mail.report`, gevuld door `ns.MailSent` bij `MAIL_SEND_SUCCESS`), knop telt af "Close (5)"; klik/kruisje/Escape = `ns.MailReportClose()` (weer aan `MailFrame`). Alleen een vraag of overslaan = mailbox blijft open. Post in de inbox (`GetInboxNumItems() > 0`) = wel verslag, mailbox blijft open (anders kun je AH-post niet ophalen).
  - #1 kant: `ch.panelSide` ("left"/"right", per karakter), `ns.DockPanel`/`ns.AddSideArrow` in `BagWindow.lua`; pijltje aan de kant van de tassen. Test 13.
- Open: Johan kon een nieuwe tas niet op een tasvak slepen met de addon aan (uit = wel). Oorzaak nog onbekend; CarefreeBag raakt de tasbalk niet aan. Volgende stap: tijdelijke logregels (hooks op `PutItemInBag`, `ClearCursor`, `CURSOR_CHANGED`, `CharacterBagNSlot` OnReceiveDrag) en Johan laten slepen + `/reload`.
- Nog niet gedaan: Warband-bank (retail), een verwijderd karakter uit de lijst halen.
- Projectpagina's CurseForge en Wago bijgewerkt (2026-11-15) met Bank & alts, zoeken op bank/alts en "Bags full". CurseForge: authors.curseforge.com → project → Description (TinyMCE, `tinymce.activeEditor`). Wago: addons.wago.io/developers/projects/carefreebag/settings (markdown-textarea, "Save changes").
- Let op: de Bash-tool halveert backslashes in heredocs/scripts (`\\` wordt `\`), waardoor texturepaden kapotgaan. Lua-bestanden alleen met Write/Edit aanpassen.
- Johans karakters (Forever): main en bank alt hebben dezelfde voornaam. Echte namen staan niet in de repo.
