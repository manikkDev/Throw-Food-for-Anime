-- Run work/vfx/build_templates.luau against Lune's Roblox reflection (real classes, real property
-- names and value types) with fake ids for every texture, and print its report.
--
--   lune run assets/vfx/tools/check_templates.luau work/vfx/build_templates.luau
--
-- Fails (exit 1) on any FAILED effect, any PROP_FAILS, or an effect with no instances.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local game = roblox.Instance.new("DataModel")
local http = {
	JSONDecode = function(_, s)
		return serde.decode("json", s)
	end,
	JSONEncode = function(_, v)
		return serde.encode("json", v)
	end,
}
local env = {}
for k, v in roblox do
	env[k] = v
end
env.game = setmetatable({
	GetService = function(_, n)
		if n == "HttpService" then
			return http
		end
		return game:GetService(n)
	end,
}, {
	__index = function(_, k)
		return game[k]
	end,
})
env.math, env.table, env.string, env.pcall, env.tostring, env.pairs, env.print, env.error, env.type, env.typeof =
	math, table, string, pcall, tostring, pairs, print, error, type, typeof
env.ipairs, env.setmetatable, env.next, env.select = ipairs, setmetatable, next, select

-- fake ids for every texture the upload list names
local list = serde.decode("json", fs.readFile("assets/vfx/upload_list.json"))
local fake = { textures = {}, meshes = {} }
for i, t in list.textures do
	fake.textures[t.file] = 1000 + i
end
env._G = { VFX_IDS = fake }
setmetatable(env, {
	__index = function(_, k)
		error("global not available in check: " .. tostring(k))
	end,
})

local path = process.args[1] or "work/vfx/build_templates.luau"
local fn = luau.load(fs.readFile(path), { debugName = path, environment = env })
local ok, report = pcall(fn)
if not ok then
	print("LOAD/RUN FAIL: " .. tostring(report))
	process.exit(1)
end
print(report)
local vfx = game:GetService("ReplicatedStorage").Assets.Vfx
local bad = false
for _, f in vfx:GetChildren() do
	local n = #f:GetDescendants()
	local tl = f:FindFirstChild("Timeline")
	local events = if tl then #serde.decode("json", tl.Value) else -1
	print(string.format("  %-20s %3d instances, %2d timeline events, missing %d", f.Name, n, events, f:GetAttribute("MissingAssets") or -1))
	if n < 3 then
		bad = true
	end
end
if string.find(report, "FAILED: none", 1, true) == nil or string.find(report, "PROP_FAILS: none", 1, true) == nil then
	bad = true
end
process.exit(if bad then 1 else 0)
