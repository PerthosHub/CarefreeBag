# Changelog

## 1.10.0
### ✨ New
- 🎒 **See how full your bags are on the backpack.** A bar in the backpack button at the bottom of your screen fills up from green to red as your bags get full, with used/total slots above it (like 40/44), just like in the CarefreeBag window. It replaces WoW's own free-space number. Reagent and profession bags do not count. You can turn it off in **Advanced settings**.
- 🙈 **Only one bag icon.** Hide the other bag slots and the key ring while your bags are closed. Open your bags and the whole bag bar is back. If you have moved your interface around, CarefreeBag asks once per character. Change it any time in **Advanced settings**.

## 1.9.3
### ✨ New
- 🎛️ **Simpler options.** General now only has the basics: on/off, language and sort options. Bags full, clams, mailing without asking and better bags moved to **Advanced settings**.

### 🔧 Fixes
- 🧱 **Sturdier under the hood.** If one part of CarefreeBag runs into a problem, the rest keeps working.
- 🔤 **"Sell automatically"** now starts with a capital letter.

## 1.9.2
### ✨ New
- ⏰ **Remind me next level.** Not sure if a leftover quest item can go? Click **Next level** in the quest list. No orange border and no reminder until you are a level higher. **All next level** does this for the whole list at once.
- 🟧 **Leftovers at a glance.** The Quest group shows **Leftovers: 3** in orange. Click it for the list with all choices, also to undo **Always keep** or **Next level** later.
- 🎛️ **Options in the WoW menu.** Esc → Options → AddOns → CarefreeBag opens the CarefreeBag options.
- 🔕 **Bags full panel can be turned off.** New option "Bags full: offer to make room".

### 🔧 Simpler
- 🧹 **Nothing to remember.** No more key tricks: Alt-click on quest items, Shift at the vendor and Shift-click on the minimap button are gone. Everything is a button you can see. CarefreeBag off? Click the minimap button and switch it on at the top of the options.
- ↔️ **Moving items in a group is one simple move.** Drag an item onto another: it takes that spot and the rest shifts along.
- 🤫 **Quieter chat.** The "loaded" line only shows the first time and after an update.

## 1.9.1
### ✨ New
- 🎒 **Take off a bag that is not empty.** Drag a bag from your bag bar into CarefreeBag. If it still has items in it, CarefreeBag first moves them to your other bags, then puts the empty bag in your bags. WoW alone says "Can't put non-empty bags in other bags". Not enough room? You get a message and nothing moves.

## 1.9.0
### ✨ New
- 📜 **See which quest an item is for.** Hover a quest item: the tooltip shows the quest, its level (in the difficulty color) and your progress, like 3/8. No database needed, CarefreeBag reads your quest log.
- 🟧 **Leftover quest items stand out.** Is a quest item not in your quest log any more? It gets a bright orange border and a grey icon. The tooltip says it can probably go, and why you may still need it (next step of a chain, reputation, a quest you have not picked up yet). You decide.
- 🔔 **Reminder when you log in.** A short list of quest items you may not need. Per item: **Always keep** (no more reminders), or **Remind me later** for the whole list. In your bags, **Alt-click** a leftover to always keep it (Alt-click again to undo).
- ❗ **Loot that starts a quest.** A small window pops up with **Start quest**: one click opens the quest and you accept it yourself. Not now? Click **Later**: the item keeps a blue glow in your bags until the quest is in your log. During a fight the window waits until the fight is over.

## 1.8.1
### ✨ New
- 📬 **Mail a whole pile with one right-click.** CarefreeBag shows 3 stacks of 20 cloth as one slot of 60. Right-click it at the mailbox and **all 60 go into the mail** (3 × 20).
- 💰 **Icons in the price tip.** The word **vendor** gets a vendor icon, **AH** an auction icon, each in its own color. You see where it should go without reading.

### 🔧 Fixes
- ✂️ **Shift-click splits a stack again**, also on a slot that holds several stacks (it splits the biggest one). At the mailbox, bank, trade or auction house, CarefreeBag no longer merges the stack you just split. It tidies up after you close the window.
- 🔑 **Keys group off = keys out of sight.** Your keys stay in the keyring, they just don't show up in CarefreeBag (before, they ended up in Other).
- ⬛ **No more dark empty slot** when you use, destroy or mail an item. The other items move up right away.
- 🤫 **No "Nothing to send" window.** The mail window only shows up when there is something to send.
- 🧮 **Bank & alts counts are more up to date** after you send mail and switch characters right away.

## 1.8.0
### ✨ New
- 🎒 **Better bags go on by themselves.** Get a bag with more slots (loot, mail, vendor) and CarefreeBag **equips it right away**. Empty bag slot first, otherwise it replaces your **smallest bag**. What was in that bag stays in your bags. Not in combat.
- 🖱️ **Right-click a bag to swap it**, also when all bag slots are full. Fewer slots? You are **asked first** ("You lose 4 bag slots").
- ⚙️ New option **"Equip better bags automatically"** under Advanced settings (on by default).

