--!strict
-- FxController - the moments that have no remote of their own, read from the
-- state the server sends: training reps, a new power rank, a rebirth, a
-- bought slot, food, gear or pass, a sale, a daily / playtime / offline /
-- zone claim, server luck and Festival Hour.
--
-- Each one is a DIFF of two snapshots (or two ticks): the server stays the
-- only authority, and nothing here can change what it granted. Every moment
-- is pcall-isolated, so a missing clip, effect or sound is silent.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local World = require(ReplicatedStorage.Shared.Core.World)
local Motion = require(script.Parent.Parent.Fx.Motion)
local Vfx = require(script.Parent.Parent.Fx.Vfx)
local ImportedFx = require(script.Parent.Parent.Fx.ImportedFx)
local Sound = require(script.Parent.SoundController)
local RevealUi = require(script.Parent.Parent.Ui.RevealUi)
local Screens = require(script.Parent.Parent.Ui.Screens)

local W = Config.World
local COUNT = Config.Server.PlotCount
local player = Players.LocalPlayer

-- The training clip for each piece of dojo gear, by the gear's NAME
-- (Config.Training.Equipment rows have no id): strikes on the dummies and the
-- sandbag, a push on the pillar, a meditation at the rest.
local GEAR_CLIP: { [string]: string } = {
	["Wooden Dummy"] = "TrainStrike",
	["Sandbag"] = "TrainStrike",
	["Iron Dummy"] = "TrainStrike",
	["Stone Pillar"] = "TrainPush",
	["Waterfall"] = "TrainMeditate",
	["Gravity Dojo"] = "TrainMeditate",
	["Dragon Shrine"] = "TrainMeditate",
	["Star Forge"] = "TrainMeditate",
}
-- a rep with no clip marker this recent gets its hit from the server's rep
-- the sky over the hub while server luck runs
local HUB_SKY = Vector3.new(0, W.GroundY + 40, W.PlotBackZ - W.HubDepth / 2)
-- the clock's life in the rebirth cinematic (the cinematic itself is about 7.8 s)
local REBIRTH_SECONDS = 8.2

local FxController = Knit.CreateController({
	Name = "FxController",
	_state = nil :: any,
	_last = nil :: any,
	_rank = nil :: number?,
	_rebirthing = false,
	_power = nil :: number?,
	_train = nil :: AnimationTrack?,
	_trainClip = "",
	_trainMarks = {} :: { RBXScriptConnection },
	_markerAt = 0,
	_luckFx = nil :: Vfx.Handle?,
	_luckOn = false,
	_envAt = 0,
})

local function root(): BasePart?
	local character = player.Character
	local found = character and character:FindFirstChild("HumanoidRootPart")
	return if found and found:IsA("BasePart") then found else nil
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function count(map: any): number
	local n = 0
	if typeof(map) == "table" then
		for _, value in map do
			if value then
				n += 1
			end
		end
	end
	return n
end

-- coins over the player: a sale or a yen claim (never an income tick)
local function coins()
	local at = root()
	if at then
		Vfx.play("Coin_Pop", at.Position + Vector3.new(0, 2.5, 0))
	end
	Sound:Play("coin_tick")
end

-- --------------------------------------------------------------- training --

-- one rep: the hit effect at the striking hand and its sound
function FxController:_hit()
	local character = player.Character
	local hand = character and character:FindFirstChild("RightHand")
	local at = if hand and hand:IsA("BasePart") then hand else root()
	if at then
		Vfx.play("Train_Hit", at)
	end
	Sound:Play("train_hit", at, { pitchVary = 0.08 })
end

function FxController:_stopTraining()
	for _, connection in self._trainMarks do
		connection:Disconnect()
	end
	table.clear(self._trainMarks)
	Motion.stop(self._train, 0.3)
	self._train = nil
	self._trainClip = ""
end

