---
tags: [changelog]
---
# Sound effects, board themes, Settings panel (2026-10-17)

Backlog items 1 and 2 in [[Next Steps]].

## Sounds (`Chess/Sounds.lua`, client)
- Every sound comes from Roblox's licensed **Pro Sound Effects** library (free in any experience),
  except the snipe shot, which is Roblox's built-in `impact_explosion_03`. Nothing is ripped from
  chess.com or uploaded by random users. Swap an id in the `LIB` table to change a sound
  everywhere.

  | Event | Asset | Notes |
  |---|---|---|
  | move | 9118623491 | hit rock with wood, pitched up |
  | capture | 9126266458 | cast-iron weight on wood |
  | castle | 9118621947 | a second wood strike, 0.09 s after the move sound |
  | check (+ / #) | 9126073001 | synth sparkle ding |
  | game start | 9126073318 | softer ding |
  | game end | 9126073011 | long ding, played after the snipe cutscene if one is running |
  | low time tick | 9118621947 | under 10 s, once a second, on your own running clock |
  | snipe shot | rbxasset impact_explosion_03 | through `Sounds`, so the toggle mutes it |
- At your own table sounds play flat. Within 60 studs of another table they play from that board
  (3D, roll-off 12–70). Further away, nothing plays.
- Your own move makes its sound at once with the prediction. The server's echo is detected
  (`echo`) and doesn't play it twice.
- `Sounds.forMove(san)` picks the sound from the SAN: `O-O` castle, `x` capture, `+`/`#` check.
  Ability actions play no move sound, because the cutscene has its own.

## Themes (`Shared/Themes.lua`)
- **Classic Green** (the default), **Walnut**, **Ocean**, **Candy**, **Slate** and **Sunset**,
  each with light/dark squares, a 3D frame colour and a 2D border colour.
- The client recolours all 6 tables' squares and frames locally (`paintBoard`), plus the 2D board
  (`Board2D:setTheme`). Coordinates recolour too. Other players see their own theme.

## Settings panel + saved prefs
- `SettingsPanel.lua`: 6 theme swatches, each a mini board, with the chosen one ringed in green.
  It has a **Sound effects: On/Off** toggle and Done. It opens from a new **Settings** button in
  the lobby bar and in the seated HUD's left column.
- Server `Tables/Prefs.lua`: DataStore `ChessPrefs_v1`, key `u_<userId>`, value
  `{ theme, sound }`. It's cached per session and cleaned: unknown keys are dropped and an unknown
  theme id is ignored.
- Lobby verbs `getPrefs` and `setPrefs` (arg `{theme?, sound?}`). The client loads prefs on join
  and saves on every change.

## Verified (by script; the user was away from the PC)
- **Sounds:** the logged sound events were start, then move ×4 (your moves and the bot's), then
  capture + check on `Qxe4+`, then finish on resign. They play from `SoundService.ChessSounds`.
- **Prefs:** a junk key was dropped. A bogus theme was ignored. **Saving walnut, restarting the
  playtest:** all 6 tables (a1 181,136,99, frame 120,82,52) and the 2D border (98,66,42) loaded
  in walnut from DataStore. Reset to green afterwards.
- `Board2D:setTheme` and the panel were built on a cloned copy: right colours, 16 coordinates
  redrawn, 6 swatches, the ring on the chosen theme, the sound label correct.
- No script errors.
- **DataStore works in Studio now** (API access must have been turned on): the save went through.

## Not checked yet (needs the PC)
- What the Settings panel looks like, and clicking it for real.
- Hearing the sounds: volumes and pitch may need tuning by ear.
- The low-time tick in a real game (the debug clock jump only shifts the server's clock, so the
  client never sees it).
- The prediction path's sound (your move clicked with the mouse).

Back to [[Home]]
