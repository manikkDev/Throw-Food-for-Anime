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
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Sfx = require(ReplicatedStorage.Shared.Sfx)
local Screens = require(script.Parent.Parent.Ui.Screens)

-- Clips longer than their moment, stopped with a CAP_FADE fade after this many
-- seconds. Values are the "cap" fields of assets/sfx/manifest.json (measured
-- in Studio by the roblox-sfx stage); keep the two in step.
local CAPS: { [string]: number } = {
	-- plan 13 phase D: the training grounds
	post_hit = 0.5,
	post_crit = 0.8,
	flurry_hit = 0.2,
	post_break = 1.6,
	post_rise = 1.2,
	breath_perfect = 1.4,
	awaken_start = 1.0,
	awaken_sting = 2.4,
	falls_split = 1.6,
	falls_crash = 2.0,
	focus_full = 1.0,
	-- plan 13 phase C: the throw and landing sounds (seconds played after STARTS, then a fade)
	throw_heave = 0.7,
	throw_spin = 0.4,
	food_ready = 0.5,
	land_bowl = 0.9,
	land_plate = 0.7,
	land_soft = 0.6,
	land_sizzle = 1.4,
	land_glass = 0.9,
	land_splash = 1.0,
	sig_sting = 1.2,
	sig_steam = 1.2,
	sig_fire = 1.3,
	sig_dark = 1.6,
	sig_blast = 1.0,
	sig_gold = 1.2,
	sig_wind = 0.9,
	sig_quake = 1.7,
	sig_shatter = 0.9,
	sig_ice = 1.6,
	sig_magic = 1.2,
	sig_electric = 1.1,
	sig_water = 1.0,
	sig_spirit = 0.9,
	favourite_burst = 1.6,
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
	post_hit = 0.08,
	flurry_hit = 0.05,
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

-- Where a sound starts (seconds in): library recordings of a pass-by or a hit often open with
-- air before the event. Measured in Studio from each clip's loudness curve (plan 13 phase C):
-- the game skips to just before the attack, so the sound lands ON its moment.
local STARTS: { [string]: number } = {
	-- plan 13 phase D (measured lead-ins, work/sfx/probe_d.json)
	post_break = 0.17,
	post_rise = 0.33,
	breath_pulse = 0.06,
	breath_perfect = 0.1,
	awaken_start = 0.25,
	awaken_loop = 0.3,
	falls_split = 0.08,
	falls_crash = 0.14,
	throw_heave = 0.62,
	land_plate = 0.05,
	land_glass = 0.05,
	land_splash = 0.05,
	sig_sting = 0.2,
	sig_dark = 0.3,
	sig_blast = 0.05,
	sig_wind = 0.2,
	sig_quake = 0.2,
	sig_ice = 0.2,
	sig_spirit = 0.4,
}

-- buttons that make their own sound (the throw tap is the throw)
local SILENT_BUTTONS: { [string]: boolean } = {
	ThrowButton = true,
	ThrowButtonFace = true,
}

local MUSIC_FADE = 1.5
-- the first six zones have a recorded ambience bed (assets/sfx/manifest.json: amb_<zone id>)
local AMBIENCE_BEDS = 6
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
		local start = STARTS[role]
		if start then
			sound.TimePosition = start
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
	local new = if zoneId then self:Play(role, nil, { fadeIn = AMBIENCE_FADE }) else nil
	if zoneId and not new then
		-- a zone with no ambience of its own (zones 7 to 17 since economy v2) borrows one of the
		-- six recorded beds, by its place down the lane, so a far throw is never silent
		for index, zone in Config.Zones do
			if zone.Id == zoneId then
				local borrow = Config.Zones[(index - 1) % AMBIENCE_BEDS + 1]
				new = self:Play("amb_" .. borrow.Id, nil, { fadeIn = AMBIENCE_FADE })
				break
			end
		end
	end
	self._ambience = new
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
