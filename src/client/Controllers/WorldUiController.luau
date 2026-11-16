--!strict
-- WorldUiController - the authored signs that live in the world: the three
-- leaderboards in the hub and the slot sign on the player's own plot.
--
-- The map's anchors are found by name (Workspace.Map.Hub.Board<X>,
-- Workspace.Map.Plots.Plot<i>.SlotSign); the guis are this client's own
-- clones, adorned to those parts. The plain text the server's blockout writes
-- on the same parts is switched off locally, on this client only. An anchor
-- that is missing (or replaced when the map is rebuilt) is looked for again
-- every couple of seconds: nothing here can error into gameplay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Screens = require(script.Parent.Parent.Ui.Screens)

local ROWS = 10 -- Row1..10 ship in the Leaderboard tree
local RESCAN_SECONDS = 2

-- board key (as the server sends it) -> its anchor part in the hub, its title
-- each board's own look: header colour, icon and subtitle (the v4 board ships gold + crown)
local BOARDS: { [string]: { anchor: string, title: string, colour: string, icon: string, sub: string } } =
	{
		yen = {
			anchor = "BoardYen",
			title = "MOST YEN",
			colour = "FFB13D",
			icon = "IconYenBig",
			sub = "Yen earned",
		},
		caught = {
			anchor = "BoardCaught",
			title = "MOST CAUGHT",
			colour = "38BDF8",
			icon = "IconSquadBig",
			sub = "Heroes caught",
		},
		rarest = {
			anchor = "BoardRarest",
			title = "RAREST CATCH",
			colour = "A855F7",
			icon = "IconCrownBig",
			sub = "Rarest hero caught",
		},
	}
local SIGN_FACES = { Enum.NormalId.Front, Enum.NormalId.Back }

type Mount = { part: BasePart, guis: { SurfaceGui } }

local WorldUiController = Knit.CreateController({
	Name = "WorldUiController",
	_state = nil :: any,
	_boards = {} :: { [string]: Mount },
	_sign = nil :: Mount?,
})

-- Put a clone of a SurfaceGui tree on one face of a part, keeping the tree's
-- proportions when the face has another shape (the content stays centred).
local function mount(part: BasePart, tree: string, face: Enum.NormalId): SurfaceGui?
	local gui = Screens.world(tree)
	if not gui or not gui:IsA("SurfaceGui") then
		return nil
	end
	local size = part.Size
	local width = if face == Enum.NormalId.Left or face == Enum.NormalId.Right
		then size.Z
		else size.X
	local height = if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom
		then size.Z
		else size.Y
	local canvas = gui.CanvasSize
	if width > 0 and height > 0 then
		local wide = canvas.Y * width / height
		gui.CanvasSize = if wide >= canvas.X
			then Vector2.new(wide, canvas.Y)
			else Vector2.new(canvas.X, canvas.X * height / width)
	end
	gui.Face = face
	gui.Adornee = part
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

local function unmount(made: Mount?)
	if made then
		for _, gui in made.guis do
			gui:Destroy()
		end
	end
end

local function anchor(...: string): BasePart?
	local node: Instance? = workspace
	for _, name in { ... } do
		node = node and node:FindFirstChild(name)
	end
	return if node and node:IsA("BasePart") then node else nil
end

