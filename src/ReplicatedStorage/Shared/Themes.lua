-- Board colour themes. Each player picks one in Settings; it recolours every board they see (the
-- 3D tables and the 2D board) on their own screen only. Saved per player (server Prefs).
--   light / dark: the squares   frame: the raised 3D border   frame2D: the 2D board's border

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Themes = {
	{ id = "green", name = "Classic Green", light = rgb(238, 238, 210), dark = rgb(118, 150, 86), frame = rgb(70, 104, 56), frame2D = rgb(52, 92, 40) },
	{ id = "walnut", name = "Walnut", light = rgb(240, 217, 181), dark = rgb(181, 136, 99), frame = rgb(120, 82, 52), frame2D = rgb(98, 66, 42) },
	{ id = "ocean", name = "Ocean", light = rgb(234, 240, 246), dark = rgb(112, 150, 186), frame = rgb(60, 92, 128), frame2D = rgb(46, 74, 106) },
	{ id = "candy", name = "Candy", light = rgb(252, 232, 238), dark = rgb(232, 136, 166), frame = rgb(186, 84, 120), frame2D = rgb(160, 66, 100) },
	{ id = "slate", name = "Slate", light = rgb(222, 226, 232), dark = rgb(120, 128, 146), frame = rgb(70, 76, 92), frame2D = rgb(56, 62, 76) },
	{ id = "sunset", name = "Sunset", light = rgb(255, 236, 200), dark = rgb(232, 140, 92), frame = rgb(176, 86, 50), frame2D = rgb(150, 70, 40) },
}

Themes.DEFAULT = "green"

function Themes.get(id: string?)
	for _, t in ipairs(Themes) do
		if t.id == id then
			return t
		end
	end
	return Themes[1]
end

return Themes
