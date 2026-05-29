<!-- BEGIN DISCLAIMER (managed by FFXIWindower author; do not remove) -->
## ⚠️ Disclaimer — Use at Your Own Risk

This is unofficial, fan-made software for *Final Fantasy XI*. It is **not affiliated with, endorsed by, or supported by Square Enix Holdings Co., Ltd.** FINAL FANTASY is a registered trademark of Square Enix.

**Square Enix's official position is that third-party tools and modifications to the FFXI client are prohibited by the Terms of Service.** Installing or using this software may result in account suspension, account termination, character data loss, or other action taken by Square Enix at their sole discretion.

This software is provided **AS IS, without warranty of any kind**, express or implied — including but not limited to warranties of merchantability, fitness for a particular purpose, and non-infringement. In no event shall the author or contributors be liable for any claim, damages, account action, lost time, lost progress, file corruption, or any other liability arising from the use of, or inability to use, this software.

**By installing, building, or running this software you acknowledge that you understand and accept these risks.**

<!-- END DISCLAIMER -->
# FFXIChecklist

A GUI fork of **HiPotionQ8**'s excellent [XIchecklist] tracker, restyled
to match the GSUI-family addon look. Same monstrous data set (every
mission, quest, key item, spell, trust, title, RoE objective, warp,
Monstrosity progression, MMM, Meeble, Sheol, Atmacite, Vorseal, Ergon,
Emporox, fish, zone visited, merit, JP, master level, crafting skill,
etc.), same automatic packet-driven detection, same per-character XML
state — just a more readable window and a real keyboard hotkey.

> **Credit:** every line of the tracker engine, packet handler, and
> data table (`maps/` totals ~1 MB of hand-curated FFXI content) is
> **HiPotionQ8**'s work. This fork's contributions are: the addon
> rename, the M-key keyboard toggle, the panel-alpha bump to 250 so
> the overlay reads as a solid window, and packaging consistent with
> the other addons in this author's setup. The original repo's
> permission grant (*"this thing is free to use / share / edit /
> anything i dont care what you do with it"*) is the only reason
> this fork can exist — full thanks.

## Install

```
cd path\to\Windower4\addons
git clone https://github.com/mullerdane85-hash/FFXIChecklist.git
```

In-game:

```
//lua load FFXIChecklist
```

To autoload, add `lua load FFXIChecklist` to `scripts\init.txt`.

## Keyboard

Press **M** to toggle the window. The keybind is suppressed while chat
is open so typing 'm' in messages still works.

## Commands

`//ffxic`, `//ffxichecklist`, `//checklist`, and `//clist` all work. The
original `//xic` and `//xichecklist` aliases are also retained for
back-compat with scripts written for HiPotionQ8's addon.

| Command | Description |
|---|---|
| `//ffxic` | Toggle the window (same as the M hotkey) |
| `//ffxic show` / `//ffxic hide` | Explicit show/hide |
| `//ffxic scale <n>` | UI scale factor (default 1, e.g. `0.75`) |
| `//ffxic showcompleted` | Toggle: show completed items in green (default off) |
| `//ffxic showexcluded` | Toggle: show hidden RoE / Titles items (default off) |
| `//ffxic copy` | Copy current tab content to clipboard |
| `//ffxic log <category>` | Print a tab to chat — every category from the original is supported |
| `//ffxic help` | Print the in-game help blurb |

## NPC-gated data

A handful of categories aren't packet-detectable and only update when you
talk to the right NPC once — this is **inherited verbatim from the
original XIchecklist** and is worth knowing:

| Data | Where |
|---|---|
| Titles | All Title NPCs (and the in-game status menu refreshes the current title) |
| Outpost Warps | Any Nation Teleporter |
| MMM Maze Count | Chatnachoq (Lower Jeuno) |
| Proto-Waypoint | Any Proto-Waypoint |
| Fish Caught | Katsunaga (Mhaura), menu: "Types of fish caught" |
| Meeble Burrows | Any Burrow Researcher or Investigator, menu: "Review expedition specifics → Zone" |
| Atmacite Levels | Any Atmacite Refiner, menu: "Enrich Atmacite" |
| Wing Skill | Nation chocobo-stable kids (Arvilauge / Gonija / Kiria-Romaria) |
| Sheol Gaol & Moogle Mastery | ??? in Rabao, "Status Report: Sheol Gaol / Moogle Mastery" |
| Escha Vorseals | Shiftrix in Reisenjima |
| Ergon Locus | Rienne in Western Adoulin |
| Emporox Goodness | Emporox in Reisenjima #8 |

Once captured, the values persist to `data/<charname>.xml` and don't
need to be re-collected per session.

## Notes

1. **By default only INCOMPLETE items show.** Toggle `//ffxic showcompleted` to also
   list things you've finished (rendered in green).
2. **First load can freeze for a few seconds** while RoE objectives register —
   normal behavior inherited from the original.
3. **Zoning refreshes:** Quests / Warps / Monstrosity / MMM counts update on
   zone change, not in real time.

## What's tracked

- Monstrosity (monster levels / race & job instincts / monster variants)
- Titles + how-to-obtain hints
- Moblin Maze Mongers (vouchers / runes / maze count)
- Meeble Burrows
- Sheol Gaol / Moogle Mastery goals
- Types of fish caught
- Records of Eminence (RoE)
- Warps (Home Points / Survival Guides / Waypoints / Outposts /
  Proto-Waypoints / Telepoints / Cavernous Maws / Lycopodium /
  Eschan Portals)
- Campaign Ops
- Missions (San d'Oria / Bastok / Windurst / Zilart / CoP / TOAU /
  Assaults / WOTG / ACP / MKD / ASA / SoA / RoV / TVR)
- Quests (San d'Oria / Bastok / Windurst / Jeuno / Aht Urhgan /
  Crystal War / Outlands / Other / Abyssea / Adoulin / Coalition)
- Key Items (Permanent / Maps / Mounts / Claim Slips / Active Effects /
  Abyssea / Voidwatch / Mog Garden)
- Spells (White / Black / Summon / Ninjutsu / Bard / Blue) + Trusts
- Atmacite levels, Vorseals, Ergon Locus, Emporox Goodness
- Zones visited
- Leveling stuff (Merits, Job Points, Master Levels, fishing & crafting
  skills, Wing Skill, Alter Ego Points)

## Changes vs. upstream XIchecklist

| Change | Why |
|---|---|
| Renamed to FFXIChecklist | Consistent with the other `FFXI*` addons in this author's repo group |
| Added M-key keyboard toggle | The original was slash-command only |
| Bumped UI panel alphas 200-240 → 250 | Original overlay was translucent; window now reads as solid |
| New `toggle` command (and bare `//ffxic`) | The M hotkey routes through it; original only had `show`/`hide` |
| Back-compat aliases (`xic`, `xichecklist`) | Scripts written for the original keep working |

Tracker logic, packet handlers, the entire `maps/` data set, and the
tab/subtab/click handling are **untouched** — all credit there to
HiPotionQ8.

## Author

Jason (2026), GUI fork of HiPotionQ8/XIchecklist. Part of the
FFXIWindower personal setup.

[XIchecklist]: HiPotionQ8/XIchecklist on GitHub (no hyperlink here per
convention; search the repo name to find the original).
