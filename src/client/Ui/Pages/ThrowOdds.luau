--!strict
-- ThrowOdds - the live odds of the next throw (plan 12, section 3.5).
--
-- Every number here comes from the same pure rules the server rolls with
-- (Core/Roll, Core/Luck) at the luck the player holds RIGHT NOW, for the zone
-- they aim at. Roblox requires that anything a paid luck boost can change is
-- shown as a percentage and follows the boost while it is on: an armed Lucky
-- Throw and Server Luck both move this table as they are switched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Roll = require(ReplicatedStorage.Shared.Core.Roll)
local Screens = require(script.Parent.Parent.Screens)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Types)

local MAPS = Lookup.of(Config)
local T = Config.Throw

local ThrowOdds = { name = "ThrowOdds" } :: Types.Page

local gui: ScreenGui
local rows: Screens.RowSet

type Line = { name: string, percent: string, oneIn: string, color: Color3?, header: boolean }

-- rarest first, as the roll checks them
local RARITIES: { string } = {}
for name in Config.Rarities do
	table.insert(RARITIES, name)
end
table.sort(RARITIES, function(a, b)
	return Config.Rarities[a].Order > Config.Rarities[b].Order
end)

local function chance(p: number): (string, string)
	if p <= 0 then
		return "0%", ""
	end
	return Format.percent(p), Format.oneIn(1 / p)
end

function ThrowOdds.render(state: any)
	local throw = Knit.GetController("ThrowController") :: any
	local hud = Knit.GetController("HudController") :: any
	local zoneIndex: number = throw:AimZone()
	local lucky: boolean = throw:LuckyArmed()
	local zone = Config.Zones[zoneIndex]
	local zoneCharacters = MAPS.zoneCharacters[zone.Id]
	local luck: number, breakdown: { any } = hud:CurrentLuck()
	local floor: string? = nil
	if lucky then
		luck = math.min(Config.Luck.Max, luck * T.LuckyThrowLuck)
		floor = T.LuckyFloor
	end

	Screens.label(gui, "OddsZone").Text = zone.Name
	Screens.label(gui, "OddsLuck").Text = `Your luck {Format.mult(luck)}`
	Screens.label(gui, "OddsNote").Text = if lucky
		then `LUCKY THROW armed: x{T.LuckyThrowLuck} luck, never below {T.LuckyFloor}`
		elseif
			state.luckyThrows and state.luckyThrows > 0
		then `A Lucky Throw: x{T.LuckyThrowLuck} luck, never below {T.LuckyFloor}`
		else "Luck divides every 1 in N. Deeper throws and better food add luck."

	local lines: { Line } = {}
	local function header(text: string)
		table.insert(lines, { name = text, percent = "", oneIn = "", header = true })
	end
	header("HEROES IN THIS ZONE")
	local chances = Roll.rarityChances(Config, zoneCharacters, luck, floor)
	for _, name in RARITIES do
		local p = chances[name]
		if p ~= nil then
			local percent, oneIn = chance(p)
			table.insert(lines, {
				name = name,
				percent = percent,
				oneIn = oneIn,
				color = Theme.rarity(name),
				header = false,
			})
		end
	end
	-- mutations and sizes: bands of one roll each, rarest first (Roll.variant)
	for _, group in
		{
			{ title = "MUTATIONS", table = Config.Mutations, mult = state.mutationMult or 1 },
			{ title = "SIZES", table = Config.Sizes, mult = 1 },
		}
	do
		header(group.title)
		local acc = 0
		for _, variant in group.table do
			local scale = 1 + (math.max(1, luck) - 1) * (variant.LuckScale or 0)
			local p = math.clamp(variant.Chance * scale * group.mult, 0, 1 - acc)
			acc += p
			local percent, oneIn = chance(p)
			table.insert(lines, {
				name = variant.Name,
				percent = percent,
				oneIn = oneIn,
				color = if group.title == "MUTATIONS"
					then Theme.mutation(variant.Name)
					else Theme.WHITE,
				header = false,
			})
		end
	end
	header("YOUR LUCK")
	for _, line in breakdown do
		table.insert(lines, {
			name = line.label,
			percent = if line.add
				then `+{math.floor(line.add * 100 + 0.5)}%`
				else Format.mult(line.mult),
			oneIn = "",
			header = false,
		})
	end
	if lucky then
		table.insert(lines, {
			name = "Lucky Throw",
			percent = Format.mult(T.LuckyThrowLuck),
			oneIn = "",
			header = false,
		})
	end
	if #breakdown == 0 and not lucky then
		table.insert(lines, { name = "No bonus yet", percent = "x1", oneIn = "", header = false })
	end

	local keys: { string } = {}
	for i in lines do
		keys[i] = tostring(i)
	end
	Screens.syncRows(rows, keys, function(row: GuiObject, key: string)
		local line = lines[tonumber(key) :: number]
		local swatch = Screens.frame(row, "Swatch")
		swatch.Visible = line.color ~= nil
		if line.color then
			Screens.tint(swatch, line.color)
		end
		local name = Screens.label(row, "Name")
		name.Text = if line.header then line.name else line.name:upper()
		name.TextColor3 = if line.header then Theme.BUY else Theme.WHITE
		Screens.label(row, "Percent").Text = line.percent
		Screens.label(row, "OneIn").Text = line.oneIn
	end, true)
end

-- luck moves with server luck, the streak and the dry streak: keep it live
ThrowOdds.tick = ThrowOdds.render

function ThrowOdds.init(_context: Types.Ctx)
	gui = Screens.get("ThrowOdds")
	rows = Screens.rows(Screens.scroller(gui, "OddsLines"), "ThrowOddsRowTemplate")
end

return ThrowOdds
