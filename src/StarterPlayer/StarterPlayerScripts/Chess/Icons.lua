-- The Illustrator icon set and Play-card art, drawn without uploaded images: IconArt.lua holds each
-- sheet as a palette + zstd-compressed pixel indices, decoded once (EncodingService) into an
-- EditableImage atlas. Labels show one cell through ImageRectOffset / ImageRectSize.
-- A published game only allows EditableImage when the owner is ID-verified and "Allow Mesh &
-- Image APIs" is on. If it isn't allowed, Icons.ok() is false and UiKit keeps the emoji.
--
--   Icons.ok() -> boolean                        are image icons available here?
--   Icons.has(name) -> boolean
--   Icons.set(imageLabel, name) -> boolean       point an ImageLabel at an icon
--   Icons.new(name, size?) -> ImageLabel?        a fresh transparent ImageLabel (nil if unavailable)
--   Icons.card(imageLabel, mode) -> boolean      Play-card art: bot / Classic / Abilities / Tournament

local AssetService = game:GetService("AssetService")

local IconArt = require(script.Parent.IconArt)

local Icons = {}

local images = {}
local failed = false

local function decode(sheet)
	local EncodingService = game:GetService("EncodingService")
	local pal = EncodingService:Base64Decode(buffer.fromstring(sheet.palette))
	local packed = EncodingService:Base64Decode(buffer.fromstring(sheet.data))
	local idx = EncodingService:DecompressBuffer(packed, Enum.CompressionAlgorithm.Zstd)
	local n = sheet.w * sheet.h
	local px = buffer.create(n * 4)
	for i = 0, n - 1 do
		buffer.writeu32(px, i * 4, buffer.readu32(pal, buffer.readu8(idx, i) * 4))
	end
	local size = Vector2.new(sheet.w, sheet.h)
	local img = AssetService:CreateEditableImage({ Size = size })
	img:WritePixelsBuffer(Vector2.zero, size, px)
	return img
end

local function sheetImage(key)
	if failed then
		return nil
	end
	if not images[key] then
		local ok, img = pcall(decode, IconArt[key])
		if not ok or not img then
			failed = true
			warn("[Icons] image icons unavailable, using emoji:", img)
			return nil
		end
		images[key] = { image = img, content = Content.fromObject(img) }
	end
	return images[key]
end

function Icons.ok(): boolean
	return sheetImage("icons") ~= nil
end

function Icons.has(name: string?): boolean
	return name ~= nil and IconArt.icons.cells[name] ~= nil and Icons.ok()
end

local function point(label, key, cellIndex)
	local s = sheetImage(key)
	if not s or not cellIndex then
		return false
	end
	local sheet = IconArt[key]
	label.ImageContent = s.content
	label.ImageRectOffset = Vector2.new(cellIndex % sheet.cols * sheet.cell, cellIndex // sheet.cols * sheet.cell)
	label.ImageRectSize = Vector2.new(sheet.cell, sheet.cell)
	label.ScaleType = Enum.ScaleType.Fit
	return true
end

function Icons.set(label: ImageLabel, name: string): boolean
	return point(label, "icons", IconArt.icons.cells[name])
end

function Icons.card(label: ImageLabel, mode: string): boolean
	return point(label, "cards", IconArt.cards.cells[mode])
end

function Icons.new(name: string, size: number?): ImageLabel?
	if not Icons.has(name) then
		return nil
	end
	local l = Instance.new("ImageLabel")
	l.Name = "IconImg"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromOffset(size or 32, size or 32)
	Icons.set(l, name)
	return l
end

return Icons
