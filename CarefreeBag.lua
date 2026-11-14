-- CarefreeBag - zorgeloze tassen voor WoW Forever (interface 16001)
--
-- 1. Eén venster met al je tassen, ingedeeld in groepen.
-- 2. Eigen categorieën. Elke categorie toont zijn items + 1 leeg vakje: sleep daar
--    een item op en dat soort item hoort voortaan bij die categorie.
-- 3. Verbergen (Hearthstone, skinning knife, ...): alleen zichtbaar via "Verborgen".
-- 5. Stapels samenvoegen: hetzelfde item over meerdere vakjes = één tegel met
--    het totaal, plus een klein "2x"-labeltje.
-- 6. Post: bij de mailbox een lijstje "naar bank-alt / naar BoE-alt" met één knop.

local ADDON, ns = ...
ns = ns or {}
local VERSION = "1.1.0"
do -- versie uit de .toc (bij een release vult de packager die in vanuit de git-tag)
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local v = get and get(ADDON, "Version")
	if v and v ~= "" and not v:find("@") then VERSION = v end
end

local DB
local Refresh -- vooruit gedeclareerd
local SavePos -- vooruit

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CarefreeBag|r: " .. tostring(msg))
end

-- Teksten: Engels in de code. Nederlands via de tabel NL hieronder, de andere
-- talen staan in Locales.lua (ns.L.de, ns.L.fr, ...).
local NL = {}
local L = ns.L or {}
ns.L = L
L.nl = NL
local function T(s)
	local t = DB and L[DB.lang]
	return (t and t[s]) or s
end

local LANGS = {
	{ "en", "English" }, { "nl", "Nederlands" }, { "de", "Deutsch" }, { "fr", "Français" },
	{ "es", "Español" }, { "it", "Italiano" }, { "pt", "Português" }, { "ru", "Русский" },
}
local function LangName(code)
	for _, l in ipairs(LANGS) do if l[1] == code then return l[2] end end
	return "English"
end
-- Taal van de WoW-client (er bestaat geen Nederlandse client, dus nl kies je zelf).
local function DetectLang()
	local map = { deDE = "de", frFR = "fr", esES = "es", esMX = "es", itIT = "it", ptBR = "pt", ptPT = "pt", ruRU = "ru" }
	return map[GetLocale and GetLocale() or ""] or "en"
end

-- Nederlandse vertalingen
NL[" Note: Buyback only keeps the last 12."] = " Let op: Buyback bewaart alleen de laatste 12."
NL[" hidden."] = " verborgen."
NL[" visible again."] = " weer zichtbaar."
NL["Add"] = "Toevoegen"
NL["Auto Sell skipped (Shift)."] = "Auto Sell overgeslagen (Shift)."
NL["Auto Sell: sold %d item(s) for %s."] = "Auto Sell: %d item(s) verkocht voor %s."
NL["Automatic (CarefreeBag decides)"] = "Automatisch (CarefreeBag kiest)"
NL["CarefreeBag mail"] = "CarefreeBag post"
NL["CarefreeBag options"] = "CarefreeBag opties"
NL["CarefreeBag: click to hide or set a category"] = "CarefreeBag: klik voor verbergen en categorie"
NL["Bank alt (AH items):"] = "Bank-alt (AH-items):"
NL["BoE alt:"] = "BoE-alt:"
NL["BoEs in their own group (green and up)"] = "BoE's automatisch apart (groen en hoger)"
NL["Busy..."] = "Bezig..."
NL["Busy: mail to %s..."] = "Bezig: mail naar %s..."
NL["Categories"] = "Categorieën"
NL["Category"] = "Categorie"
NL["Click the name, type a new name and press Enter."] = "Klik op de naam, typ een nieuwe naam en druk op Enter."
NL["Click to switch: no mail, to your bank alt or to your BoE alt."] = "Klik om te wisselen: geen post, naar je bank-alt of naar je BoE-alt."
NL["Columns maximum: %d"] = "Kolommen maximaal: %d"
NL["Columns minimum: %d"] = "Kolommen minimaal: %d"
NL["Display"] = "Weergave"
NL["Done"] = "Klaar"
NL["Drag: move along the minimap"] = "Slepen: verplaatsen langs de minimap"
NL["Drop an item here to hide it."] = "Sleep een item hierheen om het te verbergen."
NL["Drop an item here to put it in an empty slot (for example to split a stack)."] = "Laat een item hierop vallen om het in een leeg vakje te zetten (bijv. om een stapel te splitsen)."
NL["Drop an item here: it is shown with your quest items from now on."] = "Sleep een item hierheen: het staat voortaan bij je quest-items."
NL["Drop an item here: it is sold automatically at a vendor from now on, even if it is not grey."] = "Sleep een item hierheen: het wordt voortaan automatisch verkocht bij een vendor, ook als het niet grijs is."
NL["Drop an item here: it stays in Other and never moves to Auto Sell, Quest or BoE by itself."] = "Sleep een item hierheen: het blijft voortaan in Overig en gaat nooit vanzelf naar Auto Sell, Quest of BoE."
NL["Drop an item here: that kind of item belongs to %s from now on."] = "Sleep een item hierheen: dat soort item hoort voortaan bij %s."
NL["Edit"] = "Bewerken"
NL["Edit mode"] = "Bewerkmodus"
NL["Empty group: %s"] = "Lege groep: %s"
NL["Empty groups (drop an item on one)"] = "Lege groepen (sleep er een item op)"
NL["Empty slot: %s"] = "Leeg vakje: %s"
NL["Everything in Auto Sell is sold when you open a vendor. Hold Shift while opening to skip it once."] = "Alles in Auto Sell wordt verkocht zodra je een vendor opent. Houd Shift ingedrukt bij het openen om het een keer over te slaan."
NL["Everything the game marks as a quest item goes to the Quest group."] = "Alles wat de game als quest-item ziet krijgt de groep Quest."
NL["Free slots: %s of %s"] = "Vrije vakjes: %s van %s"
NL["Grey items go to Auto Sell"] = "Grijze items automatisch naar Auto Sell"
NL["Grey items go to Auto Sell automatically, most valuable first. Take one out (to Other) and CarefreeBag remembers it."] = "Grijze items komen vanzelf in Auto Sell, duurste eerst. Haal je er een uit (naar Overig), dan onthoudt CarefreeBag dat."
NL["Hidden"] = "Verborgen"
NL["Hidden items"] = "Verborgen items"
NL["Hidden items are never sent. Costs 30 copper per item."] = "Verborgen items gaan nooit mee. Kost 30 koper per item."
NL["Hidden: %d kinds of items"] = "Verborgen: %d soorten items"
NL["Hide"] = "Verberg"
NL["Hide item"] = "Verbergen"
NL["Keys"] = "Sleutels"
NL["Left-click: options"] = "Linksklik: opties"
NL["Mail"] = "Post"
NL["Mail: BoE alt"] = "Post: BoE-alt"
NL["Mail: bank alt"] = "Post: bank-alt"
NL["Mail: none"] = "Post: geen"
NL["Merge stacks"] = "Stapels samenvoegen"
NL["Nothing to send."] = "Niets om te versturen."
NL["Off = the B key opens the default bags again. Open CarefreeBag with the minimap button."] = "Uit = de B-toets opent weer de gewone tassen. CarefreeBag open je dan via de minimapknop."
NL["Options"] = "Opties"
NL["Other"] = "Overig"
NL["Other (never automatic)"] = "Overig (nooit automatisch)"
NL["Pack next mail"] = "Volgende inpakken"
NL["Partial stacks of the same item are really combined so they use fewer slots. Not during combat."] = "Losse stapels van hetzelfde item worden echt samengevoegd, zodat ze minder vakjes kosten. Niet tijdens een gevecht."
NL["Quest"] = "Quest"
NL["Quest items in their own group"] = "Quest-items automatisch apart"
NL["Remove"] = "Verwijderen"
NL["Rename"] = "Hernoemen"
NL["Replace the default bags"] = "Standaardtassen vervangen"
NL["Restack in the background"] = "Stapels op de achtergrond samenvoegen"
NL["Right-click: open/close bags"] = "Rechtsklik: tassen open/dicht"
NL["Search..."] = "Zoeken..."
NL["Sell Auto Sell at vendors"] = "Auto Sell verkopen bij de vendor"
NL["Send"] = "Versturen"
NL["Send this mail"] = "Verstuur deze mail"
NL["Sends AH items to your bank alt and BoEs to your BoE alt."] = "Stuurt AH-items naar je bank-alt en BoE's naar je BoE-alt."
NL["Sent by CarefreeBag."] = "Verstuurd door CarefreeBag."
NL["Show all again"] = "Alles weer tonen"
NL["Show minimap button"] = "Minimapknop tonen"
NL["Shows or hides the Hidden group."] = "Klapt de groep Verborgen open of dicht."
NL["The items of this category go back to Other."] = "De items van deze categorie gaan terug naar Overig."
NL["The same item in several slots becomes one tile with the total."] = "Hetzelfde item over meerdere vakjes wordt één tegel met het totaal."
NL["Then click an item to hide it or give it a category."] = "Klik daarna op een item om het te verbergen of een categorie te geven."
NL["To %s:"] = "Naar %s:"
NL["Unbound BoE items get their own group and are mailed to your BoE alt."] = "Niet-gebonden BoE-items krijgen een eigen groep en gaan naar je BoE-alt."
NL["WoW blocks automatic sending. Click the button for each mail this time."] = "WoW blokkeert automatisch versturen. Klik nu per mail op de knop."
NL["all mail has been sent."] = "alle post is verstuurd."
NL["at most 12 categories."] = "maximaal 12 categorieën."
NL["category '%s' removed. Its items are back in Other."] = "categorie '%s' verwijderd. De items staan weer bij Overig."
NL["error in %s: %s"] = "fout in %s: %s"
NL["error: %s"] = "fout: %s"
NL["free of %d"] = "vrij van %d"
NL["last %d lines of the log:"] = "laatste %d regels van het logboek:"
NL["last error: %s"] = "laatste fout: %s"
NL["mailbox closed, stopped."] = "mailbox gesloten, gestopt."
NL["more"] = "meer"
NL["none"] = "geen"
NL["nothing to send."] = "niets om te versturen."
NL["scroll for more"] = "scroll voor meer"
NL["selling is off"] = "verkopen staat uit"
NL["sending failed (not enough gold or wrong name?). The items are still in the mail window."] = "versturen mislukt (te weinig geld of verkeerde naam?). De items staan nog in het mailvenster."
NL["stopped."] = "gestopt."
NL["then scroll"] = "daarna scrollen"
NL["v%s loaded. Press B, or type /cfb for options."] = "v%s geladen. Druk op B, of /cfb voor de opties."
NL["|cffffd100Edit mode:|r click an item. Finished? Click Done."] = "|cffffd100Bewerkmodus:|r klik op een item. Klaar? Klik op Klaar."

NL["%s keeps your bags. CarefreeBag opens with the minimap button."] = "%s houdt je tassen. CarefreeBag open je met de minimapknop."
NL["CarefreeBag and %s both want to replace your bags. Which one do you want to use?"] = "CarefreeBag en %s willen allebei je tassen overnemen. Welke wil je gebruiken?"
NL["CarefreeBag: automatically sell everything in the Auto Sell group whenever you open a vendor?\n\nYou can change this later in the options."] = "CarefreeBag: alles in de groep Auto Sell automatisch verkopen zodra je een vendor opent?\n\nJe kunt dit later aanpassen in de opties."
NL["No"] = "Nee"
NL["Yes, sell"] = "Ja, verkopen"

NL["CarefreeBag: click to hide this item"] = "CarefreeBag: klik om dit item te verbergen"
NL["CarefreeBag: click to show this item again"] = "CarefreeBag: klik om dit item weer te tonen"
NL["Click items to hide them, or click a hidden item to show it again. Click Done when you are finished."] = "Klik op items om ze te verbergen, of klik op een verborgen item om het terug te halen. Klaar? Klik op Klaar."
NL["Everything without a group. What you drop here stays here and never moves to Quest, BoE or Auto Sell by itself."] = "Alles zonder groep. Wat je hierheen sleept blijft hier en verhuist nooit vanzelf naar Quest, BoE of Auto Sell."
NL["Fixed group. Everything on your keyring."] = "Vaste groep. Alles aan je sleutelring."
NL["Fixed group. Everything without a group. Items you drop here stay here and never move by themselves."] = "Vaste groep. Alles zonder groep. Wat je hierheen sleept blijft hier en verhuist nooit vanzelf."
NL["Fixed group. Grey items plus items you drop here, most valuable first. Sold when you open a vendor (hold Shift to skip). Items without a sell price stay."] = "Vaste groep. Grijze items plus wat je hierheen sleept, duurste eerst. Wordt verkocht zodra je een vendor opent (Shift = overslaan). Items zonder verkoopprijs blijven staan."
NL["Fixed group. Items the game marks as quest items, plus items you drop here. Never sold or mailed."] = "Vaste groep. Items die de game als quest-item ziet, plus wat je hierheen sleept. Wordt nooit verkocht of gemaild."
NL["Fixed group. Unbound Bind on Equip items, green and better. Mailed to the BoE address from the options, if you set one."] = "Vaste groep. Niet-gebonden BoE-items, groen en hoger. Gaan naar het BoE-postadres uit de opties, als je dat invult."
NL["Fixed group. Your hidden items. Only visible while you are hiding items."] = "Vaste groep. Je verborgen items. Alleen zichtbaar terwijl je aan het verbergen bent."
NL["Fixed groups"] = "Vaste groepen"
NL["Grey items automatically"] = "Grijze items automatisch"
NL["Grey items plus anything you drop on it, most valuable first. Items without a sell price stay."] = "Grijze items plus wat je erop sleept, duurste eerst. Items zonder verkoopprijs blijven staan."
NL["Have two half stacks of the same item, for example 8 and 5 bread? CarefreeBag puts them together into one stack of 13, so a bag slot comes free. Happens by itself after looting, never during combat."] = "Heb je twee halve stapels van hetzelfde item, bijvoorbeeld 8 en 5 brood? Dan legt CarefreeBag ze samen tot één stapel van 13, zodat er een tasvakje vrijkomt. Gebeurt vanzelf na het looten, nooit tijdens een gevecht."
NL["Hide items"] = "Verbergen"
NL["Mail to"] = "Post naar"
NL["Mail to (empty = not mailed)"] = "Post naar (leeg = niet mailen)"
NL["Mail to:"] = "Post naar:"
NL["Maximum width: %d columns"] = "Maximale breedte: %d kolommen"
NL["My categories"] = "Mijn categorieën"
NL["Name"] = "Naam"
NL["Put quest items here automatically"] = "Quest-items hier automatisch neerzetten"
NL["Quest items, plus anything you drop on it. Never sold or mailed. Putting a normal item here does no harm: it is only shown here and is protected from Auto Sell and mail."] = "Quest-items, plus wat je erop sleept. Wordt nooit verkocht of gemaild. Een gewoon item hierin zetten kan geen kwaad: het staat alleen hier en is beschermd tegen Auto Sell en post."
NL["Sell at vendors"] = "Verkopen bij vendor"
NL["The window gets wider when your bags fill up, up to this many columns. After that you scroll."] = "Het venster wordt breder als je tassen voller raken, tot dit aantal kolommen. Daarna scroll je."
NL["These groups always exist and follow fixed rules. Blue headers in your bags are fixed groups; gold headers are your own categories."] = "Deze groepen bestaan altijd en volgen vaste regels. In je tassen zijn blauwe koppen vaste groepen en gouden koppen je eigen categorieën."
NL["Tidy up stacks automatically"] = "Stapels automatisch opruimen"
NL["Type the full name of your alt, for example 'Thrall Stormrage'. At a mailbox, everything in this category is sent there. Leave empty to never mail it."] = "Typ de volledige naam van je alt, bijvoorbeeld 'Thrall Stormrage'. Bij een mailbox gaat alles uit deze categorie daarheen. Leeg = nooit mailen."
NL["Unbound Bind on Equip items, green and better. If you set an address, they are mailed there at a mailbox."] = "Niet-gebonden BoE-items, groen en hoger. Vul je een adres in, dan worden ze bij een mailbox daarheen gestuurd."
NL["Use this group"] = "Deze groep gebruiken"
NL["Width"] = "Breedte"
NL["Your category. Drop items on its + slot. Rename it, reorder it or give it a mail address in the options."] = "Jouw categorie. Sleep items op het +vakje. Hernoemen, verplaatsen of een postadres geven doe je in de opties."
NL["mail: %s"] = "post: %s"
NL["|cffffd100Hiding:|r click an item to hide it or show it again."] = "|cffffd100Verbergen:|r klik op een item om het te verbergen of terug te halen."