function WorldUiController:_paintBoard(key: string)
	local made = self._boards[key]
	if not made then
		return
	end
	local boards = self._state.Boards
	local data = if boards then boards[key] else nil
	local rows = if data and data.rows then data.rows else {}
	local look = BOARDS[key]
	for _, gui in made.guis do
		if not gui:GetAttribute("Painted") then
			gui:SetAttribute("Painted", true)
			pcall(function()
				Screens.tint(Screens.frame(gui, "BoardHeader"), Color3.fromHex(look.colour))
				Screens.setIcon(Screens.image(gui, "BoardIcon"), look.icon)
				Screens.label(gui, "BoardSub").Text = look.sub
			end)
		end
		Screens.label(gui, "BoardTitle").Text = if data and data.title
			then tostring(data.title)
			else BOARDS[key].title
		for index = 1, ROWS do
			local row = Screens.frame(gui, "Row" .. index)
			local entry = rows[index]
			row.Visible = entry ~= nil
			Screens.label(row, "RankText").Text = if entry then tostring(entry.rank) else ""
			Screens.label(row, "PlayerName").Text = if entry then tostring(entry.name) else ""
			Screens.label(row, "Score").Text = if entry then tostring(entry.text) else ""
			-- IconKey=PlayerHeadshot: the player's own thumbnail, not an icon
			Screens.image(row, "Avatar").Image = if entry and entry.userId
				then `rbxthumb://type=AvatarHeadShot&id={entry.userId}&w=48&h=48`
				else ""
		end
	end
end

function WorldUiController:_paintSign()
	local made = self._sign
	local state = self._state.State
	if not made or not state then
		return
	end
	local cost = Progress.nextSlotCost(Config, state.slots - (state.bonusSlots or 0))
	for _, gui in made.guis do
		Screens.label(gui, "FromTo").Text = if cost
			then `SLOT {state.slots} -> {state.slots + 1}`
			else `ALL {state.slots} SLOTS OPEN`
		Screens.label(gui, "Price").Text = if cost then Format.short(cost) else "MAX"
		Screens.label(gui, "BuyPrompt").Text = if not cost
			then ""
			elseif state.yen >= cost then "Buy this slot here!"
			else "Not enough yen"
	end
end

-- find the anchors (again): mount what appeared, drop what went away
function WorldUiController:_scan()
	for key, board in BOARDS do
		local part = anchor("Map", "Hub", board.anchor)
		local made = self._boards[key]
		if made and made.part ~= part then
			unmount(made)
			self._boards[key] = nil
			made = nil
		end
		if part and not made then
			local old = part:FindFirstChild("Board")
			-- the blockout's own board faces Back; ours goes where it was
			local face = if old and old:IsA("SurfaceGui") then old.Face else Enum.NormalId.Back
			local gui = mount(part, "Leaderboard", face)
			if gui then
				if old and old:IsA("SurfaceGui") then
					old.Enabled = false
				end
				self._boards[key] = { part = part, guis = { gui } }
				self:_paintBoard(key)
			end
		end
	end

	local state = self._state.State
	local part = if state and state.plot
		then anchor("Map", "Plots", "Plot" .. state.plot, "SlotSign")
		else nil
	local sign = self._sign
	if sign and sign.part ~= part then
		unmount(sign)
		self._sign = nil
		sign = nil
	end
	if part and not sign then
		local guis = {}
		for _, face in SIGN_FACES do
			local gui = mount(part, "SlotSign", face)
			if gui then
				table.insert(guis, gui)
			end
		end
		if #guis > 0 then
			local old = part:FindFirstChild("Title")
			-- the map's own title (a billboard on the blockout, a face GUI on the kit sign)
			-- would draw through ours
			if old and (old:IsA("BillboardGui") or old:IsA("SurfaceGui")) then
				old.Enabled = false
			end
			self._sign = { part = part, guis = guis }
			self:_paintSign()
		end
	end
end

function WorldUiController:KnitStart()
	self._state = Knit.GetController("StateController")
	Screens.init()

	self._state.BoardsChanged:Connect(function()
		for key in BOARDS do
			self:_paintBoard(key)
		end
	end)
	self._state:Observe(function()
		self:_paintSign()
	end)
	self._state.Ticked:Connect(function()
		self:_paintSign()
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				self:_scan()
			end)
			if not ok then
				warn(`[WorldUiController] scan failed inert: {err}`)
			end
			task.wait(RESCAN_SECONDS)
		end
	end)
end

return WorldUiController