-- Training loops the clip for the gear in use; its "Hit" / "Pulse" markers
-- are the reps you SEE (cosmetic: the server's reps are what grant power).
function FxController:_followTraining(state: any)
	-- the training clips moved to TrainingController (one clip per station, 2026-11-15): nothing
	-- plays here any more; this only stops a clip a previous build left running
	local _ = GEAR_CLIP[(Config.Training.Equipment[state.gear] or {}).Name or ""]
	local clip = ""
	if clip == self._trainClip then
		return
	end
	self:_stopTraining()
	if clip == "" then
		return
	end
	self._trainClip = clip
	local track = Motion.play(humanoid(), clip, { fade = 0.25 })
	self._train = track
	for _, marker in { "Hit", "Pulse" } do
		local connection = Motion.onMarker(track, marker, function()
			self._markerAt = os.clock()
			self:_hit()
		end)
		if connection then
			table.insert(self._trainMarks, connection)
		end
	end
end

-- every server tick: a rep (power up while training) and a new rank
function FxController:_onTick(power: number)
	self._power = power
	-- (a training rep's hit is TrainingController's, on the clip's contact marker)
	local rank = Progress.rank(Config, power).index
	if self._rank and rank > self._rank then
		local at = root()
		if at then
			Vfx.play("PowerUp_Burst", at)
		end
		Sound:Play("power_up")
	end
	self._rank = rank
end

-- -------------------------------------------------------------- rebirth --

local controls: any = nil
local function getControls(): any
	if controls then
		return controls
	end
	pcall(function()
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module then
			controls = (require :: any)(module):GetControls()
		end
	end)
	return controls
end

local function smooth(u: number): number
	local x = math.clamp(u, 0, 1)
	return x * x * (3 - 2 * x)
end

-- The rebirth, shown as a villain's level-up (owner's reviews 2026-11-16 and 3): the HUD fades
-- away and the bars come in; three close shots while the power gathers (through the clock at
-- their back, a profile close-up of the trembling fists, from the ground up at the face), the
-- world darkening and shaking more; on the burst a flash, an impact frame, a nova and the
-- banner; then a wide shot that rises and swings round while what the rebirth gave ticks in one
-- line at a time (HudController:StatTicks); a flash back to play. About 7.8 s with the
-- RebirthAwaken clip; the player cannot move meanwhile.
function FxController:_rebirthCinematic(rebirth: number)
	if self._rebirthing then
		return
	end
	self._rebirthing = true
	local hud = Knit.GetController("HudController") :: any
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local human = character and character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not rootPart:IsA("BasePart") or not human then
		Sound:Play("rebirth")
		self._rebirthing = false
		return
	end
	if Screens.isOpen() then
		Screens.close()
	end
	if hud.SetCinematic then
		hud:SetCinematic("rebirth", true)
	end
	local c = getControls()
	if c then
		c:Disable()
	end
	human:Move(Vector3.zero)
	-- the control module is not always in PlayerScripts (newer Roblox builds): hold the character
	-- by its own humanoid too (the client simulates its character, so this holds)
	local walk, jump, jumpPower = human.WalkSpeed, human.JumpHeight, human.JumpPower
	human.WalkSpeed, human.JumpHeight, human.JumpPower = 0, 0, 0
	local camera = workspace.CurrentCamera
	local baseFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	RevealUi.enable(true)
	RevealUi.letterbox(true, 0.3)
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "RebirthGrade"
	grade.Parent = Lighting

	-- the plot's world labels (station plates, the UPGRADE! marker) would sweep through the shots
	local hiddenLabels: { BillboardGui } = {}
	local state = self._state and self._state.State
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	local plotModel = if plots
			and state
			and state.plot
		then plots:FindFirstChild("Plot" .. state.plot)
		else nil
	local playerGui = player:FindFirstChild("PlayerGui")
	local upgradeMarker = playerGui and playerGui:FindFirstChild("UpgradeMarker")
	for _, gui in (if plotModel then plotModel:GetDescendants() else {}) do
		if gui:IsA("BillboardGui") and gui.Enabled then
			gui.Enabled = false
			table.insert(hiddenLabels, gui)
		end
	end
	if upgradeMarker and upgradeMarker:IsA("BillboardGui") and upgradeMarker.Enabled then
		upgradeMarker.Enabled = false
		table.insert(hiddenLabels, upgradeMarker)
	end
	local base = rootPart.CFrame
	local center = base.Position + Vector3.new(0, 0.6, 0)
	local look = base.LookVector * Vector3.new(1, 0, 1)
	local facing = if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
	local right = facing:Cross(Vector3.yAxis).Unit
	-- the clock: right behind the player's back at chest height, a little smaller than them
	-- (owner's review 3: "still a little far away, bring it closer")
	local clock = ImportedFx.play(
		"RebirthClock",
		CFrame.lookAt(
			center - facing * 0.95 + Vector3.new(0, 0.8, 0),
			center + Vector3.new(0, 0.8, 0)
		),
		{ scale = 0.46, duration = REBIRTH_SECONDS }
	)
	-- the villain's level-up (RebirthAwaken: kneel, rise trembling, burst, power stance); the
	-- older RebirthEvolve stands in until the new clip is in the place
	local awaken = Motion.has("RebirthAwaken")
	local evolve =
		Motion.play(human, if awaken then "RebirthAwaken" else "RebirthEvolve", { fade = 0.2 })
	Sound:Play("rebirth_rise")
	Sound:Play("rebirth_clock")
	local heartbeat = Sound:Play("heartbeat", nil, { fadeIn = 0.6 })
	local t0 = os.clock()
	local burstAt = t0 + (if awaken then 3.5 else 1.35)
	local endAt = burstAt + 4.3
	local burst = false
	local shake = 0
	local stats: any = nil
	local function doBurst()
		if burst then
			return
		end
		burst = true
		burstAt = os.clock()
		endAt = burstAt + 4.3
		RevealUi.flash(0.06, 0.45)
		-- one anime impact frame
		grade.Contrast, grade.Saturation = 1, -1
		grade.TintColor = Color3.fromHex("D9B8FF")
		task.delay(0.09, function()
			grade.Contrast = 0
		end)
		Vfx.play("Rebirth_Nova", rootPart.Position)
		Vfx.play(
			"PowerUp_Burst",
			rootPart.Position - Vector3.new(0, 2.6, 0),
			{ tint = Color3.fromHex("C084FC") }
		)
		Sound:Play("rebirth_burst")
		Sound:Play("rebirth_villain")
		Sound:Play("rebirth")
		if heartbeat then
			Sound:Stop(heartbeat, 0.3)
			heartbeat = nil
		end
		shake = 1.1
		if hud.LevelUp then
			hud:LevelUp(`REBIRTH {rebirth}`, "You evolved!", Color3.fromHex("B266FF"))
		end
		-- what the rebirth gave, one line at a time while the camera rises
		task.delay(0.6, function()
			if hud.StatTicks then
				local tier = Config.Rebirth.Tiers[1] or { IncomeBonus = 0.5, LuckBonus = 0.1 }
				local function mult(n: number): string
					local v = 1 + n * tier.IncomeBonus
					return if v == math.floor(v) then `x{v}` else string.format("x%.1f", v)
				end
				stats = hud:StatTicks({
					title = `REBIRTH {rebirth}`,
					color = Color3.fromHex("B266FF"),
					step = 0.55,
					hold = 1.4,
					rows = {
						{
							label = "Rebirth",
							from = tostring(rebirth - 1),
							to = tostring(rebirth),
							icon = "IconRebirth",
						},
						{
							label = "Income",
							from = mult(rebirth - 1),
							to = mult(rebirth),
							icon = "IconYen",
						},
						{
							label = "Training",
							from = `+{math.floor(
								(rebirth - 1) * (tier.TrainBonus or 0) * 100 + 0.5
							)}%`,
							to = `+{math.floor(rebirth * (tier.TrainBonus or 0) * 100 + 0.5)}%`,
							icon = "IconPower",
						},
						{
							label = "Luck",
							from = `+{math.floor((rebirth - 1) * tier.LuckBonus * 100 + 0.5)}%`,
							to = `+{math.floor(rebirth * tier.LuckBonus * 100 + 0.5)}%`,
							icon = "IconLuck",
						},
						-- economy v2: a rebirth resets Power and Yen only (plan 12)
						{ label = "Heroes, gear & food", to = "KEPT", icon = "IconIndex" },
					},
				})
			end
		end)
	end
	local rise = Motion.onMarker(evolve, "Rise", function()
		Sound:Play("rebirth_villain", nil, { speed = 0.8 })
		shake = math.max(shake, 0.25)
	end)
	local marker = Motion.onMarker(evolve, "Burst", doBurst)
	local shot = 0
	local clockGone = false
	while os.clock() < endAt do
		local now = os.clock()
		if not burst and now >= burstAt then
			doBurst()
		end
		local pre = burstAt - t0
		local u = if burst then 1 else math.clamp((now - t0) / pre, 0, 1)
		local eye: Vector3, at: Vector3, fov: number
		local want: number
		if not burst then
			-- three close shots while the power gathers, each pushing in
			if u < 0.4 then
				want = 1
				-- through the clock at their back, low, looking up
				local k = smooth(u / 0.4)
				eye = center
					- facing * (6.4 - 1.0 * k)
					+ Vector3.new(0, -0.4 + 0.3 * k, 0)
					+ right * 0.8
				at = center + Vector3.new(0, 1.4, 0)
				fov = baseFov - 8 - 4 * k
			elseif u < 0.75 then
				want = 2
				-- a profile close-up, fists and jaw, drifting
				local k = smooth((u - 0.4) / 0.35)
				eye = center
					+ right * (5.6 - 0.8 * k)
					+ facing * (2.2 - 0.6 * k)
					+ Vector3.new(0, 1.2, 0)
				at = center + Vector3.new(0, 0.9 + 0.3 * k, 0)
				fov = baseFov - 24
			else
				want = 3
				-- from the ground in front, looking up at the face as it lifts
				local k = smooth((u - 0.75) / 0.25)
				eye = center + facing * (5.4 - 1.0 * k) + Vector3.new(0, -1.6, 0) - right * 0.5
				at = center + Vector3.new(0, 1.6, 0)
				fov = baseFov - 12 - 6 * k
			end
			-- trembling with the power, more as it builds
			shake = math.max(shake, 0.03 + 0.1 * u * u)
			grade.Brightness = -0.16 * u
			grade.Saturation = -0.35 * u
			grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromHex("D9B8FF"), 0.55 * u)
		else
			want = 4
			-- the release: a wide shot that rises and swings round behind the clock
			local post = smooth((now - burstAt) / 3.8)
			local angle = math.rad(-30 + 170 * post)
			local distance = 6 + 5 * post
			local height = 0.2 + 4.2 * post
			local offset = CFrame.fromAxisAngle(Vector3.yAxis, angle)
				:VectorToWorldSpace(facing * distance)
			eye = center + offset + Vector3.new(0, height, 0)
			at = center + Vector3.new(0, 1.2 + 0.4 * post, 0)
			fov = baseFov + 8 * post * (1 - post)
			grade.Brightness = 0.05 * (1 - post)
			grade.Saturation = 0.3 * (1 - post)
			grade.TintColor = Color3.fromHex("F3E8FF"):Lerp(Color3.new(1, 1, 1), post)
		end
		if want ~= shot then
			if shot ~= 0 and want ~= 4 then
				Sound:Play("cam_whoosh", nil, { pitchVary = 0.05 })
			end
			shot = want
		end
		-- the clock fades out while still on screen, before the flash back
		if burst and not clockGone and now >= endAt - 0.8 then
			clockGone = true
			clock.stop()
		end
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake
		shake *= 0.9
		camera.CFrame = CFrame.lookAt(eye, at) * CFrame.new(jitter)
		camera.FieldOfView = fov
		RunService.RenderStepped:Wait()
	end
	if marker then
		marker:Disconnect()
	end
	if rise then
		rise:Disconnect()
	end
	if heartbeat then
		Sound:Stop(heartbeat, 0.2)
	end
	RevealUi.flash(0.18, 0.4, true)
	task.wait(0.18)
	Motion.stop(evolve, 0.3)
	clock.stop()
	grade:Destroy()
	RevealUi.letterbox(false, 0.25)
	camera.FieldOfView = baseFov
	camera.CameraType = Enum.CameraType.Custom
	if c then
		c:Enable()
	end
	if human.Parent then
		human.WalkSpeed, human.JumpHeight, human.JumpPower = walk, jump, jumpPower
	end
	if hud.SetCinematic then
		hud:SetCinematic("rebirth", false)
	end
	for _, gui in hiddenLabels do
		gui.Enabled = true
	end
	if stats and stats.Close then
		task.delay(1.2, function()
			pcall(stats.Close, stats)
		end)
	end
	self._rebirthing = false
end

-- ---------------------------------------------------------------- diffs --

function FxController:_diff(was: any, now: any)
	-- rebirth: the nova, and nothing else (it resets foods, gear and power)
	if (now.rebirth or 0) > (was.rebirth or 0) then
		self._rank = Progress.rank(Config, now.power).index
		task.spawn(function()
			local ok, err = pcall(self._rebirthCinematic, self, now.rebirth or 1)
			if not ok then
				warn(`[FxController] rebirth cinematic failed inert: {err}`)
			end
		end)
		return
	end

	local bought = false
	if count(now.foods) > count(was.foods) or (now.gear or 0) > (was.gear or 0) then
		bought = true
	end
	if count(now.passes) > count(was.passes) then
		bought = true
	end
	-- a pedestal slot: the effect on the new pedestal
	if (now.slots or 0) > (was.slots or 0) then
		if now.plot then
			local x, z = World.pedestal(W, now.plot, COUNT, now.slots)
			Vfx.play("Slot_Unlock", Vector3.new(x, W.GroundY + W.PedestalTop, z))
		end
		Sound:Play("slot_unlock")
	end

	-- rewards: daily, playtime gifts (both daily_claim), offline, zone
	local claimed = false
	local dailyNow, dailyWas = now.daily or {}, was.daily or {}
	if (dailyNow.day or 0) > (dailyWas.day or 0) then
		claimed = true
	end
	local giftsNow, giftsWas = now.gifts or {}, was.gifts or {}
	local giftCount = count(giftsNow.claimed)
	if giftCount > 0 and (giftsNow.day ~= giftsWas.day or giftCount > count(giftsWas.claimed)) then
		claimed = true
	end
	-- yen that came in one go: offline earnings, a zone reward, a sale. Not
	-- read from yen itself: StateController's ticks move the old snapshot's
	-- yen too. A hero gone with no hero gaining a star is a sale (a fuse
	-- removes heroes and raises one's stars).
	local offline = was.offline ~= nil and now.offline == nil
	local zone = count(now.zonesClaimed) > count(was.zonesClaimed)
	local sold = false
	if count(now.heroes) < count(was.heroes) then
		sold = true
		for uid, hero in now.heroes do
			local before = was.heroes[uid]
			if before and (hero.stars or 0) > (before.stars or 0) then
				sold = false
			end
		end
	end
	if claimed then
		Sound:Play("daily_claim")
		coins()
	elseif offline or zone or sold then
		coins()
	elseif (now.luckyThrows or 0) > (was.luckyThrows or 0) then
		-- lucky throws bought (a product; in Studio the test grant)
		bought = true
	end
	if bought then
		Sound:Play("buy_success")
	end
end

-- ------------------------------------------------------------------ env --

-- Server luck: the sting when it starts and the sky over the hub while it
-- runs. Festival Hour: its music. Read once a second as well as on every
-- update, because both simply run out.
function FxController:_followEnv()
	local env = self._state.Env
	if typeof(env) ~= "table" then
		return
	end
	local now = (env.unixNow or 0) + (os.clock() - self._envAt)
	local luckOn = (env.luck or 1) > 1 and (env.luckUntil == nil or env.luckUntil > now)
	if luckOn ~= self._luckOn then
		self._luckOn = luckOn
		if luckOn then
			Sound:Play("server_luck")
			self._luckFx = Vfx.play("ServerLuck_Sky", HUB_SKY, { loop = true })
		elseif self._luckFx then
			self._luckFx.stop()
			self._luckFx = nil
		end
	end
	local festival = env.festival == true and (env.festivalEnds == nil or env.festivalEnds > now)
	Sound:SetFestival(festival)
end

function FxController:KnitStart()
	local state = Knit.GetController("StateController")
	self._state = state

	state:Observe(function(snapshot: any)
		local ok, err = pcall(function()
			Vfx.setLowDetail(snapshot.settings ~= nil and snapshot.settings.lowDetail == true)
			local was = self._last
			if was then
				self:_diff(was, snapshot)
			else
				self._rank = Progress.rank(Config, snapshot.power).index
			end
			self._power = snapshot.power
			self:_followTraining(snapshot)
		end)
		if not ok then
			warn(`[FxController] snapshot moment failed inert: {err}`)
		end
		-- a shallow copy is enough: every snapshot is a new table
		self._last = snapshot
	end)
	state.Ticked:Connect(function(_yen: number, power: number)
		local ok, err = pcall(self._onTick, self, power)
		if not ok then
			warn(`[FxController] tick moment failed inert: {err}`)
		end
	end)
	state.EnvChanged:Connect(function()
		self._envAt = os.clock()
		pcall(self._followEnv, self)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(self._followEnv, self)
		end
	end)
	-- a new character has a new rig: the training loop starts again on it
	player.CharacterAdded:Connect(function()
		self:_stopTraining()
		task.wait(0.5)
		if self._state.State then
			pcall(self._followTraining, self, self._state.State)
		end
	end)
end

return FxController
