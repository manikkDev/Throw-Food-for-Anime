--!strict
-- GroundLook - how a piece of training gear is shown in a dialog or a reward card (plan 13
-- phase D). Gear is no longer a model of its own: a gear row is a tier and a level of a training
-- GROUND, whose set piece stands on a court (Core/Grounds). For a card, the place keeps a small
-- display model per tier next to the set pieces:
--   ReplicatedStorage.Assets.Grounds.Show_<ground id>_T<tier>
-- (tools/studio/grounds/build_grounds.luau: the post alone, the falls and their stone).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Grounds = require(ReplicatedStorage.Shared.Core.Grounds)

local GroundLook = {}

--- The ground (row of Training.Grounds) gear row `gear` belongs to, and its index.
function GroundLook.groundOf(gear: number): (any?, number?)
	local row = Config.Training.Equipment[gear]
	if not row then
		return nil, nil
	end
	return Config.Training.Grounds[row.Ground], row.Ground
end

--- The display model of gear row `gear`, or nil when the place has none.
function GroundLook.display(gear: number): Model?
	local row = Config.Training.Equipment[gear]
	local ground = row and Config.Training.Grounds[row.Ground]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Grounds")
	if not row or not ground or not folder then
		return nil
	end
	local found = folder:FindFirstChild(`Show_{ground.Id}_T{row.Tier}`)
	return if found and found:IsA("Model") then found else nil
end

--- The court (1 left, 2 right) that shows the ground of gear row `gear` for a player at
--- `rebirth`, or nil when that ground is not on the base now.
function GroundLook.courtOf(gear: number, rebirth: number): number?
	local row = Config.Training.Equipment[gear]
	if not row then
		return nil
	end
	for court, shown in Grounds.shown(Config, rebirth) do
		if shown.ground == row.Ground then
			return court
		end
	end
	return nil
end

--- "TIER 2  LEVEL III" for a card's tag.
function GroundLook.tag(gear: number): string
	local row = Config.Training.Equipment[gear]
	if not row then
		return ""
	end
	return `TIER {row.Tier}  LEVEL {string.rep("I", row.Level)}`
end

return GroundLook
