---
tags: [changelog, pieces, blender]
---
# Piece sets: Classic and Toon (Blender meshes) (2026-10-19)

Phase 0 and Phase 1 of the plan for this round (pieces, cutscenes, leaderboards, lobby). The user
chose: **piece sets**, a default set now, and a system that supports more sets (sellable in the Shop
later).

## Phase 0: proving the routes
- **Mesh route (verified):**
  1. Blender (MCP) → FBX → Studio's 3D Importer, driven by computer use (the user approved Roblox
     Studio and Blender).
  2. The importer uploads the meshes to **The Depths Studio** group.
  3. Blender units come in as studs exactly: export with `axis_forward -Z, axis_up Y`, and FBX
     unit scale.
  4. Each MeshPart's pivot (PivotOffset) lands at the base's underside.
  5. Colour, transparency and `ScaleTo` all work.
  6. `AssetService:CreateMeshPartAsync(Content.fromUri(id))` rebuilds a mesh in any place from its
     asset id, so each mesh only needs the importer once.
- **Cutscene route (decided):** bake from Blender into a Lua data module, the way Descent Depths
  does it (`descent-depths/blender/tools/bake_v2.py` + `StoryClient/BakedCutscene`).
  - **Conversion:** a Blender position (x, y, z) becomes (x, z, −y) in Roblox. An object rotation R
    becomes C R Cᵀ; a camera's becomes C R.
  - **Eclipse:** its Blender add-on (`eclipse_blender` 1.5.14) is installed and enabled. Blender
    runs a local server on port 49186, and Eclipse's "Blender Import" pairs rigs and cameras and
    receives the baked animation. It's for polishing in Eclipse only; the game doesn't need
    Eclipse's export. RBXMonkey is installed too.
- **Vault cleanup:** a helper fixed the stale "still open" notes (Open Questions, Classic Mode, Next
  Steps, Current State, and five changelogs).

## Phase 1: the sets
- **Source:**
  - `art/pieces/make_sets.py` is a re-runnable Blender script. `make_set("Classic" | "Toon")`,
    `export_set`, `render_set`.
  - Its output: `art/pieces/pieces.blend`, `Classic.fbx`, `Toon.fbx` and two preview PNGs.
  - **Classic (polished Staunton):**
    - pawn, rook, bishop, queen and king are spun profiles;
    - the rook has a hollow top with 6 battlements;
    - the bishop's mitre slit is cut diagonally across its front;
    - the queen has a ring of 8 balls and a top bead;
    - the king's cross faces the players;
    - the knight is a bevelled side silhouette, tapered at the face, with ears, a mane and eye
      dents.
    - About 2.2k–4.8k triangles each. Heights: pawn 1.29, rook 1.55, knight 1.82, bishop 1.86,
      queen 2.05, king 2.25 studs.
  - **Toon:** a thick puck base, round bellies, big heads, a chunky 4-battlement rook, and a
    big-eyed knight. About 1.4k–3k triangles, slightly shorter and wider than Classic.
- **Studio:**
  - `builders/piece_sets.lua` builds `ReplicatedStorage.PieceSets.<Set>.<kind>` (one MeshPart each,
    pivot at the base's underside) from the uploaded asset ids. The ids are listed in the builder.
  - **Run it in every place**, then save. **Built in Chess?? and in the Tournament template**
    (2026-10-19; the piece-set code was pushed there too).
- **Code:**
  - **`Settings.PIECE_SETS`:** Classic (the default), Toon, and Simple (the original part-built
    pieces).
  - **`Pieces.lua`:**
    - `Pieces.build(kind, color, set?)` uses `Pieces.current`;
    - a mesh set clones its MeshPart and colours it from `MESH_LOOK`: Classic ivory and ebony; Toon
      warm cream and deep indigo, so it's obvious at a glance;
    - a missing mesh falls back to Simple;
    - `Pieces.setSet(id)`; `MAX_HEIGHT` is now 2.3.
  - **`Prefs`:** saves `pieceSet`, and the server checks it against the list.
  - **Settings sheet:** a **"Pieces: Classic"** button cycles through the sets. The card is taller,
    and on phones the buttons stack on the right.
  - **`ChessClient.applyPrefs`:** rebuilds every board's pieces when the set changes.
  - **`PieceIcons`:** the 3D fallback for 2D icons stays on Simple, because its outline trick is
    tuned for that set.

## Tested
- **Edit-mode previews:** a middlegame in Classic on T5 and in Toon on T6. Both knights face the
  other side.
- **Playtest:** in a bot game, Settings → Pieces: Classic → Toon changed the board's pieces at once
  (they became MeshParts in the Toon cream). No errors.

**Not checked yet:**
- the cutscenes with mesh pieces (they move and fade models generically, so they should work);
- the Toon set on a phone;
- both places still need saving and publishing by the user.

Stills:
- `stills/2026-10-19d-classic-set.jpg`
- `e-toon-set`
- `f-classic-knights-side`
- `g-classic-blender`, `h-toon-blender`
- `i-settings-piece-set`
- `j-toon-in-game`

Back to [[Home]]
