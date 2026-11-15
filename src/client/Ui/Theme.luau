--!strict
-- Theme - the few colours client code paints with at runtime.
--
-- The screens carry their own look (src/ui, built from design/ui/theme.json).
-- Code only recolours the parts whose colour IS state: a toggle that is on, a
-- button that cannot be afforded, a rarity ribbon. Those colours live here so
-- every screen paints "on", "off" and "cannot" the same way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)

local Theme = {}

-- Text and tag colours. NOT for buttons: a button is painted by naming a
-- state (Theme.BUTTON, below), never with one of these.
Theme.CONFIRM = Color3.fromHex("34D17A")
Theme.BUY = Color3.fromHex("FFC93C")
Theme.INFO = Color3.fromHex("38BDF8")
Theme.PREMIUM = Color3.fromHex("FF4FA3")
Theme.DANGER = Color3.fromHex("F04438")
Theme.WHITE = Color3.new(1, 1, 1)

Theme.MUTATION = {
	Golden = Color3.fromRGB(255, 210, 60),
	Flame = Color3.fromRGB(255, 110, 40),
	Lightning = Color3.fromRGB(120, 200, 255),
	Galaxy = Color3.fromRGB(190, 110, 255),
} :: { [string]: Color3 }

Theme.FLAVOR = {
	Savory = Color3.fromRGB(240, 200, 120),
	Sweet = Color3.fromRGB(255, 150, 200),
	Spicy = Color3.fromRGB(255, 90, 60),
	Seafood = Color3.fromRGB(110, 200, 255),
} :: { [string]: Color3 }

-- ---------------------------------------------------------- UI v3 states --
-- The one button system (design/ui/CHANGES-v3.md). A button's STATE is a
-- colour on its face; every face carries a neutral gloss gradient, so the
-- gloss survives any of these. Pages never write a button colour: they name
-- a state and Screens.setButtonState paints it (face, lip, caption, icon).
Theme.BUTTON = {
	afford = Color3.fromHex("48D687"), -- free, or the player can pay
	cannot = Color3.fromHex("5C6286"), -- costs yen the player does not have
	neutral = Color3.fromHex("4CC4F9"), -- EQUIP, BENCH, a selected tab
	robux = Color3.fromHex("FF61AC"), -- costs Robux
	danger = Color3.fromHex("F2574C"), -- SELL, STOP
	state = Color3.fromHex("5C628F"), -- not a button any more: EQUIPPED, CLAIMED, OWNED
	off = Color3.fromHex("5C6286"), -- a toggle that is off, a timer still running
	idle = Color3.fromHex("404683"), -- a tab or filter that is not selected
	panel = Color3.fromHex("2B3175"), -- a zone tab that is not selected
	gold = Color3.fromHex("FFCE50"), -- the big yes: REBIRTH, a Lucky Throw armed
} :: { [string]: Color3 }
Theme.SOFT_RED = Color3.fromHex("FF8A8A") -- the caption on a "cannot" button

-- cards and tiles (not buttons)
Theme.FLAVOR_TILE = {
	Savory = Color3.fromHex("F2A541"),
	Sweet = Color3.fromHex("FF8CC6"),
	Spicy = Color3.fromHex("FF6A3D"),
	Seafood = Color3.fromHex("2EC4B6"),
} :: { [string]: Color3 }
Theme.NEXT_GOLD = Color3.fromHex("FFC93C") -- keyline of the next food to buy
Theme.CARD_DIM = Color3.fromHex("D9CFBA") -- a food further away than the next one
Theme.UNKNOWN_TILE = Color3.fromHex("23264F") -- a hero not caught yet
Theme.DAY_CLAIMED = Color3.fromHex("5C628F")
Theme.DAY_TODAY = Color3.fromHex("FFC93C")
Theme.DAY_AHEAD = Color3.fromHex("2B3175")
Theme.TOAST = {
	good = Color3.fromHex("1F6E4A"),
	bad = Color3.fromHex("8A2A35"),
	info = Color3.fromHex("1B1F4B"),
} :: { [string]: Color3 }

--- The lip under a face of `color`: darker, and pushed a little toward blue
--- (the same rule the UI builder uses, so a repainted button keeps a lip
--- that belongs to it).
function Theme.lip(color: Color3): Color3
	local h, s, v = color:ToHSV()
	h = (h + (if h < 0.6 then 0.05 else -0.05)) % 1
	return Color3.fromHSV(h, math.min(1, s + 0.06), v * 0.66)
end

--- The colour of a rarity (Config.Rarities), or premium pink for anything else.
function Theme.rarity(rarity: string?): Color3
	local row = if rarity then Config.Rarities[rarity] else nil
	return if row then Color3.fromHex(row.Color) else Theme.PREMIUM
end

--- The colour of a mutation tag.
function Theme.mutation(mut: string?): Color3
	return (if mut then Theme.MUTATION[mut] else nil) or Theme.INFO
end

return Theme
