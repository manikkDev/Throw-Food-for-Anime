--!strict
local Squad = require("../src/shared/Core/Squad")

-- income is just a number carried on the record in these specs
local function incomeOf(hero: any): number
	return hero.income
end

local function h(income: number, slot: number, id: string?): any
	return { id = id or "a", mut = nil, size = nil, stars = 0, slot = slot, income = income }
end

return {
	["a free slot is taken, lowest first"] = function()
		local heroes = { h1 = h(5, 1), h2 = h(5, 3) }
		local p = Squad.placement(heroes, 3, 10, 1, incomeOf)
		assert(p.action == "place" and p.slot == 2)
	end,

	["a better catch on a full plot swaps out the weakest"] = function()
		local heroes = { h1 = h(5, 1), h2 = h(2, 2) }
		local p = Squad.placement(heroes, 2, 10, 9, incomeOf)
		assert(p.action == "swap" and p.slot == 2 and p.benched == "h2" and p.sold == nil)
	end,

	["an equal catch does not swap"] = function()
		-- equal must not churn the plot every throw
		local heroes = { h1 = h(5, 1) }
		local p = Squad.placement(heroes, 1, 10, 5, incomeOf)
		assert(p.action == "bench")
	end,

	["a worse catch goes to the bench"] = function()
		local heroes = { h1 = h(5, 1) }
		local p = Squad.placement(heroes, 1, 10, 1, incomeOf)
		assert(p.action == "bench" and p.slot == 0 and p.sold == nil)
	end,

	["a full bench sells its worst, never the better catch"] = function()
		local heroes = { h1 = h(9, 1), h2 = h(1, 0), h3 = h(4, 0) }
		local p = Squad.placement(heroes, 1, 2, 3, incomeOf)
		assert(p.action == "bench" and p.sold == "h2")
	end,

	["a catch worth less than everything on a full bench is sold itself"] = function()
		local heroes = { h1 = h(9, 1), h2 = h(4, 0), h3 = h(5, 0) }
		local p = Squad.placement(heroes, 1, 2, 3, incomeOf)
		assert(p.action == "sold" and p.sold == "new")
	end,

	["a swap with a full bench sells the least valuable of the two candidates"] = function()
		local heroes = { h1 = h(5, 1), h2 = h(1, 0) }
		local p = Squad.placement(heroes, 1, 1, 9, incomeOf)
		assert(p.action == "swap" and p.sold == "h2" and p.benched == "h1")
		heroes = { h1 = h(5, 1), h2 = h(7, 0) }
		p = Squad.placement(heroes, 1, 1, 9, incomeOf)
		assert(p.action == "swap" and p.sold == "h1" and p.benched == nil)
	end,

	["nothing is ever lost when there is room"] = function()
		local heroes = {}
		for i = 1, 4 do
			local p = Squad.placement(heroes, 2, 2, i, incomeOf)
			assert(p.sold == nil, `catch {i} was sold with room to spare`)
			if p.benched then
				heroes[p.benched].slot = 0
			end
			heroes["h" .. i] = h(i, p.slot)
		end
		local onPlot, onBench = Squad.counts(heroes)
		assert(onPlot == 2 and onBench == 2)
	end,

	["equip best seats the top earners and benches the rest"] = function()
		local heroes = { h1 = h(1, 1), h2 = h(9, 0), h3 = h(5, 0), h4 = h(7, 2) }
		local seats = Squad.equipBest(heroes, 2, incomeOf)
		assert(seats.h2 == 1 and seats.h4 == 2 and seats.h3 == 0 and seats.h1 == 0)
	end,

	["fusing needs three identical heroes"] = function()
		local heroes = { h1 = h(1, 1, "x"), h2 = h(1, 0, "x"), h3 = h(1, 0, "y") }
		assert(Squad.fusePartners(heroes, "h1", 3, 3) == nil)
		heroes.h4 = h(1, 0, "x")
		local partners = Squad.fusePartners(heroes, "h1", 3, 3)
		assert(partners ~= nil and #partners == 2)
	end,

	["a mutated hero does not fuse with a plain one"] = function()
		local heroes = { h1 = h(1, 1, "x"), h2 = h(1, 0, "x"), h3 = h(1, 0, "x") }
		heroes.h3.mut = "Golden"
		assert(Squad.fusePartners(heroes, "h1", 3, 3) == nil)
	end,

	["a hero at max stars cannot be fused further"] = function()
		local heroes = { h1 = h(1, 1, "x"), h2 = h(1, 0, "x"), h3 = h(1, 0, "x") }
		for _, hero in heroes do
			hero.stars = 3
		end
		assert(Squad.fusePartners(heroes, "h1", 3, 3) == nil)
	end,
}
