--!strict
-- AuraDensity - how thick a hero's aura runs for the player's graphics quality.
--
-- WHY: Roblox draws only a SHARE of a ParticleEmitter's Rate, by graphics quality, and switches bloom
-- on near the top. Measured 2026-11-26 (a ruler of particles in Studio, engine levels 1, 5, 10, 15, 21):
-- about 0.15, 0.35, 0.5, 0.75 and 1 of the rate. Studio's edit view, where the owner judges every aura,
-- runs near 0.4. So an aura that reads well there can be drawn two and a half times as thick for a
-- player at maximum graphics: the additive ones add up to white and hide the hero (Gojo's blue sphere
-- was a white ball in the game).
--
-- THE RULE: an aura marked "hot" (design/auras.json, found by tools/aura_judge.py at maximum graphics)
-- carries the share of its rate it may be DRAWN at. The game thins its emitters just enough that the
-- engine's own share times ours never passes that mark; below it nothing changes, the engine has
-- thinned it already.

local AuraDensity = {}

--- The share of an emitter's rate the engine draws at each of the ten graphics bars of the Roblox menu.
AuraDensity.Drawn = { 0.15, 0.25, 0.35, 0.45, 0.5, 0.6, 0.7, 0.8, 0.9, 1 }

--- The bars to assume when the player's graphics are on Automatic (the game cannot read what the
--- engine picked): a desktop or console mostly sits at the top, a phone near the middle.
AuraDensity.AutomaticBars = { desktop = 10, phone = 4 }

--- The engine's share at `bars` (1..10; anything else counts as the top).
function AuraDensity.drawn(bars: number): number
	local row = AuraDensity.Drawn[math.floor(bars)]
	return row or 1
end

--- The factor for an aura's emitter rates at `bars`. `mark` is the share the aura may be drawn at
--- (nil or 1 and up: the aura is never thinned).
function AuraDensity.rate(mark: number?, bars: number): number
	if not mark or mark >= 1 or mark <= 0 then
		return 1
	end
	return math.min(1, mark / AuraDensity.drawn(bars))
end

return AuraDensity
