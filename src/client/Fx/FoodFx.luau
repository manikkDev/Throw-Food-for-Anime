--!strict
-- FoodFx - how a food FEELS when it is thrown (plan 13 phase C): which clip
-- throws it, which effect trails it, which effect and sound it lands with,
-- which aroma hangs over it while the hero walks in. One place, so the
-- thrower's cinematic and the other players' view never disagree.
--
--   Snack      ThrowTrail_Basic (the dish's colour)   Land_Impact
--   Meal       ThrowTrail_Meal  (the dish's colour)   Land_Meal + Aroma_Meal
--   Signature  Sig_<id>_Trail   (its own effect)      Sig_<id>_Land + Aroma_Signature,
--                                                     a sting and its own accent sound
--
-- Names only: Fx/Vfx plays them and falls back or stays silent when a template
-- or a sound is missing, so nothing here can break a throw.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local FoodFeel = require(ReplicatedStorage.Shared.Config.FoodFeel)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)

local MAPS = Lookup.of(Config)

export type Clips = {
	--- The loop played while the player stands on the throw spot with the food.
	hold: string,
	--- The throw itself (its "Release" marker lets the food go).
	throw: string,
	--- Seconds into `throw` (at speed 1) of the release, if the marker never comes.
	releaseAt: number,
	--- The whoosh on release.
	sound: string,
}

local FoodFx = {}

local WHITE = Color3.new(1, 1, 1)

-- by throw class (design/foods.json `throw`); the clips are assets/animations (batch r7)
local CLIPS: { [string]: Clips } = {
	pitch = { hold = "HoldPitch", throw = "Throw", releaseAt = 0.7667, sound = "throw_whoosh" },
	heave = { hold = "HoldHeave", throw = "ThrowHeave", releaseAt = 0.7667, sound = "throw_heave" },
	spin = { hold = "HoldSpin", throw = "ThrowSpin", releaseAt = 0.7, sound = "throw_spin" },
}

local function roleOf(foodId: string): string
	local food = MAPS.food[foodId]
	return if food then food.Role else "Snack"
end

--- "pitch" (one hand), "heave" (two hands, kept level) or "spin" (side-arm flick).
function FoodFx.throwClass(foodId: string): string
	local feel = FoodFeel[foodId]
	return if feel and CLIPS[feel.throw] then feel.throw else "pitch"
end

function FoodFx.clips(foodId: string): Clips
	return CLIPS[FoodFx.throwClass(foodId)]
end

--- The dish's own colour (from its icon): tints the Snack and Meal trail, the
--- Meal landing and the aroma.
function FoodFx.color(foodId: string): Color3
	local feel = FoodFeel[foodId]
	if feel then
		local ok, color = pcall(Color3.fromHex, feel.color)
		if ok then
			return color
		end
	end
	return WHITE
end

--- The flight effect and its tint (nil = the effect carries its own colours).
function FoodFx.trail(foodId: string): (string, Color3?)
	local role = roleOf(foodId)
	if role == "Signature" then
		return `Sig_{foodId}_Trail`, nil
	elseif role == "Meal" then
		return "ThrowTrail_Meal", FoodFx.color(foodId)
	end
	return "ThrowTrail_Basic", FoodFx.color(foodId)
end

--- The landing effect and its tint.
function FoodFx.landing(foodId: string): (string, Color3?)
	local role = roleOf(foodId)
	if role == "Signature" then
		return `Sig_{foodId}_Land`, nil
	elseif role == "Meal" then
		return "Land_Meal", FoodFx.color(foodId)
	end
	return "Land_Impact", nil
end

--- The loop over the resting dish until it is picked up (nil for a Snack).
function FoodFx.aroma(foodId: string): (string?, Color3?)
	local role = roleOf(foodId)
	if role == "Signature" then
		return "Aroma_Signature", FoodFx.color(foodId)
	elseif role == "Meal" then
		return "Aroma_Meal", FoodFx.color(foodId)
	end
	return nil, nil
end

--- The sounds of the landing, in the order they are played: what the dish is
--- made of, then (Signature) the sting and the dish's own accent.
function FoodFx.landSounds(foodId: string): { string }
	local feel = FoodFeel[foodId]
	local sounds = { if feel then `land_{feel.land}` else "food_land" }
	if roleOf(foodId) == "Signature" then
		table.insert(sounds, "sig_sting")
		if feel and feel.accent then
			table.insert(sounds, `sig_{feel.accent}`)
		end
	end
	return sounds
end

--- How hard the landing shakes the camera and how big the rock-and-crack
--- impact under it is: a rice ball does not crater the lane like a feast does.
function FoodFx.weight(foodId: string): number
	local role = roleOf(foodId)
	local base = if role == "Signature" then 1 elseif role == "Meal" then 0.75 else 0.5
	if FoodFx.throwClass(foodId) == "heave" then
		base += 0.15
	end
	return base
end

return FoodFx
