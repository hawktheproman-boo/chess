-- The seated camera: looks at your board from your side, either straight down or tilted.
-- It re-asserts itself every frame after Roblox's camera step (something resets CameraType to
-- Custom when you sit, so setting it once isn't enough). Leaving hands the camera back.

local RunService = game:GetService("RunService")

local Ui = require(script.Parent.UiKit)

local CameraRig = {}

local state = nil -- { view, color, tilted, target }
local BIND = "ChessCamera"

local BASE_FOV = 50
local HALF_BOARD = 6.6 -- half the board incl. its frame, in studs
local TILT_ANGLE = math.rad(52) -- tilted view: degrees down from horizontal
local MAX_DISTANCE = 26 -- open sky now; past this the view widens instead of rising
local strip = false -- an Abilities game: the ability panel takes the bottom of a wide screen
local STRIP_SHIFT = 1.5 -- studs the camera aims toward you then, so the board sits higher on screen
local function stripOn()
	return strip and not Ui.compact(workspace.CurrentCamera.ViewportSize) -- (phones put the panel beside the board)
end

-- Camera distance and field of view at which the whole board fits the window, leaving room for the
-- HUD bars (top/bottom) and the side panels. Past MAX_DISTANCE the view widens instead.
local function fit()
	local v = workspace.CurrentCamera.ViewportSize
	local aspect = math.max(v.X, 1) / math.max(v.Y, 1)
	-- half-extent needed vertically (player cards + top bar, and the ability panel on wide screens)
	local needV = HALF_BOARD * (if stripOn() then 1.62 else 1.48)
	local needH = HALF_BOARD * 1.5 / aspect -- (expressed vertically)
	local need = math.max(needV, needH)
	local d = need / math.tan(math.rad(BASE_FOV / 2))
	if d <= MAX_DISTANCE then
		return d, BASE_FOV
	end
	return MAX_DISTANCE, math.min(2 * math.deg(math.atan(need / MAX_DISTANCE)), 85)
end

local function target(view, color, tilted)
	local side = if color == "b" then -1 else 1 -- White sits at +Z
	local c = view.center
	if stripOn() then
		c += Vector3.new(0, 0, STRIP_SHIFT * side) -- aim a little toward you: the board rises on screen
	end
	local d = fit()
	if tilted then
		local d2 = d * 0.92
		local offset = Vector3.new(0, math.sin(TILT_ANGLE) * d2, math.cos(TILT_ANGLE) * d2 * side)
		return CFrame.lookAt(c + offset, c + Vector3.new(0, 0, -0.6 * side))
	end
	-- straight down; "up" on screen points away from you
	return CFrame.lookAt(c + Vector3.new(0, d, 0.001 * side), c, Vector3.new(0, 0, -side))
end

local override = nil -- { cf, fov, time, current }: a cutscene owns the camera
local shake = nil

-- Cutscenes: hold the camera on cf (glide there over `time` seconds); nil hands it back.
function CameraRig.override(cf, fov, time)
	if cf == nil then
		override = nil
		if state then
			state.snap = false -- glide back to the board view
		end
		return
	end
	local current = override and override.current
	override = { cf = cf, fov = fov or 50, time = time, current = current }
end

function CameraRig.shake(amount, length)
	shake = { amount = amount, length = length, untilT = os.clock() + length }
end

local function step(dt)
	local camera = workspace.CurrentCamera
	if not state or not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local shakeOffset = CFrame.new()
	if shake and os.clock() < shake.untilT then
		local m = shake.amount * ((shake.untilT - os.clock()) / shake.length)
		shakeOffset = CFrame.new((math.random() - 0.5) * m, (math.random() - 0.5) * m, 0)
	end
	if override then
		-- a cutscene shot: glide to it (rate from its glide time), then hold
		local rate = if override.time then 3 / override.time else 60
		local a = 1 - math.exp(-dt * rate)
		camera.FieldOfView += (override.fov - camera.FieldOfView) * a
		override.current = (override.current or camera.CFrame):Lerp(override.cf, a)
		camera.CFrame = override.current * shakeOffset
		return
	end
	local _, fov = fit()
	camera.FieldOfView += (fov - camera.FieldOfView) * (1 - math.exp(-dt * 9))
	state.target = target(state.view, state.color, state.tilted) -- follows window resizes
	local alpha = 1 - math.exp(-dt * 9) -- smooth approach, frame-rate independent
	if state.snap then
		camera.CFrame = state.target
	else
		camera.CFrame = camera.CFrame:Lerp(state.target, alpha)
		if (camera.CFrame.Position - state.target.Position).Magnitude < 0.01 then
			state.snap = true
		end
	end
end

-- your own table's lamp would hang in front of the camera: hide it for you only (it still lights)
local function setLamp(view, hidden)
	for _, name in { "Shade", "Bulb", "Cord" } do
		local p = view.model:FindFirstChild(name)
		if p then
			p.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

function CameraRig.enter(view, color, tilted)
	local first = state == nil
	if state and state.view ~= view then
		setLamp(state.view, false)
	end
	setLamp(view, true)
	state = { view = view, color = color, tilted = tilted, target = target(view, color, tilted) }
	if first then
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, step)
	end
end

function CameraRig.setTilted(tilted)
	if state then
		state.tilted = tilted
		state.target = target(state.view, state.color, tilted)
		state.snap = false
	end
end

function CameraRig.setStrip(on: boolean)
	strip = on
end

function CameraRig.isTilted()
	return state ~= nil and state.tilted
end

function CameraRig.exit()
	if not state then
		return
	end
	setLamp(state.view, false)
	state = nil
	RunService:UnbindFromRenderStep(BIND)
	local camera = workspace.CurrentCamera
	camera.FieldOfView = 70
	camera.CameraType = Enum.CameraType.Custom
end

function CameraRig.active()
	return state ~= nil
end

return CameraRig
