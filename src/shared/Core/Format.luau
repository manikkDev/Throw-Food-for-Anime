--!strict
-- Format - numbers and durations as the player reads them.
--
-- The economy runs from 1 to beyond 1e30, so every number on screen goes
-- through here. Never scientific notation below the last named suffix: a kid
-- reads "4.5Qa", not "4.5e15".

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trim(text: string): string
	-- "1.50" -> "1.5", "2.00" -> "2"
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return text
end

--- 950 -> "950", 1234 -> "1.23K", 15300000 -> "15.3M", 1e15 -> "1Qa".
function Format.short(value: number): string
	if value ~= value then
		return "0"
	end
	local sign = if value < 0 then "-" else ""
	local n = math.abs(value)
	local whole = math.floor(n + 0.5)
	if whole < 1000 then
		return sign .. tostring(whole)
	end
	n = math.max(n, 1000) -- 999.6 rounds to a thousand: it is "1K", not "1000"
	local index = math.floor(math.log10(n) / 3)
	local scaled = n / 10 ^ (index * 3)
	-- three significant figures, and never "1000K": rounding can push 999.96
	-- over the edge, so bump to the next suffix when it does
	local digits = if scaled >= 100 then 0 elseif scaled >= 10 then 1 else 2
	local rounded = tonumber(string.format(`%.{digits}f`, scaled)) :: number
	if rounded >= 1000 then
		index += 1
		rounded = 1
		digits = 2
	end
	if index > #SUFFIXES then
		return sign
			.. string.format(
				"%.2fe%d",
				n / 10 ^ math.floor(math.log10(n)),
				math.floor(math.log10(n))
			)
	end
	return sign .. trim(string.format(`%.{digits}f`, rounded)) .. SUFFIXES[index]
end

--- 1234567 -> "1,234,567". Used for "1 in N" and leaderboard counts.
function Format.comma(value: number): string
	local text = tostring(math.floor(math.abs(value) + 0.5))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if value < 0 then "-" else "") .. out
end

--- "1 in 48,400" below a billion, "1 in 2.5B" above it.
function Format.oneIn(n: number): string
	if n < 1 then
		n = 1
	end
	if n >= 1e9 then
		return "1 in " .. Format.short(n)
	end
	return "1 in " .. Format.comma(n)
end

--- 37 -> "37s", 252 -> "4m 12s", 3900 -> "1h 05m", 90000 -> "1d 1h".
function Format.duration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s < 60 then
		return `{s}s`
	elseif s < 3600 then
		return `{s // 60}m {string.format("%02d", s % 60)}s`
	elseif s < 86400 then
		return `{s // 3600}h {string.format("%02d", (s % 3600) // 60)}m`
	end
	return `{s // 86400}d {(s % 86400) // 3600}h`
end

--- 1.5 -> "x1.5", 2 -> "x2". Luck and income multipliers.
function Format.mult(value: number): string
	return "x" .. trim(string.format("%.2f", value))
end

--- 0.0034 -> "0.34%", 0.25 -> "25%". Chances in the Index and the odds screen.
function Format.percent(fraction: number): string
	local pct = fraction * 100
	if pct >= 10 then
		return trim(string.format("%.1f", pct)) .. "%"
	elseif pct >= 0.01 then
		return trim(string.format("%.2f", pct)) .. "%"
	elseif pct <= 0 then
		return "0%"
	end
	return trim(string.format("%.4f", pct)) .. "%"
end

return Format
