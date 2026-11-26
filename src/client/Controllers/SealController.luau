--!strict
-- SealController - the SEALED GATE this player sees on the lane (plan 12, section 5).
--
-- A zone whose RebirthReq the player has not earned is sealed. The lane is one
-- for all five players and each has their own rebirth, and the first sealed
-- gate stands past the streaming radius from the throw stage, so the seal is
-- not part of the map: this client clones ReplicatedStorage.Assets.World.ZoneSeal
-- (tools/studio/zone_seal.luau) onto the FIRST gate it cannot pass, and moves
-- it to the next band when the player rebirths. A local model is not streamed,
-- so it shows from any distance.
--
-- Nothing here can error into gameplay: a missing template only means no seal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)

local W = Config.World
-- a zone's torii stands this far into its zone (tools/studio/zone_gates.luau)
local GATE_INTO_ZONE = 45.4
-- the lane floor's top, under a gate (the floor kit sits a little above LaneY)
local FLOOR_ABOVE_LANE = 0.4

local SealController = Knit.CreateController({
	Name = "SealController",
	_zone = 0,
	_model = nil :: Model?,
})

-- world Z of zone `index`'s gate
local function gateZ(index: number): number
	local z = W.LaneStartZ
	for i = 1, index - 1 do
		z += Config.Zones[i].LengthStuds
	end
	return z + GATE_INTO_ZONE
end

function SealController:_clear()
	local model = self._model
	if model then
		self._model = nil
		model:Destroy()
	end
	self._zone = 0
end

-- put the seal on zone `index`'s gate (0 = the whole lane is open: no seal)
function SealController:_show(index: number)
	if index == self._zone then
		return
	end
	self:_clear()
	if index <= 0 then
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local world = assets and assets:FindFirstChild("World")
	local template = world and world:FindFirstChild("ZoneSeal")
	if not template or not template:IsA("Model") then
		return
	end
	local zone = Config.Zones[index]
	local model = template:Clone()
	model.Name = "ZoneSeal_" .. zone.Id
	model:PivotTo(CFrame.new(0, W.LaneY + FLOOR_ABOVE_LANE, gateZ(index)))
	local text = model:FindFirstChild("SealText", true)
	if text and text:IsA("TextLabel") then
		text.Text = `REBIRTH {zone.RebirthReq} TO ENTER`
	end
	model.Parent = workspace
	self._model = model
	self._zone = index
end

function SealController:KnitStart()
	local state = Knit.GetController("StateController")
	state:Observe(function(snapshot: any)
		local ok, err = pcall(function()
			local open = Throw.openZones(Config.Zones, snapshot.rebirth or 0)
			self:_show(if open < #Config.Zones then open + 1 else 0)
		end)
		if not ok then
			warn("[SealController]", err)
		end
	end)
end

return SealController