NL["Sends every category that has a mail address to that address, and BoEs to the BoE address."] = "Stuurt elke categorie met een postadres naar dat adres, en BoE's naar het BoE-adres."

NL["Give unbound BoE items their own group."] = "Geef niet-gebonden BoE-items een eigen groep."
NL["Minimap button"] = "Minimapknop"
NL["Put everything the game marks as a quest item here."] = "Zet alles wat de game als quest-item ziet hier neer."
NL["Put grey items here automatically. Take one out (to Other) and CarefreeBag remembers it."] = "Zet grijze items hier automatisch neer. Haal je er een uit (naar Overig), dan onthoudt CarefreeBag dat."
NL["Replace default bags"] = "Standaardtassen vervangen"
NL["These groups always exist and follow fixed rules. Blue headers in your bags are fixed groups; gold headers are your own categories. Hover a header in your bags to see its rules."] = "Deze groepen bestaan altijd en volgen vaste regels. In je tassen zijn blauwe koppen vaste groepen en gouden koppen je eigen categorieën. Ga met je muis over een kop om de regels te zien."
NL["Tidy up stacks"] = "Stapels opruimen"
NL["automatic"] = "automatisch"
NL["grey items"] = "grijze items"
NL["on"] = "aan"
NL["sell at vendor"] = "verkopen bij vendor"

NL["%s keeps your bags. CarefreeBag is turned off; turn it on again with the minimap button."] = "%s houdt je tassen. CarefreeBag staat nu uit; zet hem weer aan met de minimapknop."
NL["CarefreeBag is off. Shift-click the minimap button to turn it on."] = "CarefreeBag staat uit. Shift-klik op de minimapknop om hem aan te zetten."
NL["CarefreeBag is off. Your normal bags are back."] = "CarefreeBag staat uit. Je gewone tassen zijn terug."
NL["CarefreeBag is on."] = "CarefreeBag staat aan."
NL["CarefreeBag on"] = "CarefreeBag aan"
NL["Everything on your keyring."] = "Alles aan je sleutelring."
NL["Fixed group"] = "Vaste groep"
NL["Groups"] = "Groepen"
NL["Left-click: open/close bags"] = "Linksklik: tassen open/dicht"
NL["Mail to / settings"] = "Post naar / instellingen"
NL["Off = your normal bags, no Auto Sell, no mail and no tidying. Shift-click the minimap button does the same."] = "Uit = je gewone tassen, geen Auto Sell, geen post en geen opruimen. Shift-klik op de minimapknop doet hetzelfde."
NL["Right-click: options"] = "Rechtsklik: opties"
NL["Shift-click: turn CarefreeBag on/off"] = "Shift-klik: CarefreeBag aan/uit"
NL["Type a name on the left and click Add to make your own category."] = "Typ links een naam en klik op Toevoegen om een eigen categorie te maken."
NL["Type the full name of your alt, for example 'Thrall Stormrage'. At a mailbox, everything in this group is sent there. Leave empty to never mail it."] = "Typ de volledige naam van je alt, bijvoorbeeld 'Thrall Stormrage'. Bij een mailbox gaat alles uit deze groep daarheen. Leeg = nooit mailen."
NL["off"] = "uit"

NL["grey"] = "grijs"
NL["sell"] = "verkopen"

NL["Off = this group is not used; its items go to Other."] = "Uit = deze groep wordt niet gebruikt; de items gaan naar Overig."
NL["On/off"] = "Aan/uit"

NL["sell automatically"] = "automatisch verkopen"
NL["Drop an item: it goes here from now on."] = "Sleep een item hierheen: het komt hier voortaan."
NL["Quest items. Never sold or mailed."] = "Quest-items. Nooit verkocht of gemaild."
NL["Your keyring."] = "Je keyring."
NL["Unbound BoE items, green and better."] = "Ongebonden BoE-items, groen en beter."
NL["Grey items. Sold at a vendor (Shift = skip)."] = "Grijze items. Verkocht bij de vendor (Shift = overslaan)."
NL["Everything without a group."] = "Alles zonder groep."
NL["Drop an item to hide it."] = "Sleep een item hierheen om het te verbergen."
NL["Your hidden items."] = "Je verborgen items."
NL["These items are mailed to %s when you open a mailbox."] = "Deze items worden naar %s gemaild als je een mailbox opent."
NL["AH value after 5%% cut: %s"] = "AH-waarde na 5%% kosten: %s"
NL["Drag items onto each other to reorder."] = "Sleep items op elkaar om de volgorde te veranderen."
NL["Off = your normal bags."] = "Uit = je gewone tassen."
NL["Off: items go to Other."] = "Uit: items gaan naar Overig."
NL["Full name of your alt, e.g. 'Thrall Stormrage'. Empty = no mail."] = "Volledige naam van je alt, bijv. 'Thrall Stormrage'. Leeg = niet mailen."
NL["Items go back to Other."] = "Items gaan terug naar Overig."
NL["Add a category that fills itself."] = "Voeg een categorie toe die zichzelf vult."
NL["Window width before you scroll."] = "Vensterbreedte voordat je gaat scrollen."
NL["Sell at a vendor. Shift = skip once."] = "Verkopen bij de vendor. Shift = één keer overslaan."
NL["At a mailbox you are asked per category whether to send it."] = "Bij de mailbox krijg je per categorie de vraag of hij weg moet."
NL["Choose how this group is sorted: type, stack price, newest last or manual."] = "Kies hoe deze groep gesorteerd wordt: soort, stackprijs, nieuwste als laatst of handmatig."
NL["Sort: %s"] = "Sortering: %s"
NL["type"] = "soort"
NL["stack price"] = "stackprijs"
NL["newest last"] = "nieuwste als laatst"
NL["manual"] = "handmatig"
NL["Sorting"] = "Sortering"
NL["Click to switch: type, stack price, newest last or manual. In manual you drag items into your own order."] = "Klik om te wisselen: soort, stackprijs, nieuwste als laatst of handmatig. Bij handmatig sleep je items in je eigen volgorde."
NL["Auto mail to: %s"] = "Automatisch mailen naar: %s"
NL["Sorting set to manual for this group."] = "Sortering van deze groep staat nu op handmatig."
NL["Click items to hide them, or a hidden item to show it again. Click the eye again when you are done."] = "Klik items aan om ze te verbergen, of een verborgen item om het weer te tonen. Klik nog een keer op het oog als je klaar bent."
NL["Drag an item onto another item in the same group: on the left edge it goes in between (gold line), elsewhere they swap (gold border)."] = "Sleep een item op een ander item in dezelfde groep: op de linkerrand komt het ertussen (gouden streep), ergens anders wisselen ze om (gouden rand)."
NL["Food & Drink"] = "Eten & drinken"
NL["Potions & Elixirs"] = "Potions & elixirs"
NL["Scrolls"] = "Scrolls"
NL["Fills itself with food and drink."] = "Vult zichzelf met eten en drinken."
NL["Fills itself with potions, elixirs and flasks."] = "Vult zichzelf met potions, elixirs en flasks."
NL["Fills itself with scrolls."] = "Vult zichzelf met scrolls."
NL["Ready-made category: the name is fixed. Items you drop on it go here from now on, even if they are another kind."] = "Kant-en-klare categorie: de naam staat vast. Items die je erop sleept gaan voortaan hierheen, ook als ze eigenlijk iets anders zijn."
NL["Ready-made category"] = "Kant-en-klare categorie"
NL["Ready-made"] = "Kant-en-klaar"
NL["Add a ready-made category that fills itself. Its name is fixed."] = "Voeg een kant-en-klare categorie toe die zichzelf vult. De naam staat vast."
NL["Consumables"] = "Consumables"
NL["Professions"] = "Beroepen"
NL["Gear"] = "Gear"
NL["Fills itself with food, drink, potions, elixirs, scrolls, bandages and enchants."] = "Vult zichzelf met eten, drinken, potions, elixirs, scrolls, bandages en enchants."
NL["Fills itself with trade goods and recipes."] = "Vult zichzelf met trade goods en recepten."
NL["Fills itself with weapons and armor you can wear."] = "Vult zichzelf met wapens en armor die je kunt dragen."
NL["AH value of this stack after the 5%% AH cut: %s"] = "AH-waarde van deze stack na 5%% AH-kosten: %s"
NL["%s sent."] = "%s verstuurd."
NL["Send %s to %s?"] = "%s versturen naar %s?"
NL["After that: %s"] = "Daarna: %s"
NL["Yes, send"] = "Ja, versturen"
NL["Skip"] = "Overslaan"
NL["Asks per category whether to send it to its mail address. BoEs go to the BoE address."] = "Vraagt per categorie of hij naar zijn postadres moet. BoE's gaan naar het BoE-adres."

-- Logboek in de SavedVariables (laatste 80 regels). Lees met /cfb log.
local function Log(msg)
	if not DB then return end
	DB.log = DB.log or {}
	local stamp = date and date("%d-%m %H:%M:%S") or tostring(GetTime())
	table.insert(DB.log, stamp .. "  " .. tostring(msg))
	while #DB.log > 80 do table.remove(DB.log, 1) end
end

---------------------------------------------------------------------------
-- Instellingen
---------------------------------------------------------------------------

-- Kant-en-klare categorieën: vullen zichzelf op itemsoort (zoals WoW die in de
-- tooltip toont). De naam staat vast, zodat altijd duidelijk is wat erin komt.
-- Itemsoort (Enum.ItemClass): 0 Consumable, 2 Weapon, 3 Gem, 4 Armor, 7 Tradegoods,
-- 8 ItemEnhancement, 9 Recipe, 19 Profession. Consumable-subsoort: 1 Potion,
-- 2 Elixir, 3 Flask, 4 Scroll, 5 Food & Drink.
-- Volgorde = voorrang: Food & Drink wint van het bredere Consumables.
local PRESETS = {
	{ id = "food", name = "Food & Drink", tip = "Fills itself with food and drink.",
		match = function(e) return e.classID == 0 and e.subclassID == 5 end },
	{ id = "potions", name = "Potions & Elixirs", tip = "Fills itself with potions, elixirs and flasks.",
		match = function(e) return e.classID == 0 and (e.subclassID == 1 or e.subclassID == 2 or e.subclassID == 3) end },
	{ id = "scrolls", name = "Scrolls", tip = "Fills itself with scrolls.",
		match = function(e) return e.classID == 0 and e.subclassID == 4 end },
	{ id = "consum", name = "Consumables", tip = "Fills itself with food, drink, potions, elixirs, scrolls, bandages and enchants.",
		match = function(e) return e.classID == 0 or e.classID == 8 end },
	{ id = "prof", name = "Professions", tip = "Fills itself with trade goods and recipes.",
		match = function(e) return e.classID == 3 or e.classID == 7 or e.classID == 9 or e.classID == 19 end },
	{ id = "gear", name = "Gear", tip = "Fills itself with weapons and armor you can wear.",
		match = function(e) return (e.classID == 2 or e.classID == 4) and (e.equipLoc or "") ~= "" end },
}
local PRESET = {}
for i, p in ipairs(PRESETS) do p.rank = i; PRESET[p.id] = p end

-- Nieuwe installaties beginnen met drie kant-en-klare categorieën.
local DEFAULT_CATS = { "consum", "prof", "gear" }

