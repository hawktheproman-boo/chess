---
tags: [changelog, shop, abilities, stats]
---
# Shop, coins and PvP-only stats (2026-10-18)

The user asked for three things:
1. a **Shop**, with the abilities sold in it (UI references: the "Charge Your Egg!" panel and a
   simulator "Store" with a coin balance, item cards with Buy buttons and category tabs);
2. **coins for winning a 1v1** (a game against a person), and nothing for bot games;
3. **Stats count only games against people**: wins, draws and losses against bots are gone.

## Economy (agent's numbers; change them in `Shared/Shop.lua`)
- **+50 coins** for every win against a person, in Classic or Abilities. A win only pays once the
  game is **10 plies** long (5 moves each), so an alt resigning at once can't farm coins.
  Draws, losses and bot games pay nothing.
- A new player starts with **100 coins**: enough for the cheapest ability.
- **Prices:** Any Passant 100, Double Jump 150, Swap 150, Royal Escape 200, Battering Ram 250,
  Snipe 300. That's 1,150 for all six, about 21 wins on top of the starting coins.
- **Abilities are bought once and kept forever.** There's nothing to equip.

## How ownership works in a game
- In an **Abilities** game each player can only use the abilities they own. The rest start with no
  charge (`Modes/Abilities.setLoadout`, called right after `Game.new`).
- **A bot gets the same abilities as the person it plays**, so a bot game is a fair practice.
- The server decides: `ChessTable:start` asks `loadoutFor(participant)` (the wallet) and puts the
  `loadout` in every snapshot. The client applies it when it rebuilds the game. An unbought
  ability is rejected by the server as an illegal ability (tested).
- Test drivers' fake players have no `Player`, so they keep every ability, and their games never
  touch real stats or wallets.
- Classic is unchanged.

## Server
- **`Tables/Wallet.lua`:** DataStore `ChessWallet_v1`, key `u_<userId>`,
  `{ coins, owned = { [id] = true }, earned }`.
  - Every change goes through `UpdateAsync`, so two servers can't spend the same coins twice.
    Purchases are checked inside the update.
  - A session cache answers reads. The wallet is preloaded when a player joins.
  - `Remotes.Wallet` (new RemoteEvent) pushes `{ coins, owned, gained? }` after a win reward.
- **Lobby verbs:** `wallet` returns `{ coins, owned, vip }`; `buy` (an ability id) returns
  `ok, { coins, owned }` or an error ("not enough coins", "already owned").
- **`onFinished`:** stats and coins only for games where **both** seats are real players.
  `Results.record` is no longer called for bot games.
- **Studio:** `ChessDebug:Invoke("wallet", userId, coins?, ownedIds?)` sets a test wallet. From
  then on that player's wallet is a **sandbox** for the session: nothing saves.

## Client
- **`ShopPanel.lua` (new), a 760×476 card:**
  - **header:** a cart icon, "Shop", and your coin balance in a dark pill (it bumps when it
    changes);
  - **gold hint line:** "Win 1v1 games to earn coins: +50 a win";
  - **Abilities tab:** a 3×2 grid of item cards. Each has the piece's colour gradient (the same
    accents as the ability panel), the ability name, "PIECE · ONCE A GAME", a one-line rule, the
    white piece big on the right, then a coin price and a green **Buy**:
    - **Buying takes two taps** (Buy, then a gold "Sure?" for 3 s).
    - When you can't afford it, the button is slate with "Need N more", and a tap says how many
      coins are missing.
    - **Owned** cards show a green OWNED and a green ring.
  - **VIP tab:** the VIP pass (live Robux price, or OWNED) beside **Steal a Piece** (locked,
    "Coming soon"). *Resolved by [[Changelog/2026-10-18 Gamepasses and Steal a Piece]]: Steal is an in-game button now, and the VIP tab is just the VIP pass.*
  - Category tabs (Abilities / VIP) run along the bottom, like the reference's Food / Swords /
    Boosts.
- **Lobby side column:**
  - a **coin counter** on top (coin icon and a big gold number; it bumps when coins arrive);
  - then **Shop** (green), Tables (now purple), Stats, Settings.
  - On phones the column sits at 47% height (was 42%) to fit the extra rows.
  - The Shop card fits the screen's width as well as its height.
- **Ability panel:** abilities you don't own show a padlock on the piece tile and a gold **SHOP**
  status, and are faded. Tapping one says "Unlock X in the Shop".
- **Result card:** "+50 coins" with the coin icon pops in under the reason after a paid win.
- **New icons:** `coin` (gold coin with a star) and `shop` (white cart). They're in
  `art/ui/make_icons.py`, exported through Illustrator and packed into `IconArt.lua`.

## Stats (`StatsPanel.lua`)
- The Wins / Draws / Losses totals and the win rate add up **only the per-mode buckets**. Old
  `*_bot` buckets in saved data are ignored.
- The VIP rows "Classic bots" / "Abilities bots" and the bot-level chips are gone. The rows are
  now two columns of five (taller rows).
- **Known leftover:** older `detail` figures (streaks, Avg. game, Checkmates) were recorded with
  bot games mixed in. They're correct from this update on.

## Tested (Studio playtest, sandbox wallet)
- AbilityTests 24/24 and BotTests pass. A loadout of `{ w = { "BishopSnipe" } }` leaves White
  only Snipe and Black all six.
- **Shop:**
  - balance 400, Any Passant OWNED;
  - Buy → "Sure?" → Buy bought Double Jump (400 → 250, OWNED, toast);
  - Snipe then showed "Need 50 more" on a slate button.
- **PvP Abilities game** (you vs a test player):
  - the snapshot loadout was your two abilities, and the panel showed 4 SHOP padlocks;
  - a Snipe from c4 was rejected by the server ("illegal ability");
  - after 10 plies the rival resigned: **+50 coins** on the result card, and the counter went
    200 → 250.
- **Bot game (Abilities):** the bot's loadout matched yours, no coins, and the Stats DataStore
  value was unchanged.
- **Stats card:** PvP totals only (0 W, 2 D, 1 L for the test account); bot rows are gone.
- **VIP tab:** OWNED for a VIP, and Steal a Piece shows Coming soon.
- **Console:** only Roblox's own UIBlox warnings.
- **Mistake fixed:** the first PvP test (fake rival) wrote one win into the user's real
  `ChessStats_v1` record. It was reverted by hand (Abilities w, streaks, games, plies, fastestWin,
  winsBy). The rule is now "both seats real players", so this can't happen again.
- **Not checked:** the phone layout of the Shop, and coins on a live server.

Stills: `stills/2026-10-18j-shop.jpg`, `k-locked-abilities`, `l-win-coins`, `m-shop-vip`,
`n-stats-pvp`.

Back to [[Home]]
