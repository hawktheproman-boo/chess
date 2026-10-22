---
tags: [changelog]
---
# Icons and less text (2026-10-17)

The user's feedback, from a screenshot of the table panel: "the UI has way too much text, it's really
cluttered, this game is meant for all ages". They also asked where the promised icons were (the UI
restyle hadn't been built yet), and for a **Copy** button on the PGN.

## Icons beside text
- `UiKit.ICONS` is one table of icons. They're **emoji for now**, because images can't be uploaded
  yet. To switch to image icons later, only those strings change.
- `button(..., icon)` puts the icon in front of the text, one size bigger (RichText `<font size>`).
  - `Ui.setText(face, text, icon?)` changes the text and keeps the icon.
  - `Ui.tile` is a square icon button with a short caption under it.
  - `Ui.closeX` is a red ✖ in a card's corner.

## Less text
- **Table panel:**
  - before: a "White: … / Black: …" block plus "Mode: Classic", "Clock: 10 min", "Play the bot",
    "Leave table";
  - after: the title "Table 1" and three rows: ♟️ Classic | ⏱️ 10 min, 🤖 Bot | 😎 Club, then ✅ Ready / 🚪 Leave;
  - the bot row hides when a person sits opposite;
  - "✅ Ready" before a game now shows on the player bars.
- **Seated side column:** before, it was 8 wide buttons. Now it's 🤝 Draw and 🏳️ Resign (while
  playing) plus a 2×2 grid of tiles: 2D/3D, Tilt/Flat, Settings, Leave.
- **Auto-queen** moved into Settings and is saved with the other prefs. The server `Prefs` now stores
  `autoQueen`.
- **Move list:** hidden until the first move.
- **Bot player bar:** the second "Computer" line is gone.
- **Result card:**
  - title: 🏆 You win! / 😢 You lost / 🤝 Draw;
  - short reasons such as "Resigned" and "Out of time";
  - buttons: 🔁 Rematch, 📊 Review, 🚪 Leave.
- **Small dialogs:**
  - draw offer: "🤝 Draw?" with ✅ Yes / ❌ No;
  - confirms: "🏳️ Resign?", "🚪 Leave? You lose this game.";
  - promotion: just the four pieces.
- **Device hints:** one short line each, e.g. "🖱️ Click or drag a piece".
- **Lobby bar:**
  - 🤖 Play Bot and ⚔️ PvP;
  - Tables, Stats and Settings as tiles;
  - sheets close with a red ✖ instead of a Close button.
- **Bot setup:** level tiles show a big emoji (🐣 😎 🔥 🙂) and the name, without blurbs. Then
  mode, clock and colour buttons with icons, and ▶️ Play!.
- **Tables list:** one line per table: "Empty", "👤 name", or "🎮 A vs B".
- **Stats:** a 🏆/😢/🤝 legend, then ⚔️ People and 🤖 Bots lines per mode.
- **Review:**
  - the grade table only lists grades someone got;
  - buttons: 📋 PGN, ⭐ Key moment, ✖ Close, 💡 Best move.

## PGN Copy
- The PGN sheet has **📋 Copy** and ↩️ Back.
- Copy focuses the box and selects all of it, then shows "✅ Selected! Now press Ctrl+C" ("…tap
  Copy" on phones).
- Roblox gives games **no clipboard API** (checked 2026-10-17), so the player's own copy is the
  last step.
- Tested by a real click: the box was focused with all 254 characters selected. Ctrl+C wasn't
  simulated (it would overwrite the user's clipboard).

## Checked
- Studio playtest stills of each screen:
  - lobby bar, Play Bot, Settings, Tables, Stats;
  - table panel, in-game HUD, result card;
  - review, PGN sheet.
- Not checked yet:
  - phone and controller layouts;
  - how the emoji look on other devices (Roblox draws them with its own emoji font).

Back to [[Home]]
