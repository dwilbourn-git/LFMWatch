# LFMWatch

A World of Warcraft addon for **WoW Forever** (interface 16001) that spots
people recruiting for the dungeons and raids you care about, so you do not
have to watch chat.

When someone in guild chat or a watched channel posts a line such as
"LFM Deadmines need tank", LFMWatch:

- tags and tints the line in chat, for example `[LFM Deadmines]`;
- adds the sender to a small pop-out list of who is recruiting, with the
  dungeon and the roles they asked for.

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
| `/lfw test <text>` | Run a line through the matcher as if someone had said it |
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

## Status

Version 0.1.1. Early release: the settings, the matcher and the list have
been tried in game, but it has had little use with real recruiting traffic.
Bug reports are welcome on the issue tracker.

## Licence

MIT. See [LICENSE](LICENSE).
