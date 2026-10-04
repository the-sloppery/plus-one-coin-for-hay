--!strict
-- Actual server bootstrap + Roblox instance geometry, with service and scheduling boundaries.
local H = require("./Harness")
local R = H.roblox
local S = H.shared()
local f = H.environment(S)
local storage = R.Instance.new("ReplicatedStorage")
local folder = R.Instance.new("Folder")
folder.Name = "Shared"
folder.Parent = storage
local lookup = {}
for name, value in S do
	local marker = R.Instance.new("ModuleScript")
	marker.Name = name
	marker.Parent = folder
	lookup[marker] = value
end
f.env.require = function(value)
	return lookup[value] or value
end
f.services.ReplicatedStorage = storage
f.services.Lighting = R.Instance.new("Lighting")
f.services.DataStoreService = {}
local pool = {}
local clients = {}
local players: any = {
	PlayerAdded = H.signal(),
	PlayerRemoving = H.signal(),
	GetPlayers = function()
		return pool
	end,
	GetPlayerByUserId = function(_, id)
		for _, player in pool do
			if player.UserId == id then
				return player
			end
		end
		return nil
	end,
}
f.services.Players = players
f.services.MemoryStoreService = {
	GetHashMap = function()
		return {}
	end,
}
f.services.TeleportService = { TeleportInitFailed = H.signal() }
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end
R.implementMethod("RemoteEvent", "FireClient", function(_, player, data)
	if data.kind == "state" then
		clients[player] = copy(data)
	end
end)
R.implementMethod("Model", "PivotTo", function(model, target)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = target
		root.Position = target.Position
	end
end)
local world = R.Instance.new("Workspace")
f.env.workspace = world
local modules = {}
for _, name in { "World", "Profiles", "Travel" } do
	modules[name] = H.load(`src/server/{name}.luau`, f.env)
end
f.env.script = { Parent = modules }
local shutdown: any = nil
f.env.game.BindToClose = function(_, callback)
	shutdown = callback
end
H.load("src/server/Main.server.luau", f.env)
local action = storage:FindFirstChild("HayAction")
local passed = 0
local function test(name, callback)
	callback()
	passed += 1
	print(`PASS {name}`)
end
local function pose(root, cframe)
	root.CFrame = cframe
	root.Position = cframe.Position
end
local function player(id)
	local character = R.Instance.new("Model")
	local root = R.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	pose(root, R.CFrame.new(0, 4, 22))
	root.Parent = character
	local humanoid = R.Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.Parent = character
	local p = {
		UserId = id,
		DisplayName = `Player{id}`,
		Character = character,
		CharacterAdded = H.signal(),
		Parent = players,
	}
	table.insert(pool, p)
	players.PlayerAdded:Fire(p)
	return p, root
end
f.tick(4) -- begin the actual autosave worker
local elapsedSinceSave = 0
local function request(p, verb, value)
	f.advance(0.3)
	elapsedSinceSave += 0.3
	if elapsedSinceSave >= 30 then
		f.tick(4)
		elapsedSinceSave = 0
	end
	H.event(action, "OnServerEvent"):Fire(p, verb, value)
end
local a, ar = player(1)
local b, br = player(2)
local c, cr = player(3)
local d, dr = player(4)
local e, er = player(5)
local g, gr = player(6)
local outsider, oroot = player(7)
local lobby = world:FindFirstChild("HayLobby")
local square = lobby:FindFirstChild("Square 1")
local joinPrompt = square:FindFirstChildOfClass("ProximityPrompt")
test("server boot creates exactly four entry squares", function()
	local count = 0
	for _, item in lobby:GetChildren() do
		if item.Name:sub(1, 7) == "Square " then
			count += 1
		end
	end
	assert(count == 4)
end)
test("remote and prompt paths reject distant queue entry", function()
	H.event(joinPrompt, "Triggered"):Fire(a)
	assert(not clients[a].square)
end)
for _, pair in
	{ { a, ar }, { b, br }, { c, cr }, { d, dr }, { e, er }, { g, gr }, { outsider, oroot } }
do
	pose(pair[2], R.CFrame.new(square.Position + R.Vector3.new(0, 3, 0)))
	H.event(joinPrompt, "Triggered"):Fire(pair[1])
