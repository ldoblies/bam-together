# Bam Together

**Bam Together** plays the classic **BAM!** sound on your critical hits and shares it with your party. Everyone in the party who has the addon installed hears everyone's BAMs. A critical finisher/kill can optionally play the longer **BAAAM!**.

Based on [Bam! Forever](https://www.curseforge.com/wow/addons/bam-forever/comments) by Fedex1991, which builds on the original **Bam!** addon by maggo.

## Features

- BAM sound on detected critical hits
- Melee and spell crits can be toggled separately
- Optional BAAAM sound on a critical finisher/kill
- Choose the crit and finisher sound, or Shuffle for a random one each time
- Party sharing: your BAMs are sent to party members with the addon, and theirs play for you with the sound each player picked (on by default)
- Optional chat line with crit damage and target, for your crits and your party's
- Optional muting inside dungeons or while in a group; this only silences your own client, your BAMs are still sent to the party
- Sound anti-spam delay from 0 to 2 seconds
- Diagnostic mode
- Settings window via `/bam`

## Party sharing and crit detection

WoW Forever hides who caused a crit, so the addon guesses whether a crit on your target was yours. In a group, several clients can claim the same crit. When a crit with the same target and damage arrives from more than one party member within half a second, only the first claim plays and prints, so one crit is one BAM. The name shown in chat is whoever claimed it first and may not be the actual critter.

Party members without the addon neither send nor hear BAMs. In a raid, sharing reaches only your own subgroup.

## Commands

- `/bam` - open the settings
- `/bam test` - test your crit sound
- `/bam testbig` or `/bam baaam` - test your finisher sound
- `/bam on` - enable the addon
- `/bam off` - disable the addon
- `/bam reset` - reset the settings

## Installation

1. Copy the `BamTogether` folder to `World of Warcraft/Interface/AddOns/`.
2. Remove `BamForever` or an old `Bam` folder if installed, they also use `/bam`.
3. Start WoW or run `/reload`.
4. Open the settings with `/bam`.

## Languages

The addon uses the language of your WoW client: German (deDE), English (enUS/enGB), Spanish (esES/esMX), French (frFR) and Italian (itIT). Other locales fall back to English.

## Sounds

`sounds/bam.ogg` and `sounds/baaam.ogg` come from the original Bam! addon package. Any sound can be picked for either slot; Shuffle picks from the crit or finisher group.

To add a sound, put an `.ogg` file in `sounds/` and add an entry to `Bam.sounds` in `Core.lua`. Party members need the same file and entry to hear it; otherwise they hear the default BAM/BAAAM.

## License

MIT. The copyright notices of maggo (Bam!) and Fedex1991 (Bam! Forever) are kept, see `LICENSE` and `CREDITS.md`.
