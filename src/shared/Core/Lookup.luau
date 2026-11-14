--!strict
-- Lookup - id -> row maps over the generated config.
--
-- GameConfig stores every table as an ordered ARRAY (so the order a designer
-- wrote is the order the game shows). Rules need "the row for this id", so the
-- maps are built once per config table and cached. Pure: plain tables only.

local Lookup = {}

export type Maps = {
	character: { [string]: any },
	premium: { [string]: any },
	zone: { [string]: any },
	zoneCharacters: { [string]: { any } },
	food: { [string]: any },
	mutation: { [string]: any },
	size: { [string]: any },
	pass: { [string]: any },
	product: { [string]: any },
	productById: { [number]: any },
	passById: { [number]: any },
}

local cache: { [any]: Maps } = setmetatable({}, { __mode = "k" }) :: any

local function byKey(rows: { any }, key: string): { [string]: any }
	local map = {}
	for _, row in rows do
		map[row[key]] = row
	end
	return map
end

--- Build (or fetch) every id map for `cfg`.
function Lookup.of(cfg: any): Maps
	local hit = cache[cfg]
	if hit then
		return hit
	end
	local zoneCharacters: { [string]: { any } } = {}
	for _, zone in cfg.Zones do
		zoneCharacters[zone.Id] = {}
	end
	for _, character in cfg.Characters do
		local list = zoneCharacters[character.Zone]
		if list then
			table.insert(list, character)
		end
	end
	local productById, passById = {}, {}
	for _, product in cfg.Monetization.Products do
		if product.ProductId ~= 0 then
			productById[product.ProductId] = product
		end
	end
	for _, pass in cfg.Monetization.Passes do
		if pass.ProductId ~= 0 then
			passById[pass.ProductId] = pass
		end
	end
	local maps: Maps = {
		character = byKey(cfg.Characters, "Id"),
		premium = byKey(cfg.PremiumCharacters, "Id"),
		zone = byKey(cfg.Zones, "Id"),
		zoneCharacters = zoneCharacters,
		food = byKey(cfg.Foods, "Id"),
		mutation = byKey(cfg.Mutations, "Name"),
		size = byKey(cfg.Sizes, "Name"),
		pass = byKey(cfg.Monetization.Passes, "Key"),
		product = byKey(cfg.Monetization.Products, "Key"),
		productById = productById,
		passById = passById,
	}
	cache[cfg] = maps
	return maps
end

return Lookup
