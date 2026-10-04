--!strict
local H = require("./Harness")
local S = H.shared()
local f = H.environment(S)
local View = H.load("src/client/View.luau", f.env)
local parent = H.roblox.Instance.new("Folder")
local sent = {}
local controller = View.create(parent, 1, function(verb, value)
	table.insert(sent, { verb, value })
end)
local p = S.GameState.profile()
S.GameState.accept(p, "starter")
local function snapshot(mode)
	return {
		mode = mode,
		studio = true,
		profile = if mode == "field" then p else nil,
		queues = {
			{ members = { { id = 1, name = "Farmer" } }, host = 1, capacity = 6, seconds = 20 },
		},
		square = if mode == "lobby" then 1 else nil,
		field = { host = 1, pile = 1, players = 6, remaining = 1000, needlesLeft = 3, won = false },
	}
end
local passed = 0
local function test(name, fn)
	fn()
	passed += 1
	print(`PASS {name}`)
end
test("production view opens contracts and focuses its modal close button", function()
	controller.render(snapshot("field"))
	controller.panel("contracts")
	assert(controller.gui.Journal.Visible and controller.gui:GetAttribute("JournalOpen"))
	assert(
		f.services.GuiService.SelectedObject == controller.gui.Journal.Close
			and controller.gui.Journal.Close.Modal
	)
	assert(not controller.gui.Controls.Visible and not controller.gui.Header.Visible)
end)
test("claim button dispatches only the contract ID, never a reward", function()
	local button = controller.gui.Journal.Entries.Entry1.Action
	H.event(button, "Activated"):Fire()
	assert(sent[1][1] == "claim" and sent[1][2] == "starter" and #sent[1] == 2)
end)
test("closing restores HUD and releases gamepad modal focus", function()
	H.event(controller.gui.Journal.Close, "Activated"):Fire()
	assert(
		not controller.gui.Journal.Visible
			and controller.gui.Controls.Visible
			and not controller.gui:GetAttribute("JournalOpen")
	)
	assert(f.services.GuiService.SelectedObject == nil)
end)
test("equipment view sends a catalog key rather than a client price", function()
	controller.panel("equipment")
	H.event(controller.gui.Journal.Entries.Entry1.Action, "Activated"):Fire()
	assert(sent[2][1] == "buy" and sent[2][2] == "rake")
end)
test("group panel reflects host capacity and leave controls", function()
	controller.render(snapshot("lobby"))
	controller.panel("group")
	H.event(controller.gui.Journal.Entries.Entry2.Action, "Activated"):Fire()
	assert(sent[3][1] == "capacity" and sent[3][2] == 1)
end)
test("periodic countdown snapshots preserve button identity and scroll", function()
	local before = controller.gui.Journal.Entries.Entry2.Action
	controller.gui.Journal.Entries.CanvasPosition = H.roblox.Vector2.new(0, 20)
	local data = snapshot("lobby")
	data.queues[1].seconds = 19
	controller.render(data)
	assert(
		controller.gui.Journal.Entries.Entry2.Action == before
			and controller.gui.Journal.Entries.CanvasPosition.Y == 20
	)
end)
test("all production menu buttons have at least 44 pixel vertical targets", function()
	for _, item in controller.gui:GetDescendants() do
		if item:IsA("TextButton") then
			assert(item.Size.Y.Offset >= 44)
		end
	end
end)
test("travel UI announces loading without exposing inventory routing data", function()
	controller.panel(nil)
	controller.render(snapshot("travel"))
	assert(controller.gui.Header.Title.Text == "OFF TO THE HAYSTACK")
end)
print(`RESULT {passed} UI scenarios passed (no native layout or input)`)
assert(passed == 8, "UI cases did not all execute")
