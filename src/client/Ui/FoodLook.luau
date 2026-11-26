--!strict
-- FoodLook - which food the player throws right now, and how a food is drawn.
-- (Plan 13.) One place, so the HUD chip, the throw panel, the shop, the Index
-- and the throw itself never disagree.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Foods = require(ReplicatedStorage.Shared.Core.Foods)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)

local MAPS = Lookup.of(Config)

local FoodLook = {}

-- UNTIL PHASE B OF PLAN 13 (the 51 real models): a food with no template of its
-- own borrows one of the twelve old ones, by its place in the ladder. Once
-- `Assets.Foods.Food_<id>` exists for a food it is used and this is skipped.
local OLD = {
	"onigiri",
	"dango",
	"sushi",
	"spicy_bun",
	"gyoza",
	"ice_cream",
	"takoyaki",
	"ramen",
	"curry",
	"tempura",
	"festival_cake",
	"dragon_feast",
}

local ROLE_COLOR: { [string]: Color3 } = {
	Snack = Color3.fromRGB(240, 200, 120),
	Meal = Color3.fromRGB(110, 200, 255),
	Signature = Color3.fromRGB(255, 201, 60),
}
local ROLE_TILE: { [string]: Color3 } = {
	Snack = Color3.fromHex("F2A541"),
	Meal = Color3.fromHex("2EC4B6"),
	Signature = Color3.fromHex("FFC93C"),
}

local function hasTemplate(key: string): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local foods = assets and assets:FindFirstChild("Foods")
	return foods ~= nil and foods:FindFirstChild(key) ~= nil
end

--- The id whose art a food is drawn with: its own once its model exists.
function FoodLook.artId(foodId: string): string
	if hasTemplate("Food_" .. foodId) then
		return foodId
	end
	local food = MAPS.food[foodId]
	local tier = if food then food.Tier else 1
	return OLD[(tier - 1) % #OLD + 1]
end

--- The template name in ReplicatedStorage.Assets.Foods.
function FoodLook.modelKey(foodId: string): string
	return "Food_" .. FoodLook.artId(foodId)
end

--- The icon key (Config/Icons): the food's own icon once it is uploaded.
function FoodLook.iconKey(foodId: string): string
	local own = "Food_" .. foodId
	if (Icons :: any)[own] then
		return own
	end
	return "Food_" .. FoodLook.artId(foodId)
end

--- A food's colour in the world (trail, glow) and on a card tile: by its role.
function FoodLook.color(food: any?): Color3
	return (food and ROLE_COLOR[food.Role]) or Color3.new(1, 1, 1)
end

function FoodLook.tile(food: any?): Color3
	return (food and ROLE_TILE[food.Role]) or Color3.new(1, 1, 1)
end

--- The zone the player's next throw goes to: the aim, or as far as Power reaches.
function FoodLook.targetZone(state: any): number
	local reach = Throw.reach(Config.Zones, state.power or 0, state.rebirth or 0)
	local aim = state.aim or 0
	if aim >= 1 and aim < reach then
		return aim
	end
	return reach
end

--- The food the next throw uses (auto-pick or the pinned one) and its zone.
function FoodLook.current(state: any, zoneIndex: number?): (any?, number)
	local zone = zoneIndex or FoodLook.targetZone(state)
	return Foods.forThrow(Config, MAPS.food, state, zone), zone
end

--- That food's Luck in that zone (x1 when there is none).
function FoodLook.luck(state: any, zoneIndex: number?): number
	local food, zone = FoodLook.current(state, zoneIndex)
	return if food then Foods.luckAt(Config, food, zone) else 1
end

return FoodLook