local function Defaults()
	local fresh = (CarefreeBagDB == nil) or (next(CarefreeBagDB) == nil)
	CarefreeBagDB = CarefreeBagDB or {}
	DB = CarefreeBagDB
	-- Taal: bestaande installaties (van voor 0.6.0) waren Nederlands.
	if DB.lang == nil then DB.lang = fresh and DetectLang() or "nl" end
	if not L[DB.lang] and DB.lang ~= "en" then DB.lang = "en" end
	-- Auto Sell: nieuwe gebruikers krijgen bij de eerste vendor een vraag.
	if DB.autoSellAsked == nil then DB.autoSellAsked = (not fresh) and DB.autoSell ~= nil end
	DB.chars = DB.chars or {}     -- per karakter: { assign = { [itemID] = categorie-key } }
	DB.hidden = DB.hidden or {}   -- [itemID] = true
	DB.locked = nil               -- locken is weggehaald in 0.3.0
	if not DB.cats then
		DB.cats = {}
		for _, id in ipairs(DEFAULT_CATS) do
			DB.cats[#DB.cats + 1] = { key = id, preset = id }
		end
	end
	-- 1.1.0-test had "auto"; kant-en-klare categorieën krijgen hun vaste naam in jouw taal.
	local OLD = { consumable = "consum", profession = "prof", gear = "gear" }
	for _, c in ipairs(DB.cats) do
		if c.auto then c.preset = OLD[c.auto]; c.auto = nil end
		if c.preset and PRESET[c.preset] then c.name = T(PRESET[c.preset].name) else c.preset = nil end
	end
	-- Post: elke categorie heeft zijn eigen adres (mailTo). Oude instellingen omzetten.
	if DB.bankAlt ~= nil or DB.boeAlt ~= nil then
		for _, c in ipairs(DB.cats) do
			if c.mail == "bank" and DB.bankAlt and DB.bankAlt ~= "" then c.mailTo = DB.bankAlt
			elseif c.mail == "boe" and DB.boeAlt and DB.boeAlt ~= "" then c.mailTo = DB.boeAlt end
			c.mail = nil
		end
		if DB.boeMail == nil then DB.boeMail = DB.boeAlt or "" end
		DB.bankAlt, DB.boeAlt = nil, nil
	end
	if DB.boeMail == nil then DB.boeMail = "" end
	DB.merge, DB.autoStack = true, true -- altijd aan: dit is wat CarefreeBag doet
	-- Vaste groepen aan/uit. Uit = de items vallen terug naar Overig.
	DB.fixedOn = DB.fixedOn or {}
	if DB.fixedOn.boe == nil then DB.fixedOn.boe = (DB.boeAuto ~= false) end
	DB.boeAuto = nil
	for _, k in ipairs({ "quest", "keys", "grey" }) do
		if DB.fixedOn[k] == nil then DB.fixedOn[k] = true end
	end
	if not DB.keysOffDone then DB.fixedOn.keys = false; DB.keysOffDone = true end
	if DB.enabled == nil then DB.enabled = (DB.replaceBags ~= false) end
	DB.replaceBags = nil
	DB.questAuto = true -- quest-items gaan altijd naar Quest (groep uit = naar Overig)
	DB.greyAuto = true -- grijze items gaan altijd naar Auto Sell
	if DB.autoSell == nil then DB.autoSell = false end
	DB.conflictOK = DB.conflictOK or {}
	DB.maxCols = DB.maxCols or 14  -- breder dan dit wordt het venster niet; daarna scrollen
	DB.cols = nil
	DB.minimapAngle = DB.minimapAngle or 230
end

-- Forever gebruikt voornaam + achternaam ("Voornaam Achternaam"). Intern zet de game er
-- een vast scheidingsteken tussen. Dat teken lezen we uit de game zelf, of we leiden
-- het af van je eigen naam.
local function SurnameSep()
	local c = Constants and Constants.CharacterNameSeparatorConsts
	local sep = c and c.CHARACTERNAME_SURNAME_SEPARATOR
	if type(sep) == "string" and sep ~= "" then return sep end
	local me = UnitName("player")
	if me and me:find("-", 1, true) then return "-" end
	if me and me:find(" ", 1, true) then return " " end
	return nil
end

local function FullName(input)
	input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local first, last = input:match("^([^%s%-]+)[%s%-]+([^%s%-]+)$")
	local sep = SurnameSep()
	if first and sep then return first .. sep .. last end
	return input
end

-- Je eigen volledige naam. UnitName("player") geeft in Forever alleen de voornaam;
-- UnitNameUnmodified geeft voornaam én achternaam terug.
local function MyFullName()
	local n, sur
	if UnitNameUnmodified then n, sur = UnitNameUnmodified("player") end
	if not n then n, sur = UnitName("player") end
	if sur and sur ~= "" then return n .. " " .. sur end
	return n
end

local function SameName(a, b)
	local function norm(x) return (x or ""):lower():gsub("[%s%-]+", " ") end
	return norm(a) == norm(b)
end

-- Wat jij versleept onthoudt CarefreeBag per karakter. Van voor 1.1.0 was dat
-- één lijst voor het hele account (DB.assign); elk karakter begint met een kopie daarvan.
local charKey
local function CharEntry()
	if not charKey then
		local name = UnitName and UnitName("player")
		if not name or name == "" or name == UNKNOWNOBJECT then return nil end
		charKey = name .. "-" .. ((GetRealmName and GetRealmName()) or "")
	end
	local ch = DB.chars[charKey]
	if not ch then
		ch = { assign = {} }
		for id, k in pairs(DB.assign or {}) do ch.assign[id] = k end
		DB.chars[charKey] = ch
	end
	ch.seen = ch.seen or {}
	ch.manual = ch.manual or {}
	return ch
end
local function Assign()
	local ch = CharEntry()
	return ch and ch.assign or (DB.assign or {})
end

local function CatByKey(key)
	for i, c in ipairs(DB.cats) do
		if c.key == key then return c, i end
	end
end

local function NewCatKey(name)
	local base = (name:lower():gsub("[^%w]", "")):sub(1, 12)
	if base == "" then base = "cat" end
	local key, n = base, 1
	while CatByKey(key) or key == "boe" or key == "other" or key == "hidden" or key == "quest" or key == "grey" do
		n = n + 1
		key = base .. n
	end
	return key
end

---------------------------------------------------------------------------
-- Tassen uitlezen
---------------------------------------------------------------------------

local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
local needInfo = false

local function ItemExtra(itemID)
	local ok, name, _, _, _, _, _, _, stack, equipLoc, _, price, classID, subclassID, bind = pcall(C_Item.GetItemInfo, itemID)
	if ok and name then return stack or 1, bind or 0, price or 0, classID, equipLoc, subclassID end
	needInfo = true
	if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
	return nil, nil, 0, nil, nil, nil
end

local QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12

local function IsQuestItem(bag, slot, classID)
	if classID == QUEST_CLASS then return true end
	if C_Container.GetContainerItemQuestInfo then
		local ok, q = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
		if ok and q and (q.isQuestItem or q.questID) then return true end
	end
	return false
end

-- AH-prijs per stuk via Auctionator (als die geïnstalleerd is en een scan heeft).
local function AHPrice(link)
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	if not (api and api.GetAuctionPriceByItemLink and link) then return nil end
	local ok, price = pcall(api.GetAuctionPriceByItemLink, "CarefreeBag", link)
	if ok and type(price) == "number" and price > 0 then return price end
	return nil
end

local AH_CUT = 0.05 -- het AH houdt 5% van de verkoopprijs in (de borg krijg je terug)

local function IsBoE(e)
	return e.bindType == 2 and not e.bound and (e.quality or 0) >= 2
end

-- Keyring (sleutelring): alleen als Forever die toont.
local function KeyringBag()
	local id = KEYRING_CONTAINER or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)
	if not id then return nil end
	if C_ActionBar and C_ActionBar.ShouldShowKeyring then
		local ok, show = pcall(C_ActionBar.ShouldShowKeyring)
		if ok and not show then return nil end
	end
	return id
end

