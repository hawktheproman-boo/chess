---
tags: [changelog]
---
# Simulator style and the Play screen (2026-10-17)

The user shared two popular-game screens ("Charge Your Egg!" and "Matchmaking") and asked to
reverse-engineer them, fit them to the chess game, and plan the art in Adobe. Choices:
- dark green panels;
- Adobe apps: Illustrator, Photoshop and Firefly;
- a new Play screen of mode cards.

The full breakdown and the Adobe asset plan are in [[Design/UI Style]].

## Done (code only; no images needed)
- **`UiKit.lua` style layer.** Every screen picks it up.
  - Panels: deep green gradient panels with a faint checkerboard and a 4 px ink outline.
  - Text: chunky Fredoka One with an ink outline.
  - Buttons:
    - flat colour with a sheen overlay and diagonal stripes;
    - a press squash;
    - new styles: blue, gold, abilities and locked.
  - Close button: a red tilted square X.
  - Panels pop when shown.
  - New helpers: `header`, `chunky`, `highlight`, `restyle`, `badge`, `spaced`.
- **Lobby:**
  - one big **▶ PLAY** button;
  - a left column like the simulator games: 🪑 Tables (green), 🏆 Stats (blue), ⚙️ Settings
    (gold).
- **Play screen (`PlayScreen.lua`):**
  - The world blurs (`BlurEffect`) and darkens; "C H O O S E  A  M O D E" sits over a big PLAY
    title.
  - Four cards:
    - **VS BOT** opens the bot options;
    - **CLASSIC 1v1** and **ABILITIES 1v1** queue for a player in that mode;
    - **TOURNAMENT** shows "🔒 Soon" (VIP).
  - Hover, tap or D-pad picks a card: it grows, gets a white plate, a shine sweeps across it and
    PLAY appears.
  - B closes. A scroll bar shows when the cards don't fit, e.g. on phones.
- **Server:** `quick` with `{vs = "player", mode}` only joins someone waiting in that mode. A
  fresh table waits in the picked mode.
- **Retuned for the dark style:**
  - the table panel, player bars and move list;
  - the result card (big chunky "😢 You lost");
  - Settings (gold ring on the picked theme; toggles turn green when on);
  - Review (dark backdrop and panel, white board kept).
- **Fixed:**
  - "a5 is a good." now reads "a5 is a good move.";
  - the seated Settings tile is now blue, so the gear shows.

## Checked
- Studio playtest stills of the lobby, Play screen, PvP Classic seating, table panel, game HUD,
  result card, review, Settings and the bot sheet.
- BotTests and AbilityTests pass.
- Not checked yet: phone and controller on the Play screen.

## Gotcha found
A `UIGradient` on a TextButton tints its **text**, which made the button text dark. Faces now use
a flat colour plus a `Sheen` overlay.

## Left for later
- Part B art (blocked on image uploads):
  - icons;
  - 9-slice frames;
  - corner stickers;
  - card art from our pieces;
  - checker and stripe tiles.
- ✅ (restyled 2026-10-17, [[Changelog/2026-10-17 Table signs and Adobe art]]; then replaced by ground lights 2026-10-18, [[Changelog/2026-10-18 Drawn icons, VIP stats, ground lights]]) The 3D table signs ("Table 4 · open") used the old white pill style.

Back to [[Home]]
