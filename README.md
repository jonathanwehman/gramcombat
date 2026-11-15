# Gram Combat

Clean floating combat text for **WoW Forever**. Made to sit next to Gram Frames.

**Version 1.0.1** · Interface 16001 · type `/gc` in game

## Install
1. **[Download GramCombat.zip](https://github.com/jonathanwehman/gramcombat/raw/main/GramCombat.zip)**
2. Unzip into `World of Warcraft\_forever_\Interface\AddOns` so you get `AddOns\GramCombat`.
3. Log in and type `/gc`. Under Scroll areas, turn on Configuration mode to drag things where you want.

## Layout
- **Incoming** (damage and heals you take): beside your player frame
- **Outgoing** (your hits and heals): beside your target frame
- **Notification** (buffs, combat in/out, loot, cooldowns ready): near the top

## How it works on Forever
WoW Forever doesn't let addons read the combat log. Gram Combat reads what the
game still shares: the damage, heals and misses each unit takes, and your own
casts. Your hits get matched to your spells by timing and target.

- Solo: everything that hits your mob counts as yours (pet swings included).
- In a group: only hits matched to your casts show. Auto attacks and DoT ticks
  can't be told apart from your group's, so they're hidden unless you turn on
  "Show unmatched hits in groups" under General.
- Damage you take shows its school (Fire, Shadow...) but not the spell name; the
  game doesn't share it.
- Some buffs are hidden during combat on Forever; those are skipped.

## Thanks
Built on Parrot 2 by ckknight, Neb and profalbert, under the LGPL v2.1 (see LICENSE.txt).