local function Scan()
	local items, free = {}, {}
	local total = 0
	needInfo = false
	local bags = {}
	for bag = 0, LAST_BAG do bags[#bags + 1] = bag end
	local keyBag = KeyringBag()
	if keyBag then bags[#bags + 1] = keyBag end
	for _, bag in ipairs(bags) do
		local isKey = (bag == keyBag)
		local n = C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, n do
			if not isKey then total = total + 1 end
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				local stack, bind, price, classID, equipLoc, subclassID = ItemExtra(info.itemID)
				local link = info.hyperlink
				items[#items + 1] = {
					bag = bag, slot = slot, info = info, itemID = info.itemID,
					count = info.stackCount or 1, quality = info.quality or 1,
					bound = info.isBound, link = link,
					name = link and link:match("%[(.-)%]") or tostring(info.itemID),
					maxStack = stack or ((info.stackCount or 1) > 1 and 20 or 1),
					stackKnown = stack ~= nil,
					bindType = bind or 0,
					price = price or 0,
					quest = IsQuestItem(bag, slot, classID),
					classID = classID, subclassID = subclassID, equipLoc = equipLoc,
					key = isKey,
				}
			elseif not isKey then
				free[#free + 1] = { bag = bag, slot = slot }
			end
		end
	end
	return items, free, total
end

local function On(k) return not (DB.fixedOn and DB.fixedOn[k] == false) end

local function SectionOf(e)
	if DB.hidden[e.itemID] then return "hidden" end
	if e.key then return On("keys") and "keys" or "other" end
	local key = Assign()[e.itemID]
	if key == "grey" and On("grey") then return "grey" end    -- zelf naar Auto Sell gesleept
	if key == "other" then return "other" end                 -- zelf naar Overig gesleept: nooit automatisch
	if key == "quest" and On("quest") then return "quest" end -- zelf naar Quest gesleept
	if key == "boe" and On("boe") then return "boe" end       -- zelf naar BoE gesleept
	if key and CatByKey(key) then return key end
	if On("quest") and DB.questAuto and e.quest then return "quest" end
	if On("grey") and DB.greyAuto and e.quality == 0 then return "grey" end
	if On("boe") and IsBoE(e) then return "boe" end
	local best, bestKey
	for _, c in ipairs(DB.cats) do
		local p = c.preset and PRESET[c.preset]
		if p and (not best or p.rank < best.rank) and p.match(e) then best, bestKey = p, c.key end
	end
	if bestKey then return bestKey end
	return "other"
end

-- Waar moet een item heen bij de mailbox? (nil = nergens)
local function MailTarget(e)
	if DB.hidden[e.itemID] or e.bound or e.key then return nil end
	local sec = SectionOf(e)
	local name
	if sec == "boe" then
		name = DB.boeMail
	else
		local c = CatByKey(sec)
		name = c and c.mailTo
	end
	if not name or name == "" then return nil end
	if SameName(name, MyFullName()) then return nil end -- nooit naar jezelf
	return FullName(name), sec
end

---------------------------------------------------------------------------
-- Stijl
---------------------------------------------------------------------------

local TILE, GAP, PAD = 37, 4, 16
local GOLD = { 1, 0.82, 0 }
local DIALOG_BACKDROP = BACKDROP_DIALOG_32_32 or {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileEdge = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local SLOT_TEX = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function NewWindow(name, title, w, h)
	local ok, f = pcall(CreateFrame, "Frame", name, UIParent, "BackdropTemplate")
	if not ok then f = CreateFrame("Frame", name, UIParent) end
	f:SetSize(w, h)
	f:SetFrameStrata("MEDIUM")
	f:SetToplevel(true)
	if f.SetBackdrop then f:SetBackdrop(DIALOG_BACKDROP) end
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	local okH, header = pcall(CreateFrame, "Frame", nil, f, "DialogHeaderTemplate")
	if okH and header and header.Setup then
		pcall(header.Setup, header, title)
	else
		local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		t:SetPoint("TOP", f, "TOP", 0, -12)
		t:SetText(title)
	end
	local okC, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
	if okC then
		close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
		close:SetScript("OnClick", function() f:Hide() end)
	end
	if UISpecialFrames then tinsert(UISpecialFrames, name) end
	f:Hide()
	return f
end

local function MakeButton(parent, text, w)
	local ok, btn = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
	if not ok then btn = CreateFrame("Button", nil, parent) end
	btn:SetSize(w or 100, 22)
	if btn.SetText then btn:SetText(text) end
	return btn
end

local function Tooltip(frame, title, ...)
	local lines = { ... }
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(title)
		for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- Hoofdvenster
---------------------------------------------------------------------------

local main
local itemPool, headerPool, plusPool = {}, {}, {}
local usedItems, usedHeaders, usedPlus = 0, 0, 0
local showHidden = false -- true = verbergmodus: verborgen groep zichtbaar, klik = verbergen/terughalen
local layoutPending, inLayout = false, false
local lastFree, lastItems = {}, {}
local searchText = ""
-- Vaste volgorde zolang het venster open is: [sectie] = { key, key, ... }.
-- Leeg = opnieuw sorteren (bij openen, of als je een categorie wijzigt).
local frozen = {}
local function ResetOrder() frozen = {} end

local function CursorItemID()
	local kind, id = GetCursorInfo()
	if kind == "item" then return id end
end

-- Sorteren per categorie: soort, stapelprijs, nieuwste als laatst of handmatig.
local SORTS = { "type", "value", "newest", "manual" }
local SORT_NAME = { type = "type", value = "stack price", newest = "newest last", manual = "manual" }
local function SortMode(sec)
	DB.sort = DB.sort or {}
	return DB.sort[sec.key] or (sec.byValue and "value" or "type")
end

-- Per karakter: wanneer is een item voor het eerst gezien, en jouw eigen volgorde.
local function CharData()
	return CharEntry() or { seen = {}, manual = {} }
end

local SetHidden -- vooruit
local lastOrder = {} -- per groep: de item-ID's in de volgorde zoals ze nu in beeld staan

-- Komt het item op de cursor uit dezelfde groep als deze tegel?
local function ReorderTarget(b)
	local id = CursorItemID()
	local g = b.group
	if not id or not g or id == g.itemID or not b.secKey then return false end
	for _, e in ipairs(lastItems or {}) do
		if e.itemID == id then return SectionOf(e) == b.secKey end
	end
	return false
end

local function Reorder(b)
	if not ReorderTarget(b) then return false end
	local id, target, key = CursorItemID(), b.group.itemID, b.secKey
	local list = {}
	for _, v in ipairs(lastOrder[key] or {}) do list[#list + 1] = v end
	local from, to
	for i, v in ipairs(list) do
		if v == id and not from then from = i end
		if v == target and not to then to = i end
	end
	if not from or not to then return false end
	if (b.dropMode or "swap") == "swap" then
		list[from], list[to] = list[to], list[from]
	else
		table.remove(list, from)
		if from < to then to = to - 1 end
		table.insert(list, to, id)
	end
	DB.sort = DB.sort or {}
	if DB.sort[key] ~= "manual" then
		DB.sort[key] = "manual"
		Print(T("Sorting set to manual for this group."))
	end
	CharData().manual[key] = list
	Log("reorder " .. key .. ": " .. id .. " " .. (b.dropMode or "swap") .. " " .. target)
	ClearCursor()
	b.insertMark:Hide(); b.swapMark:Hide(); b.watch:Hide()
	ResetOrder(); Refresh()
	return true
end

local function NewItemButton(i)
	local b = CreateFrame("ItemButton", "CarefreeBagItem" .. i, main.content, "ContainerFrameItemButtonTemplate")
	b:SetSize(TILE, TILE)
	-- Volgorde aanpassen: sleep een item op een ander item in dezelfde groep.
	-- Links op de tegel = ertussen zetten (gouden streep), rest = omwisselen (gouden rand).
	b.insertMark = b:CreateTexture(nil, "OVERLAY", nil, 7)
	b.insertMark:SetColorTexture(1, 0.82, 0, 1)
	b.insertMark:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 2)
	b.insertMark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -3, -2)
	b.insertMark:SetWidth(3)
	b.insertMark:Hide()
	b.swapMark = b:CreateTexture(nil, "OVERLAY", nil, 7)
	b.swapMark:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	b.swapMark:SetBlendMode("ADD")
	b.swapMark:SetVertexColor(1, 0.82, 0)
	b.swapMark:SetPoint("CENTER")
	b.swapMark:SetSize(TILE * 1.8, TILE * 1.8)
	b.swapMark:Hide()
	b.watch = CreateFrame("Frame", nil, b)
	b.watch:Hide()
	b.watch:SetScript("OnUpdate", function()
		if not CursorHasItem() or not b:IsMouseOver() then
			b.insertMark:Hide(); b.swapMark:Hide(); b.dropMode = nil; b.watch:Hide(); return
		end
		local x = GetCursorPosition() / (b:GetEffectiveScale() or 1)
		local left, w = b:GetLeft() or 0, b:GetWidth() or TILE
		b.dropMode = ((x - left) / w < 0.35) and "insert" or "swap"
		b.insertMark:SetShown(b.dropMode == "insert")
		b.swapMark:SetShown(b.dropMode == "swap")
	end)
	b:HookScript("OnEnter", function(self)
		if ReorderTarget(self) then self.watch:Show() end
	end)
	b:HookScript("OnLeave", function(self) self.insertMark:Hide(); self.swapMark:Hide(); self.watch:Hide() end)
	local origDrag = b:GetScript("OnReceiveDrag")
	b:SetScript("OnReceiveDrag", function(self, ...)
		if Reorder(self) then return end
		if origDrag then return origDrag(self, ...) end
	end)
	b:HookScript("OnEnter", function(self)
		local g = self.group
		local each = g and AHPrice(g.link)
		if not each or not GameTooltip:IsOwned(self) then return end
		local net = math.floor(each * g.count * (1 - AH_CUT))
		GameTooltip:AddLine(T("AH value after 5%% cut: %s"):format(
			GetMoneyString and GetMoneyString(net, true) or tostring(net)), 0.4, 0.8, 1)
		GameTooltip:Show()
	end)
	b.multi = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	b.multi:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.multi:SetTextColor(0.4, 0.85, 1)

	-- Een gewone knop bovenop de tegel, alleen zichtbaar in de verbergmodus.
	local o = CreateFrame("Button", nil, b)
	o:SetAllPoints(b)
	o:SetFrameLevel(b:GetFrameLevel() + 5)
	o:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	o.tex = o:CreateTexture(nil, "OVERLAY")
	o.tex:SetAllPoints(o)
	o:SetScript("OnClick", function(self)
		local g = b.group
		if g then SetHidden(g.itemID, not DB.hidden[g.itemID]) end
	end)
	o:SetScript("OnEnter", function(self)
		local g = b.group
		if not g then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if g.link then GameTooltip:SetHyperlink(g.link) end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(DB.hidden[g.itemID] and T("CarefreeBag: click to show this item again") or T("CarefreeBag: click to hide this item"), GOLD[1], GOLD[2], GOLD[3])
		GameTooltip:Show()
	end)
	o:SetScript("OnLeave", function() GameTooltip:Hide() end)
	o:Hide()
	b.overlay = o
	return b
end

local function GetItemButton()
	usedItems = usedItems + 1
	local b = itemPool[usedItems]
	if not b then
		b = NewItemButton(usedItems)
		itemPool[usedItems] = b
	end
	return b
end

-- Rode vierkante knop zoals Blizzard die gebruikt (128-RedButton-...).
local function HasAtlas(a) return a and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(a) ~= nil end
local function SetRedKit(b, kit, fallback)
	if HasAtlas(kit) then
		b:SetNormalAtlas(kit)
		if HasAtlas(kit .. "-Pressed") then b:SetPushedAtlas(kit .. "-Pressed") end
		if HasAtlas(kit .. "-Highlight") then b:SetHighlightAtlas(kit .. "-Highlight", "ADD")
		else b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD") end
	elseif fallback then
		b:SetNormalTexture(fallback)
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	end
end
local function RedButton(parent, name, size, kit, fallback, iconAtlases)
	local b = CreateFrame("Button", name, parent)
	b:SetSize(size, size)
	SetRedKit(b, kit, fallback)
	if iconAtlases and HasAtlas(kit) then
		for _, a in ipairs(iconAtlases) do
			if HasAtlas(a) then
				b.icon = b:CreateTexture(nil, "OVERLAY")
				b.icon:SetAtlas(a)
				b.icon:SetSize(size * 0.6, size * 0.6)
				b.icon:SetPoint("CENTER", 0, 1)
				break
			end
		end
	end
	return b
end

local MAIL_ICON = "|TInterface\\Minimap\\Tracking\\Mailbox:14:14|t"
local CHECK_ICON = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14|t"
local ARROW_ICON = "|TInterface\\ChatFrame\\ChatFrameExpandArrow:10:10:0:0:16:16:0:16:0:16|t"
local keepHeader -- na in-/uitklappen: dit kopje moet op dezelfde plek blijven

-- Keuzelijstje voor sorteren (één lijstje, gedeeld door alle groepen).
local sortMenu
local function OpenSortMenu(anchor, sec)
	if not sec then return end
	if not sortMenu then
		sortMenu = CreateFrame("Frame", "CarefreeBagSortMenu", UIParent, "BackdropTemplate")
		sortMenu:SetFrameStrata("DIALOG")
		sortMenu:SetClampedToScreen(true)
		if sortMenu.SetBackdrop then
			sortMenu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
				insets = { left = 3, right = 3, top = 3, bottom = 3 } })
			sortMenu:SetBackdropColor(0, 0, 0, 0.95)
		end
		sortMenu:SetSize(170, #SORTS * 20 + 10)
		sortMenu.buttons = {}
		for i, m in ipairs(SORTS) do
			local b = CreateFrame("Button", nil, sortMenu)
			b:SetSize(160, 20)
			b:SetPoint("TOPLEFT", sortMenu, "TOPLEFT", 5, -5 - (i - 1) * 20)
			b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
			b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			b.fs:SetPoint("LEFT", b, "LEFT", 4, 0)
			b.mode = m
			b:SetScript("OnClick", function(self)
				DB.sort = DB.sort or {}
				DB.sort[sortMenu.sec.key] = self.mode
				Log("sort " .. sortMenu.sec.key .. ": " .. self.mode)
				sortMenu:Hide()
				ResetOrder(); Refresh()
			end)
			sortMenu.buttons[i] = b
		end
		sortMenu:Hide()
	end
	if sortMenu:IsShown() and sortMenu.sec == sec then sortMenu:Hide(); return end
	sortMenu.sec = sec
	local cur = SortMode(sec)
	for _, b in ipairs(sortMenu.buttons) do
		b.fs:SetText((b.mode == cur and CHECK_ICON or "    ") .. " " .. T(SORT_NAME[b.mode]))
	end
	sortMenu:ClearAllPoints()
	sortMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
	sortMenu:Show()
end

local function GetHeader()
	usedHeaders = usedHeaders + 1
	local h = headerPool[usedHeaders]
	if not h then
		h = CreateFrame("Frame", nil, main.content)
		h:SetSize(200, 16)
		h:EnableMouse(true)
		-- [-] / [+]: groep in- of uitklappen
		h.toggle = RedButton(h, nil, 15, "128-redbutton-minus", "Interface\\Buttons\\UI-MinusButton-Up")
		h.toggle:SetPoint("LEFT", h, "LEFT", 0, 0)
		h.toggle:SetScript("OnClick", function()
			if not h.key then return end
			DB.collapsed = DB.collapsed or {}
			DB.collapsed[h.key] = not DB.collapsed[h.key] or nil
			keepHeader = { key = h.key, top = h:GetTop() } -- het minnetje blijft onder je muis
			Refresh()
		end)
		h.fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		h.fs:SetPoint("LEFT", h, "LEFT", 18, 0)
		h.fs:SetJustifyH("LEFT")
		h.SetText = function(self, t) self.fs:SetText(t) end
		-- "Auto" + envelop: alleen hier staat de post-info in de tooltip
		h.mail = CreateFrame("Button", nil, h)
		h.mail:SetSize(50, 14)
		h.mail:SetPoint("LEFT", h.fs, "RIGHT", 6, 0)
		h.mail.fs = h.mail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		h.mail.fs:SetPoint("LEFT")
		h.mail.fs:SetText("|cff888888Auto|r " .. MAIL_ICON)
		h.mail:SetScript("OnEnter", function(self)
			if not (h.sec and h.sec.mailTo) then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(T("These items are mailed to %s when you open a mailbox."):format(h.sec.mailTo), 1, 1, 1, true)
			GameTooltip:Show()
		end)
		h.mail:SetScript("OnLeave", function() GameTooltip:Hide() end)
		-- Sorteerknop rechts: klik = volgende manier van sorteren
		h.sort = CreateFrame("Button", nil, h)
		h.sort:SetSize(18, 18)
		h.sort:SetPoint("RIGHT", h, "RIGHT", 0, 0)
		if HasAtlas("bags-button-autosort-up") then
			h.sort:SetNormalAtlas("bags-button-autosort-up")
			if HasAtlas("bags-button-autosort-down") then h.sort:SetPushedAtlas("bags-button-autosort-down") end
			h.sort:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		else
			SetRedKit(h.sort, "128-redbutton-arrowdown", "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
		end
		h.sort:SetScript("OnClick", function(self) OpenSortMenu(self, h.sec) end)
		h.sort:SetScript("OnEnter", function(self)
			if not h.sec then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(T("Sort: %s"):format(T(SORT_NAME[SortMode(h.sec)])))
			GameTooltip:AddLine(T("Drag items onto each other to reorder."), 1, 1, 1, true)
			GameTooltip:Show()
		end)
		h.sort:SetScript("OnLeave", function() GameTooltip:Hide() end)
		h:SetScript("OnEnter", function(self)
			if not self.rules then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(self.ruleTitle or "")
			GameTooltip:AddLine(self.rules, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		h:SetScript("OnLeave", function() GameTooltip:Hide() end)
		headerPool[usedHeaders] = h
	end
	h.rules, h.ruleTitle = nil, nil
	h:Show()
	return h
end

-- Assign: wat er gebeurt als je een item op een "+"-vakje laat vallen.
local function DropOn(sectionKey)
	local id = CursorItemID()
	if not id then return end
	if sectionKey == "hidden" then
		DB.hidden[id] = true
	elseif sectionKey == "other" then
		DB.hidden[id] = nil
		Assign()[id] = "other"
	else
		DB.hidden[id] = nil
		Assign()[id] = sectionKey
	end
	Log("dropped " .. id .. " -> " .. sectionKey)
	ClearCursor() -- item gaat terug naar zijn eigen vakje
	ResetOrder()
	Refresh()
end

local function NewSlotTile(parent)
	local t = CreateFrame("Button", nil, parent)
	t:SetSize(TILE, TILE)
	t:RegisterForClicks("LeftButtonUp")
	t.bg = t:CreateTexture(nil, "BACKGROUND")
	t.bg:SetTexture(SLOT_TEX)
	t.bg:SetPoint("TOPLEFT", -1, 1)
	t.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	t.bg:SetVertexColor(0.8, 0.8, 0.8, 0.7)
	t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	t.text:SetPoint("CENTER")
	return t
end

local function GetPlus()
	usedPlus = usedPlus + 1
	local t = plusPool[usedPlus]
	if not t then
		t = NewSlotTile(main.content)
		t.text:SetText("+")
		t.text:SetTextColor(0.6, 0.6, 0.6)
		local function drop(self) DropOn(self.section) end
		t:SetScript("OnReceiveDrag", drop)
		t:SetScript("OnClick", drop)
		t:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(self.tipTitle)
			GameTooltip:AddLine(self.tipText, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		t:SetScript("OnLeave", function() GameTooltip:Hide() end)
		plusPool[usedPlus] = t
	end
	t:Show()
	return t
end

-- Vrije vakjes: liever een gewone tas dan een speciale (quiver, herb bag).
local function FirstFreeSlot()
	local id = CursorItemID()
	local itemFam = 0
	if id and C_Item.GetItemFamily then
		local okI, fam = pcall(C_Item.GetItemFamily, id)
		if okI and fam then itemFam = fam end
	end
	local best
	for _, f in ipairs(lastFree) do
		local okF, _, family = pcall(C_Container.GetContainerNumFreeSlots, f.bag)
		family = okF and family or 0
		if family == 0 then return f end
		-- beroepstas: alleen als het item erin past
		if bit and bit.band and itemFam ~= 0 and bit.band(itemFam, family) ~= 0 then best = best or f end
	end
	return best
end

local function SetupItemButton(b, g)
	local e = g.rep
	local info = e.info
	b.group = g
	b:SetBagID(e.bag)
	b:SetID(e.slot)
	pcall(ClearItemButtonOverlay, b)
	pcall(b.SetHasItem, b, info.iconFileID)
	SetItemButtonTexture(b, info.iconFileID)
	pcall(SetItemButtonQuality, b, info.quality, info.hyperlink, false, info.isBound)
	SetItemButtonCount(b, g.count)
	SetItemButtonDesaturated(b, info.isLocked)
	pcall(b.UpdateNewItem, b, info.quality)
	pcall(b.UpdateJunkItem, b, info.quality, info.hasNoValue)
	pcall(b.UpdateCooldown, b, info.iconFileID)
	local match = searchText == "" or (g.name or ""):lower():find(searchText, 1, true) ~= nil
	if b.SetMatchesSearch then pcall(b.SetMatchesSearch, b, match) end
	b:SetAlpha(match and 1 or 0.3)
	if #g.slots > 1 then
		b.multi:SetText(#g.slots .. "x")
		b.multi:Show()
	else
		b.multi:Hide()
	end
	if showHidden then
		if DB.hidden[g.itemID] then b.overlay.tex:SetColorTexture(0.6, 0, 0, 0.35)
		else b.overlay.tex:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.12) end
		b.overlay:Show()
	else
		b.overlay:Hide()
	end
	b:Show()
end

local BLUE = "|cff66ccff"

-- Volgorde van alle groepen (eigen categorieën + vaste groepen), aanpasbaar in de opties.
local FIXED = { quest = true, keys = true, boe = true, grey = true, other = true }

local function FixOrder()
	DB.order = DB.order or {}
	local seen, clean = {}, {}
	for _, k in ipairs(DB.order) do
		if not seen[k] and (FIXED[k] or CatByKey(k)) then clean[#clean + 1] = k; seen[k] = true end
	end
	-- Ontbrekende eigen categorieën: na de laatste eigen categorie (of bovenaan).
	for _, c in ipairs(DB.cats) do
		if not seen[c.key] then
			local pos = 0
			for idx, k in ipairs(clean) do if not FIXED[k] then pos = idx end end
			table.insert(clean, pos + 1, c.key)
			seen[c.key] = true
		end
	end
	for _, k in ipairs({ "quest", "keys", "boe", "grey", "other" }) do
		if not seen[k] then clean[#clean + 1] = k end
	end
	DB.order = clean
	return clean
end

local function FixedSection(key)
	if key ~= "other" and not On(key) then return nil end
	if key == "quest" then
		return { key = "quest", title = T("Quest"), plus = true, fixed = true,
			tip = T("Drop an item: it goes here from now on."),
			rules = T("Quest items. Never sold or mailed.") }
	elseif key == "keys" then
		return { key = "keys", title = T("Keys"), plus = false, fixed = true,
			rules = T("Your keyring.") }
	elseif key == "boe" then
		return { key = "boe", title = "BoE", mailTo = (DB.boeMail ~= "" and DB.boeMail or nil), plus = true, fixed = true,
			tip = T("Drop an item: it goes here from now on."),
			rules = T("Unbound BoE items, green and better.") }
	elseif key == "grey" then
		return { key = "grey", title = "Auto Sell" .. ((DB.autoSell or not DB.autoSellAsked) and "" or ("  |cff888888(" .. T("selling is off") .. ")|r")), plus = true, byValue = true, fixed = true,
			tip = T("Drop an item: it goes here from now on."),
			rules = T("Grey items. Sold at a vendor (Shift = skip).") }
	elseif key == "other" then
		return { key = "other", title = T("Other"), plus = true, fixed = true,
			tip = T("Drop an item: it goes here from now on."),
			rules = T("Everything without a group.") }
	end
end

local function SectionList()
	local list = {}
	for _, key in ipairs(FixOrder()) do
		if FIXED[key] then
			local sec = FixedSection(key)
			if sec then list[#list + 1] = sec end
		else
			local c = CatByKey(key)
			local title = c.name
			list[#list + 1] = { key = c.key, title = title, plus = true, byValue = (c.mailTo and c.mailTo ~= "") and "ah" or nil,
				mailTo = (c.mailTo and c.mailTo ~= "") and c.mailTo or nil,
				tip = T("Drop an item: it goes here from now on."),
				rules = c.preset and T(PRESET[c.preset].tip) or nil }
		end
	end
	if showHidden then
		list[#list + 1] = { key = "hidden", title = T("Hidden"), plus = true, fixed = true,
			tip = T("Drop an item to hide it."),
			rules = T("Your hidden items.") }
	end
	return list
end

local function SortGroups(a, b)
	if a.quality ~= b.quality then return a.quality > b.quality end
	if a.name ~= b.name then return a.name < b.name end
	return a.rep.bag * 100 + a.rep.slot < b.rep.bag * 100 + b.rep.slot
end

local gapPool, usedGaps = {}, 0
local FOOTER_H = TILE + 6

-- Gat op de plek van een item dat net op is (tot je de tassen sluit).
-- Laat je er een item op vallen, dan gaat het naar een leeg vakje.
local function GetGap()
	usedGaps = usedGaps + 1
	local t = gapPool[usedGaps]
	if not t then
		t = NewSlotTile(main.content)
		t.bg:SetVertexColor(0.5, 0.5, 0.5, 0.5)
		local function drop()
			if not CursorHasItem() then return end
			local f = FirstFreeSlot()
			if f then C_Container.PickupContainerItem(f.bag, f.slot) end
		end
		t:SetScript("OnReceiveDrag", drop)
		t:SetScript("OnClick", drop)
		gapPool[usedGaps] = t
	end
	t:Show()
	return t
end

local function StripColors(t)
	return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Layout()
	if not main or not main:IsShown() then return end
	if not DB.enabled then main:Hide(); return end
	-- Tassenknoppen zijn geen beschermde frames: opbouwen mag ook in een gevecht.
	if inLayout then return end
	inLayout = true

	local items, free, total = Scan()
	lastFree, lastItems = free, items

	-- 1. Groeperen per sectie (en per item als stapels samengevoegd worden).
	local bySection, hiddenCount = {}, 0
	for _, e in ipairs(items) do
		local sec = SectionOf(e)
		if sec == "hidden" then hiddenCount = hiddenCount + 1 end
		local s = bySection[sec]
		if not s then s = { groups = {}, byKey = {} }; bySection[sec] = s end
		local key = (DB.merge and e.maxStack > 1) and ("i" .. e.itemID) or ("s" .. e.bag .. ":" .. e.slot)
		local g = s.byKey[key]
		if not g then
			g = { key = key, slots = {}, count = 0, quality = e.quality, name = e.name, link = e.link, itemID = e.itemID, price = e.price, value = 0, ahValue = 0 }
			s.byKey[key] = g
			s.groups[#s.groups + 1] = g
		end
		g.slots[#g.slots + 1] = e
		g.count = g.count + e.count
		g.value = g.value + (e.price or 0) * e.count
		local c = CatByKey(sec)
		if c and c.mailTo and c.mailTo ~= "" then
			-- AH-waarde van de hele stapel; geen AH-prijs bekend = vendorprijs.
			g.ahValue = g.ahValue + (AHPrice(e.link) or e.price or 0) * e.count
		end
		-- Klik gebruikt de kleinste stapel, zo raakt hij het eerst leeg.
		if not g.rep or e.count < g.rep.count then g.rep = e end
	end

	-- Nieuwste als laatst: onthoud wanneer een item voor het eerst in je tassen kwam.
	do
		local ch, now, present = CharData(), (time and time()) or 0, {}
		for _, e in ipairs(items) do
			present[e.itemID] = true
			if not ch.seen[e.itemID] then ch.seen[e.itemID] = now end
		end
		for id in pairs(ch.seen) do if not present[id] then ch.seen[id] = nil end end
	end

	-- 2. Per sectie sorteren, of de vaste volgorde aanhouden zolang het venster open is.
	local full = {}
	for _, sec in ipairs(SectionList()) do
		local s = bySection[sec.key]
		local groups = s and s.groups or {}
		local field = (sec.byValue == "ah") and "ahValue" or "value"
		local mode = SortMode(sec)
		local ch = CharData()
		local function newer(a, b)
			local ta, tb = ch.seen[a.itemID] or 0, ch.seen[b.itemID] or 0
			if ta ~= tb then return ta < tb end
			return a.name < b.name
		end
		if mode == "value" then
			table.sort(groups, function(a, b)
				if a[field] ~= b[field] then return a[field] > b[field] end
				return a.name < b.name
			end)
		elseif mode == "newest" then
			table.sort(groups, newer)
		elseif mode == "manual" then
			local pos = {}
			for i, id in ipairs(ch.manual[sec.key] or {}) do pos[id] = pos[id] or i end
			table.sort(groups, function(a, b)
				local pa, pb = pos[a.itemID], pos[b.itemID]
				if pa and pb then if pa ~= pb then return pa < pb end return a.key < b.key end
				if pa or pb then return pa ~= nil end
				return newer(a, b)
			end)
		else
			table.sort(groups, SortGroups)
		end
		local cells = {}
		local order = frozen[sec.key]
		if order then
			local byKey = s and s.byKey or {}
			local used = {}
			for _, k in ipairs(order) do
				if byKey[k] then cells[#cells + 1] = byKey[k]; used[k] = true
				else cells[#cells + 1] = { gap = true } end
			end
			for _, g in ipairs(groups) do
				if not used[g.key] then cells[#cells + 1] = g; order[#order + 1] = g.key end
			end
		else
			order = {}
			for _, g in ipairs(groups) do cells[#cells + 1] = g; order[#order + 1] = g.key end
			frozen[sec.key] = order
		end
		local title = sec.title
		DB.collapsed = DB.collapsed or {}
		if DB.collapsed[sec.key] then
			full[#full + 1] = { sec = sec, cells = {}, title = title, collapsed = true, n = #groups }
		-- Ook een groep met alleen nog gaten blijft staan tot je de tassen sluit.
		elseif #cells > 0 then
			full[#full + 1] = { sec = sec, cells = cells, title = title }
		elseif sec.plus or (sec.fixed and sec.key ~= "hidden" and (sec.key ~= "keys" or KeyringBag())) then
			-- Lege groep: gewone regel (met het lege +vakje als die er een heeft).
			full[#full + 1] = { sec = sec, cells = cells, title = title }
		end
	end

	usedItems, usedHeaders, usedPlus, usedGaps = 0, 0, 0, 0

	-- 4. Hoogte uitrekenen voor een aantal kolommen.
	local function Measure(cols)
		local h = 8
		for _, f in ipairs(full) do
			local n = f.collapsed and 0 or (#f.cells + (f.sec.plus and 1 or 0))
			h = h + 18 + math.ceil(n / cols) * (TILE + GAP) + 6
		end
		return h
	end

	-- 5. Kolommen kiezen: eerst breder (tot het maximum), dan pas scrollen.
	local top = showHidden and 78 or 62
	local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768
	if screenH <= 0 then screenH = 768 end
	local maxView = math.floor(screenH * 0.8) - top - FOOTER_H - PAD
	local maxCols = DB.maxCols
	local minCols = math.min(8, maxCols)
	local cols, contentH = minCols, Measure(minCols)
	while contentH > maxView and cols < maxCols do
		cols = cols + 1
		contentH = Measure(cols)
	end
	local width = cols * (TILE + GAP) - GAP

	-- 6. Plaatsen.
	local y = -8
	local function place(frame, col)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", main.content, "TOPLEFT", col * (TILE + GAP), y)
	end
	for _, f in ipairs(full) do
		local h = GetHeader()
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", main.content, "TOPLEFT", 0, y)
		h:SetWidth(width)
		h.key, h.sec = f.sec.key, f.sec
		local t = f.sec.fixed and (BLUE .. f.title .. "|r") or f.title
		if f.collapsed and f.n > 0 then t = t .. "  |cff888888(" .. f.n .. ")|r" end
		h:SetText(t)
		SetRedKit(h.toggle, f.collapsed and "128-redbutton-plus" or "128-redbutton-minus",
			f.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
		h.sort:SetShown(not f.collapsed and f.sec.key ~= "hidden" and f.sec.key ~= "keys")
		h.mail:SetShown(f.sec.mailTo ~= nil)
		h.sort.mode = SortMode(f.sec)
		h.rules, h.ruleTitle = f.sec.rules, StripColors(f.sec.title)
		y = y - 18
		local col = 0
		local ids = {}
		lastOrder[f.sec.key] = ids
		for _, cell in ipairs(f.collapsed and {} or f.cells) do
			local b
			if cell.gap then
				b = GetGap()
			else
				b = GetItemButton()
				SetupItemButton(b, cell)
				b.secKey = f.sec.key
				ids[#ids + 1] = cell.itemID
			end
			place(b, col)
			col = col + 1
			if col == cols then col = 0; y = y - (TILE + GAP) end
		end
		if f.sec.plus and not f.collapsed then
			local p = GetPlus()
			p.section = f.sec.key
			p.tipTitle = StripColors(f.sec.title)
			p.tipText = f.sec.tip
			place(p, col)
			col = col + 1
		end
		if col > 0 then y = y - (TILE + GAP) end
		y = y - 6
	end
	for i = usedItems + 1, #itemPool do itemPool[i]:Hide(); itemPool[i].group = nil end
	for i = usedHeaders + 1, #headerPool do headerPool[i]:Hide() end
	for i = usedPlus + 1, #plusPool do plusPool[i]:Hide() end
	for i = usedGaps + 1, #gapPool do gapPool[i]:Hide() end

	-- 7. Scrollgebied en venstergrootte.
	local keep = keepHeader
	contentH = -y
	local viewH = math.min(contentH, maxView)
	main.content:SetSize(width, contentH)
	main.scroll:ClearAllPoints()
	main.scroll:SetPoint("TOPLEFT", main, "TOPLEFT", PAD, -top)
	main.scroll:SetSize(width, viewH)
	main.scrollMax = math.max(0, contentH - viewH)
	local cur = main.scroll.GetVerticalScroll and main.scroll:GetVerticalScroll() or 0
	if cur > main.scrollMax then main.scroll:SetVerticalScroll(main.scrollMax) end
	main.scrollHint:SetShown(main.scrollMax > 0)
	if keep then
		keepHeader = nil
		for i = 1, usedHeaders do
			local h = headerPool[i]
			if h.key == keep.key and keep.top then
				local now = h:GetTop()
				local p, rel, rp, x, yy = main:GetPoint(1)
				if now and p then
					main:ClearAllPoints()
					main:SetPoint(p, rel, rp, x, yy + (keep.top - now))
					SavePos()
				end
			end
		end
	end

	-- Voetregel: vrije vakjes + goud, altijd onderaan in beeld.
	local used = math.max(0, total - #free)
	local frac = total > 0 and used / total or 0
	main.freeBar:SetValue(frac)
	-- vloeiend van groen naar oranje naar rood
	local r, g, bl
	if frac < 0.6 then r, g, bl = 0.30, 0.80, 0.40
	elseif frac < 0.85 then local t = (frac - 0.6) / 0.25; r, g, bl = 0.30 + 0.70 * t, 0.80 - 0.10 * t, 0.40 - 0.30 * t
	else local t = math.min(1, (frac - 0.85) / 0.15); r, g, bl = 1.00 - 0.10 * t, 0.70 - 0.50 * t, 0.10 + 0.05 * t end
	main.freeBar:SetStatusBarColor(r, g, bl)
	main.freeBar.text:SetText(used .. "/" .. total)
	main.freeBar.free, main.freeBar.total = #free, total
	local money = GetMoney()
	if money >= 10000 then money = money - money % 100 end -- met goud: geen koper meer tonen
	main.money:SetText(GetMoneyString and GetMoneyString(money, true) or tostring(money))

	main.hiddenBtn.count:SetText(hiddenCount > 0 and hiddenCount or "")
	SetRedKit(main.hiddenBtn, showHidden and "128-redbutton-visibilityon" or "128-redbutton-visibilityoff", "Interface\\Icons\\Spell_Shadow_EvilEye")
	main.hint:SetShown(showHidden)

	main:SetSize(width + 2 * PAD, top + viewH + FOOTER_H + PAD)
	inLayout = false

	if needInfo and not main.infoRetry then
		main.infoRetry = true
		C_Timer.After(1, function() main.infoRetry = nil; Refresh() end)
	end
end

local refreshQueued = false
Refresh = function()
	if refreshQueued then return end
	refreshQueued = true
	C_Timer.After(0.05, function()
		refreshQueued = false
		local ok, err = pcall(Layout)
		inLayout = false
		if not ok then DB.lastError = tostring(err); Log("error: " .. tostring(err)); Print(T("error: %s"):format(tostring(err))) end
	end)
end

local function ShowMain()
	if InCombatLockdown() then Log("opened during combat") end
	main:Show()
	Refresh()
end

SavePos = function()
	local point, _, rel, x, y = main:GetPoint(1)
	DB.pos = { point = point, rel = rel, x = x, y = y }
end

local ToggleConfig -- vooruit

local function BuildMain()
	main = NewWindow("CarefreeBagFrame", "CarefreeBag", 438, 300)
	main:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos() end)
	if DB.pos then
		main:SetPoint(DB.pos.point or "BOTTOMRIGHT", UIParent, DB.pos.rel or DB.pos.point or "BOTTOMRIGHT", DB.pos.x or -80, DB.pos.y or 120)
	else
		main:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 120)
	end
	main:SetScript("OnShow", function() if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_BACKPACK_OPEN) end end)
	main:SetScript("OnHide", function()
		showHidden = false
		ResetOrder() -- volgende keer openen: netjes opnieuw gesorteerd
		-- Nieuwe items hebben nu één keer geknipperd: markering weghalen.
		if C_NewItems and C_NewItems.RemoveNewItem then
			for _, e in ipairs(lastItems) do
				local okN, isNew = pcall(C_NewItems.IsNewItem, e.bag, e.slot)
				if okN and isNew then pcall(C_NewItems.RemoveNewItem, e.bag, e.slot) end
			end
		end
		if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_BACKPACK_CLOSE) end
	end)

	-- Twee rode Blizzard-knoppen rechtsboven: verbergen en opties.
	main.optBtn = RedButton(main, "CarefreeBagOptionsButton", 24, "128-RedButton", "Interface\\Icons\\Trade_Engineering",
		{ "GM-icon-settings", "questlog-icon-setting", "OptionsIcon-Brown" })
	main.optBtn:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, -32)
	main.optBtn:SetScript("OnClick", function() ToggleConfig() end)
	Tooltip(main.optBtn, T("Options"))
	main.hiddenBtn = RedButton(main, "CarefreeBagHideButton", 24, "128-redbutton-visibilityoff", "Interface\\Icons\\Spell_Shadow_EvilEye")
	main.hiddenBtn:SetPoint("RIGHT", main.optBtn, "LEFT", -4, 0)
	main.hiddenBtn.count = main.hiddenBtn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	main.hiddenBtn.count:SetPoint("BOTTOMRIGHT", main.hiddenBtn, "BOTTOMRIGHT", 2, -2)
	main.hiddenBtn:SetScript("OnClick", function() showHidden = not showHidden; Refresh() end)
	Tooltip(main.hiddenBtn, T("Hide items"))

	-- Zoekbalk: typ een naam, alles wat niet past wordt grijs.
	local okS, sb = pcall(CreateFrame, "EditBox", "CarefreeBagSearch", main, "SearchBoxTemplate")
	if not okS then sb = CreateFrame("EditBox", "CarefreeBagSearch", main, "InputBoxTemplate") end
	sb:SetSize(200, 20)
	sb:SetAutoFocus(false)
	sb:SetPoint("TOPLEFT", main, "TOPLEFT", PAD + 6, -34)
	sb:SetPoint("RIGHT", main.hiddenBtn, "LEFT", -8, 0)
	sb:HookScript("OnTextChanged", function(self)
		local t = (self:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if t ~= searchText then searchText = t; Refresh() end
	end)
	sb:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
	sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	if type(sb.Instructions) == "table" and sb.Instructions.SetText then pcall(sb.Instructions.SetText, sb.Instructions, T("Search...")) end
	main.search = sb

	main.hint = main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	main.hint:SetPoint("TOPLEFT", main, "TOPLEFT", PAD, -60)
	main.hint:SetText(T("|cffffd100Hiding:|r click an item to hide it or show it again."))
	main.hint:Hide()

	-- Scrollgebied: alleen nodig als het venster op zijn breedst nog te hoog is.
	main.scroll = CreateFrame("ScrollFrame", nil, main)
	main.scroll:SetPoint("TOPLEFT", main, "TOPLEFT", PAD, -62)
	main.scroll:SetSize(100, 100)
	main.content = CreateFrame("Frame", nil, main.scroll)
	main.content:SetSize(100, 100)
	main.scroll:SetScrollChild(main.content)
	main.scrollMax = 0
	main.scroll:EnableMouseWheel(true)
	main.scroll:SetScript("OnMouseWheel", function(self, delta)
		local v = (self:GetVerticalScroll() or 0) - delta * (TILE + GAP)
		self:SetVerticalScroll(math.max(0, math.min(main.scrollMax or 0, v)))
	end)
	main.scrollHint = main:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	main.scrollHint:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -PAD, FOOTER_H + 2)
	main.scrollHint:SetText(T("scroll for more"))
	main.scrollHint:Hide()

	-- Balk die laat zien hoe vol je tassen zitten (groen, oranje, rood).
	-- Balk in Blizzard-stijl, zoals de levensbalk in een tooltip.
	local bar = CreateFrame("StatusBar", "CarefreeBagFreeBar", main)
	bar:SetSize(150, 10)
	bar:SetPoint("LEFT", main, "BOTTOMLEFT", PAD + 4, PAD - 2 + TILE / 2)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(bar)
	bar.bg:SetColorTexture(0, 0, 0, 0.6)
	bar.border = bar:CreateTexture(nil, "OVERLAY")
	bar.border:SetTexture("Interface\\Tooltips\\UI-StatusBar-Border")
	bar.border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
	bar.border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
	bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.text:SetPoint("LEFT", bar, "RIGHT", 6, 0)
	bar:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(T("Free slots: %s of %s"):format(tostring(self.free or "?"), tostring(self.total or "?")))
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
	main.freeBar = bar
	main.money = main:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	main.money:SetJustifyH("RIGHT")
	main.money:SetPoint("RIGHT", main, "BOTTOMRIGHT", -PAD - 4, PAD - 2 + TILE / 2)
end

---------------------------------------------------------------------------
-- Bewerkmenu per item
---------------------------------------------------------------------------

SetHidden = function(id, v) DB.hidden[id] = v or nil; Log((v and "hidden: " or "visible: ") .. id); ResetOrder(); Refresh() end
---------------------------------------------------------------------------
-- Standaardtassen vervangen
---------------------------------------------------------------------------

local lastToggle, openedAt, openedBy = -1, -1, nil

local function HideBlizzardBags()
	if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then ContainerFrameCombinedBags:Hide() end
	for i = 1, (NUM_CONTAINER_FRAMES or 13) do
		local f = _G["ContainerFrame" .. i]
		if f and f:IsShown() then f:Hide() end
	end
end

-- Openen door de game (vendor, mailbox, backpack-knop). Als het venster nu door
-- een frame geopend wordt, onthouden we welk frame: dat mag het ook weer sluiten.
local function OpenMain(frame)
	local t = GetTime()
	if not main:IsShown() then
		openedAt = t
		openedBy = nil
		ShowMain()
	end
	if frame and frame.GetName and openedAt == t then openedBy = frame:GetName() end
end

local function OnToggle()
	if not DB.enabled then return end
	HideBlizzardBags()
	local t = GetTime()
	-- Eén toetsdruk kan meerdere Blizzard-functies aanroepen: maar één keer wisselen.
	if t == openedAt or t == lastToggle then return end
	lastToggle = t
	if main:IsShown() then
		main:Hide()
	else
		openedAt = t
		openedBy = nil
		ShowMain()
	end
end

local function OnOpenAll(frame)
	if not DB.enabled then return end
	HideBlizzardBags()
	OpenMain(frame)
end

local function OnCloseAll(frame)
	if not DB.enabled then return end
	HideBlizzardBags()
	local name = frame and frame.GetName and frame:GetName()
	if not frame or (openedBy and name == openedBy) then
		openedBy = nil
		main:Hide()
	end
end

-- De B-toets (en de backpack-toets) direct aan CarefreeBag koppelen. Zo hoeft de toets
-- niet via Blizzards eigen tasfuncties, en is het altijd: open <-> dicht.
local BindKeys -- hieronder ingevuld
local toggleBtn, binding, bindPending = nil, false, false

local function ToggleFromKey()
	local t = GetTime()
	lastToggle = t
	if main:IsShown() then
		main:Hide()
	else
		openedAt = t
		openedBy = nil
		HideBlizzardBags()
		ShowMain()
	end
end

BindKeys = function()
	if not toggleBtn then return end
	if InCombatLockdown() then bindPending = true; return end
	binding = true
	ClearOverrideBindings(toggleBtn)
	local keys = {}
	if DB.enabled then
		for _, action in ipairs({ "OPENALLBAGS", "TOGGLEBACKPACK" }) do
			for _, k in ipairs({ GetBindingKey(action) }) do
				SetOverrideBindingClick(toggleBtn, true, k, "CarefreeBagToggleButton")
				keys[#keys + 1] = k
			end
		end
	end
	binding = false
	local list = table.concat(keys, ", ")
	if list ~= DB.lastKeys then
		DB.lastKeys = list
		Log("keys for CarefreeBag: " .. (list ~= "" and list or "none"))
	end
end

local function HookBags()
	toggleBtn = CreateFrame("Button", "CarefreeBagToggleButton", UIParent)
	toggleBtn:SetScript("OnClick", ToggleFromKey)
	BindKeys()
	if ToggleAllBags then hooksecurefunc("ToggleAllBags", OnToggle) end
	if ToggleBackpack then hooksecurefunc("ToggleBackpack", OnToggle) end
	if OpenAllBags then hooksecurefunc("OpenAllBags", OnOpenAll) end
	if OpenBackpack then hooksecurefunc("OpenBackpack", function() OnOpenAll(nil) end) end
	if CloseAllBags then hooksecurefunc("CloseAllBags", OnCloseAll) end
end

---------------------------------------------------------------------------
-- CarefreeBag aan/uit (minimapknop en bovenaan de opties)
---------------------------------------------------------------------------

local UpdateMinimapIcon, RefreshConfig, mailPanel -- vooruit

local function SetEnabled(v)
	DB.enabled = v and true or false
	Log("CarefreeBag " .. (DB.enabled and "on" or "off"))
	if BindKeys then BindKeys() end
	if not DB.enabled then
		if main then main:Hide() end
		if mailPanel then mailPanel:Hide() end
		Print(T("CarefreeBag is off. Your normal bags are back."))
	else
		Print(T("CarefreeBag is on."))
	end
	if UpdateMinimapIcon then UpdateMinimapIcon() end
	if RefreshConfig then RefreshConfig() end
end

---------------------------------------------------------------------------
-- Andere tassen-addons herkennen
---------------------------------------------------------------------------

local OTHER_BAGS = { "Baganator", "Bagnon", "AdiBags", "ArkInventory", "BetterBags", "Combuctor", "GudaBags",
	"OneBag3", "Inventorian", "LiteBag", "BagDaddy", "BazBags", "Bagforge", "HardcoreBags", "BlockBags", "MyBags", "Sorted" }

local function IsLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
		return ok and loaded
	end
	return IsAddOnLoaded and IsAddOnLoaded(name)
end

local function CheckOtherBags()
	if not DB.enabled or not StaticPopupDialogs or not StaticPopup_Show then return end
	for _, name in ipairs(OTHER_BAGS) do
		if IsLoaded(name) and not DB.conflictOK[name] then
			Log("other bag addon found: " .. name)
			StaticPopupDialogs["CAREFREEBAG_CONFLICT"] = {
				text = T("CarefreeBag and %s both want to replace your bags. Which one do you want to use?"),
				button1 = "CarefreeBag",
				button2 = name,
				OnAccept = function()
					DB.conflictOK[name] = true
					Log("conflict: user chose CarefreeBag, disabling " .. name)
					if C_AddOns and C_AddOns.DisableAddOn then pcall(C_AddOns.DisableAddOn, name)
					elseif DisableAddOn then pcall(DisableAddOn, name) end
					ReloadUI()
				end,
				OnCancel = function(_, _, reason)
					if reason ~= "clicked" then return end
					DB.conflictOK[name] = true
					Log("conflict: user chose " .. name .. ", CarefreeBag turned off")
					SetEnabled(false)
					Print(T("%s keeps your bags. CarefreeBag is turned off; turn it on again with the minimap button."):format(name))
				end,
				timeout = 0, whileDead = true, hideOnEscape = false,
			}
			StaticPopup_Show("CAREFREEBAG_CONFLICT", name)
			return
		end
	end
end

---------------------------------------------------------------------------
-- Stapels op de achtergrond samenvoegen (echt, in de tassen)
---------------------------------------------------------------------------

-- Eén verplaatsing per keer: pak de kleinste losse stapel op en laat hem vallen
-- op de grootste niet-volle stapel van hetzelfde item. Daarna wachten we tot de
-- game klaar is (BAG_UPDATE_DELAYED) en doen we de volgende.
local stack = { moves = 0, burst = 0, scheduled = false }
local mail -- vooruit (post-status)
local sell -- vooruit (auto sell)

local function RestackStep()
	if not DB.enabled or InCombatLockdown() or CursorHasItem() then return false end
	if mail and mail.busy then return false end
	if sell and sell.busy then return false end
	if stack.burst >= 40 then return false end -- veiligheidsrem
	local items = Scan()
	local by = {}
	for _, e in ipairs(items) do
		if e.stackKnown and not e.key and e.maxStack > 1 and e.count < e.maxStack and not e.info.isLocked then
			by[e.itemID] = by[e.itemID] or {}
			table.insert(by[e.itemID], e)
		end
	end
	for _, list in pairs(by) do
		if #list >= 2 then
			table.sort(list, function(a, b) return a.count < b.count end)
			local src, dst = list[1], list[#list]
			C_Container.PickupContainerItem(src.bag, src.slot)
			C_Container.PickupContainerItem(dst.bag, dst.slot)
			if CursorHasItem() then C_Container.PickupContainerItem(src.bag, src.slot) end -- rest terug
			stack.moves = stack.moves + 1
			stack.burst = stack.burst + 1
			return true
		end
	end
	if stack.burst > 0 then
		Log("restacked: " .. stack.burst .. " move(s)")
		stack.burst = 0
	end
	return false
end

local function ScheduleRestack()
	if stack.scheduled or not DB.enabled then return end
	stack.scheduled = true
	C_Timer.After(0.3, function()
		stack.scheduled = false
		local ok, err = pcall(RestackStep)
		if not ok then DB.lastError = "restack: " .. tostring(err); Log("restack error: " .. tostring(err)) end
	end)
end

---------------------------------------------------------------------------
-- Auto Sell bij de vendor
---------------------------------------------------------------------------

sell = { busy = false, queue = nil, n = 0, value = 0 }

local function SellStop(reason)
	if not sell.busy then return end
	sell.busy = false
	sell.queue = nil
	if sell.n > 0 then
		local money = GetMoneyString and GetMoneyString(sell.value, true) or tostring(sell.value)
		Print(T("Auto Sell: sold %d item(s) for %s."):format(sell.n, money) .. (sell.n > 12 and T(" Note: Buyback only keeps the last 12.") or ""))
		Log("auto sell: " .. sell.n .. " item(s), " .. sell.value .. " copper" .. (reason and (" (" .. reason .. ")") or ""))
	end
	Refresh()
end

local function SellNext()
	if not sell.busy then return end
	if not (MerchantFrame and MerchantFrame:IsShown()) then SellStop("vendor closed"); return end
	local it = table.remove(sell.queue, 1)
	if not it then SellStop(); return end
	local info = C_Container.GetContainerItemInfo(it.bag, it.slot)
	if info and info.itemID == it.itemID and not info.isLocked then
		C_Container.UseContainerItem(it.bag, it.slot)
		sell.n = sell.n + 1
		sell.value = sell.value + it.value
	end
	C_Timer.After(0.15, SellNext)
end

local SellStart

-- Eerste keer bij een vendor (nieuwe gebruikers): vragen of Auto Sell aan moet.
local function AskAutoSell()
	if not StaticPopupDialogs or not StaticPopup_Show then return end
	StaticPopupDialogs["CAREFREEBAG_AUTOSELL"] = {
		text = T("CarefreeBag: automatically sell everything in the Auto Sell group whenever you open a vendor?\n\nYou can change this later in the options."),
		button1 = T("Yes, sell"),
		button2 = T("No"),
		OnAccept = function()
			DB.autoSell, DB.autoSellAsked = true, true
			Log("auto sell turned on (first vendor)")
			SellStart(true)
			Refresh()
		end,
		OnCancel = function(_, _, reason)
			if reason == "clicked" then
				DB.autoSell, DB.autoSellAsked = false, true
				Log("auto sell turned off (first vendor)")
				Refresh()
			end
		end,
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
	StaticPopup_Show("CAREFREEBAG_AUTOSELL")
end

SellStart = function(confirmed)
	if sell.busy or not DB.enabled then return end
	if not confirmed and DB.autoSellAsked and not DB.autoSell then return end
	if not On("grey") then return end
	if IsShiftKeyDown and IsShiftKeyDown() then Print(T("Auto Sell skipped (Shift).")); return end
	local items = Scan()
	local q = {}
	for _, e in ipairs(items) do
		if SectionOf(e) == "grey" and not e.info.hasNoValue and (e.price or 0) > 0 then
			q[#q + 1] = { bag = e.bag, slot = e.slot, itemID = e.itemID, value = e.price * e.count }
		end
	end
	if #q == 0 then return end
	if not confirmed and not DB.autoSellAsked then AskAutoSell(); return end
	sell.busy, sell.queue, sell.n, sell.value = true, q, 0, 0
	C_Timer.After(0.2, SellNext)
end

---------------------------------------------------------------------------
-- Post naar je alts
---------------------------------------------------------------------------

mail = { busy = false, plan = nil, step = false, skipped = {} }

-- Per categorie: wat gaat waarheen. De volgorde is die van je groepen.
-- Je krijgt per categorie de vraag of hij verstuurd moet worden.
local function BuildMailPlan()
	local items = Scan()
	local plan = {}
	for _, e in ipairs(items) do
		local to, sec = MailTarget(e)
		if to and not mail.skipped[sec] then
			if not plan[sec] then
				local c = CatByKey(sec)
				plan[sec] = { key = sec, cat = c and c.name or "BoE", to = to, items = {} }
			end
			local p = plan[sec]
			p.items[#p.items + 1] = { bag = e.bag, slot = e.slot, itemID = e.itemID, name = e.name, count = e.count }
		end
	end
	local list = {}
	for _, sec in ipairs(SectionList()) do
		if plan[sec.key] then list[#list + 1] = plan[sec.key] end
	end
	return list
end

local UpdateMailPanel -- vooruit

local function MailStop(msg)
	mail.busy = false
	mail.current = nil
	if msg then Print(msg); Log("mail: " .. msg) end
	UpdateMailPanel()
end

-- Volgende mail inpakken (max 12 items).
local function MailPack()
	local p = mail.queue and mail.queue[1]
	while p and #p.items == 0 do
		table.remove(mail.queue, 1)
		p = mail.queue[1]
	end
	if not p then
		local done = mail.cat
		mail.cat = nil
		if #BuildMailPlan() == 0 then MailStop(T("all mail has been sent."))
		else MailStop(T("%s sent."):format(done or "")) end
		return false
	end
	if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, 2) end
	ClearCursor()
	local n = 0
	local max = ATTACHMENTS_MAX_SEND or 12
	while #p.items > 0 and n < max do
		local it = table.remove(p.items, 1)
		local info = C_Container.GetContainerItemInfo(it.bag, it.slot)
		if info and info.itemID == it.itemID and not info.isLocked then
			C_Container.PickupContainerItem(it.bag, it.slot)
			ClickSendMailItemButton()
			ClearCursor()
			n = n + 1
		end
	end
	if n == 0 then return MailPack() end
	mail.current = { to = p.to, n = n }
	if SendMailNameEditBox then SendMailNameEditBox:SetText(p.to) end
	return true
end

local function MailSend()
	local c = mail.current
	if not c then return end
	mail.waiting = true
	Log("mail to '" .. c.to .. "': " .. c.n .. " item(s)")
	-- Geen tekst in de mail: dan verdwijnt hij vanzelf zodra je de bijlagen eruit haalt
	-- (een mail met tekst blijft staan als "brief").
	SendMail(c.to, "CarefreeBag: " .. c.n .. " item(s)", "")
end

-- Verstuurt alleen de categorie waar nu de vraag over staat.
local function MailStart()
	if mail.busy then return end
	local plan = BuildMailPlan()
	if #plan == 0 then Print(T("nothing to send.")); return end
	mail.queue = { plan[1] }
	mail.cat = plan[1].cat
	mail.busy = true
	if MailPack() then
		if mail.step then
			UpdateMailPanel()
		else
			C_Timer.After(0.4, function() if mail.busy then MailSend() end end)
		end
	end
	UpdateMailPanel()
end

local function MailButtonClick()
	if mail.busy and mail.step then
		-- Stapmodus: elke klik doet één stap (inpakken of versturen).
		if mail.current and not mail.waiting then MailSend()
		elseif not mail.current then MailPack() end
		UpdateMailPanel()
		return
	end
	if mail.busy then MailStop(T("stopped.")) return end
	MailStart()
end

local function MailSkip()
	if mail.busy then return end
	local plan = BuildMailPlan()
	if plan[1] then mail.skipped[plan[1].key] = true end
	UpdateMailPanel()
end

UpdateMailPanel = function()
	if not mailPanel or not mailPanel:IsShown() then return end
	local plan = mail.busy and mail.queue or BuildMailPlan()
	local lines = {}
	local p = plan[1]
	local any = p ~= nil and #p.items > 0
	if any then
		lines[#lines + 1] = "|cffffd100" .. T("Send %s to %s?"):format(p.cat, p.to) .. "|r"
		for i = 1, math.min(8, #p.items) do
			local it = p.items[i]
			lines[#lines + 1] = "  " .. it.name .. (it.count > 1 and (" x" .. it.count) or "")
		end
		if #p.items > 8 then lines[#lines + 1] = "  |cff888888+" .. (#p.items - 8) .. " " .. T("more") .. "|r" end
		if not mail.busy and #plan > 1 then
			local nxt = {}
			for i = 2, #plan do nxt[#nxt + 1] = plan[i].cat end
			lines[#lines + 1] = " "
			lines[#lines + 1] = "|cff888888" .. T("After that: %s"):format(table.concat(nxt, ", ")) .. "|r"
		end
	end
	if not any and not mail.busy then lines[1] = "|cff888888" .. T("Nothing to send.") .. "|r" end
	if mail.busy then
		lines[#lines + 1] = " "
		lines[#lines + 1] = "|cff33ff99" .. (mail.current and T("Busy: mail to %s..."):format(mail.current.to) or T("Busy...")) .. "|r"
	end
	mailPanel.text:SetText(table.concat(lines, "\n"))
	if mail.busy and mail.step then
		mailPanel.send:SetText(mail.current and T("Send this mail") or T("Pack next mail"))
	elseif mail.busy then
		mailPanel.send:SetText("Stop")
	else
		mailPanel.send:SetText(T("Yes, send"))
	end
	mailPanel.send:SetEnabled(any or mail.busy)
	mailPanel.skip:SetShown(any and not mail.busy)
	mailPanel:SetHeight(math.max(120, mailPanel.text:GetStringHeight() + 80))
end

local function BuildMailPanel()
	if not MailFrame then return end
	mailPanel = NewWindow("CarefreeBagMailPanel", T("CarefreeBag mail"), 260, 160)
	mailPanel:SetParent(MailFrame)
	mailPanel:ClearAllPoints()
	mailPanel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, 0)
	mailPanel:SetMovable(false)
	mailPanel.text = mailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	mailPanel.text:SetPoint("TOPLEFT", mailPanel, "TOPLEFT", PAD, -30)
	mailPanel.text:SetWidth(260 - 2 * PAD)
	mailPanel.text:SetJustifyH("LEFT")
	mailPanel.send = MakeButton(mailPanel, T("Yes, send"), 110)
	mailPanel.send:SetPoint("BOTTOMLEFT", mailPanel, "BOTTOMLEFT", PAD, 16)
	mailPanel.send:SetScript("OnClick", MailButtonClick)
	mailPanel.skip = MakeButton(mailPanel, T("Skip"), 110)
	mailPanel.skip:SetPoint("BOTTOMRIGHT", mailPanel, "BOTTOMRIGHT", -PAD, 16)
	mailPanel.skip:SetScript("OnClick", MailSkip)

	mailPanel:SetScript("OnShow", function() UpdateMailPanel() end)
end

---------------------------------------------------------------------------
-- Opties-venster
---------------------------------------------------------------------------

local config
local catRows = {}

local function NewCheck(parent, label, tip, get, set)
	local ok, cb = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
	if not ok then cb = CreateFrame("CheckButton", nil, parent) end
	cb:SetSize(24, 24)
	cb.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
	cb.label:SetText(label)
	cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); Refresh(); RefreshConfig() end)
	cb.get = get
	if tip then Tooltip(cb, label, tip) end
	return cb
end

local function NewEdit(parent, w)
	local ok, eb = pcall(CreateFrame, "EditBox", nil, parent, "InputBoxTemplate")
	if not ok then eb = CreateFrame("EditBox", nil, parent) end
	eb:SetSize(w, 20)
	eb:SetAutoFocus(false)
	eb:SetFontObject("ChatFontNormal")
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return eb
end

local function Trim(t) return ((t or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local CW = 440 -- breedte optievenster

local function BuildConfig()
	config = NewWindow("CarefreeBagConfig", T("CarefreeBag options"), CW, 600)
	config:SetPoint("CENTER", UIParent, "CENTER", -200, 40)
	config:SetScript("OnDragStop", config.StopMovingOrSizing)
	config:SetScript("OnShow", function() RefreshConfig() end)
	config.checks, config.edits = {}, {}

	local y = -32
	local function Heading(parent, text, yy)
		local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		h:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 4, yy)
		h:SetText(text)
		return h
	end

	-- 0. Aan/uit -------------------------------------------------------------
	local onCb = NewCheck(config, T("CarefreeBag on"), T("Off = your normal bags."),
		function() return DB.enabled end, function(v) SetEnabled(v) end)
	onCb:SetPoint("TOPLEFT", config, "TOPLEFT", PAD + 4, y)
	config.checks[#config.checks + 1] = onCb
	-- Taalknop: alleen een icoontje; de taal staat in de tooltip.
	local langBtn = CreateFrame("Button", "CarefreeBagLangButton", config)
	langBtn:SetSize(24, 24)
	langBtn:SetPoint("TOPRIGHT", config, "TOPRIGHT", -PAD - 4, y)
	langBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
	langBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Down")
	langBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	-- keuzelijstje met alle talen; kiezen = opslaan + interface herladen
	local langMenu = CreateFrame("Frame", "CarefreeBagLangMenu", config, "BackdropTemplate")
	langMenu:SetSize(150, #LANGS * 22 + 8)
	langMenu:SetPoint("TOPRIGHT", langBtn, "BOTTOMRIGHT", 0, -2)
	langMenu:SetFrameStrata("DIALOG")
	if langMenu.SetBackdrop then
		langMenu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		langMenu:SetBackdropColor(0, 0, 0, 0.95)
	end
	langMenu:Hide()
	for i, l in ipairs(LANGS) do
		local b = MakeButton(langMenu, l[2], 140)
		b:SetPoint("TOP", langMenu, "TOP", 0, -4 - (i - 1) * 22)
		b.langCode = l[1]
		b:SetScript("OnClick", function()
			langMenu:Hide()
			if DB.lang == l[1] then return end
			DB.lang = l[1]
			Log("language: " .. DB.lang)
			ReloadUI()
		end)
	end
	langBtn:SetScript("OnClick", function()
		if langMenu:IsShown() then langMenu:Hide() else langMenu:Show() end
	end)
	Tooltip(langBtn, "Language: " .. LangName(DB.lang))
	y = y - 34

	-- 1. Groepen: eigen categorieën en vaste groepen in één lijst ---------------
	Heading(config, T("Groups"), y)
	y = y - 20
	local colA = config:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	colA:SetPoint("TOPLEFT", config, "TOPLEFT", PAD + 12, y)
	colA:SetText(T("Name"))
	local colB = config:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	colB:SetPoint("TOPLEFT", config, "TOPLEFT", PAD + 148, y)
	colB:SetText(T("Mail to / settings"))
	y = y - 14
	config.catTop = y

	local function MoveKey(idx, dir)
		local o = DB.order
		local j2 = idx + dir
		if j2 < 1 or j2 > #o then return end
		o[idx], o[j2] = o[j2], o[idx]
		ResetOrder(); Refresh(); RefreshConfig()
	end

	local FIXED_TIPS = {
		quest = T("Quest items. Never sold or mailed."),
		keys = T("Your keyring."),
		boe = T("Unbound BoE items, green and better."),
		grey = T("Grey items. Sold at a vendor (Shift = skip)."),
		other = T("Everything without a group."),
	}

	for i = 1, 20 do
		local r = CreateFrame("Frame", nil, config)
		r:SetSize(CW - 2 * PAD, 24)
		-- Eigen categorie: naam en postadres zijn invulvelden.
		r.name = NewEdit(r, 120)
		r.name:SetPoint("LEFT", r, "LEFT", 10, 0)
		local function rename(self)
			local c = r.key and CatByKey(r.key)
			local new = Trim(self:GetText())
			if c and new ~= "" and new ~= c.name then
				Log("renamed: " .. c.name .. " -> " .. new)
				c.name = new
				Refresh()
			end
			self:ClearFocus()
			if c then self:SetText(c.name) end
		end
		r.name:SetScript("OnEnterPressed", rename)
		r.name:SetScript("OnEditFocusLost", rename)

		-- Vaste groep: blauwe naam, niet aan te passen, uitleg in de tooltip.
		r.fixedName = CreateFrame("Frame", nil, r)
		r.fixedName:SetSize(120, 20)
		r.fixedName:SetPoint("LEFT", r, "LEFT", 34, 0)
		r.fixedName:EnableMouse(true)
		r.fixedName.fs = r.fixedName:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		r.fixedName.fs:SetPoint("LEFT")
		r.fixedName:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local c = CatByKey(r.key)
			if c and c.preset then
				GameTooltip:AddLine(T("Ready-made category"))
				GameTooltip:AddLine(T(PRESET[c.preset].tip), 1, 1, 1, true)
			else
				GameTooltip:AddLine(T("Fixed group"))
				GameTooltip:AddLine(FIXED_TIPS[r.key] or "", 1, 1, 1, true)
			end
			GameTooltip:Show()
		end)
		r.fixedName:SetScript("OnLeave", function() GameTooltip:Hide() end)
		-- Aan/uit voor een vaste groep.
		r.onCb = NewCheck(r, "", nil, function() return r.key and On(r.key) end,
			function(v) if r.key then DB.fixedOn[r.key] = v and true or false; Log("fixed group " .. r.key .. " " .. (v and "on" or "off")); ResetOrder() end end)
		r.onCb:SetPoint("LEFT", r, "LEFT", 8, 0) -- vinkje vóór de naam
		Tooltip(r.onCb, T("Off: items go to Other."))

		r.mail = NewEdit(r, 140)
		r.mail:SetPoint("LEFT", r, "LEFT", 146, 0)
		local function setMail(self)
			if r.key == "boe" then
				DB.boeMail = Trim(self:GetText())
			else
				local c = r.key and CatByKey(r.key)
				if c then
					local v = Trim(self:GetText())
					c.mailTo = (v ~= "") and v or nil
				end
			end
			Log("mail address for " .. tostring(r.key) .. " changed")
			self:ClearFocus()
			Refresh()
		end
		r.mail:SetScript("OnEnterPressed", setMail)
		r.mail:SetScript("OnEditFocusLost", setMail)
		Tooltip(r.mail, T("Mail to"), T("Full name of your alt, e.g. 'Thrall Stormrage'. Empty = no mail."))

		-- Vinkjes voor vaste groepen (in de kolom van het postadres).
		r.cb1 = NewCheck(r, "", nil, function() return r.cb1Field and DB[r.cb1Field] end, function(v) if r.cb1Field then DB[r.cb1Field] = v end end)
		r.cb1:SetPoint("LEFT", r, "LEFT", 146, 0)
		r.cb2 = NewCheck(r, "", nil, function() return r.cb2Field and DB[r.cb2Field] end, function(v) if r.cb2Field then DB[r.cb2Field] = v end end)
		r.cb2:SetPoint("LEFT", r, "LEFT", 226, 0)
		for _, cb in ipairs({ r.cb1, r.cb2 }) do
			cb:HookScript("OnEnter", function(self)
				if not self.tip then return end
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine(self.label:GetText() or "")
				GameTooltip:AddLine(self.tip, 1, 1, 1, true)
				GameTooltip:Show()
			end)
			cb:HookScript("OnLeave", function() GameTooltip:Hide() end)
		end

		r.up = MakeButton(r, "^", 24)
		r.up:SetPoint("LEFT", r, "LEFT", 294, 0)
		r.down = MakeButton(r, "v", 24)
		r.down:SetPoint("LEFT", r.up, "RIGHT", 2, 0)
		r.del = MakeButton(r, "X", 24)
		r.del:SetPoint("LEFT", r.down, "RIGHT", 6, 0)
		r.up:SetScript("OnClick", function() MoveKey(r.index, -1) end)
		r.down:SetScript("OnClick", function() MoveKey(r.index, 1) end)
		r.del:SetScript("OnClick", function()
			local c, idx = CatByKey(r.key)
			if c then
				table.remove(DB.cats, idx)
				for _, ch in pairs(DB.chars) do
					for id, k in pairs(ch.assign) do if k == c.key then ch.assign[id] = nil end end
				end
				if DB.assign then for id, k in pairs(DB.assign) do if k == c.key then DB.assign[id] = nil end end end
				Print(T("category '%s' removed. Its items are back in Other."):format(c.name))
			end
			ResetOrder(); Refresh(); RefreshConfig()
		end)
		Tooltip(r.del, T("Remove"), T("Items go back to Other."))
		catRows[i] = r
	end

	config.newEdit = NewEdit(config, 120)
	config.addBtn = MakeButton(config, T("Add"), 90)
	local function add()
		local name = Trim(config.newEdit:GetText())
		if name == "" then return end
		if #DB.cats >= 12 then Print(T("at most 12 categories.")); return end
		DB.cats[#DB.cats + 1] = { key = NewCatKey(name), name = name }
		config.newEdit:SetText("")
		config.newEdit:ClearFocus()
		ResetOrder(); Refresh(); RefreshConfig()
	end
	config.newEdit:SetScript("OnEnterPressed", add)
	config.addBtn:SetScript("OnClick", add)


	-- Kant-en-klare categorie kiezen uit een lijstje.
	config.presetBtn = MakeButton(config, T("Ready-made") .. " v", 110)
	local pm = CreateFrame("Frame", "CarefreeBagPresetMenu", config, "BackdropTemplate")
	pm:SetFrameStrata("DIALOG")
	if pm.SetBackdrop then
		pm:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		pm:SetBackdropColor(0, 0, 0, 0.95)
	end
	pm:Hide()
	pm.buttons = {}
	for i, p in ipairs(PRESETS) do
		local b = MakeButton(pm, T(p.name), 150)
		b.presetID = p.id
		b:SetScript("OnClick", function()
			pm:Hide()
			for _, c in ipairs(DB.cats) do if c.preset == p.id then return end end
			if #DB.cats >= 12 then Print(T("at most 12 categories.")); return end
			local key = p.id
			if CatByKey(key) then key = NewCatKey("p" .. p.id) end
			DB.cats[#DB.cats + 1] = { key = key, preset = p.id, name = T(p.name) }
			Log("preset added: " .. p.id)
			ResetOrder(); Refresh(); RefreshConfig()
		end)
		Tooltip(b, T(p.name), T(p.tip))
		pm.buttons[i] = b
	end
	config.presetMenu = pm
	config.presetBtn:SetScript("OnClick", function()
		if pm:IsShown() then pm:Hide(); return end
		local n = 0
		for _, b in ipairs(pm.buttons) do
			local used = false
			for _, c in ipairs(DB.cats) do if c.preset == b.presetID then used = true end end
			b:ClearAllPoints()
			if used then b:Hide() else
				b:SetPoint("TOP", pm, "TOP", 0, -4 - n * 22); b:Show(); n = n + 1
			end
		end
		if n == 0 then return end
		pm:SetSize(160, n * 22 + 8)
		pm:ClearAllPoints()
		pm:SetPoint("TOPLEFT", config.presetBtn, "BOTTOMLEFT", 0, -2)
		pm:Show()
	end)
	Tooltip(config.presetBtn, T("Add a category that fills itself."))

	-- Alles hieronder schuift mee met het aantal groepen.
	local low = CreateFrame("Frame", nil, config)
	low:SetSize(CW, 100)
	config.low = low
	local ly = -6

	-- 2. Breedte ---------------------------------------------------------------
	config.colsLabel = low:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	config.colsLabel:SetPoint("TOPLEFT", low, "TOPLEFT", PAD + 8, ly - 3)
	local minus = MakeButton(low, "-", 24)
	minus:SetPoint("TOPLEFT", low, "TOPLEFT", 294, ly)
	minus:SetScript("OnClick", function() DB.maxCols = math.max(5, DB.maxCols - 1); ResetOrder(); Refresh(); RefreshConfig() end)
	local plus = MakeButton(low, "+", 24)
	plus:SetPoint("LEFT", minus, "RIGHT", 2, 0)
	plus:SetScript("OnClick", function() DB.maxCols = math.min(30, DB.maxCols + 1); ResetOrder(); Refresh(); RefreshConfig() end)
	Tooltip(minus, T("Window width before you scroll."))
	Tooltip(plus, T("Window width before you scroll."))
	ly = ly - 34
	low:SetHeight(-ly)

	config.version = config:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	config.version:SetPoint("BOTTOMRIGHT", config, "BOTTOMRIGHT", -PAD, 14)
	config.version:SetText("CarefreeBag " .. VERSION)
end

-- Per vaste groep: wat staat er in de middelste kolom.
local FIXED_ROW = {
	quest = {},
	keys = {},
	boe = { mail = true },
	grey = { cb1 = { "autoSell", "sell automatically", "Sell at a vendor. Shift = skip once." } },
	other = {},
}
local FIXED_NAME = { quest = "Quest", keys = "Keys", boe = "BoE", grey = "Auto Sell", other = "Other" }

local function SetupCheck(r, cb, field, spec)
	if spec then
		r[field] = spec[1]
		cb.label:SetText(spec[2] ~= "" and T(spec[2]) or "")
		cb.tip = T(spec[3])
		cb:SetChecked(DB[spec[1]] and true or false)
		cb:Show(); cb.label:Show()
	else
		r[field] = nil
		cb:Hide(); cb.label:Hide()
	end
end

RefreshConfig = function()
	if not config or not config:IsShown() then return end
	for _, cb in ipairs(config.checks) do cb:SetChecked(cb.get() and true or false) end
	config.colsLabel:SetText(T("Maximum width: %d columns"):format(DB.maxCols))

	local order = FixOrder()
	local y = config.catTop
	-- "Toevoegen" komt na de laatste eigen categorie (daar komt een nieuwe ook terecht).
	local addAfter = 0
	for i, k in ipairs(order) do if not FIXED[k] then addAfter = i end end
	local function PlaceAdd()
		config.newEdit:ClearAllPoints()
		config.newEdit:SetPoint("TOPLEFT", config, "TOPLEFT", PAD + 12, y - 2)
		config.addBtn:ClearAllPoints()
		config.addBtn:SetPoint("LEFT", config.newEdit, "RIGHT", 8, 0)
		config.presetBtn:ClearAllPoints()
		config.presetBtn:SetPoint("LEFT", config.addBtn, "RIGHT", 8, 0)
		local free = false
		for _, p in ipairs(PRESETS) do
			local used = false
			for _, c in ipairs(DB.cats) do if c.preset == p.id then used = true end end
			if not used then free = true end
		end
		config.presetBtn:SetEnabled(free)
		y = y - 30
	end
	if addAfter == 0 then PlaceAdd() end
	for i, r in ipairs(catRows) do
		local key = order[i]
		if key then
			r.index, r.key = i, key
			local fixed = FIXED[key]
			local cc = not fixed and CatByKey(key)
			local preset = cc and cc.preset
			r.name:SetShown(not fixed and not preset)
			r.fixedName:SetShown((fixed or preset) and true or false)
			r.fixedName:ClearAllPoints()
			r.fixedName:SetPoint("LEFT", r, "LEFT", preset and 14 or 34, 0)
			r.onCb:SetShown(fixed and key ~= "other" and true or false)
			if fixed then r.onCb:SetChecked(On(key)) end
			r.del:SetShown(not fixed)
			if fixed then
				local spec = FIXED_ROW[key]
				local nm = (key == "grey" and "Auto Sell" or (key == "boe" and "BoE" or T(FIXED_NAME[key])))
				r.fixedName.fs:SetText((On(key) and BLUE or "|cff777777") .. nm .. "|r")
				SetupCheck(r, r.cb1, "cb1Field", spec.cb1)
				SetupCheck(r, r.cb2, "cb2Field", spec.cb2)
				if spec.mail then
					r.mail:Show()
					if not r.mail:HasFocus() then r.mail:SetText(DB.boeMail or "") end
				else
					r.mail:Hide()
				end
			else
				local c = CatByKey(key)
				SetupCheck(r, r.cb1, "cb1Field", nil)
				SetupCheck(r, r.cb2, "cb2Field", nil)
				r.mail:Show()
				if preset then r.fixedName.fs:SetText("|cffffd100" .. c.name .. "|r")
				elseif not r.name:HasFocus() then r.name:SetText(c.name) end
				if not r.mail:HasFocus() then r.mail:SetText(c.mailTo or "") end
			end
			r.up:SetEnabled(i > 1)
			r.down:SetEnabled(i < #order)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", config, "TOPLEFT", PAD, y)
			r:Show()
			y = y - 26
			if i == addAfter then PlaceAdd() end
		else
			r:Hide()
		end
	end
	y = y - 8
	config.low:ClearAllPoints()
	config.low:SetPoint("TOPLEFT", config, "TOPLEFT", 0, y)
	config:SetHeight(-y + config.low:GetHeight() + 24)
end

ToggleConfig = function()
	if config:IsShown() then config:Hide() else config:Show() end
end

---------------------------------------------------------------------------
-- Minimapknop
---------------------------------------------------------------------------

local function PlaceMinimapButton(btn)
	local angle = math.rad(DB.minimapAngle or 230)
	local radius = (Minimap:GetWidth() / 2) + 6
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function BuildMinimapButton()
	if not Minimap then return end
	local btn = CreateFrame("Button", "CarefreeBagMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)
	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
	icon:SetSize(18, 18)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	btn:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function(s)
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			DB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
			PlaceMinimapButton(s)
		end)
	end)
	btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	btn:SetScript("OnClick", function(_, mouse)
		if IsShiftKeyDown and IsShiftKeyDown() then
			SetEnabled(not DB.enabled)
		elseif mouse == "RightButton" then
			ToggleConfig()
		elseif DB.enabled then
			if main:IsShown() then main:Hide() else ShowMain() end
		else
			Print(T("CarefreeBag is off. Shift-click the minimap button to turn it on."))
		end
	end)
	btn.icon = icon
	UpdateMinimapIcon = function()
		if btn.icon.SetDesaturated then btn.icon:SetDesaturated(not DB.enabled) end
		btn.icon:SetAlpha(DB.enabled and 1 or 0.5)
	end
	UpdateMinimapIcon()
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("CarefreeBag  " .. (DB.enabled and ("|cff33ff99" .. T("on") .. "|r") or ("|cffff5555" .. T("off") .. "|r")))
		GameTooltip:AddLine(T("Left-click: open/close bags"), 1, 1, 1)
		GameTooltip:AddLine(T("Right-click: options"), 1, 1, 1)
		GameTooltip:AddLine(T("Shift-click: turn CarefreeBag on/off"), 1, 1, 1)
		GameTooltip:AddLine(T("Drag: move along the minimap"), 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	btn:SetShown(not DB.hideMinimap)
	PlaceMinimapButton(btn)
end

---------------------------------------------------------------------------
-- Opstarten en events
---------------------------------------------------------------------------

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")

local function Try(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		DB.lastError = label .. ": " .. tostring(err)
		Log("error in " .. label .. ": " .. tostring(err))
		Print(T("error in %s: %s"):format(label, tostring(err)))
	end
end

driver:SetScript("OnEvent", function(_, event, a1, a2)
	if event == "ADDON_LOADED" and a1 == ADDON then
		Defaults()
	elseif event == "PLAYER_LOGIN" then
		Try("order", FixOrder)
		Try("window", BuildMain)
		Try("options", BuildConfig)
		Try("minimap", BuildMinimapButton)
		Try("bags", HookBags)
		C_Timer.After(2, function() Try("other bags", CheckOtherBags) end)
		mail.step = false
		DB.mailStep = nil -- niet meer onthouden: elk mailboxbezoek eerst automatisch proberen
		for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY",
			"GET_ITEM_INFO_RECEIVED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED",
			"MAIL_SEND_SUCCESS", "MAIL_FAILED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED",
			"ADDON_ACTION_FORBIDDEN" }) do
			pcall(driver.RegisterEvent, driver, ev)
		end
		Print(T("v%s loaded. Press B, or type /cfb for options."):format(VERSION))
		local sep = SurnameSep()
		Log("v" .. VERSION .. " loaded as '" .. tostring(MyFullName()) .. "', name separator: '" .. tostring(sep) .. "'")
		pcall(driver.RegisterEvent, driver, "UI_ERROR_MESSAGE")
		pcall(driver.RegisterEvent, driver, "UPDATE_BINDINGS")
		ScheduleRestack()
	elseif event == "MERCHANT_SHOW" then
		Refresh()
		local ok, err = pcall(SellStart)
		if not ok then Log("auto sell error: " .. tostring(err)) end
	elseif event == "MERCHANT_CLOSED" then
		SellStop("vendor closed")
		Refresh()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if layoutPending then layoutPending = false; Refresh() end
		ScheduleRestack()
		if bindPending then bindPending = false; BindKeys() end
	elseif event == "UPDATE_BINDINGS" then
		if not binding then C_Timer.After(0.1, BindKeys) end
	elseif event == "UI_ERROR_MESSAGE" then
		if mail.busy then Log("game message during mail: " .. tostring(a2)) end
	elseif event == "MAIL_SHOW" then
		mail.step = false -- nieuw bezoek: eerst weer automatisch proberen
		mail.skipped = {}  -- en alle categorieën worden weer gevraagd
		if not DB.enabled then return end
		if not mailPanel then Try("mail", BuildMailPanel) end
		if mailPanel then mailPanel:Show(); UpdateMailPanel() end
		Refresh()
	elseif event == "MAIL_CLOSED" then
		if mail.busy then MailStop(T("mailbox closed, stopped.")) end
		if mailPanel then mailPanel:Hide() end
		Refresh()
	elseif event == "MAIL_SEND_SUCCESS" then
		if mail.busy and mail.waiting then
			mail.waiting = false
			mail.current = nil
			if mail.step then
				UpdateMailPanel()
			else
				C_Timer.After(0.6, function()
					if mail.busy and MailPack() then
						C_Timer.After(0.4, function() if mail.busy then MailSend() end end)
					end
					UpdateMailPanel()
				end)
			end
		end
		Refresh()
	elseif event == "MAIL_FAILED" then
		Log("MAIL_FAILED" .. (mail.current and (" (to '" .. mail.current.to .. "')") or ""))
		if mail.busy then
			mail.waiting = false
			MailStop(T("sending failed (not enough gold or wrong name?). The items are still in the mail window."))
		end
	elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		if a1 == ADDON then
			DB.lastError = event .. ": " .. tostring(a2)
			Log("blocked by WoW: " .. tostring(a2))
			if mail.busy and not mail.step then
				-- WoW staat automatisch versturen niet toe: vanaf nu één klik per stap.
				mail.step = true
				mail.waiting = false
				Print(T("WoW blocks automatic sending. Click the button for each mail this time."))
				UpdateMailPanel()
			end
		end
	else
		-- Tassen veranderd, vendor open/dicht, geld, iteminfo binnen.
		Refresh()
		if event == "BAG_UPDATE_DELAYED" then
			ScheduleRestack()
			if mailPanel and mailPanel:IsShown() and not mail.busy then UpdateMailPanel() end
		end
	end
end)

SLASH_CAREFREEBAG1 = "/carefree"
SLASH_CAREFREEBAG2 = "/cfb"
SlashCmdList["CAREFREEBAG"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "show" or msg == "tassen" then
		ShowMain()
	elseif msg == "minimap" then
		DB.hideMinimap = not DB.hideMinimap
		if CarefreeBagMinimapButton then CarefreeBagMinimapButton:SetShown(not DB.hideMinimap) end
	elseif msg == "log" then
		local l = DB.log or {}
		Print(T("last %d lines of the log:"):format(math.min(15, #l)))
		for i = math.max(1, #l - 14), #l do print("  " .. l[i]) end
	elseif msg == "fout" or msg == "error" then
		Print(T("last error: %s"):format(tostring(DB.lastError or T("none"))))
	else
		ToggleConfig()
	end
end
