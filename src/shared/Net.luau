--!strict
-- Net - the ONLY networking transport for gameplay and cross-client paths.
--
-- Knit's auto-generated remotes are deliberately NOT used here. When play-mode
-- introspection is unreachable, the most primitive debuggable transport wins:
-- one folder of plain RemoteEvents, created server-side, awaited client-side,
-- every name declared in this file and nowhere else.
--
-- Server: Net.server("EventName") -> RemoteEvent (creates on first use)
-- Client: Net.client("EventName") -> RemoteEvent? (nil on timeout - callers
--         must fail inert, never error)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "ThrowFoodForAnimeNet"
local CLIENT_WAIT_TIMEOUT = 10

-- Every remote in the game is declared here. A name not on this list is a bug.
-- Client -> server remotes are REQUESTS: the server validates and may ignore.
export type EventName =
	-- client -> server: "my controllers are up, send me my state". Sent once.
	"ClientReady"
	-- client -> server: (charge: number 0..1, useLuckyThrow: boolean). The
	-- server decides the zone, the roll and the grant; nothing else is trusted.
	| "ThrowRequest"
	-- client -> server: (on: boolean) start or stop training on the dojo pad.
	| "TrainSet"
	-- client -> server: (kind: "food" | "gear" | "slot", id: string?) spend Yen.
	| "ShopBuy"
	-- client -> server: (foodId: string) equip a food already owned.
	| "FoodEquip"
	-- client -> server: (action: "place" | "bench" | "sell" | "equipBest" |
	-- "fuse", uid: string?, slot: number?) manage owned heroes.
	| "SquadAction"
	-- client -> server: (action: "claimZone" | "rebirth", zoneId: string?).
	| "ProgressAction"
	-- client -> server: (kind: "daily" | "gift" | "code" | "offline", arg).
	| "RewardClaim"
	-- client -> server: (key: string, value) one setting; also tutorial step.
	| "SettingSet"
	-- client -> server: (targetUserId: number, passKey: string) who the next
	-- gift purchase is for. The grant itself only ever happens in ProcessReceipt.
	| "StoreGiftTarget"
	-- client -> server: (command: string, arg) owner-only event controls, and
	-- Studio-only test grants. Refused for everyone else.
	| "AdminCommand"
	-- server -> ONE client: the whole view of that player's saved state.
	-- Sent on join and whenever something other than Yen/Power changes.
	| "StateSnapshot"
	-- server -> ONE client: (yen, power, serverNow) once a second, so the
	-- counters move without resending the whole state.
	| "StateTick"
	-- server -> ONE client: every plot in the server, on join.
	| "PlotsSnapshot"
	-- server -> ALL clients: (plotIndex, plotState | nil) one plot changed or
	-- was freed. Clients build hero rigs from this; the server spawns none.
	| "PlotUpdate"
	-- server -> the THROWER: the full result of a throw (zone, landing point,
	-- hero, odds, placement). Separate from ThrowSeen because only the thrower
	-- gets the camera, the odds and the placement.
	| "ThrowResult"
	-- server -> everyone ELSE: a lighter "food flew, hero appeared" for others.
	| "ThrowSeen"
	-- server -> ONE client: heroes granted outside a throw (store, gifts), so
	-- the client can play a reveal for each.
	| "HeroGranted"
	-- server -> ONE client: (text: string, kind: string) a short notice.
	| "Toast"
	-- server -> ALL clients: a rare-catch banner or an event message.
	| "Announce"
	-- server -> ALL clients: server luck and Festival Hour state.
	| "EnvUpdate"
	-- server -> ALL clients: the three leaderboards' cached top lists.
	| "Leaderboards"

local Net = {}

local function serverFolder(): Folder
	assert(RunService:IsServer(), "Net.server is server-only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

--- Server side: get (or create) the RemoteEvent for `name`.
function Net.server(name: EventName): RemoteEvent
	local folder = serverFolder()
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

--- Client side: wait for the RemoteEvent for `name`. Returns nil rather than
--- erroring, so a missing remote degrades one feature instead of the client.
function Net.client(name: EventName): RemoteEvent?
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_WAIT_TIMEOUT)
	if not folder then
		warn(`[Net] no {FOLDER_NAME} folder after {CLIENT_WAIT_TIMEOUT}s`)
		return nil
	end
	local remote = folder:WaitForChild(name, CLIENT_WAIT_TIMEOUT)
	if not remote or not remote:IsA("RemoteEvent") then
		warn(`[Net] remote {name} never arrived`)
		return nil
	end
	return remote
end

return Net