### 📏 How CarefreeBag picks
- **More slots wins.** Same number of slots: **soulbound bags first**, **BoE bags last** (equipping binds them, so they stay tradeable).
- A **normal bag replaces a profession bag** (Herb Bag and the like). A profession bag only goes into an empty slot.
- **Left alone:** quivers, ammo pouches, soul bags, bags in a group you mail to an alt, bags in Auto Sell, and a bag slot you emptied yourself.

### 🔧 Fixes
- 🔁 Swapping also works when the new bag **sits inside the bag it replaces** (WoW refuses that on its own).

## 1.7.2
- Bags full window: the options under the item now look like a normal WoW menu, with the item name and its group as headings.
- Bags full window: never offers to destroy an item that is also in the loot (that loot would stack onto it). Example: a clam in the loot and clams in your bags.
- Bags full window: the "worth more/less" line no longer breaks over two lines.
- Bags full window: "Leave it" only leaves that one item; if more loot does not fit, the next one is shown right away. Closing the window (X or Escape) stops the questions until you close the loot window; before, it came back a few seconds later.
- Clams you loot are opened automatically (new option "Open clams automatically" under General, on by default). Never in combat, and never while a vendor, bank, mailbox, trade or auction house is open.
- Bags full window: solid background, and it picks a spot next to the loot window that does not cover your bags (right, left, below or above). Handy when you open a clam on top of your bags.

## 1.7.1
- Reagent bag: its own small fill bar next to the big one (green, orange, red, just like the big bar), sized in proportion. Hover it for the details.
- Bags full window is cleaner: one question ("To pick up X, destroy:") with the cheapest item from your bags. The advised button is green: "Destroy & pick up" when the loot is worth more, "Leave it" when it is worth less, with the difference right above it. Without Auctionator the vendor price is used.
- Hover the item in that window (arrow on the right) for the options: never destroy this item, skip it this time, never destroy anything from its group, or skip the group this time. "This time" lasts until you close the loot window.
- The window moves to the left of the loot window when there is no room on the right.
- Gold under your bags shows the silver again when it is 0 (1g 0s instead of 1g).
- Hover the item in the Bags full window to see where the prices come from: Auctionator not installed, no AH price yet (vendor price used), or the AH price and when Auctionator last saw it.
- Mail: when the mailbox stays open because there is mail to pick up, it switches to the inbox after sending, and the CarefreeBag window goes away after the countdown.

## 1.7.0
- Bank & alts panel: see the gold of the character you look at and of all your characters together (bottom of the panel). Hover a character's icon to see its gold. A character's gold shows up after you log in with it once.
- Mail: when everything is sent (by itself or after you said yes), the mailbox closes (not when there is mail in your inbox to pick up). The CarefreeBag window stays for 5 seconds and shows what was sent to whom. The button counts down ("Close (5)"); click it to close the window right away.
- Options and the Bank & alts panel can sit on the right of your bags too: click the arrow at the top, on the side of your bags. Each character remembers its own side.

## 1.6.1
- Drag something you are wearing (or an item from the bank) to your bags: drop it on a group's "+", on an item, on the window or on the fill bar, and it goes into a free slot. On a "+" it also joins that group. Before, it went back to your character. Bags full: you get the usual "Inventory is full" message.

## 1.6.0
- Bags full and the loot does not fit? A small window next to the loot shows the loot and the cheapest item or stack in your bags, with their prices side by side (vendor price, or the AH price after the cut if Auctionator has a better one). Green: the loot is worth more. Red: it is worth less.
- One click on "Destroy & loot" destroys that cheapest item and picks up the loot. WoW only allows destroying items after a click, so this never happens by itself. "Skip" leaves it alone until you close the loot.
- Items without a price (like your Hearthstone), quest items, keys and hidden items are never offered. Quest loot is always worth it.
- Want to keep the offered item? "Always keep item" or "Always keep group" in the same window, and the next cheapest item is shown right away. Each character remembers its own.
- The fill bar counts only your normal bags. The reagent bag (retail and Forever) is shown next to it ("Reagents 0/36"), because only crafting reagents fit there.
- Profession bags: only items from a bag the loot can go into are offered (freeing a slot in a mining bag does not help for a shell fragment).
- Options: an "Always keep" tick per group (not for Auto Sell and Other: those hold things you can get rid of). Under the new "Advanced settings" at the bottom (click to open): bag width, and "Clear" for the items you chose to always keep. Kept items say so in their tooltip.
- Options: the "Send without asking" tick behind the mail address now has a column title (Auto).
- Options: the window is wider. Per group you see an envelope with the alt it mails to; click it to type the name and tick "Send without asking". Groups that mail without asking show "Auto".

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
