--!strict
-- GENERATED FILE - DO NOT EDIT BY HAND.
-- Source: design/animations.json + assets/animations/ids.json (uploaded clip ids)
-- Regenerate: python tools/gen_anim_ids.py
-- id = "" means not uploaded yet: Fx/Motion falls back to the session KeyframeSequence.

export type Clip = { id: string, priority: string, looped: boolean }

local Animations: { Clips: { [string]: Clip }, Emotes: { string } } = {
	Clips = {
		BreathAscend = { id = "rbxassetid://97059147871858", priority = "Action", looped = true },
		CarriedRide = { id = "rbxassetid://129171837155585", priority = "Action", looped = true },
		CarryHold = { id = "rbxassetid://123151573991982", priority = "Action", looped = true },
		CarryShoulder = { id = "rbxassetid://92687348195038", priority = "Action", looped = true },
		Celebrate = { id = "rbxassetid://76710208383938", priority = "Action", looped = false },
		Eat = { id = "rbxassetid://130105520151450", priority = "Action", looped = false },
		HeroArrive = { id = "rbxassetid://79905936733587", priority = "Action", looped = false },
		HeroMenace = { id = "rbxassetid://121112025666488", priority = "Action", looped = false },
		HeroPickUp = { id = "rbxassetid://99290478316788", priority = "Action", looped = false },
		HeroStalk = { id = "rbxassetid://113773708526725", priority = "Movement", looped = true },
		HeroWalkIn = { id = "rbxassetid://84826437664869", priority = "Movement", looped = true },
		HoldHeave = { id = "rbxassetid://103685919511269", priority = "Action", looped = true },
		HoldPitch = { id = "rbxassetid://108958635939226", priority = "Action", looped = true },
		HoldSpin = { id = "rbxassetid://129761511631155", priority = "Action", looped = true },
		IdleBlade = { id = "rbxassetid://81022685656687", priority = "Core", looped = true },
		IdleCheer = { id = "rbxassetid://117438369708402", priority = "Core", looped = true },
		IdleCool = { id = "rbxassetid://125613591649255", priority = "Core", looped = true },
		IdleFloat = { id = "rbxassetid://138797528623443", priority = "Core", looped = true },
		IdleNinja = { id = "rbxassetid://79047369672478", priority = "Core", looped = true },
		IdlePower = { id = "rbxassetid://90410459126519", priority = "Core", looped = true },
		IdleShy = { id = "rbxassetid://77216879621963", priority = "Core", looped = true },
		PlaceHero = { id = "rbxassetid://77773650101040", priority = "Action", looped = false },
		PostFinish = { id = "rbxassetid://112536509537880", priority = "Action", looped = false },
		PostFlurry = { id = "rbxassetid://132319214674778", priority = "Action", looped = true },
		RebirthAwaken = { id = "rbxassetid://128371788611919", priority = "Action", looped = false },
		RebirthEvolve = { id = "rbxassetid://116897390479380", priority = "Action", looped = false },
		RevealLand = { id = "rbxassetid://122474403767673", priority = "Action", looped = false },
		Throw = { id = "rbxassetid://71725881856076", priority = "Action", looped = false },
		ThrowHeave = { id = "rbxassetid://75510375255020", priority = "Action", looped = false },
		ThrowSpin = { id = "rbxassetid://73973272432226", priority = "Action", looped = false },
		TrainBreath = { id = "rbxassetid://116903687681313", priority = "Action", looped = true },
		TrainLift = { id = "rbxassetid://125310741661163", priority = "Action", looped = true },
		TrainMeditate = { id = "rbxassetid://114324040023472", priority = "Action", looped = true },
		TrainPost = { id = "rbxassetid://92792148863787", priority = "Action", looped = true },
		TrainPush = { id = "rbxassetid://80340524340542", priority = "Action", looped = true },
		TrainStrike = { id = "rbxassetid://87578970825099", priority = "Action", looped = true },
	},
	-- Roblox-owned emotes: play in any experience (variety on the pedestals)
	Emotes = {
		"rbxassetid://3333387824",
		"rbxassetid://5915693819",
		"rbxassetid://3334538554",
		"rbxassetid://3344650532",
		"rbxassetid://3334392772",
		"rbxassetid://3338055167",
		"rbxassetid://3344585679",
	},
}

return Animations
