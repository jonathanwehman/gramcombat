# Gram Combat

Clean floating combat text for **WoW Forever**. Made to sit next to Gram Frames.

**Version 1.1.0** · Interface 16001 · type `/gc` in game

- `/gc` Gram Combat panel · `/gc move` drag the text areas · `/gc test` fake hits · `/gc advanced` every setting · `/gc debug` print what the game sends

## Install
1. **[Download GramCombat.zip](https://github.com/jonathanwehman/gramcombat/raw/main/GramCombat.zip)**
2. Unzip into `World of Warcraft\_forever_\Interface\AddOns` so you get `AddOns\GramCombat`.
3. Log in, type `/gc`, hit **Unlock & Move**, drag the pink boxes, then **Lock**.

## Layout
- **Incoming** (damage and heals you take): bottom left, stacked right-aligned against your player frame
- **Outgoing** (your hits and heals): bottom right, stacked left-aligned with spell icons
- **Notification** (loot, power gains, buffs, combat in/out): small text near the top

## How it works on Forever
WoW Forever doesn't let addons read the combat log. Gram Combat reads what the
game still shares: the damage, heals and misses each unit takes, and your own
casts. Your hits get matched to your spells by timing and target.

- Solo: everything that hits your mob counts as yours (pet swings included).
- In a group: only hits matched to your casts show. Auto attacks and DoT ticks
  can't be told apart from your group's, so they're hidden unless you turn on
  "Show unmatched hits in groups" under General.
- Forever hides the damage and heal numbers themselves from addons. Gram Combat
  passes them straight to the screen, so you still see the real numbers, but
  hidden hits can't be added up into "(2x)" groups.
- Damage you take is colored by school (Fire, Shadow...) but has no spell name;
  the game doesn't share it.
- Some buffs are hidden during combat on Forever; those are skipped.

## Thanks
Built on Parrot 2 by ckknight, Neb and profalbert, under the LGPL v2.1 (see LICENSE.txt).
