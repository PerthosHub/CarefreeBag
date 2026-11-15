# Changelog

## 1.6.0 (not released yet)
- Bags full and the loot does not fit? A small window next to the loot shows the loot and the cheapest item or stack in your bags, with their prices side by side (vendor price, or the AH price after the cut if Auctionator has a better one). Green: the loot is worth more. Red: it is worth less.
- One click on "Destroy & loot" destroys that cheapest item and picks up the loot. WoW only allows destroying items after a click, so this never happens by itself. "Skip" leaves it alone until you close the loot.
- Items without a price (like your Hearthstone), quest items, keys and hidden items are never offered. Quest loot is always worth it.
- Want to keep the offered item? "Keep this item" or "Keep this group" in the same window, and the next cheapest item is shown right away. Each character remembers its own.
- Options: a "Keep" tick per group (not for Auto Sell: that group is there to get rid of things), and "Clear" for the items you chose to keep. Kept items say so in their tooltip.

## 1.5.1
- Items you loot while your bags are open keep blinking, also when you already had that item (for example one more potion). Move the mouse over it to stop the blinking; loot more of it and it blinks again. Closing the bags stops all blinking.
- Search starts at 2 letters and stops the blinking of new items. Closing the bags clears the search. Escape in an empty search box closes the bags.
- Search also finds items in your bank and on your other characters: the Bank & alts button shows how many, and the panel opens by itself where they are (your bank first, then your alts). It closes again when you clear the search.
- Bank & alts panel: pick a character by its round class icon on the left (the chosen one is in color with a golden glow). Bags and Bank have icons and show the number of search hits.
- Bank & alts panel shows the free slots of the bank or bags you are looking at.

## 1.5.0
- Under the hood: the code is split into smaller files, with automatic tests on GitHub before every release. Nothing changes in the game.
- Fix: two characters with the same first name (Forever: "Thrall Frostwolf" and "Thrall Stormrage") shared their groups and learned items. Each character now really has its own. The character that logged in last keeps the changed groups; the other gets its groups from before 1.3.0 back. `/cfb resetgroups` resets the groups of the current character.
- Fix: the bags and bank of other characters were sometimes saved empty (when closing the bank or logging out).
- Bank & alts panel: pick a character, then Bags or Bank. Opens on your own bank (your own bags are already open next to it).
- Fix: removing a group made every character forget the items learned for it. Now only the current character does.
- New "Bank & alts" button: a panel next to your bags shows your bank, and the bags and bank of your other characters, sorted into that character's groups. View only; at the banker you move items as usual.
- Your bank is remembered each time you visit a banker. Your bags are remembered as you play.
- Item tooltips show where else you have the item, per character (bags and bank).
- The search box also dims items in the panel.
- Mail: per group you can tick "Send without asking" (shows up once the group has a recipient). At the mailbox those groups are sent right away, before the groups that still ask.
- Mail: the first time something is about to be mailed, you are asked once whether mail may always be sent without asking. Change it any time with "Always mail without asking" in the options.
- The options window now opens attached to the left of your bags, in the same spot as the Bank & alts panel (one of the two at a time).
- Bank & alts panel: the title says whose bank or bags you see ("Your bank", "Bank of ..."), and your own character is marked "(you)" in the list.

## 1.4.0
- Now also loads in retail (Midnight), MoP Classic, TBC Classic Anniversary and Classic Era. These versions are new and less tested: please report problems on GitHub.
- Retail: normal items are never dropped into the reagent bag.
- Classic: the keyring works in the Keys group.
- The mail address tip shows the right name format for your game version.

## 1.3.0
- Groups are now per character: each character has its own groups, order, sorting and mail settings. Existing characters start with the groups you had.

## 1.2.3
- With Auctionator, the item tooltip keeps showing what the stack earns on the AH after the 5% cut, and whether the AH or the vendor pays more.
- The version number in game is correct again (no more "vv1.2.2").
- "+ Add group" sits at the top of the groups panel.
- Clearer mail question: "Send everything in [group] to [alt]?" with the group and alt in their own colour.
- The bag width setting now really sets the number of columns (it only grew when the screen was full before).
- Cleaner options window: a General section on top (on/off, language, bag width, sort options) and the groups in their own panel.
- "+ Add group" offers "Custom group" and "Predefined groups", which opens a second list. Dropdowns close when you click next to them.
- The alt's name stands out in the Auto mail tooltip.
- Group tooltips show how many items the group learned. Renaming a group warns that its learned items stay.

## 1.2.2
- Changing the language now asks to reload the interface (WoW Forever blocks addons from reloading by themselves).
- One "+ Add group" button: pick a ready-made group or a custom group (green) that learns from what you drag onto it.

## 1.2.1
- CarefreeBag opens with every bag key you use (open all bags, backpack, single bags) and when you click a bag button.
- New items get a clear pulsing gold border until you hover them.

## 1.2.0 – works out of the box
- **Ready-made categories** that fill themselves: Consumables, Professions and Gear for new installs; add Food & Drink, Potions & Elixirs, Scrolls or your own category from the options.
- **Mail asks per category** at the mailbox: Yes, send or Skip. Mailed groups show "Auto" with an envelope.
- **Per group in the bag:** collapse it. Turn on sort buttons in the options to choose Stack price, Newest last or Manual. Drag items onto each other to reorder.
- **Remembered per character:** what you drag where, hidden items and your own order.
- AH value of a stack after the 5% AH cut in the item tooltip (needs Auctionator).
- Bag fill bar, Blizzard-style buttons, shorter tooltips, no copper shown once you have gold. Keys group is off by default.

## 1.1.0 – more languages
- New languages: Deutsch, Français, Español, Italiano, Português and Русский, next to English and Nederlands.
- New installs pick the language of your WoW client automatically. Change it at the top of the options (/cfb).
- The translations are machine-assisted. Native speakers: corrections are very welcome on GitHub.

## 1.0.0 – first release
Tired of playing the inventory-management minigame? CarefreeBag plays it for you.
- One window for all your bags, split into groups you make yourself. Drag an item onto a group's empty slot and it stays there.
- Fixed groups: Quest, Keys, BoE, Auto Sell and Other. Turn each on or off and change the order.
- Auto Sell: grey items (and anything you drop in) are sold at the vendor. Hold Shift to skip.
- Half stacks are combined automatically (never in combat).
- Mail to alts: give a group a character name and send it with one click at the mailbox. Mails have no text, so they disappear once emptied.
- Groups you mail away are sorted by stack value, using Auctionator prices if installed.
- Hide items, search box, keyring, new items flash once, tiles stay in place while the window is open.
- English and Dutch.

## 0.9.6
- Mails sent by CarefreeBag have no body text anymore, so they disappear by themselves once you take the attachments (also with Open All).

## 0.9.5
- Fixed: on the character that a group is mailed to, CarefreeBag no longer tries to mail items to itself (full name with surname is now used).

## 0.9.4 – first public release
- One window for all your bags, grouped into your own categories.
- Drag an item onto a group's empty slot and it stays in that group.
- Fixed groups: Quest, Keys, BoE, Auto Sell and Other (each can be turned off).
- Auto Sell: grey items (and anything you drop in) are sold at a vendor. Hold Shift to skip.
- Stacks are merged in the window and tidied up in your bags automatically (never in combat).
- Mail: give a group an address and its items are sent there at a mailbox with one click.
- To-AH groups are sorted by stack value, using Auctionator prices when available.
- Search box, keyring support, new items flash once, hide items you never need.
- English and Dutch.
