-- PGN export. Classic games are standard PGN (they import into chess.com, lichess and any chess
-- program). Abilities games use a small dialect: a Variant "Abilities" header, and each ability
-- written as a null move "--" with the ability in a comment, e.g. -- {Bishop Snipe: Bc1 snipe NE x3},
-- so the move numbering stays right; other programs can't replay those games.
--
--   Pgn.build({ startFen, moves = { { san, ability = bool } }, mode, white, black, result,
--               clock = Settings clock entry?, date = "YYYY.MM.DD"? })

local Notation = require(script.Parent.Notation)

local Pgn = {}

local ABILITY_NAMES = { BishopSnipe = "Bishop Snipe", KnightJump = "Double Jump", RookRam = "Battering Ram",
	QueenSwap = "Swap", KingEscape = "Royal Escape", PawnPassant = "Any Passant" }

-- game.result { winner, reason } -> "1-0" / "0-1" / "1/2-1/2" / "*"
function Pgn.resultToken(result)
	if not result then
		return "*"
	elseif result.reason == "aborted" then
		return "*"
	elseif result.winner == "w" then
		return "1-0"
	elseif result.winner == "b" then
		return "0-1"
	end
	return "1/2-1/2"
end

local function escape(s)
	s = tostring(s or "?")
	return (string.gsub(string.gsub(s, "\\", "\\\\"), "\"", "\\\""))
end

-- the moves of a finished (or running) game, read from its history
function Pgn.movesFrom(game)
	local out = {}
	for _, h in game.history do
		local ability = h.action.kind == "ability"
		table.insert(out, { san = h.san, ability = ability, id = ability and h.action.id or nil })
	end
	return out
end

function Pgn.build(rec)
	local startFen = rec.startFen or Notation.START
	local result = Pgn.resultToken(rec.result)
	local headers = {
		{ "Event", "Roblox Chess (" .. (rec.mode or "Classic") .. ")" },
		{ "Site", "Roblox" },
		{ "Date", rec.date or os.date("!%Y.%m.%d") },
		{ "Round", "-" },
		{ "White", rec.white or "?" },
		{ "Black", rec.black or "?" },
		{ "Result", result },
	}
	if rec.mode and rec.mode ~= "Classic" then
		table.insert(headers, { "Variant", rec.mode })
	end
	if rec.clock and rec.clock.base then
		table.insert(headers, { "TimeControl", rec.clock.base .. "+" .. (rec.clock.increment or 0) })
	end
	if rec.result and rec.result.reason then
		table.insert(headers, { "Termination", rec.result.reason })
	end
	if startFen ~= Notation.START then
		table.insert(headers, { "SetUp", "1" })
		table.insert(headers, { "FEN", startFen })
	end

	local lines = {}
	for _, h in headers do
		table.insert(lines, string.format("[%s \"%s\"]", h[1], escape(h[2])))
	end
	table.insert(lines, "")

	-- movetext: numbers before White's moves (and "N..." when Black moves first), wrapped at 80
	local fields = string.split(startFen, " ")
	local turn = fields[2] or "w"
	local number = tonumber(fields[6]) or 1
	local tokens = {}
	for i, m in rec.moves or {} do
		if turn == "w" then
			table.insert(tokens, number .. ".")
		elseif i == 1 then
			table.insert(tokens, number .. "...")
		end
		if m.ability then
			local name = ABILITY_NAMES[m.id] or m.id or "Ability"
			table.insert(tokens, "--")
			table.insert(tokens, "{" .. name .. ": " .. m.san .. "}")
		else
			table.insert(tokens, m.san)
		end
		if turn == "b" then
			number += 1
		end
		turn = if turn == "w" then "b" else "w"
	end
	table.insert(tokens, result)

	local line = ""
	for _, t in tokens do
		if #line > 0 and #line + 1 + #t > 80 then
			table.insert(lines, line)
			line = t
		else
			line = if #line > 0 then line .. " " .. t else t
		end
	end
	table.insert(lines, line)
	return table.concat(lines, "\n") .. "\n"
end

return Pgn
