-- Run after every builder: python tools/run_luau.py builders/check_zfighting.lua
-- Flags pairs of block parts whose boxes overlap AND share a face plane (z-fighting).
-- Parts that only touch are fine. (Adapted from Descent Depths.)
local root = workspace:FindFirstChild("Lobby")
if not root then
	return "no workspace.Lobby"
end
local parts = {}
for _, p in root:GetDescendants() do
	if p:IsA("BasePart") and (not p:IsA("Part") or p.Shape == Enum.PartType.Block) and p.Transparency < 1 then
		local _, _, _, r00, r01, r02, r10, r11, r12 = p.CFrame:GetComponents()
		local axisAligned = math.abs(r00) > 0.999 or math.abs(r01) > 0.999 or math.abs(r02) > 0.999
		axisAligned = axisAligned and (math.abs(r11) > 0.999 or math.abs(r10) > 0.999 or math.abs(r12) > 0.999)
		if axisAligned then
			local size = p.CFrame:VectorToWorldSpace(p.Size)
			size = Vector3.new(math.abs(size.X), math.abs(size.Y), math.abs(size.Z))
			table.insert(parts, { p = p, min = p.Position - size / 2, max = p.Position + size / 2 })
		end
	end
end
local eps = 0.002
local out = {}
for i = 1, #parts do
	for j = i + 1, #parts do
		local a, b = parts[i], parts[j]
		local overlap = true
		for _, ax in { "X", "Y", "Z" } do
			if a.min[ax] >= b.max[ax] - eps or b.min[ax] >= a.max[ax] - eps then
				overlap = false
			end
		end
		if overlap then
			for _, ax in { "X", "Y", "Z" } do
				for _, fa in { a.min[ax], a.max[ax] } do
					for _, fb in { b.min[ax], b.max[ax] } do
						if math.abs(fa - fb) < eps then
							table.insert(out, ("%s / %s  (%s=%.2f)"):format(a.p:GetFullName(), b.p:GetFullName(), ax, fa))
						end
					end
				end
			end
		end
	end
end
return #parts .. " block parts, " .. #out .. " coplanar overlaps\n" .. table.concat(out, "\n", 1, math.min(#out, 60))
