---
tags: [changelog, ui, vip]
---
# Drawn icons, VIP stats and saved games, ground lights (2026-10-18)

The user asked for three things:
- real icons instead of emoji, matching the earlier references;
- total wins / draws / losses in Stats, plus detailed stats and saved games (games they reviewed)
  for VIPs. VIP gamepass: **2037495121**;
- the "Free table" signs replaced by a green or grey light on the ground.

## Icons: the Illustrator set, in-game without uploads
- Four new icons in `art/ui/make_icons.py`: `user`, `save` (bookmark), `gamepad` and `target`.
  There are also aliases `fire`, `new` and `close`. The set was exported through Illustrator
  (52 names, 43 unique pictures).
- `art/ui/make_icon_data.py` packs two atlases into the generated `IconArt.lua` (96 KB):
  - icons: 128 px cells, 1024×768;
  - the four Play-card illustrations: 256 px cells, 512×512.
- Each atlas is quantized to a 256-colour RGBA palette, then **zstd-compressed and base64'd**. That
  makes it about 3× smaller than the run-length encoding the pieces use.
- **`Icons.lua`** decodes each sheet once with **`EncodingService`** (`Base64Decode` plus
  `DecompressBuffer` with Zstd, built into Roblox) into one `EditableImage`. Labels show a cell
  through `ImageRectOffset` / `ImageRectSize`.
- **UiKit:**
  - callers still pass the emoji (`Ui.ICONS.x`);
  - `setText` swaps in an `ImageLabel` ("IconImg") placed just left of the text, with an
    "IconPad" `UIPadding`;
  - `tile`, `header(…, iconArg)` and the new `Ui.icon(parent, icon, size, pos)` do the same.
  - If EditableImage isn't allowed, everything falls back to the emoji.
- Emoji glued into strings (confirm dialogs, result title, draw offer, promotion, review title,
  hints) now go through `setText`, or were dropped.
- **Play cards:** each card shows its big illustration faded (50%) and tucked into the bottom-right
  corner, like the matchmaking reference. The small icon and the big label stay on top.
- **Publishing:** this needs the same setting as the 2D pieces: the owner ID-verified, and Game
  Settings → Security → **Allow Mesh & Image APIs** on.

## Stats (`StatsPanel.lua`, new)
- **Everyone:** three big tiles (Wins, Draws, Losses) with totals across all modes.
- **VIP:**
  - 12 rows: win rate, current and best streak, games played, average game length, checkmate
    wins, W/D/L per mode against people and against bots, average accuracy and brilliant moves
    (both from saved games);
  - chips for the 4 bot levels;
  - a **Saved games** tab: a scrolling list showing opponent, Win/Loss/Draw, accuracy, moves and
    date, with a **Review** button that reopens the review.
- **Not VIP:** a gold VIP card listing the perks, with a **Get VIP** button
  (`PromptGamePassPurchase`). The Saved tab shows a lock. Buying refreshes the card.
- The PLAY button hides while a lobby card is open (it used to sit under the card).

## Server
- `Settings.VIP_PASS = 2037495121`, `Settings.MAX_SAVED_GAMES = 25`.
- **`Vip.lua`:** `UserOwnsGamePassAsync`, cached:
  - an owner stays cached;
  - a non-owner is re-checked after 60 s;
  - a purchase in this server flips the cache at once.
  - Studio override: `ChessDebug:Invoke("vip", userId, true|false|nil)`.
- **`SavedGames.lua`:** DataStore `ChessGames_v1`, newest 25 per player.
  - The server **replays the client's record** and keeps only the legal actions, with plain fields.
  - Reviewing the same game again updates its entry, matched by a signature of start FEN plus
    actions.
- **`Results.lua`:** now also records `detail` for everyone: streak, best streak, games, plies,
  longest game, fastest win, wins by reason, and W/D/L per bot level. Only VIPs see it, so buying
  VIP shows history from this update on. Older games only count in the totals.
- **New Lobby verbs:**
  - `stats` now returns `{ results, vip, games }`;
  - `saveGame` (record), `savedGame` (id) and `deleteGame` (id) are VIP only.
- **When games save:** when a review's analysis finishes (`ReviewPanel.onAnalysed`), the client
  sends the record with its accuracy and grade counts. The review shows "Saved to Stats". A game
  opened from Saved games isn't saved again.

## Ground lights (replace the floating signs)
- Each table has an invisible slab 0.08 studs above the floor, so nothing is coplanar.
- A `SurfaceGui` draws a ring (`UIStroke`) and a soft rim glow, and a `PointLight` lights the floor.
- **Green** (pulsing) when a seat is free, **grey** when the table is full or a game is on.
- Who's playing is still in the Tables list.

## Tested (Studio playtest)
- **Icons:** 80 icons drew as images, none as emoji. Screenshots checked: the HUD side column,
  the lobby, Stats, Play screen and Review.
- **Ground lights:** 6 lights and 0 signs; green around free tables, grey under the one in play.
- **Save flow:** a bot game (e4, Nf3, Bc4), resigned, then reviewed:
  - the game saved (83.7% accuracy, 6 plies);
  - `detail` recorded the loss against Beginner;
  - Stats → Saved games → Review reopened it, and the saved count stayed at 1.
- **Non-VIP view:** the VIP card and the lock show (VIP override off).
- **Console:** no game errors.

Back to [[Home]]
