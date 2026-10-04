# Bam Together

A World of Warcraft addon that plays the classic **BAM!** sound on critical hits and shares it with your party. Everyone in the party who has the addon installed hears everyone's BAMs.

Based on [Bam! Forever](https://www.curseforge.com/wow/addons/bam-forever/comments) by Fedex1991, which builds on the original Bam! addon by maggo.

## Features

- BAM sound on your critical hits, BAAAM on critical finishers
- Party sharing: your BAMs are sent to party members running the addon, and theirs play for you
- Party sharing can be toggled in the settings and is on by default
- Pick your own crit and finisher sound, or shuffle; party members hear the sound you picked
- Optional chat line with crit damage and target, for your crits and your party's
- Mute in dungeon/group only silences your own client; your BAMs are still sent to the party

## Party sharing and crit detection

WoW Forever hides who caused a crit, so the addon guesses whether a crit on your target was yours. In a group, several clients can claim the same crit. When a crit with the same target and damage arrives from more than one party member within half a second, only the first claim plays and prints, so one crit is one BAM. The name shown in chat is whoever claimed it first and may not be the actual critter.

Party members without the addon neither send nor hear BAMs. In a raid, sharing reaches only your own subgroup.

## Installation

1. Copy the `BamTogether` folder to `World of Warcraft/Interface/AddOns/`.
2. Remove `BamForever` if installed, both addons use `/bam`.
3. Start WoW or run `/reload`.
4. Open the settings with `/bam`.

## License

MIT. See `LICENSE` and `BamTogether/LICENSE`.
