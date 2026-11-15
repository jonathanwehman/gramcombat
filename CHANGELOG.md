# Gram Combat

## 1.2.0
- Resize the text areas: in Unlock & Move, drag the pink corner of a box; the
  box height is how far the text scrolls
- Screenshots and CurseForge release

## 1.1.0
- Real hits now show: Forever hides damage and heal numbers from addons, so
  Gram Combat hands them straight to the screen without reading them
- New Gram Combat panel (`/gc`): Unlock & Move, Test, Reset Positions,
  show/hide switches, text and crit size, spell icons and names
- Drag-to-move boxes for Incoming, Outgoing and Notifications (`/gc move`)
- The old Parrot settings are still there under "Advanced Settings"

## 1.0.3
- All settings now live in the game's Options > AddOns > Gram Combat, with
  pages for Events, Triggers, Scroll areas, Suppressions, Cooldowns and Profiles
  (no more "Load config" button)
- `/gc` opens the same settings in a bigger window

## 1.0.2
- New default layout: incoming stacked right-aligned against your player frame
  (bottom left), outgoing stacked left-aligned with spell icons by your target
  frame (bottom right), loot and power gains in small text near the top
- Smaller, cleaner text (14 normal, 20 for crits, thin outline)
- Your existing setup is moved to the new layout once on update

## 1.0.1
- Fixed the loot error (an old item-count call the new client removed)
- Replaced a few more removed calls (mana check, honor, vehicle, number formatting)
- The settings menu now opens even if one page has a problem
- New: `/gc test` sends fake hits so you can see the layout; `/gc debug` prints what the game sends

## 1.0.0
- First release for WoW Forever (Interface 16001)
- New combat feed: Forever closed the combat log to addons, so Gram Combat reads
  what the game still shares (UNIT_COMBAT, your own casts, auras) and matches
  your hits to your spells
- Default layout: incoming text beside your player frame, outgoing beside your
  target frame, announcements near the top of the screen
- Expressway font by default when EllesmereUI, ElvUI or SharedMedia has it
- Gram branding, minimap addon-compartment entry, /gc to open settings
- Old API calls moved to the modern client (spellbook, spell info, cooldowns)
- Values the game hides in combat are skipped quietly instead of erroring
