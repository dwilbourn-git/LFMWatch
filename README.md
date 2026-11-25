# LFMWatch

A World of Warcraft addon for **WoW Forever** (interface 16001) that spots
people recruiting for the dungeons and raids you care about, so you do not
have to watch chat.

When someone in guild chat or a watched channel posts a line such as
"LFM Deadmines need tank", LFMWatch:

- tags and tints the line in chat, for example `[LFM Deadmines]`;
- adds the sender to a small pop-out list of who is recruiting, with the
  dungeon and a row of icons showing which places are open.

There is no sound. A sender drops off the list five minutes after their most
recent message (the time is adjustable from 1 to 15 minutes).

## Install

1. Download or clone this repository.
2. Copy it into your addons folder as a folder named exactly `LFMWatch`:
   `World of Warcraft\_forever_\Interface\AddOns\LFMWatch`
3. Restart the game. Type `/lfw` to open the settings.

## Setting up

Open the settings with `/lfw` and tick:

- **Channels** — guild chat and any ordinary chat channels you have joined.
- **Dungeons and raids** — only ticked ones count. A recruiting line that
  names no ticked dungeon is ignored.

A line matches when it contains both a watched dungeon (its name or an alias
such as `dm`, `sm`, `brd`) and a recruiting word (`lfm`, `need`, `lf tank`,
`last spot`, `lf2m` and so on). Lines containing an ignore word (`wts`,
`wtb`, `selling`, `boost`) never match. All three word lists can be edited in
the settings, and you can add dungeons of your own with their aliases.

"Looking for group" lines (people seeking a group, not forming one) are
ignored unless you tick **Include LFG**.

## The list

One row per recruiter. If the same person posts again, in any watched
channel, their row is updated in place and flashes; it is never duplicated.
A follow-up such as "still need a healer" updates the row without naming the
dungeon again. If they say the group is full, the row dims, is labelled
"Group Full" and leaves after a minute. The thin bar under a row is the time
it has left.

### Seat icons

A dungeon row shows five places: tank, healer and three damage.

| Icon | Meaning |
|---|---|
| Bright role icon | That place is open: the line asked for it |
| Dim role icon | Filled, worked out from what the line asked for |
| Gold question mark | Nothing to go on |
| Class icon in a coloured ring | A particular class is wanted; the ring is blue for tank, green for healer, red for damage, bronze when the role was not stated |

"LFM DM need tank and healer" lights the tank and healer and dims the three
damage places. "LF2M dps" lights two damage places. A line that names no
role, class or number shows five question marks.

A raid row shows only what is being asked for, for example two healer icons
and a warlock.

| Action | Result |
|---|---|
| Hover a row | Shows the full message and the channel |
| Left-click a row | Opens a whisper to the sender |
| Right-click a row | Removes the row |
| Drag the window | Moves it; the position is saved per character |

## Commands

| Command | What it does |
|---|---|
| `/lfw` | Open or close the settings |
| `/lfw list` | Show or hide the list |
| `/lfw test <text>` | Run a line through the matcher as if someone had said it, and print the places it read |
| `/lfw clear` | Empty the list |
| `/lfw rescan` | Restore any built-in dungeons missing from your list |
| `/lfw debug` | Save a snapshot of recent decisions for troubleshooting |

`/lfmwatch` works in place of `/lfw`.

## Limits

- **Community channels cannot be watched.** The game hides the text of
  community chat from addons, so there is nothing to match. They appear
  greyed out in the settings.
- The dungeon list is built in, because this client has no dungeon journal
  for an addon to read. A new dungeon has to be added by hand in the settings
  until the list is updated.
- Scarlet Monastery, Dire Maul and Stratholme are listed by wing. `dm` alone
  means Deadmines.
- Channel and dungeon ticks are saved per character; word lists and the
  dungeon list are shared across characters.

## Credits

The look follows FlareUI by
Malkkav. The border and icon art are copied from FlareUI (MIT) and the font is
Roboto Condensed (Apache 2.0); see the `LICENSES` folder. LFMWatch does not
need FlareUI installed.

## Status

Version 0.2.0. Early release: the settings, the matcher and the list have
been tried in game, but it has had little use with real recruiting traffic.
Bug reports are welcome on the issue tracker.

## Licence

MIT. See [LICENSE](LICENSE).
