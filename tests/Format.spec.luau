--!strict
local Format = require("../src/shared/Core/Format")

local function eq(got: string, want: string)
	assert(got == want, `expected "{want}", got "{got}"`)
end

return {
	["numbers under a thousand are whole"] = function()
		eq(Format.short(0), "0")
		eq(Format.short(999), "999")
		eq(Format.short(12.4), "12")
	end,

	["a thousand is 1K, never 1000"] = function()
		eq(Format.short(1000), "1K")
		eq(Format.short(1234), "1.23K")
		eq(Format.short(15300000), "15.3M")
		eq(Format.short(123456789), "123M")
	end,

	["rounding never produces 1000K"] = function()
		-- the boundary that prints nonsense if the suffix is picked before rounding
		eq(Format.short(999999), "1M")
		eq(Format.short(999.6), "1K")
	end,

	["the top of the economy still has a name"] = function()
		eq(Format.short(4.5e15), "4.5Qa")
		eq(Format.short(1e33), "1Dc")
	end,

	["commas group by three"] = function()
		eq(Format.comma(1234567), "1,234,567")
		eq(Format.comma(999), "999")
		eq(Format.comma(1000), "1,000")
	end,

	["one in N reads as a sentence"] = function()
		eq(Format.oneIn(48400), "1 in 48,400")
		eq(Format.oneIn(0.5), "1 in 1")
		eq(Format.oneIn(2.5e9), "1 in 2.5B")
	end,

	["durations pick two units"] = function()
		eq(Format.duration(37), "37s")
		eq(Format.duration(252), "4m 12s")
		eq(Format.duration(3900), "1h 05m")
		eq(Format.duration(90000), "1d 1h")
	end,

	["multipliers and percents drop trailing zeros"] = function()
		eq(Format.mult(2), "x2")
		eq(Format.mult(1.5), "x1.5")
		eq(Format.percent(0.25), "25%")
		eq(Format.percent(0.0034), "0.34%")
	end,
}