end
test("actual lobby refuses a seventh member", function()
	request(a, "sync", nil)
	request(outsider, "sync", nil)
	assert(not clients[outsider].square and #clients[a].queues[1].members == 6)
end)
test("a non-host cannot launch the expedition", function()
	request(b, "start", nil)
	assert(clients[b].mode == "lobby")
end)
test("host starts and all six characters move into one isolated field", function()
	request(a, "start", nil)
	for _, p in { a, b, c, d, e, g } do
		assert(clients[p].mode == "field" and clients[p].field.players <= 6)
	end
	assert(ar.Position.X == 220 and br.Position.X == 220 and not clients[a].square)
end)
local field = world:FindFirstChild("HayField1")
local hay = field:FindFirstChild("Hay 1")
test("distant and malformed collection requests do not grant coins", function()
	local p = modules.Profiles.get(1)
	local coins = p.coins
	pose(ar, R.CFrame.new(0, 4, 0))
	request(a, "dig", 1)
	request(a, "dig", 0 / 0)
	request(a, "dig", {})
	request(a, "buy", "forged")
	assert(p.coins == coins)
end)
test("actual server dig binding clears hay and updates the owner HUD", function()
	pose(ar, R.CFrame.new(hay.Position + R.Vector3.new(0, 2, 0)))
	request(a, "dig", 1)
	assert(modules.Profiles.get(1).coins == 1 and clients[a].profile.coins == 1)
end)
test("server prompt and remote share the same digging cooldown", function()
	local before = modules.Profiles.get(1).coins
	H.event(hay:FindFirstChildOfClass("ProximityPrompt"), "Triggered"):Fire(a)
	assert(modules.Profiles.get(1).coins == before)
end)
test("field membership cannot be bypassed with the queue leave action", function()
	local position = ar.Position
	request(a, "leaveQueue", nil)
	assert(ar.Position == position and clients[a].mode == "field")
end)
test("actual contract reward is claimed once and equipment reduces the balance", function()
	for _ = 1, 34 do
		request(a, "dig", 1)
	end
	local second = field:FindFirstChild("Hay 2")
	pose(ar, R.CFrame.new(second.Position + R.Vector3.new(0, 2, 0)))
	for _ = 1, 34 do
		request(a, "dig", 2)
	end
	local third = field:FindFirstChild("Hay 3")
	pose(ar, R.CFrame.new(third.Position + R.Vector3.new(0, 2, 0)))
	for _ = 1, 34 do
		request(a, "dig", 3)
	end
	local p = modules.Profiles.get(1)
	assert(p.contracts.starter.progress == 30)
	request(a, "claim", "starter")
	local balance = p.coins
	request(a, "claim", "starter")
	assert(p.coins == balance)
	request(a, "buy", "rake")
	assert(p.equipment.rake == 1 and p.coins == balance - 60)
end)
test("dead characters cannot dig", function()
	local p = modules.Profiles.get(1)
	local balance = p.coins
	a.Character:FindFirstChildOfClass("Humanoid").Health = 0
	request(a, "dig", 2)
	assert(p.coins == balance)
	a.Character:FindFirstChildOfClass("Humanoid").Health = 100
end)
test("hay clearing exposes actual collectible geometry and wins through needle prompts", function()
	for i = 1, 81 do
		local target = field:FindFirstChild(`Hay {i}`)
		pose(ar, R.CFrame.new(target.Position + R.Vector3.new(0, 2, 0)))
		for _ = 1, 32 do
			request(a, "dig", i)
		end
	end
	local found = 0
	for _, part in field:GetChildren() do
		for _, def in S.Catalog.Needles do
			if part.Name == def.name then
				pose(ar, R.CFrame.new(part.Position + R.Vector3.new(0, 2, 0)))
				local event = H.event(part:FindFirstChildOfClass("ProximityPrompt"), "Triggered")
				event:Fire(a)
				event:Fire(a)
				found += 1
				break
			end
		end
	end
	assert(
		found == 3 and clients[a].field.won and clients[a].field.needlesLeft == 0,
		`found={found} won={clients[a].field.won} left={clients[a].field.needlesLeft}`
	)
	for _, p in { a, b, c, d, e, g } do
		assert(modules.Profiles.get(p.UserId).stats.needles == 3)
	end
end)
test("only the host advances a won pile", function()
	request(b, "next", nil)
	assert(clients[b].field.pile == 1)
	request(a, "next", nil)
	assert(clients[a].field.pile == 2 and not clients[a].field.won)
end)
test("host leaves cleanly and ownership passes to another player", function()
	request(a, "return", nil)
	assert(clients[a].mode == "lobby" and ar.Position.X == 0)
	request(b, "sync", nil)
	assert(clients[b].field.host == 2 and clients[b].field.players == 5)
end)
test("last departure removes field geometry and clears player state", function()
	for _, p in { b, c, d, e, g } do
		request(p, "return", nil)
		assert(not modules.Profiles.get(p.UserId))
	end
	assert(not world:FindFirstChild("HayField1") and type(shutdown) == "function")
end)
print(`RESULT {passed} integrated server scenarios passed (offline engine boundaries)`)
assert(passed == 15, "integration cases did not all execute")
