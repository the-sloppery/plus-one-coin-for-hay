--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Shared = ReplicatedStorage.Shared
local Catalog = require(Shared.Catalog)
local Queue = require(Shared.Queue)
local State = require(Shared.GameState)
local Config = require(Shared.Config)
local World = require(script.Parent.World)
local Profiles = require(script.Parent.Profiles)
local Travel = require(script.Parent.Travel)
type Session = {
	id: number,
	host: number,
	members: { Player },
	round: State.Round,
	field: World.Field,
	bootFound: boolean,
}
local studio = RunService:IsStudio()
local reserved = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 and not studio
local action = Instance.new("RemoteEvent")
action.Name = "HayAction"
action.Parent = ReplicatedStorage
local update = Instance.new("RemoteEvent")
update.Name = "HayState"
update.Parent = ReplicatedStorage
local queues: { Queue.Queue } = { Queue.new(), Queue.new(), Queue.new(), Queue.new() }
local queueOf: { [Player]: number } = {}
local sessionOf: { [Player]: Session } = {}
local sessions: { [number]: Session } = {}
local outgoing: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}
local lastDig: { [Player]: number } = {}
local pads: { BasePart } = {}
local padLabels: { TextLabel } = {}
local closing = false
Lighting.ClockTime = 15
Lighting.Brightness = 2.5
Lighting.Ambient = Color3.fromRGB(155, 145, 113)
local function message(player: Player, text: string)
	update:FireClient(player, { kind = "message", text = text })
end
local function root(player: Player): BasePart?
	local found = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if found and found:IsA("BasePart") then found else nil
