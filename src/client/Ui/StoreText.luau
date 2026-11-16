--!strict
-- StoreText - the words for everything sold with Robux: a pass's name and exactly what it grants,
-- a product's name and what one purchase does. ONE place, so the Store page and the purchase
-- celebration (Ui/Celebrate) can never disagree. Every number comes from the config values the
-- server applies (StoreService, Luck, SquadService, TrainingService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)

local MAPS = Lookup.of(Config)
local C: any = Config

local StoreText = {}

--- The icon key of each pass (the Store's pass cards and the celebration).
StoreText.PASS_ICONS = {
	DoubleYen = "IconYen",
	DoubleTraining = "IconTrain",
	Vip = "IconCrown",
	AutoThrow = "IconAuto",
	LuckyAura = "IconLuck",
	BigBench = "IconBench",
} :: { [string]: string }

--- The icon key of each product kind.
StoreText.KIND_ICONS = {
	lucky = "IconLuckyThrow",
	serverluck = "IconLuck",
	yen = "IconYen",
	train = "IconTrain",
	character = "IconStar",
	offline2x = "IconTimer",
	summon = "IconScroll",
	starter = "IconStore",
	gift = "IconGift",
} :: { [string]: string }

-- 12 -> "12", 1.75 -> "1.75", 1.5 -> "1.5"
function StoreText.fmt(n: number): string
	return (string.format("%.2f", n):gsub("%.?0+$", ""))
end

function StoreText.passName(key: string): string
	if key == "Vip" then
		return "VIP"
	end
	local spaced = key:gsub("(%l)(%u)", "%1 %2")
	return (spaced:gsub("^Double ", "2x "))
end

--- exactly what a pass grants
function StoreText.passDesc(pass: any): string
	local key = pass.Key
	if key == "DoubleYen" then
		return "Every hero earns double yen, forever."
	elseif key == "DoubleTraining" then
		return "2x Power from every rep, perfect tap and boost."
	elseif key == "Vip" then
		return `+{math.floor(C.Luck.VipBonus * 100 + 0.5)}% luck on every throw and +{C.Plot.VipBonusSlots} hero slots.`
	elseif key == "AutoThrow" then
		return "Adds AUTO to your throw pad: it throws for you."
	elseif key == "LuckyAura" then
		return `x{StoreText.fmt(pass.Luck or 1)} luck on every throw, forever.`
	elseif key == "BigBench" then
		return `Your bench holds {pass.BenchSlots} heroes instead of {C.Plot.BenchSlots}.`
	end
	return ""
end

function StoreText.duration(minutes: number): string
	if minutes >= 60 then
		local hours = minutes // 60
		return `{hours} hour{if hours == 1 then "" else "s"}`
	end
	return `{minutes} min`
end

function StoreText.productName(product: any): string
	if product.Kind == "lucky" then
		return `{product.Amount} Lucky Throw{if product.Amount == 1 then "" else "s"}`
	elseif product.Kind == "serverluck" then
		return "Server Luck"
	elseif product.Kind == "yen" then
		local minutes = product.Minutes
		return if minutes >= 60 then `{minutes // 60} hour Yen` else `{minutes} min Yen`
	elseif product.Kind == "train" then
		return `{product.Minutes} min Training`
	elseif product.Kind == "character" then
		local hero = MAPS.premium[product.Hero]
		return if hero then hero.Name else product.Key
	end
	return (product.Key:gsub("(%l)(%u)", "%1 %2"))
end

--- what one purchase of a product does (StoreService:GrantProduct)
function StoreText.productDesc(product: any): string
	if product.Kind == "lucky" then
		local throws = if product.Amount == 1 then "one throw" else `{product.Amount} throws`
		return `x{StoreText.fmt(C.Throw.LuckyThrowLuck)} luck on {throws}`
	elseif product.Kind == "serverluck" then
		return `Server luck up for {C.Luck.ServerStepMinutes} min`
	elseif product.Kind == "train" then
		return `{product.Minutes} min of training Power`
	elseif product.Kind == "yen" then
		return `{StoreText.duration(product.Minutes)} of your income`
	end
	return ""
end

return StoreText
