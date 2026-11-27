--!strict
-- Grounds - which training grounds a base shows and what they look like. Pure.
-- (Plan 13, sections 5.2 and 5.3.)
--
-- One ground opens per rebirth band (config Training.Grounds, in order). A base
-- has two courts (court 1 left, court 2 right) and shows the TWO NEWEST grounds
-- the owner has opened, one on each; in the first band the second court shows
-- the next ground LOCKED, so the first rebirth has something to open.
--
-- Every gear row (Training.Equipment: 19 tiers x 3 levels) belongs to one
-- ground. A ground wears the look of the owner's gear while the gear is one of
-- its own tiers; an older ground stays at its last tier, level III; a newer one
-- the gear has not reached yet shows its first tier, level I.
local Grounds = {}

export type Shown = {
	--- index into Training.Grounds
	ground: number,
	--- the rebirth tier that opens it, when the owner is not there yet
	locked: number?,
}

--- Court (1 left, 2 right) of a ground, from its Side.
function Grounds.court(cfg: any, ground: number): number
	local row = cfg.Training.Grounds[ground]
	return if row and row.Side > 0 then 2 else 1
end

--- The newest ground open at `rebirth` (at least the first).
function Grounds.newest(cfg: any, rebirth: number): number
	local newest = 1
	for g, row in cfg.Training.Grounds do
		if row.Rebirth <= rebirth then
			newest = math.max(newest, g)
		end
	end
	return newest
end

--- What each court shows at `rebirth`: `[court] = { ground, locked }`.
function Grounds.shown(cfg: any, rebirth: number): { Shown }
	local list = cfg.Training.Grounds
	local newest = Grounds.newest(cfg, rebirth)
	local other = if newest > 1 then newest - 1 else math.min(2, #list)
	local shown: { Shown } = {}
	for _, g in { newest, other } do
		local row = list[g]
		shown[Grounds.court(cfg, g)] =
			{ ground = g, locked = if row.Rebirth > rebirth then row.Rebirth else nil }
	end
	return shown
end

--- The first and the last gear tier of a ground.
function Grounds.tiers(cfg: any, ground: number): (number, number)
	local first, last = math.huge, 0
	for _, row in cfg.Training.Equipment do
		if row.Ground == ground then
			first, last = math.min(first, row.Tier), math.max(last, row.Tier)
		end
	end
	return first, last
end

--- The tier and level (1..3) of gear row `gear` (the index a profile stores).
function Grounds.tierOf(cfg: any, gear: number): (number, number)
	local list = cfg.Training.Equipment
	local row = list[math.clamp(gear, 1, #list)]
	return row.Tier, row.Level
end

--- The tier and level a ground is drawn at for an owner on gear row `gear`
--- (0 = an empty base: the ground's first look).
function Grounds.look(cfg: any, ground: number, gear: number): (number, number)
	local first, last = Grounds.tiers(cfg, ground)
	if gear <= 0 then
		return first, 1
	end
	local tier, level = Grounds.tierOf(cfg, gear)
	if tier < first then
		return first, 1
	elseif tier > last then
		return last, 3
	end
	return tier, level
end

--- The template of a ground at a tier: ReplicatedStorage.Assets.Grounds.<this>.
function Grounds.template(cfg: any, ground: number, tier: number): string
	return `Ground_{cfg.Training.Grounds[ground].Id}_T{tier}`
end

--- The model name of a tier (the first gear row of that tier carries it).
function Grounds.tierName(cfg: any, tier: number): string
	for _, row in cfg.Training.Equipment do
		if row.Tier == tier then
			return row.Model
		end
	end
	return ""
end

return Grounds