end
local function inRange(player: Player, position: Vector3, distance: number): boolean
	local r = root(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return r ~= nil
		and humanoid ~= nil
		and humanoid.Health > 0
		and (r.Position - position).Magnitude <= distance
end
local function move(player: Player, target: CFrame)
	if player.Character then
		player.Character:PivotTo(target)
	end
end
local function queueSnapshot()
	local result = {}
	for i, q in queues do
		local members = {}
		for _, id in q.members do
			local player = Players:GetPlayerByUserId(id)
			table.insert(
				members,
				{ id = id, name = if player then player.DisplayName else "Leaving" }
			)
		end
		local seconds = if q.deadline then math.max(0, math.ceil(q.deadline - os.clock())) else 0
		result[i] = { members = members, host = q.host, seconds = seconds, capacity = q.capacity }
		if padLabels[i] then
			padLabels[i].Text = `FIELD {i}\n{#members} / {q.capacity} • {if #members > 0
				then tostring(seconds) .. "s"
				else "Walk in"}`
		end
	end
	return result
end
local function push(player: Player)
	local session = sessionOf[player]
	local p = Profiles.get(player.UserId)
	local snapshot: any = {
		kind = "state",
		studio = studio,
		mode = if outgoing[player] then "travel" elseif session then "field" else "lobby",
		queues = queueSnapshot(),
		square = queueOf[player],
	}
	if p then
		snapshot.profile = p
	end
	if session then
		snapshot.field = {
			host = session.host,
			pile = session.round.number,
			remaining = session.round.remaining,
			total = session.round.total,
			needlesLeft = session.round.needlesLeft,
			won = session.round.won,
			players = #session.members,
		}
	end
	update:FireClient(player, snapshot)
end
local function profiles(session: Session): { State.Profile }
	local list = {}
	for _, player in session.members do
		local p = Profiles.get(player.UserId)
		if p then
			table.insert(list, p)
		end
	end
	return list
end
local function collect(player: Player, index: number)
	local session = sessionOf[player]
	if
		not session
		or outgoing[player]
		or not Profiles.get(player.UserId)
		or not inRange(player, World.cellPosition(session.field.origin, index), 14)
	then
		return
	end
	local needle = State.collect(session.round, profiles(session), index)
	if needle then
		for _, member in session.members do
			message(member, `Needle found! {needle} added to your collection.`)
		end
		World.update(session.field, session.round, collect)
		for _, member in session.members do
			push(member)
		end
	end
end
-- Keep all world needles bound to this authoritative collector.
local function refresh(session: Session)
	World.update(session.field, session.round, collect)
	for _, player in session.members do
		push(player)
	end
end
local function digCell(player: Player, session: Session, index: number, automated: boolean?): number
	local p = Profiles.get(player.UserId)
	if not p then
		return 0
	end
	local cell = session.round.cells[index]
	if not cell then
		return 0
	end
	local discovery = cell.discovery
	local amount = State.dig(session.round, p, index, automated)
	if amount > 0 then
		for _, member in session.members do
			local other = Profiles.get(member.UserId)
			if other and member ~= player then
				State.progress(other, "teamHay", amount)
			end
		end
		if discovery and not cell.discovery then
			message(player, "Hidden keepsake discovered! +50 coins")
		end
	end
	return amount
end
local function dig(player: Player, index: number)
	local session = sessionOf[player]
	if
		not session
		or outgoing[player]
		or not inRange(player, World.cellPosition(session.field.origin, index), 14)
	then
		return
	end
	local now = os.clock()
	if now - (lastDig[player] or -1) < 0.2 then
		return
	end
	lastDig[player] = now
	local removed = digCell(player, session, index)
	local p = Profiles.get(player.UserId)
	if p and (p.equipment.blower or 0) > 0 and removed > 0 then
		for _, neighbor in { index - 1, index + 1, index - Catalog.Grid, index + Catalog.Grid } do
			if
				neighbor >= 1
				and neighbor <= #session.round.cells
				and (World.cellPosition(session.field.origin, neighbor) - World.cellPosition(
						session.field.origin,
						index
					)).Magnitude
					< 6
			then
				digCell(player, session, neighbor, true)
			end
		end
	end
	if removed > 0 then
		refresh(session)
	end
end
local function toss(player: Player, bale: BasePart)
	local session = sessionOf[player]
	local r = root(player)
	if
		not session
		or outgoing[player]
		or not Profiles.get(player.UserId)
		or not r
		or not bale:IsDescendantOf(session.field.model)
		or not inRange(player, bale.Position, 12)
	then
		return
	end
	local now = os.clock()
	if now - (lastDig[player] or -1) < 0.4 then
		return
	end
	lastDig[player] = now
	bale:SetNetworkOwner(nil)
	bale.AssemblyLinearVelocity = r.CFrame.LookVector * 45 + Vector3.new(0, 22, 0)
	bale.AssemblyAngularVelocity = Vector3.new(3, 6, 2)
end
local function makeSession(id: number, host: number): Session
	local origin = Vector3.new(id * 220, 0, 0)
	local field = World.field(id, origin, dig, toss)
	local session = {
		id = id,
		host = host,
		members = {},
		round = State.round(1, math.random(1, 1000000)),
		field = field,
		bootFound = false,
	}
	sessions[id] = session
	local boot = field.model:FindFirstChild("Lost farmer's boot")
	if boot and boot:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Investigate"
		prompt.MaxActivationDistance = 10
		prompt.Parent = boot
		prompt.Triggered:Connect(function(player)
			local p = Profiles.get(player.UserId)
			if
				sessionOf[player] == session
				and p
				and not session.bootFound
				and inRange(player, boot.Position, 12)
			then
				session.bootFound = true
				p.coins += 50
				State.progress(p, "discoveries", 1)
				message(player, "You found the farmer's lost boot! +50 coins")
				push(player)
				boot:Destroy()
			end
		end)
	end
	refresh(session)
	return session
end
local function enter(player: Player, session: Session)
	if #session.members >= Catalog.MaxPlayers or sessionOf[player] then
		return
	end
	local profile = Profiles.load(player.UserId)
	if not profile then
		message(player, "Your save is unavailable or open elsewhere. Please rejoin shortly.")
		return
	end
	if player.Parent ~= Players then
		Profiles.release(player.UserId)
		return
	end
	if profile.stats.hay == nil then
		State.accept(profile, "starter")
	end
	table.insert(session.members, player)
	sessionOf[player] = session
	queueOf[player] = nil
	move(player, session.field.spawn)
	push(player)
end
local function leaveQueue(player: Player)
	local index = queueOf[player]
	if index then
		Queue.leave(queues[index], player.UserId)
		queueOf[player] = nil
	end
end
local function join(player: Player, index: number)
	if
		reserved
		or outgoing[player]
		or sessionOf[player]
		or queueOf[player] == index
		or not pads[index]
	then
		return
	end
	if not inRange(player, pads[index].Position, 13) then
		return
	end
	if #queues[index].members >= queues[index].capacity then
		message(player, "This square is full")
		return
	end
	leaveQueue(player)
	if Queue.join(queues[index], player.UserId, os.clock()) then
		queueOf[player] = index
		push(player)
	end
end
local function launch(index: number, requester: number?)
	local q = queues[index]
	local ids = Queue.take(q, os.clock(), requester)
	if not ids then
		return
	end
	local group: { Player } = {}
	for _, id in ids do
		local player = Players:GetPlayerByUserId(id)
		if player then
			table.insert(group, player)
			queueOf[player] = nil
			outgoing[player] = true
			push(player)
		end
	end
	queues[index] = Queue.new()
	if #group == 0 then
		return
	end
	if studio then
		local id = index
		while sessions[id] do
			id += 4
		end
		local session = makeSession(id, ids[1])
		for _, player in group do
			enter(player, session)
			outgoing[player] = nil
			push(player)
		end
	elseif not Travel.launch(group, ids[1]) then
		for _, player in group do
			outgoing[player] = nil
			message(player, "Could not reserve a field. Try again shortly.")
			push(player)
		end
	end
end
Travel.configure(function(player, text)
	outgoing[player] = nil
	message(player, text)
	push(player)
end)
if not reserved then
	pads, padLabels = World.lobby(join)
end
local function leaveField(player: Player)
	local session = sessionOf[player]
	if not session then
		return
	end
	-- Freeze mutations before yielding to persist the latest profile and release its lease.
	sessionOf[player] = nil
	local at = table.find(session.members, player)
	if at then
		table.remove(session.members, at)
	end
	if session.host == player.UserId then
		session.host = if session.members[1] then session.members[1].UserId else 0
	end
	if not Profiles.release(player.UserId) then
		message(player, "Save failed. Your save may remain locked for up to two minutes.")
	end
	if #session.members == 0 then
		session.field.model:Destroy()
		sessions[session.id] = nil
	else
		refresh(session)
	end
end
action.OnServerEvent:Connect(function(player: Player, verb: any, value: any)
	local now = os.clock()
	if
		closing
		or type(verb) ~= "string"
		or #verb > 24
		or now - (lastRequest[player] or -1) < 0.08
	then
		return
	end
	lastRequest[player] = now
	if verb == "sync" then
		push(player)
		return
	end
	if outgoing[player] then
		return
	end
	if verb == "leaveQueue" and sessionOf[player] then
		return
	end
	if verb == "leaveQueue" then
		leaveQueue(player)
		move(player, CFrame.new(0, 4, 22))
		push(player)
		return
	end
	local square = queueOf[player]
	if verb == "start" and square then
		launch(square, player.UserId)
		return
	end
	if
		verb == "capacity"
		and square
		and type(value) == "number"
		and value == value
		and math.abs(value) < 10
	then
		Queue.capacity(queues[square], player.UserId, value)
		push(player)
		return
	end
	local session, p = sessionOf[player], Profiles.get(player.UserId)
	if not session or not p then
		return
	end
	if
		verb == "dig"
		and type(value) == "number"
		and value == value
		and value % 1 == 0
		and value >= 1
		and value <= 81
	then
		dig(player, value)
		return
	end
	if verb == "accept" or verb == "claim" or verb == "buy" then
		if type(value) ~= "string" or #value > 24 then
			return
		end
		local success = if verb == "accept"
			then State.accept(p, value)
			elseif verb == "claim" then State.claim(p, value)
			else State.buy(p, value)
		message(
			player,
			if success
				then "Journal updated"
				else "Not available yet. Check coins, tier and progress."
		)
		push(player)
	elseif verb == "next" and session.host == player.UserId and session.round.won then
		World.resetNeedles(session.field)
		session.round = State.round(session.round.number + 1, math.random(1, 1000000))
		refresh(session)
	elseif verb == "return" then
		if studio then
			leaveField(player)
			move(player, CFrame.new(0, 4, 22))
			push(player)
		else
			-- Freeze gameplay while saving and traveling; failed travel restores this field.
			outgoing[player] = true
			if Profiles.save(player.UserId) and Travel.returnToLobby(player) then
				push(player)
			else
				outgoing[player] = nil
				message(player, "Could not save or travel. Please try again.")
			end
		end
	end
end)
local admittedHost: number? = nil
local function added(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				leaveQueue(player)
			end)
		end
		if character:WaitForChild("HumanoidRootPart", 10) then
			local session = sessionOf[player]
			move(player, if session then session.field.spawn else CFrame.new(0, 4, 22))
		end
	end)
	if reserved then
		local manifest = Travel.admit(player)
		if not manifest or (admittedHost and admittedHost ~= manifest.host) then
			player:Kick("Join this expedition from a lobby square.")
			return
		end
		admittedHost = manifest.host
		local session = sessions[1] or makeSession(1, manifest.host)
		enter(player, session)
		if not sessionOf[player] then
			player:Kick("Your save is unavailable. Rejoin after its previous session closes.")
		end
		task.delay(30, function()
			if sessions[1] == session then
				local host = Players:GetPlayerByUserId(session.host)
				if not host or sessionOf[host] ~= session then
					session.host = if session.members[1] then session.members[1].UserId else 0
					refresh(session)
				end
			end
		end)
	end
	push(player)
