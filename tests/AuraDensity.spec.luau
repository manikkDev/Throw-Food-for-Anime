--!strict
local Support = require("./Support")
local AuraDensity = require("../src/shared/Core/AuraDensity")
local Auras = require("../src/shared/Config/Auras")

return {
	["an aura with no mark is never thinned"] = function()
		for bars = 1, 10 do
			assert(AuraDensity.rate(nil, bars) == 1)
			assert(AuraDensity.rate(1, bars) == 1)
		end
	end,

	["at maximum graphics a hot aura runs at exactly its mark"] = function()
		assert(AuraDensity.rate(0.4, 10) == 0.4)
		assert(AuraDensity.rate(0.3, 10) == 0.3)
	end,

	["what is drawn never passes the mark, and is never thinned below what the engine already does"] = function()
		for bars = 1, 10 do
			local drawn = AuraDensity.drawn(bars)
			local rate = AuraDensity.rate(0.4, bars)
			assert(rate <= 1 and rate > 0)
			assert(drawn * rate <= 0.4 + 1e-9, `bars {bars} draws {drawn * rate}`)
			if drawn <= 0.4 then
				assert(rate == 1, `bars {bars} is thin already`)
			end
		end
	end,

	["more graphics never means a thicker rate factor"] = function()
		local last = 1
		for bars = 1, 10 do
			local rate = AuraDensity.rate(0.4, bars)
			assert(rate <= last + 1e-9)
			last = rate
		end
	end,

	["an unknown bar counts as the top"] = function()
		assert(AuraDensity.drawn(0) == 1)
		assert(AuraDensity.drawn(11) == 1)
		assert(Support.near(AuraDensity.rate(0.4, 0), 0.4, 1e-6))
	end,

	["every hot mark in the config is a share of an aura somebody wears"] = function()
		local worn: { [string]: boolean } = {}
		for _, key in Auras.ByHero do
			worn[key] = true
		end
		for key, mark in Auras.Hot do
			assert(worn[key], `{key} is marked hot but nobody wears it`)
			assert(mark > 0 and mark < 1, `{key}: a mark is a share between 0 and 1`)
		end
	end,
}
