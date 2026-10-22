-- Game-wide settings shared by server and client (the lobby UI lists these).

local Settings = {}

Settings.MODES = { "Classic", "Abilities" } -- module names under Shared/Modes
Settings.SNIPE_CUTSCENE = 10.5 -- seconds the opponent's clock pauses while the snipe cutscene plays
-- every ability's cutscene length (the server holds the opponent's clock that long)
Settings.CUTSCENES = { BishopSnipe = 10.5, KnightJump = 8.5, RookRam = 8.0, KingEscape = 7.5, PawnPassant = 7.5,
	StealPiece = 8.0 }
function Settings.cutscene(id: string?): number
	return Settings.CUTSCENES[id or ""] or Settings.SNIPE_CUTSCENE
end

Settings.CLOCKS = {
	{ id = "none", label = "No clock" },
	{ id = "10+0", label = "10 min", base = 600, increment = 0 },
	{ id = "5+3", label = "5 min + 3 s", base = 300, increment = 3 },
	{ id = "3+2", label = "3 min + 2 s", base = 180, increment = 2 },
}
Settings.DEFAULT_CLOCK = "10+0"

-- 3D piece sets (each player picks theirs in Settings; it only changes what they see).
-- Classic and Toon are Blender meshes (art/pieces/make_sets.py, ReplicatedStorage.PieceSets, built
-- by builders/piece_sets.lua); Simple is the original part-built set (Pieces.lua), also the fallback.
Settings.PIECE_SETS = {
	{ id = "Classic", name = "Classic" },
	{ id = "Toon", name = "Toon" },
	{ id = "Simple", name = "Simple" },
}
Settings.DEFAULT_PIECE_SET = "Classic"
function Settings.pieceSet(id: string?)
	for _, s in Settings.PIECE_SETS do
		if s.id == id then
			return s
		end
	end
	return nil
end

Settings.STEAL_PRODUCT = 3719153067 -- developer product: one Steal a Piece (50 Robux), used in a game
Settings.STEAL_ROBUX = 50 -- shown until the product's real price loads
Settings.VIP_PASS = 2037495121 -- gamepass: detailed stats, saved game reviews (and later the tournament)
Settings.MAX_SAVED_GAMES = 25 -- reviewed games kept per VIP, newest first
Settings.TABLE_COUNT = 8 -- table ids "T1".."T8" (builders/build_room.lua); a tournament round of 16 needs 8
Settings.DISCONNECT_GRACE = 60 -- seconds a disconnected player has to come back before forfeiting
Settings.START_PLACE_ID = 93046632926618 -- the lobby; any other place running this code is a tournament server
-- Tournaments (Shared/Tournament): the place every tournament place is copied from with
-- AssetService:CreatePlaceAsync. A separate place in this experience with copying turned on, holding
-- the same code (so the lobby itself stays copy-locked). 0 = not set up: tournaments can't launch.
Settings.TOURNAMENT_TEMPLATE_ID = 15361839010 -- the "Tournament" place (copying on), added by the user 2026-10-18
Settings.FIRST_MOVE_LIMIT = 30 -- tournament games: seconds each player has for their first move

function Settings.clock(id: string)
	for _, c in Settings.CLOCKS do
		if c.id == id then
			return c
		end
	end
	return nil
end

function Settings.hasMode(id: string): boolean
	return table.find(Settings.MODES, id) ~= nil
end

return Settings
