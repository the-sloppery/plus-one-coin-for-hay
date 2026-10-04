--!strict
-- Exports production World and View code with explicit no-physics/service fixtures for RHR.
local fs = require("@lune/fs")
local H = require("../tests/Harness")
local S = H.shared()
local f = H.environment(S)
local roblox = H.roblox
local workspace = roblox.Instance.new("Workspace")
f.env.workspace = workspace
local World = H.load("src/server/World.luau", f.env)
World.lobby(function() end)
local field = World.field(1, roblox.Vector3.new(110, 0, 0), function() end, function() end)
local round = S.GameState.round(1, 42)
for i = 1, 12 do
	round.cells[i].hay = 0
end
World.update(field, round, function() end)
local process = require("@lune/process")
fs.writeDir("outputs/render")
for _, instance in workspace:GetDescendants() do
	-- Lune stores Position separately; straw is already authored with CFrame.
	if instance:IsA("BasePart") and not instance:GetAttribute("Strand") then
		local ok, position = pcall(function()
			return instance.Position
		end)
		if ok then
			instance.CFrame = roblox.CFrame.new(position) * instance.CFrame.Rotation
		end
	end
	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		instance.FontFace = roblox.Font.fromEnum(instance.Font)
	end
end
fs.writeFile("outputs/render/world.rbxm", roblox.serializeModel(workspace:GetChildren()))
fs.writeFile(
	"outputs/render/lobby-scene.rbxm",
	roblox.serializeModel({ workspace:FindFirstChild("HayLobby") })
)
fs.writeFile("outputs/render/field-scene.rbxm", roblox.serializeModel({ field.model }))
local view = H.load("src/client/View.luau", f.env)
local folder = roblox.Instance.new("Folder")
local p = S.GameState.profile()
p.coins = 180
p.xp = 125
S.GameState.accept(p, "clear")
local controller = view.create(folder, 1, function() end)
local mode = process.args[1] or "lobby"
controller.render({
	mode = if mode == "lobby" then "lobby" else "field",
	studio = true,
	queues = { { members = { { id = 1, name = "Farmer" } }, host = 1, capacity = 6, seconds = 20 } },
	square = if mode == "lobby" then 1 else nil,
	profile = if mode ~= "lobby" then p else nil,
	field = {
		host = 1,
		pile = 1,
		players = 3,
		remaining = round.remaining,
		total = round.total,
		needlesLeft = round.needlesLeft,
		won = false,
	},
})
if mode == "contracts" or mode == "equipment" or mode == "group" then
	controller.panel(mode)
end
for _, instance in controller.gui:GetDescendants() do
	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		instance.FontFace = roblox.Font.fromEnum(instance.Font)
	end
end
fs.writeFile(`outputs/render/{mode}.rbxm`, roblox.serializeModel({ controller.gui }))
print(`Exported actual production geometry and {mode} UI`)
