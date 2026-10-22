---
tags: [changelog, lobby, ui, sound, music, mobile]
---
# Lobby feedback, table panel QOL, background music (2026-10-20)

**The user's feedback** on the new lobby, in five screenshots:
- the leaderboards should show on both sides;
- the colourful flower balls look like candy and don't fit;
- on a phone, 2D taps pick the wrong piece;
- the button "UI thing" doesn't cover the whole button, PLAY included;
- the table panel jumps when the bot level changes;
- the bot level should be clearer;
- the bot choice should be a checkmark, with the level hidden until a bot is chosen;
- remove the hover sounds, keep the clicks;
- add classical background music, with an on/off checkmark in Settings.

## Lobby
**Leaderboards on both sides.** `LobbyBoards` now draws each board on the front of its Screen
part and on the **back of the board's Back panel**, refilled together.

**No more candy balls:**
- the spawn-path beds are now a clipped low hedge with four topiary balls each (`build_decor`);
- the corner planters lost their four coloured balls and keep one bigger bush (`build_room`).

Overlap check: 0.

## Fixes
**2D taps on phones.** `Board2D` took only the top-bar part of the GUI inset off a tap. On a
phone with a notch, the inset also has a **left** part, about one square wide on a small board, so
a tap landed one file to the right (the knight picked the bishop). It now takes off both the X and
Y inset.
- **Checked on desktop:** a tap on b1 selects the knight, with a3 and c3 shown.
- **Not checked yet:** a real notched phone, since Studio's emulator can't show it.

**Button overlays didn't cover the button.** Two causes:
1. **The icon's padding.** A button with an icon (or a tick box) gets a `UIPadding` to make room,
   and that padding also pushed the face's **Sheen** and **Stripes** overlays right, leaving a bare
   strip down the left side, on every iconed button. New `fitOverlays` in UiKit keeps both
   overlays spanning the whole face, and it reruns whenever the padding changes.
2. **The stripes themselves.** A 30° rotated gradient doesn't reach a wide button's corners. The
   stripes are now drawn on a frame 1.4× the button, clipped by a plain frame.
   - A CanvasGroup was tried first, but under a UIScale (the Settings sheet) Roblox drew it in the
     wrong place, as ghost stripes below and to the left. Don't use CanvasGroups for this.

**The table panel jumped on a level change.** Changing the level used to remove the bot and add a
new one, so the Ready row vanished for a moment and the panel shrank. There's a new lobby verb,
**`botLevel`** (`ChessTable:setBotLevel`), which changes the seated bot's level and name in place.
The panel height stayed at 310 px through two level changes.

## Table panel QOL
- **"Play vs bot" is a tick box** (new `Ui.checkbox`: a dark button with a tick box on the left that
  turns green with a tick). Ticking it seats a bot; unticking removes it.
- **"Bot level: Club"** is its own full-width button, shown **only while a bot is seated**, so it
  reads as the bot's level. Each press steps to the next level.

## Sounds
- **Hover sounds removed:** on every UiKit button (mouse-over and controller focus), the Settings
  theme swatches and the Play-screen cards. Clicks stay.

**Background music (new `Chess/Music.lua`):** a shuffled playlist from Roblox's licensed music
library (found with `AssetService:SearchAudio`).

| Track | Asset id |
|---|---|
| Chopin: Nocturne | 9048615440 |
| Debussy: Clair de Lune | 1844513698 |
| Satie: Gymnopédie No. 1 | 1837474061 |
| Chopin: Impromptu Op. 36 | 1848053043 |
| Satie: Gymnopédie No. 3 | 1837474107 |
| Liszt: Valse oubliée No. 1 | 1847113523 |
| Debussy: Prelude, "Les sons et les parfums" | 1837474465 |

- It plays at volume 0.32, with fades between tracks and a short pause after each.
- A track that won't load is skipped. Each new shuffle never repeats the last track first.
- **Cutscenes duck it** to 0.08 for the seated players (the ability scenes and Snipe), then bring
  it back.

**Settings: a "Background music" tick box.**
- It's saved as `prefs.music` in `ChessPrefs_v1`, on by default, and `Prefs.clean` keeps it.
- The Settings sheet is 60 px taller on wide screens, and the phone column is tighter (5 rows).

## Tested (Chess?? playtest)
- Both sides of the boards show the list.
- The topiary beds look right.
- **Table panel:**
  - the tick box seats a bot, and "Bot level: Club" and Ready appear;
  - the level cycles Club → Strong → Beginner with no size change.
- The buttons have full-width shine and stripes (table panel, Settings).
- **Music:**
  - it plays and loads (Impromptu, 359 s);
  - unticking fades it to 0 and saves `music = false`;
  - re-ticking resumes it (the Nocturne).
  - **The test toggle wrote the user's real prefs**, so it was put back to **on**.
- No console errors.

**Not checked yet:**
- by ear (the music and ambience volumes together);
- a notched phone for the 2D taps;
- the Settings phone layout with 5 rows;
- the Tournament place (needs the push and builders).

Back to [[Home]]
