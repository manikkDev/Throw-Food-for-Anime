--!strict
-- Vfx - every authored effect, played by NAME, through one safe door.
--
-- Where an effect comes from, first that exists:
--   1. the runtime kit Fx/VfxKit (written by the VFX stage), required lazily:
--      VfxKit.play(name, at, opts) or VfxKit.build(name, part, opts)
--   2. the template ReplicatedStorage.Assets.Vfx.<Name>, cloned and fired here
--   3. the code-built look of Fx/Particles where one already existed (so
--      today's look survives until the kit lands), else nothing
--
-- This module owns the POLICY: at most MAX_AURAS live auras (the ones nearest
-- the camera win, re-checked every AURA_EVAL seconds), the low-detail switch
-- (Settings), and the fallbacks. Cosmetics never break gameplay: every entry
-- point is pcall-isolated and a missing effect is silent.

local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Particles = require(script.Parent.Particles)
local HeroAura = require(script.Parent.HeroAura)
local AuraConfig = require(ReplicatedStorage.Shared.Config.Auras)

export type Opts = {
	--- 1 = authored size.
	scale: number?,
	tint: Color3?,
	--- A loop (aura, trail, charge): runs until the handle is stopped.
	loop: boolean?,
	--- How long a one-shot's anchor lives (seconds).
	life: number?,
	--- Burst multiplier for a one-shot.
	mult: number?,
}

export type Handle = {
	--- True when an authored effect is playing (not a fallback).
	authored: boolean,
	stop: () -> (),
}

local Vfx = {}

local MAX_AURAS = 24
local AURA_EVAL = 2
local ONE_SHOT_LIFE = 4
local INERT: Handle = { authored = false, stop = function() end }

local kit: any = nil
local kitTried = false
local lowDetail = false

-- The kit, once it exists. Looked for again on every call until found (the
-- module may arrive with a later sync); required once.
local function getKit(): any
	if kit then
		return kit
	end
	local module = script.Parent:FindFirstChild("VfxKit")
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	if kitTried then
		return nil
	end
	kitTried = true
	local ok, result = pcall(require, module)
	if ok and typeof(result) == "table" then
		kit = result
		if lowDetail and typeof(kit.setLowDetail) == "function" then
			pcall(kit.setLowDetail, true)
		end
	else
		warn(`[Vfx] VfxKit failed to load, effects fall back: {result}`)
	end
	return kit
end

local function template(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Vfx")
	return folder and folder:FindFirstChild(name)
end

-- An invisible anchored part to hang a one-shot on (removed after `life`).
local function anchorAt(at: Vector3 | CFrame, life: number?): Part
	local part = Instance.new("Part")
	part.Name = "VfxAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = if typeof(at) == "CFrame" then at else CFrame.new(at)
	part.Parent = workspace
	if life then
		Debris:AddItem(part, life)
	end
	return part
end

-- Wrap whatever the kit handed back into a Handle.
local function wrap(handle: any, cleanup: Instance?): Handle
	local stopped = false
	return {
		authored = true,
		stop = function()
			if stopped then
				return
			end
			stopped = true
			pcall(function()
				if typeof(handle) == "table" then
					if typeof(handle.stop) == "function" then
						handle.stop()
					elseif typeof(handle.Stop) == "function" then
						handle:Stop()
					else
						if typeof(handle.setEnabled) == "function" then
							handle.setEnabled(false)
						end
						if typeof(handle.destroy) == "function" then
							-- let the last particles finish their life first
							task.delay(1.5, function()
								pcall(handle.destroy)
							end)
						end
					end
				elseif typeof(handle) == "Instance" then
					handle:Destroy()
				end
			end)
			if cleanup then
				Debris:AddItem(cleanup, 1.6)
			end
		end,
	}
end

-- 2. The template, cloned and fired by hand: every emitter and light under it
-- goes on one attachment on `part`.
local function fromTemplate(
	source: Instance,
	part: BasePart,
	opts: Opts,
	cleanup: Instance?
): Handle
	local attachment = Instance.new("Attachment")
	attachment.Name = "Vfx_" .. source.Name
	attachment.Parent = part
	local clone = source:Clone()
	local emitters: { ParticleEmitter } = {}
	local others: { Instance } = {}
	local scale = opts.scale or 1
	for _, item in clone:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			table.insert(emitters, item)
		elseif item:IsA("Light") or item:IsA("Beam") or item:IsA("Trail") then
			table.insert(others, item)
		end
	end
	if clone:IsA("ParticleEmitter") then
		table.insert(emitters, clone)
	end
	for _, emitter in emitters do
		if scale ~= 1 then
			local keys = {}
			for _, key in emitter.Size.Keypoints do
				table.insert(
					keys,
					NumberSequenceKeypoint.new(key.Time, key.Value * scale, key.Envelope * scale)
				)
			end
			emitter.Size = NumberSequence.new(keys)
		end
		if opts.tint then
			emitter.Color = ColorSequence.new(opts.tint)
		end
		emitter.Parent = attachment
		if opts.loop then
			emitter.Enabled = true
		else
			local count = emitter:GetAttribute("EmitCount")
			emitter.Enabled = false
			emitter:Emit(
				math.floor((if typeof(count) == "number" then count else 20) * (opts.mult or 1))
			)
		end
	end
	for _, item in others do
		item.Parent = attachment
	end
	clone:Destroy()
	if not opts.loop then
		Debris:AddItem(attachment, opts.life or ONE_SHOT_LIFE)
	end
	local stopped = false
	return {
		authored = true,
		stop = function()
			if stopped then
				return
			end
			stopped = true
			for _, emitter in emitters do
				emitter.Enabled = false
			end
			Debris:AddItem(attachment, 1.5)
			if cleanup then
				Debris:AddItem(cleanup, 1.6)
			end
		end,
	}
end

-- 3. The code-built look that existed before the kit, where there is one.
local function fallback(name: string, part: BasePart, opts: Opts): Handle
	local scale = opts.scale or 1
	if name == "Land_Impact" then
		Particles.dust(part.Position, scale)
	elseif name:sub(1, 7) == "Reveal_" then
		-- the burst sits at chest height over the spot the reveal stands on
		Particles.burst(
			part.Position + Vector3.new(0, 3 * scale, 0),
			opts.tint or Color3.new(1, 1, 1),
			math.floor(80 * (opts.mult or 1))
		)
	elseif name:sub(1, 5) == "Aura_" and name ~= "Aura_Titan" then
		-- the old placeholder aura: a glowing ring at the feet (the soles are
		-- the hero model's pivot)
		local model = part:FindFirstAncestorOfClass("Model")
		local feet = if model then model:GetPivot().Position else part.Position
		local ring = Instance.new("Part")
		ring.Name = "AuraRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.25, 7 * scale, 7 * scale)
		ring.CFrame = CFrame.new(feet) * CFrame.Angles(0, 0, math.rad(90))
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Material = Enum.Material.Neon
		ring.Color = opts.tint or Color3.new(1, 1, 1)
		ring.Transparency = 0.25
		ring.Parent = part
		return {
			authored = false,
			stop = function()
				ring:Destroy()
			end,
		}
	end
	return INERT
end

--- Play effect `name` at a part, an attachment, a point or a CFrame. Returns
--- a handle (stop it for a loop; a one-shot cleans itself up). Never nil,
--- never throws: a missing effect returns an inert handle.
function Vfx.play(name: string, at: Instance | Vector3 | CFrame, opts: Opts?): Handle
	local o: Opts = opts or {}
	local ok, result = pcall(function(): Handle
		local part: BasePart
		local cleanup: Instance? = nil
		if typeof(at) == "Instance" then
			if at:IsA("BasePart") then
				part = at
			elseif at:IsA("Attachment") and at.Parent and at.Parent:IsA("BasePart") then
				part = at.Parent
			else
				return INERT
			end
		else
			part = anchorAt(at :: any, if o.loop then nil else (o.life or ONE_SHOT_LIFE))
			cleanup = if o.loop then part else nil
		end
		local k = getKit()
		if k then
			local options = { scale = o.scale, tint = o.tint, loop = o.loop }
			if typeof(k.play) == "function" then
				local handle = k.play(name, at, options)
				if handle ~= nil then
					return wrap(handle, cleanup)
				end
			elseif typeof(k.build) == "function" then
				local handle = k.build(name, part, options)
				if handle ~= nil then
					if o.loop and typeof(handle.setEnabled) == "function" then
						handle.setEnabled(true)
					elseif typeof(handle.emit) == "function" then
						handle.emit(o.mult or 1)
						if typeof(handle.destroy) == "function" then
							task.delay(o.life or ONE_SHOT_LIFE, function()
								pcall(handle.destroy)
							end)
						end
					end
					return wrap(handle, cleanup)
				end
			end
		end
		local source = template(name)
		if source then
			return fromTemplate(source, part, o, cleanup)
		end
		local handle = fallback(name, part, o)
		if cleanup and handle == INERT then
			cleanup:Destroy()
		elseif cleanup then
			local inner = handle.stop
			handle.stop = function()
				inner()
				cleanup:Destroy()
			end
		end
		return handle
	end)
	if not ok then
		warn(`[Vfx] {name} failed inert: {result}`)
		return INERT
	end
	return result
end

-- ------------------------------------------------------------------ auras --
-- A hero registers its auras once; which ones are LIVE is decided here: only
-- heroes in the world, nearest the camera first, at most MAX_AURAS.

type Aura = {
	model: Model,
	names: { string },
	scale: number,
	tint: Color3?,
	live: { Handle }?,
	-- the hero's own character aura (Assets.Auras.<heroKey>), budgeted separately
	heroKey: string?,
	heroLive: HeroAura.Handle?,
}

local auras: { [Model]: Aura } = {}
local evalQueued = false

local function liveOff(aura: Aura)
	local live = aura.live
	if live then
		aura.live = nil
		for _, handle in live do
			handle.stop()
		end
	end
end

local function liveOn(aura: Aura)
	if aura.live then
		return
	end
	local root = aura.model.PrimaryPart
	if not root then
		return
	end
	local live = {}
	for _, name in aura.names do
		table.insert(
			live,
			Vfx.play(name, root, { loop = true, scale = aura.scale, tint = aura.tint })
		)
	end
	aura.live = live
end

local function heroOff(aura: Aura)
	local h = aura.heroLive
	if h then
		aura.heroLive = nil
		h.stop()
	end
end

local function heroOn(aura: Aura, rate: number)
	if aura.heroLive or not aura.heroKey then
		return
	end
	local ok, handle = pcall(HeroAura.attach, aura.model, aura.heroKey, aura.scale, rate)
	if ok then
		aura.heroLive = handle
	else
		warn(`[Vfx] hero aura {aura.heroKey} failed inert: {handle}`)
	end
end

local function evaluate()
	evalQueued = false
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local ranked: { { aura: Aura, d: number } } = {}
	for model, aura in auras do
		if model.Parent and model:IsDescendantOf(workspace) then
			table.insert(ranked, { aura = aura, d = (model:GetPivot().Position - eye).Magnitude })
		else
			liveOff(aura)
			heroOff(aura)
		end
	end
	table.sort(ranked, function(a, b)
		return a.d < b.d
	end)
	-- phones get the low-detail aura budget whatever the setting says (no lag on any device)
	local phone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local budget = if lowDetail or phone then AuraConfig.LowDetail else AuraConfig.Budget
	local heroes, particles = 0, 0
	for index, entry in ranked do
		local aura = entry.aura
		if #aura.names > 0 then
			if index <= MAX_AURAS then
				liveOn(aura)
			else
				liveOff(aura)
			end
		end
		-- character auras: nearest first, within range, under the count and the particle budget.
		-- A hero still popping in (HeroController sets "Popping" while it scales up) waits: an aura
		-- fitted to it mid-scale stayed oversized once it reached full size (owner's review 3).
		if aura.heroKey then
			local cost = HeroAura.cost(aura.heroKey) * budget.RateScale
			if
				aura.model:GetAttribute("Popping") ~= true
				and entry.d <= budget.Range
				and heroes < budget.MaxLive
				and particles + cost <= budget.ParticleBudget
			then
				heroes += 1
				particles += cost
				heroOn(aura, budget.RateScale)
			else
				heroOff(aura)
			end
		end
	end
end

local function queueEval()
	if not evalQueued then
		evalQueued = true
		task.defer(function()
			local ok, err = pcall(evaluate)
			if not ok then
				warn(`[Vfx] aura budget failed inert: {err}`)
			end
		end)
	end
end

--- Give `model` its looping auras (`names`, e.g. {"Aura_Flame", "Aura_Titan"}).
--- They run while the model is in the world and among the nearest auras, and
--- go when the model is destroyed. Call again after a parent change to have
--- the budget re-checked at once.
function Vfx.aura(model: Model, names: { string }, scale: number?, tint: Color3?, heroKey: string?)
	if #names == 0 and not heroKey then
		return
	end
	if not auras[model] then
		auras[model] =
			{ model = model, names = names, scale = scale or 1, tint = tint, heroKey = heroKey }
		model.Destroying:Once(function()
			local aura = auras[model]
			auras[model] = nil
			if aura then
				liveOff(aura)
				heroOff(aura)
			end
		end)
	end
	queueEval()
end

--- The character aura key of hero `id` (design/auras.json), or nil.
function Vfx.heroAuraKey(id: string): string?
	return AuraConfig.ByHero[id]
end

--- Re-check the aura budget soon (a hero was shown or hidden).
function Vfx.touchAuras()
	queueEval()
end

--- Low detail (Settings): the kit drops to its cheap versions.
function Vfx.setLowDetail(on: boolean)
	if on == lowDetail then
		return
	end
	lowDetail = on
	-- character auras are rebuilt at the new rate on the next evaluation
	for _, aura in auras do
		heroOff(aura)
	end
	queueEval()
	local k = getKit()
	if k and typeof(k.setLowDetail) == "function" then
		pcall(k.setLowDetail, on)
	end
end

task.spawn(function()
	while true do
		task.wait(AURA_EVAL)
		if next(auras) ~= nil then
			local ok, err = pcall(evaluate)
			if not ok then
				warn(`[Vfx] aura budget failed inert: {err}`)
			end
		end
	end
end)

return Vfx
