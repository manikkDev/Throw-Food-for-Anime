--!strict
-- HudMoments - the animated HUD moments HudController triggers: a toast's
-- entrance and exit, the server announcement banner, the zone label a thrown
-- food shows as it crosses into a new region, the LEVEL UP banner, and the
-- cinematic fade of the HUD groups.
--
-- Everything here is a one-off tween run when a moment starts (no per-frame
-- work of its own; the flares turn on the shared UiFx loop, held only while a
-- moment is on screen). Sounds go through Screens.sound (the SoundController
-- hook), so a role the bank does not have yet is simply silent.

local TweenService = game:GetService("TweenService")

local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local UiFx = require(script.Parent.UiFx)

local HudMoments = {}

local function tween(
	object: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function scaleOf(object: GuiObject, name: string): UIScale
	local found = object:FindFirstChild(name)
	if found and found:IsA("UIScale") then
		return found
	end
	local made = Instance.new("UIScale")
	made.Name = name
	made.Parent = object
	return made
end

local function faceOf(control: GuiObject): GuiObject
	local face = control:FindFirstChild("Face")
	return if face and face:IsA("GuiObject") then face else control
end

-- a shine over the whole face of a panel, swept once
local function shineOver(control: GuiObject, seconds: number?, lean: number?)
	local face = faceOf(control)
	-- inside the face, unless the face lays out its children: then beside it
	local laidOut = face:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
	local shine = if laidOut and face ~= control
		then UiFx.makeShine(face, control)
		else UiFx.makeShine(face, face, true)
	UiFx.sweep(shine, seconds or 0.7, lean)
end

-- the home position of a face, remembered the first time it is animated
local function home(face: GuiObject): UDim2
	local saved = face:GetAttribute("HomePosition")
	if typeof(saved) == "UDim2" then
		return saved
	end
	face:SetAttribute("HomePosition", face.Position)
	return face.Position
end

-- -------------------------------------------------------------------- fade --

-- the properties a fade moves, per instance (their shipped values are kept as
-- attributes the first time, so a fade back in restores exactly the design)
local function fadeProps(object: Instance): { string }
	if object:IsA("UIStroke") then
		return { "Transparency" }
	end
	if not object:IsA("GuiObject") then
		return {}
	end
	local props = { "BackgroundTransparency" }
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		table.insert(props, "TextTransparency")
		table.insert(props, "TextStrokeTransparency")
	elseif object:IsA("ImageLabel") or object:IsA("ImageButton") or object:IsA("ViewportFrame") then
		table.insert(props, "ImageTransparency")
	end
	return props
end

local function shipped(object: Instance, prop: string): number
	local key = "Ship" .. prop
	local value = object:GetAttribute(key)
	if typeof(value) ~= "number" then
		value = (object :: any)[prop]
		object:SetAttribute(key, value)
	end
	return value :: number
end

--- Fade `root` and everything under it in (to its shipped look) or out (to
--- clear) over `seconds` (0 = at once). Shines and glosses are left alone.
local function fadeTree(root: Instance, visible: boolean, seconds: number)
	local function each(object: Instance)
		local props = fadeProps(object)
		if #props == 0 then
			return
		end
		local goal = {}
		for _, prop in props do
			local base = shipped(object, prop)
			goal[prop] = if visible then base else 1
		end
		if seconds <= 0 then
			for prop, value in goal do
				(object :: any)[prop] = value
			end
		else
			tween(object, seconds, goal, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end
	end
	local function walk(object: Instance)
		if object.Name == "Shine" or object.Name == "Gloss" then
			return
		end
		each(object)
		for _, child in object:GetChildren() do
			walk(child)
		end
	end
	walk(root)
end

-- the border stroke of a frame (its rim), if it has one
local function rimOf(object: Instance): UIStroke?
	for _, child in object:GetChildren() do
		if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			return child
		end
	end
	return nil
end

-- ------------------------------------------------------------------ toasts --

export type ToastLook = { color: Color3, icon: string, sound: string }

-- v4.4: one colour per kind, carried by the round icon well and the pill's rim
HudMoments.TOAST = {
	good = { color = Color3.fromHex("2FBF71"), icon = "IconTick", sound = "toast_good" },
	reward = { color = Color3.fromHex("F5A524"), icon = "IconGift", sound = "toast_good" },
	bad = { color = Color3.fromHex("F0524D"), icon = "IconClose", sound = "toast_warn" },
	info = { color = Color3.fromHex("3B82F6"), icon = "IconInfo", sound = "toast_pop" },
} :: { [string]: ToastLook }

local TOAST_NAVY = Color3.fromHex("161A48")
local TOAST_DROP = 14 -- px a toast slides down as it fades in

--- Which look a toast gets: "bad" stays a warning; a "good" one that hands
--- something out (yen, a gift, a reward) is gold, other successes green.
function HudMoments.toastKind(text: string, kind: string?): string
	if kind == "bad" then
		return "bad"
	end
	if kind == "good" then
		local lower = text:lower()
		if
			lower:find("+", 1, true)
			or lower:find("gift", 1, true)
			or lower:find("claimed", 1, true)
			or lower:find("reward", 1, true)
		then
			return "reward"
		end
		return "good"
	end
	if kind == "reward" then
		return "reward"
	end
	return "info"
end

--- Dress and play a toast's entrance (v4.4): a compact pill at the top centre;
--- its well and rim take the kind's colour, it slides down a little and fades
--- in. Nothing bounces, nothing is rotated.
function HudMoments.toastIn(toast: GuiObject, kind: string)
	local look = HudMoments.TOAST[kind] or HudMoments.TOAST.info
	local face = faceOf(toast)
	local well = Screens.frame(toast, "IconWell")
	well.BackgroundColor3 = look.color
	Screens.setIcon(Screens.image(toast, "Icon"), look.icon)
	local rim = rimOf(face)
	if rim then
		rim.Color = look.color:Lerp(TOAST_NAVY, 0.25)
	end
	UiFx.level(toast)
	local at = home(face)
	fadeTree(face, false, 0)
	face.Position = at - UDim2.fromOffset(0, TOAST_DROP)
	tween(face, 0.32, { Position = at }, Enum.EasingStyle.Quint)
	fadeTree(face, true, 0.24)
	Screens.sound(look.sound)
end

--- Play a toast's exit (fades and lifts away); `done` runs after it.
function HudMoments.toastOut(toast: GuiObject, done: () -> ())
	local face = faceOf(toast)
	local at = home(face)
	fadeTree(face, false, 0.2)
	tween(
		face,
		0.22,
		{ Position = at - UDim2.fromOffset(0, 10) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	).Completed:Once(function()
		face.Position = at
		fadeTree(face, true, 0)
		done()
	end)
end

-- ----------------------------------------------------------- announcements --

-- per announcement kind: accent colour and icon (a catch takes its rarity colour)
local ANNOUNCE_LOOK: { [string]: { color: Color3, icon: string } } = {
	catch = { color = Color3.fromHex("FFB020"), icon = "IconCrown" },
	festival = { color = Color3.fromHex("FF5FA2"), icon = "IconGift" },
	luck = { color = Color3.fromHex("2FCB6F"), icon = "IconLuck" },
	rebirth = { color = Color3.fromHex("A35BFF"), icon = "IconRebirth" },
	say = { color = Color3.fromHex("3B82F6"), icon = "IconInfo" },
}
local ANNOUNCE_RARITY_ICON: { [string]: string } = {
	Legendary = "IconCrown",
	Mythic = "IconLuckyThrow",
	Secret = "IconLuckyThrow",
}
local ANNOUNCE_DROP = 26 -- px the bar slides down on its way in

--- Paint the bar for `kind` (and the catch's `rarity`): the accent edges, the
--- end washes, the rim and the portrait rim take the colour; the plate stays
--- dark so the hero name reads first.
function HudMoments.dressAnnouncement(banner: GuiObject, kind: string, rarity: string?)
	local look = ANNOUNCE_LOOK[kind] or ANNOUNCE_LOOK.say
	local color = if kind == "catch" and rarity then Theme.rarity(rarity) else look.color
	if kind == "catch" and rarity == "Secret" then
		color = Color3.fromHex("E9E6FF") -- the secret colour is black: a pale moonlight accent on the dark bar
	end
	for _, name in { "AccentLeft", "AccentRight", "RarityWash" } do
		local part = banner:FindFirstChild(name, true)
		if part and part:IsA("GuiObject") then
			part.BackgroundColor3 = color
		end
	end
	local rim = rimOf(banner)
	if rim then
		rim.Color = color:Lerp(Color3.new(1, 1, 1), 0.3)
	end
	local well = banner:FindFirstChild("PortraitWell", true)
	local wellRim = if well then rimOf(well) else nil
	if wellRim then
		wellRim.Color = color
	end
	local icon = (if kind == "catch" and rarity then ANNOUNCE_RARITY_ICON[rarity] else nil)
		or look.icon
	Screens.setIcon(Screens.image(banner, "AnnounceIcon"), icon)
	UiFx.setRarity(banner, if kind == "catch" then rarity or "Epic" else "Epic")
end

--- The bar's entrance: slides down from the top edge and fades in, then one
--- soft shine crosses it.
function HudMoments.announceIn(banner: GuiObject)
	local at = home(banner)
	UiFx.level(banner)
	fadeTree(banner, false, 0)
	banner.Position = at - UDim2.fromOffset(0, ANNOUNCE_DROP)
	banner.Visible = true
	UiFx.activate("announce", true)
	tween(banner, 0.45, { Position = at }, Enum.EasingStyle.Quint)
	fadeTree(banner, true, 0.3)
	task.delay(0.4, function()
		if banner.Visible then
			-- an upright streak: on a 10:1 bar a leaning one read as the bar tilting
			shineOver(banner, 0.9, 0)
		end
	end)
	Screens.sound("announce")
end

--- The bar's exit: fades as it lifts back up; `done` hides it.
function HudMoments.announceOut(banner: GuiObject, done: () -> ())
	local at = home(banner)
	fadeTree(banner, false, 0.28)
	tween(
		banner,
		0.3,
		{ Position = at - UDim2.fromOffset(0, ANNOUNCE_DROP) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	).Completed:Once(function()
		banner.Position = at
		fadeTree(banner, true, 0)
		UiFx.activate("announce", false)
		done()
	end)
end

-- ------------------------------------------------------------ zone label --

local zoneStamp = 0

local function setTextAlpha(label: TextLabel, alpha: number)
	label.TextTransparency = alpha
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = alpha
	end
end

local function textFade(label: TextLabel, to: number, seconds: number)
	tween(label, seconds, { TextTransparency = to })
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		tween(stroke, seconds, { Transparency = to })
	end
end

--- The region banner a thrown food shows when it crosses into zone `index`,
--- at the TOP centre under the letterbox (below the flight's luck line). It
--- builds suspense: the small "ZONE n" tag drops in first, a beat later the
--- name SLAMS in from big and clear (with an echo that blows outward, like a
--- motion blur), the plate bumps, rays and a glow in the zone colour turn
--- behind it, a sheen crosses. Later zones hype harder: bigger rays, a longer
--- beat and hold, "zone_hype" from zone 4.
function HudMoments.zoneCross(gui: ScreenGui, name: string, color: Color3, index: number)
	local holder = Screens.frame(gui, "ZoneCross")
	local plate = Screens.frame(holder, "ZonePlate")
	local tag = Screens.frame(holder, "ZoneNumber")
	local title = Screens.label(holder, "ZoneTitle")
	local ghost = Screens.label(holder, "ZoneGhost")
	zoneStamp += 1
	local stamp = zoneStamp
	local level = math.clamp(index, 1, 6)
	title.Text = name
	ghost.Text = name
	Screens.label(holder, "ZoneNumberText").Text = `ZONE {index}`
	Screens.tint(plate, color)
	local h, s, v = color:ToHSV()
	UiFx.setColour(holder, Color3.fromHSV(h, s * 0.55, math.min(1, v + 0.25)))
	UiFx.setRarity(
		holder,
		if index >= 6
			then "Mythic"
			elseif index >= 5 then "Legendary"
			elseif index >= 3 then "Epic"
			else "Rare"
	)
	-- later zones: a bigger flare
	local rays = Screens.image(holder, "Rays")
	local raysHome = rays:GetAttribute("HomeSize")
	if typeof(raysHome) ~= "UDim2" then
		raysHome = rays.Size
		rays:SetAttribute("HomeSize", raysHome)
	end
	local grow = 0.8 + 0.1 * level
	local homeSize = raysHome :: UDim2
	rays.Size = UDim2.fromOffset(homeSize.X.Offset * grow, homeSize.Y.Offset * grow)
	UiFx.activate("zone", true)

	local at = home(holder)
	local pop = scaleOf(holder, "SlamScale")
	local titleScale = scaleOf(title, "SlamScale")
	local ghostScale = scaleOf(ghost, "EchoScale")
	local tagScale = scaleOf(tag, "DropScale")
	-- v4.3 (owner's review 4): the food crosses a gate fast, so the banner is
	-- readable on its FIRST frame: everything appears at full opacity and slams
	-- in by scale only (no text fade in), holds, then eases out.
	UiFx.level(holder)
	holder.Position = at
	pop.Scale = 1.18
	tagScale.Scale = 1.25
	titleScale.Scale = 1.22 + 0.03 * level
	setTextAlpha(title, 0)
	setTextAlpha(ghost, 0.35)
	ghostScale.Scale = 1
	holder.Visible = true
	tween(pop, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(titleScale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(tagScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	-- the echo blows outward and fades (a motion-blur feel), a sheen crosses
	tween(ghostScale, 0.35, { Scale = 1.5 })
	textFade(ghost, 1, 0.35)
	shineOver(plate, 0.6)
	Screens.sound("zone_cross")
	Screens.sound("banner_slam")
	if index >= 4 then
		Screens.sound("zone_hype")
	end
	local hold = 1.5 + level * 0.12
	task.delay(hold, function()
		if zoneStamp ~= stamp then
			return
		end
		tween(pop, 0.22, { Scale = 0.8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		textFade(title, 1, 0.2)
		tween(
			holder,
			0.22,
			{ Position = at - UDim2.fromOffset(0, 24) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		).Completed:Once(function()
			if zoneStamp == stamp then
				holder.Visible = false
				holder.Position = at
				pop.Scale = 1
				UiFx.activate("zone", false)
			end
		end)
	end)
end

-- --------------------------------------------------------------- level up --

local levelStamp = 0
local LEVEL_GOLD = Color3.fromHex("FFB830")

-- the medallion icon for a banner, from its title
local function levelIcon(title: string): string
	local t = title:upper()
	if t:find("REBIRTH") then
		return "IconRebirth"
	elseif t:find("RANK") then
		return "IconPower"
	elseif t:find("GEAR") then
		return "IconTrain"
	elseif t:find("FOOD") then
		return "IconShop"
	elseif t:find("SLOT") then
		return "IconPlace"
	end
	return "IconStar"
end

--- THE celebratory banner (rank up, rebirth; one per moment, never also a
--- toast): ONE glossy plate at the top centre, in the empty band under
--- Roblox's top bar, so it never covers the character. The small title sits
--- over the big item name INSIDE the plate; an icon medallion on its left end.
--- It slams down from the top with a bump, rays and a glow turn behind it,
--- sparkles twinkle, a sheen crosses it twice; it eases out upward.
function HudMoments.levelUp(gui: ScreenGui, title: string, sub: string, color: Color3?)
	local holder = Screens.frame(gui, "LevelUp")
	local plate = Screens.frame(holder, "LevelPlate")
	local medal = Screens.frame(holder, "LevelMedal")
	levelStamp += 1
	local stamp = levelStamp
	local titleLabel = Screens.label(holder, "LevelTitle")
	local subLabel = Screens.label(holder, "LevelSub")
	-- one line only when there is no item name: the title takes the big line
	if sub == "" then
		titleLabel.Text = ""
		subLabel.Text = title
	else
		titleLabel.Text = title
		subLabel.Text = sub
	end
	local tint = color or LEVEL_GOLD
	Screens.tint(plate, tint)
	local h, s, v = tint:ToHSV()
	UiFx.setColour(holder, Color3.fromHSV(h, s * 0.5, math.min(1, v + 0.3)))
	Screens.setIcon(Screens.image(medal, "LevelIcon"), levelIcon(title))
	UiFx.setRarity(holder, "Epic")
	UiFx.activate("level", true)

	local at = home(holder)
	local pop = scaleOf(holder, "PopScale")
	local medalPop = scaleOf(medal, "MedalPop")
	UiFx.level(holder)
	holder.Position = at - UDim2.fromOffset(0, 130)
	pop.Scale = 1.15
	medalPop.Scale = 0
	holder.Visible = true
	-- the slam: falls fast, lands with a squash, settles
	tween(holder, 0.26, { Position = at }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Once(
		function()
			if levelStamp ~= stamp then
				return
			end
			pop.Scale = 0.94
			tween(pop, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(medalPop, 0.45, { Scale = 1 }, Enum.EasingStyle.Elastic)
			shineOver(plate, 0.8)
			Screens.sound("level_up")
		end
	)
	Screens.sound("banner_slam")
	task.delay(1.5, function()
		if levelStamp == stamp then
			shineOver(plate, 0.8)
		end
	end)
	task.delay(2.8, function()
		if levelStamp ~= stamp then
			return
		end
		tween(pop, 0.3, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(
			holder,
			0.3,
			{ Position = at - UDim2.fromOffset(0, 140) },
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		).Completed:Once(function()
			if levelStamp == stamp then
				holder.Visible = false
				holder.Position = at
				pop.Scale = 1
				UiFx.activate("level", false)
			end
		end)
	end)
end

-- --------------------------------------------------------------- the fade --

type Snap = { inst: Instance, prop: string, value: number }

-- every visible transparency under (and on) `root`, as it is now
local function snapshot(root: Instance): { Snap }
	local out: { Snap } = {}
	local function add(inst: Instance, prop: string, value: number)
		if value < 1 then
			table.insert(out, { inst = inst, prop = prop, value = value })
		end
	end
	local function look(inst: Instance)
		if inst:IsA("GuiObject") then
			add(inst, "BackgroundTransparency", inst.BackgroundTransparency)
			if inst:IsA("ImageLabel") or inst:IsA("ImageButton") or inst:IsA("ViewportFrame") then
				add(inst, "ImageTransparency", (inst :: any).ImageTransparency)
			elseif inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				add(inst, "TextTransparency", inst.TextTransparency)
			end
		elseif inst:IsA("UIStroke") then
			add(inst, "Transparency", inst.Transparency)
		end
	end
	look(root)
	for _, d in root:GetDescendants() do
		look(d)
	end
	return out
end

export type Fade = { snaps: { [GuiObject]: { Snap } }, tweens: { Tween } }

function HudMoments.newFade(): Fade
	return { snaps = {}, tweens = {} }
end

local function cancel(fade: Fade)
	for _, t in fade.tweens do
		t:Cancel()
	end
	table.clear(fade.tweens)
end

--- Fade `groups` out over `seconds` (their transparencies are remembered);
--- `done` runs at the end. The groups stay Visible: the caller hides them.
function HudMoments.fadeOut(fade: Fade, groups: { GuiObject }, seconds: number, done: () -> ())
	cancel(fade)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, group in groups do
		local snaps = fade.snaps[group]
		if not snaps then
			snaps = snapshot(group)
			fade.snaps[group] = snaps
		end
		for _, snap in snaps do
			local t = TweenService:Create(snap.inst, info, { [snap.prop] = 1 })
			table.insert(fade.tweens, t)
			t:Play()
		end
	end
	local count = #fade.tweens
	task.delay(seconds, function()
		if #fade.tweens == count then
			done()
		end
	end)
end

--- Put every remembered transparency back at once (the groups are hidden).
function HudMoments.restore(fade: Fade)
	cancel(fade)
	for _, snaps in fade.snaps do
		for _, snap in snaps do
			(snap.inst :: any)[snap.prop] = snap.value
		end
	end
end

--- Fade `groups` back in from clear to what they were.
function HudMoments.fadeIn(fade: Fade, groups: { GuiObject }, seconds: number)
	cancel(fade)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, group in groups do
		local snaps = fade.snaps[group]
		if snaps then
			for _, snap in snaps do
				local t = TweenService:Create(snap.inst, info, { [snap.prop] = snap.value })
				table.insert(fade.tweens, t)
				t:Play()
			end
		end
	end
	-- the next fade-out takes a fresh snapshot (the HUD may have changed)
	task.delay(seconds, function()
		table.clear(fade.snaps)
	end)
end

--- Start the fade-in from fully clear (call after the groups are visible).
function HudMoments.clear(fade: Fade, groups: { GuiObject })
	for _, group in groups do
		local snaps = fade.snaps[group]
		if snaps then
			for _, snap in snaps do
				(snap.inst :: any)[snap.prop] = 1
			end
		end
	end
end

return HudMoments
