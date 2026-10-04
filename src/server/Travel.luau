--!strict
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Admission = require(Shared.Admission)
type Transfer = {
	options: TeleportOptions,
	attempts: number,
	expires: number,
	sessionId: string,
	busy: boolean,
}
local pending: { [Player]: Transfer } = {}
local returning: { [Player]: number } = {}
local Travel = {}
local map = if RunService:IsStudio() then nil else MemoryStoreService:GetHashMap(Config.SessionMap)
local failureHandler: (Player, string) -> () = function(_player: Player, _message: string) end
function Travel.configure(handler: (Player, string) -> ())
	failureHandler = handler
end
local function failed(player: Player, message: string)
	if not pending[player] then
		return
	end
	pending[player] = nil
	if player.Parent == Players then
		failureHandler(player, message)
	end
end
local function attempt(player: Player, transfer: Transfer)
	if pending[player] ~= transfer or transfer.busy or player.Parent ~= Players then
		return
	end
	if transfer.attempts >= 3 or os.clock() > transfer.expires then
		failed(player, "Travel failed. Join a square to try again.")
		return
	end
	transfer.busy = true
	transfer.attempts += 1
	local ok = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, transfer.options)
	end)
	transfer.busy = false
	if not ok then
		task.delay(2, function()
			attempt(player, transfer)
		end)
	end
end
function Travel.launch(players: { Player }, host: number): boolean
	if not map then
		return false
	end
	if #players < 1 or #players > 6 then
		return false
	end
	local sessionId = HttpService:GenerateGUID(false)
	local ids: { number } = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	local ok, accessCode = pcall(function()
		local code = TeleportService:ReserveServerAsync(game.PlaceId)
		map:SetAsync(
			sessionId,
			{ ids = ids, host = host, sourcePlace = game.PlaceId, expires = os.time() + 180 },
			180
		)
		return code
	end)
	if not ok then
		return false
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	-- Only a routing ID crosses TeleportData; inventory and authority stay server-side.
	options:SetTeleportData({ haySession = sessionId })
	for _, player in players do
		pending[player] = {
			options = options,
			attempts = 1,
			expires = os.clock() + 30,
			sessionId = sessionId,
			busy = true,
		}
	end
	local sent = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players, options)
	end)
	for _, player in players do
		local transfer = pending[player]
		if transfer then
			transfer.busy = false
			if not sent then
				task.delay(2, function()
					attempt(player, transfer)
				end)
			end
		end
	end
	return true
end
function Travel.admit(player: Player): Admission.Manifest?
	if not map then
		return nil
	end
	local join = player:GetJoinData()
	local data: any = join.TeleportData
	if
		type(data) ~= "table"
		or type(data.haySession) ~= "string"
		or #data.haySession > 64
		or join.SourcePlaceId ~= game.PlaceId
	then
		return nil
	end
	local ok, manifest = pcall(function()
		return map:GetAsync(data.haySession)
	end)
	if ok and Admission.valid(manifest, player.UserId, game.PlaceId, os.time()) then
		return manifest
	end
	return nil
end
function Travel.returnToLobby(player: Player): boolean
	-- No reserved options: matchmaking sends returning players to a public lobby.
	returning[player] = os.clock() + 30
	local ok = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player })
	end)
	if not ok then
		returning[player] = nil
	end
	return ok
end
TeleportService.TeleportInitFailed:Connect(function(player, _, _, placeId)
	local transfer = pending[player]
	if placeId == game.PlaceId and transfer then
		task.delay(2, function()
			attempt(player, transfer)
		end)
	end
	if placeId == game.PlaceId and returning[player] then
		returning[player] = nil
		failureHandler(player, "Return travel failed. You can try again.")
	end
end)
Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
	returning[player] = nil
end)
task.spawn(function()
	while true do
		task.wait(1)
		for player, transfer in pending do
			if os.clock() > transfer.expires then
				failed(player, "Travel timed out. Join a square to try again.")
			end
		end
		for player, deadline in returning do
			if os.clock() > deadline then
				returning[player] = nil
				failureHandler(player, "Return timed out. You can try again.")
			end
		end
	end
end)
return Travel