end
Players.PlayerAdded:Connect(added)
Players.PlayerRemoving:Connect(function(player)
	leaveQueue(player)
	leaveField(player)
	outgoing[player] = nil
	lastRequest[player] = nil
	lastDig[player] = nil
end)
for _, player in Players:GetPlayers() do
	task.spawn(added, player)
end
task.spawn(function()
	while not closing do
		task.wait(0.5)
		if not reserved then
			for _, player in Players:GetPlayers() do
				if not queueOf[player] and not sessionOf[player] and not outgoing[player] then
					local r = root(player)
					if r then
						for i, pad in pads do
							local offset = r.Position - pad.Position
							if
								math.abs(offset.X) < 8
								and math.abs(offset.Z) < 7
								and math.abs(offset.Y) < 8
							then
								join(player, i)
								break
							end
						end
					end
				end
			end
			for i, q in queues do
				if q.deadline and os.clock() >= q.deadline then
					launch(i, nil)
				end
			end
		end
		for _, player in Players:GetPlayers() do
			push(player)
		end
	end
end)
task.spawn(function()
	while not closing do
		task.wait(2)
		for player, session in sessionOf do
			local p, r = Profiles.get(player.UserId), root(player)
			if p and r and not outgoing[player] then
				if (p.equipment.collector or 0) > 0 then
					local closest, distance = 0, 14
					for i, cell in session.round.cells do
						local d = (r.Position - World.cellPosition(session.field.origin, i)).Magnitude
						if cell.hay > 0 and d < distance then
							closest = i
							distance = d
						end
					end
					if closest > 0 then
						digCell(player, session, closest, true)
						refresh(session)
					end
				end
				if (p.equipment.magnet or 0) > 0 then
					for i, cell in session.round.cells do
						if cell.hay == 0 and cell.needle and not cell.collected then
							collect(player, i)
						end
					end
				end
			end
		end
		for _, session in sessions do
			for _, child in session.field.model:GetChildren() do
				if
					child:IsA("BasePart")
					and not child.Anchored
					and (child.Position - session.field.origin).Magnitude > 75
				then
					child.CFrame = CFrame.new(session.field.origin + Vector3.new(0, 3, -33))
					child.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end
end)
task.spawn(function()
	while not closing do
		task.wait(Config.SaveSeconds)
		for player in sessionOf do
			if not Profiles.save(player.UserId) then
				message(player, "Save service unavailable. Retrying on the next autosave.")
				if not Profiles.get(player.UserId) then
					player:Kick("Save ownership expired. Please rejoin to protect your progress.")
				end
			end
		end
	end
end)
game:BindToClose(function()
	closing = true
	local count = 0
	for player in sessionOf do
		count += 1
		task.spawn(function()
			Profiles.release(player.UserId)
			count -= 1
		end)
	end
	local deadline = os.clock() + 25
	while count > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)
