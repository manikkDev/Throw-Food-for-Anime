--!strict
-- SoundController - every sound the client makes, by ROLE (Shared/Sfx), in
-- one of two SoundGroups whose volumes follow the Settings sliders:
--   Music    music_* and amb_*      (Settings "music")
--   Effects  everything else        (Settings "sfx")
--
-- It owns the music bed (music_home from join, music_festival_hour while
-- Festival Hour runs, crossfaded), the zone ambience under a throw's flight,
-- the caps on clips longer than their moment, and the throttles on sounds
-- that can fire many times a second. UI sounds are hooked here once (every
-- button press, every page open and close), never per page.
--
-- Cosmetics never break gameplay: every method is pcall-isolated and a
-- missing sound is silent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Screens = require(script.Parent.Parent.Ui.Screens)

-- Clips longer than their moment, stopped with a CAP_FADE fade after this many
-- seconds. Values are the "cap" fields of assets/sfx/manifest.json (measured
-- in Studio by the roblox-sfx stage); keep the two in step.
local CAPS: { [string]: number } = {
	reveal_drumroll = 6.0,
	reveal_legendary = 5.5,
	reveal_epic = 4.5,
	server_luck = 3.5,
	rarity_step = 1.4,
	impact_frame = 2.6,
	train_push = 0.9,
	suspense_riser = 3.1,
	-- section 4 rework 2 (2026-11-16)
	rebirth_rise = 1.5,
	zone_hype = 1.8,
	announce = 2.2,
	level_up = 2.2,
	odds_slam = 1.6,
	cam_whoosh = 0.8,
	hero_place = 1.2,
	toast_good = 1.2,
	-- section 4 rework 3 (owner's review 3)
	upgrade_ready = 1.8,
	banner_slam = 2.0,
	rebirth_villain = 4.5,
	confirm_open = 0.9,
	villain_power = 2.2,
}
local CAP_FADE = 0.4

-- The least time between two plays of a role: sounds that can fire many
-- times a second (reveal_tick: 20 per second at most).
local GAPS: { [string]: number } = {
	coin_tick = 0.1,
	reveal_tick = 0.05,
	letter_type = 0.03,
	ui_click = 0.04,
	ui_open = 0.08,
	ui_close = 0.08,
	ui_error = 0.15,
	toast_pop = 0.1,
	train_hit = 0.08,
	train_lift = 0.1,
	train_push = 0.15,
	rarity_step = 0.12,
	ui_hover = 0.05,
	odds_tick = 0.04,
	dialogue_blip = 0.05,
	footstep_heavy = 0.12,
	stat_tick = 0.06,
	prompt_show = 0.08,
	reward_pop = 0.3,
	reward_whoosh = 0.3,
	cam_whoosh = 0.2,
	toast_warn = 0.2,
	toast_good = 0.3,
	hero_pickup = 0.3,
	train_curl = 0.15,
	zone_cross = 0.12,
	eat_munch = 0.15,
	dash_whoosh = 0.1,
	-- one moment can be seen twice (a gift hero: HeroGranted AND the gifts
	-- diff; a product: the grant AND the state diff): heard once
	daily_claim = 0.5,
	buy_success = 0.5,
}

-- buttons that make their own sound (the throw tap is the throw)
local SILENT_BUTTONS: { [string]: boolean } = {
	ThrowButton = true,
	ThrowButtonFace = true,
}

local MUSIC_FADE = 1.5
local AMBIENCE_FADE = 0.5

export type Opts = {
	pitchVary: number?,
	speed: number?,
	--- Seconds after which the sound fades out (overrides CAPS).
	cap: number?,
	--- Fade in over this many seconds.
	fadeIn: number?,
}

local SoundController = Knit.CreateController({
	Name = "SoundController",
	_groups = {} :: { [string]: SoundGroup },
	_lastAt = {} :: { [string]: number },
	_music = nil :: Sound?,
	_musicRole = "",
	_ambience = nil :: Sound?,
	_ambienceRole = "",
	_volumes = { music = 0.6, sfx = 0.8 } :: { [string]: number },
})

local function isMusic(role: string): boolean
	return role:sub(1, 6) == "music_" or role:sub(1, 4) == "amb_"
end

function SoundController:_group(name: string): SoundGroup
	local group = self._groups[name]
	if group and group.Parent then
		return group
	end
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		group = existing
	else
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	local made = group :: SoundGroup
	made.Volume = if name == "Music" then self._volumes.music else self._volumes.sfx
	self._groups[name] = made
	return made
end

-- Fade `sound` to silence over `seconds`, then destroy it.
local function fadeOut(sound: Sound, seconds: number)
	pcall(function()
		if not sound.Parent then
			return
		end
		local tween = TweenService:Create(sound, TweenInfo.new(seconds), { Volume = 0 })
		tween.Completed:Once(function()
			pcall(function()
				sound:Stop()
				sound:Destroy()
			end)
		end)
		tween:Play()
	end)
end

--- Play `role` (2D, or 3D on `parent`). Returns the Sound, or nil when it was
--- throttled, missing or failed.
function SoundController:Play(role: string, parent: Instance?, opts: Opts?): Sound?
	local ok, result = pcall(function(): Sound?
		local now = os.clock()
		local gap = GAPS[role]
		if gap then
			local last = self._lastAt[role]
			if last and now - last < gap then
				return nil
			end
			self._lastAt[role] = now
		end
		local o: Opts = opts or {}
		local sound = Sfx.play(role, parent, o.pitchVary)
		if not sound then
			return nil
		end
		sound.SoundGroup = self:_group(if isMusic(role) then "Music" else "Effects")
		if o.speed then
			sound.PlaybackSpeed = o.speed
		end
		if o.fadeIn and o.fadeIn > 0 then
			local full = sound.Volume
			sound.Volume = 0
			TweenService:Create(sound, TweenInfo.new(o.fadeIn), { Volume = full }):Play()
		end
		local cap = o.cap or CAPS[role]
		if cap then
			task.delay(cap, fadeOut, sound, CAP_FADE)
		end
		return sound
	end)
	if not ok then
		warn(`[SoundController] {role} failed inert: {result}`)
		return nil
	end
	return result
end

--- Stop a sound started with Play, with a fade (default 0.4 s).
function SoundController:Stop(sound: Sound?, fade: number?)
	if sound then
		fadeOut(sound, fade or CAP_FADE)
	end
end

-- crossfade the music bed to `role`
function SoundController:_setMusic(role: string)
	if role == self._musicRole then
		return
	end
	self._musicRole = role
	local old = self._music
	self._music = self:Play(role, nil, { fadeIn = if old then MUSIC_FADE else 2 })
	if old then
		fadeOut(old, MUSIC_FADE)
	end
end

--- Festival Hour's music while it runs, the home theme otherwise (FxController
--- reads the server's env and calls this; 1.5 s crossfade).
function SoundController:SetFestival(on: boolean)
	self:_setMusic(if on then "music_festival_hour" else "music_home")
end

--- The zone ambience under a throw's flight: amb_<zoneId> fades in under the
--- music; nil fades it out.
function SoundController:SetAmbience(zoneId: string?)
	local role = if zoneId then "amb_" .. zoneId else ""
	if role == self._ambienceRole then
		return
	end
	self._ambienceRole = role
	local old = self._ambience
	self._ambience = if zoneId then self:Play(role, nil, { fadeIn = AMBIENCE_FADE }) else nil
	if old then
		fadeOut(old, AMBIENCE_FADE)
	end
end

--- Live volume while a Settings slider is dragged ("music" | "sfx", 0..1).
function SoundController:Preview(key: string, value: number)
	if key ~= "music" and key ~= "sfx" then
		return
	end
	self._volumes[key] = math.clamp(value, 0, 1)
	pcall(function()
		self:_group(if key == "music" then "Music" else "Effects").Volume = self._volumes[key]
	end)
end

function SoundController:KnitInit()
	self:_group("Music")
	self:_group("Effects")
end

function SoundController:KnitStart()
	task.spawn(Sfx.preload)
	self:_setMusic("music_home")

	local state = Knit.GetController("StateController")
	state:Observe(function(snapshot: any)
		local settings = snapshot and snapshot.settings
		if settings then
			for _, key in { "music", "sfx" } do
				local value = settings[key]
				if typeof(value) == "number" then
					self:Preview(key, value)
				end
			end
		end
	end)

	-- the UI, once for every screen
	Screens.Pressed:Connect(function(button: GuiButton)
		if not SILENT_BUTTONS[button.Name] then
			self:Play("ui_click")
		end
	end)
	Screens.Opened:Connect(function()
		self:Play("ui_open")
	end)
	Screens.Closed:Connect(function()
		self:Play("ui_close")
	end)
end

return SoundController
