-- Flat piece icons for the 2D board and the promotion picker.
-- First choice: the Illustrator piece set (art/ui), drawn from pixel data in PieceArt.lua with an
-- EditableImage, so no uploaded images are needed. A published game only allows EditableImage when
-- the owner is ID-verified and "Allow Mesh & Image APIs" is on; if it isn't allowed, the fallback
-- renders the 3D piece models: a ViewportFrame looks at the piece from the side through a very
-- narrow lens (almost orthographic), with flat lighting and a dark, slightly larger copy behind it
-- as an outline.
--
--   PieceIcons.new(kind, color) -> ImageLabel | ViewportFrame (transparent background, size it yourself)

local AssetService = game:GetService("AssetService")

local Pieces = require(script.Parent.Pieces)
local PieceArt = require(script.Parent.PieceArt)

local PieceIcons = {}

-- base64 -> bytes
local B64 = {}
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, 64 do
		B64[string.byte(alphabet, i)] = i - 1
	end
end
local function unbase64(s: string): buffer
	local n = #s
	local pad = (if string.sub(s, -2) == "==" then 2 elseif string.sub(s, -1) == "=" then 1 else 0)
	local out = buffer.create(n // 4 * 3 - pad)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local v = B64[a] * 262144 + B64[b] * 4096 + (B64[c] or 0) * 64 + (B64[d] or 0)
		buffer.writeu8(out, o, v // 65536)
		if o + 1 < buffer.len(out) then
			buffer.writeu8(out, o + 1, v // 256 % 256)
		end
		if o + 2 < buffer.len(out) then
			buffer.writeu8(out, o + 2, v % 256)
		end
		o += 3
	end
	return out
end

-- one EditableImage per piece, shared by every icon of it; after one failure, all icons use the 3D render
local images = {}
local imagesAllowed = true
local function artImage(key)
	if not imagesAllowed or not PieceArt.data[key] then
		return nil
	end
	if images[key] then
		return images[key]
	end
	local ok, img = pcall(function()
		local size = PieceArt.size
		local rle = unbase64(PieceArt.data[key])
		local pixels = buffer.create(size * size * 4)
		local o = 0
		for i = 0, buffer.len(rle) - 1, 5 do
			local count = buffer.readu8(rle, i)
			local rgba = buffer.readu32(rle, i + 1)
			for _ = 1, count do
				buffer.writeu32(pixels, o, rgba)
				o += 4
			end
		end
		local image = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
		image:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), pixels)
		return image
	end)
	if not ok or not img then
		imagesAllowed = false -- not allowed here: every icon falls back to the 3D render
		warn("[PieceIcons] 2D piece art unavailable, using the 3D icons:", img)
		return nil
	end
	images[key] = img
	return img
end

local OUTLINE = Color3.fromRGB(38, 38, 38)
local FOV = 9
local VIEW_HEIGHT = 2.5 -- studs visible top to bottom: a king fills most of the square
local CENTER_Y = 1.12 -- every piece shares one baseline, like a printed set
local DISTANCE = (VIEW_HEIGHT / 2) / math.tan(math.rad(FOV / 2))

local templates = {}

local function paint(model, color)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0
		end
	end
end

local function build(kind, color)
	local frame = Instance.new("ViewportFrame")
	frame.Name = "Piece"
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(205, 205, 205)
	frame.LightColor = Color3.fromRGB(255, 255, 255)
	frame.LightDirection = Vector3.new(1, -0.8, 0.35) -- from the viewer's side, slightly above

	local piece = Pieces.build(kind, color, "Simple") -- (the outline trick is tuned for the part-built set)
	piece:PivotTo(CFrame.new()) -- 2D icons all face the same way (knights look left)
	piece.Parent = frame

	-- outline: four dark copies just behind the piece, nudged up / down / left / right on screen
	-- (screen axes are world Y and Z here), so an even dark rim shows all the way round
	local push, t = 1.2, 0.07
	local grow = (DISTANCE + push) / DISTANCE -- undo the shrink from sitting further away
	for _, o in { Vector3.new(0, t, 0), Vector3.new(0, -t, 0), Vector3.new(0, 0, t), Vector3.new(0, 0, -t) } do
		local outline = Pieces.build(kind, color, "Simple")
		paint(outline, OUTLINE)
		outline:ScaleTo(outline:GetScale() * grow)
		outline:PivotTo(CFrame.new(Vector3.new(push, -CENTER_Y * (grow - 1), 0) + o))
		outline.Parent = frame
	end

	local cam = Instance.new("Camera")
	cam.FieldOfView = FOV
	-- from -X looking +X: the piece's -Z (a knight's nose) points left on screen
	cam.CFrame = CFrame.lookAt(Vector3.new(-DISTANCE, CENTER_Y, 0), Vector3.new(0, CENTER_Y, 0))
	cam.Parent = frame
	frame.CurrentCamera = cam
	return frame
end

function PieceIcons.new(kind: string, color: string): GuiObject
	local img = artImage(color .. kind)
	if img then
		local l = Instance.new("ImageLabel")
		l.Name = "Piece"
		l.BackgroundTransparency = 1
		l.ImageContent = Content.fromObject(img)
		l.ScaleType = Enum.ScaleType.Fit
		return l
	end
	local key = kind .. color
	if not templates[key] then
		templates[key] = build(kind, color)
	end
	local f = templates[key]:Clone()
	f.CurrentCamera = f:FindFirstChildOfClass("Camera")
	return f
end

return PieceIcons
