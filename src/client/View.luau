--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local View = {}
local GuiService = game:GetService("GuiService")
local cream = Color3.fromRGB(255, 246, 219)
local ink = Color3.fromRGB(48, 54, 39)
local green = Color3.fromRGB(42, 91, 75)
local HttpService = game:GetService("HttpService")
local function frame(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = f
	return f
end
local function text(
	parent: Instance,
	name: string,
	value: string,
	size: UDim2,
	pos: UDim2,
	color: Color3,
	fontSize: number
): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Text = value
	t.Size = size
	t.Position = pos
	t.BackgroundTransparency = 1
	t.TextColor3 = color
	t.Font = Enum.Font.GothamBold
	t.TextSize = fontSize
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = parent
	return t
end
local function button(
	parent: Instance,
	name: string,
	value: string,
	size: UDim2,
	pos: UDim2,
	callback: () -> ()
): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = value
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = green
	b.TextColor3 = cream
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextWrapped = true
	b.AutoButtonColor = true
	b.BorderSizePixel = 0
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	b.Activated:Connect(callback)
	return b
end
export type Controller = {
	gui: ScreenGui,
	render: (any) -> (),
	notify: (string) -> (),
	panel: (string?) -> (),
}
function View.create(parent: Instance, userId: number, send: (string, any?) -> ()): Controller
	local gui = Instance.new("ScreenGui")
	gui.Name = "HayJournal"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = parent
	local hud = frame(gui, "Header", UDim2.new(1, -24, 0, 68), UDim2.fromOffset(12, 10), cream)
	local title = text(
		hud,
		"Title",
		"+1 COIN FOR HAY",
		UDim2.new(0.62, -16, 0, 30),
		UDim2.fromOffset(12, 6),
		green,
		19
	)
	local subtitle = text(
		hud,
		"Status",
		"Choose one of the four squares",
		UDim2.new(0.62, -16, 0, 26),
		UDim2.fromOffset(12, 36),
		ink,
		12
	)
	local coins = text(
		hud,
		"Coins",
		"Ready to explore?",
		UDim2.new(0.38, -16, 1, -12),
		UDim2.new(0.62, 4, 0, 6),
		ink,
		15
	)
	coins.TextXAlignment = Enum.TextXAlignment.Right
	local hint = text(
		gui,
		"Hint",
		"Walk onto a colored square to form an expedition.",
		UDim2.new(1, -40, 0, 42),
		UDim2.fromOffset(20, 84),
		cream,
		14
	)
	hint.TextStrokeTransparency = 0.3
	hint.TextXAlignment = Enum.TextXAlignment.Center
	local controls =
		frame(gui, "Controls", UDim2.new(0.88, 0, 0, 50), UDim2.new(0.06, 0, 1, -110), cream)
	local controlLimit = Instance.new("UISizeConstraint")
	controlLimit.MaxSize = Vector2.new(500, 50)
	controlLimit.Parent = controls
	controls.AnchorPoint = Vector2.new(0.5, 0)
	controls.Position = UDim2.new(0.5, 0, 0, 84)
	hint.Position = UDim2.fromOffset(20, 140)
	local state: any = { mode = "lobby", queues = {} }
	local selected: string? = nil
	local modal =
		frame(gui, "Journal", UDim2.fromScale(0.92, 0.72), UDim2.new(0.5, 0, 0.5, 12), cream)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Visible = false
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(620, 620)
	limit.Parent = modal
	local heading = text(
		modal,
		"Heading",
		"FIELD JOURNAL",
		UDim2.new(1, -80, 0, 42),
		UDim2.fromOffset(16, 8),
		green,
		20
	)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Entries"
	scroll.Size = UDim2.new(1, -24, 1, -66)
	scroll.Position = UDim2.fromOffset(12, 58)
	scroll.ClipsDescendants = true
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = modal
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	local notice =
		text(gui, "Notice", "", UDim2.new(0.9, 0, 0, 46), UDim2.new(0.5, 0, 1, -166), cream, 15)
	notice.AnchorPoint = Vector2.new(0.5, 0)
	notice.TextXAlignment = Enum.TextXAlignment.Center
	notice.TextStrokeTransparency = 0.3
	local generation = 0
	local function notify(value: string)
		generation += 1
		local token = generation
		notice.Text = value
		task.delay(5, function()
			if generation == token then
				notice.Text = ""
			end
		end)
	end
	local function row(
		name: string,
		detail: string,
		label: string?,
		callback: (() -> ())?,
		order: number
	)
		local f = frame(
			scroll,
			`Entry{order}`,
			UDim2.new(1, -8, 0, 112),
			UDim2.fromOffset(0, 0),
			Color3.fromRGB(242, 229, 192)
		)
		f.LayoutOrder = order
		text(f, "Name", name, UDim2.new(1, -20, 0, 25), UDim2.fromOffset(10, 6), ink, 17)
		text(f, "Detail", detail, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 32), ink, 12)
		if label and callback then
			button(f, "Action", label, UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 62), callback)
		end
	end
	local draw: () -> ()
	local function panel(name: string?)
		selected = name
		modal.Visible = name ~= nil
		hud.Visible = name == nil
		hint.Visible = name == nil
		controls.Visible = name == nil
		gui:SetAttribute("JournalOpen", name ~= nil)
		local closeButton = modal:FindFirstChild("Close")
		if closeButton and closeButton:IsA("TextButton") then
			GuiService.SelectedObject = if name then closeButton else nil
		end
		draw()
	end
	local close = button(
		modal,
		"Close",
		"×",
		UDim2.fromOffset(44, 44),
		UDim2.new(1, -52, 0, 6),
		function()
			panel(nil)
		end
	)
	close.Modal = true -- visible journal captures touch input and hides movement controls
	button(
		controls,
		"JournalButton",
		"Journal",
		UDim2.new(0.333, -8, 0, 44),
		UDim2.fromOffset(4, 3),
		function()
			panel(if selected == "contracts" then nil else "contracts")
		end
	)
	button(
		controls,
		"EquipmentButton",
		"Equipment",
		UDim2.new(0.333, -8, 0, 44),
		UDim2.new(0.333, 4, 0, 3),
		function()
			panel(if selected == "equipment" then nil else "equipment")
		end
	)
	local groupButton = button(
		controls,
		"GroupButton",
		"Expedition",
		UDim2.new(0.334, -8, 0, 44),
		UDim2.new(0.666, 4, 0, 3),
		function()
			panel(if selected == "group" then nil else "group")
		end
	)
	draw = function()
		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if not selected then
			return
		end
		local p = state.profile
		if selected == "contracts" then
			heading.Text = "CONTRACTS & COLLECTION"
			if not p then
				row(
					"Field journal",
					"Start an expedition to see contracts and your collection.",
					nil,
					nil,
					1
				)
				return
			end
			for i, def in Catalog.Contracts do
				local active = p.contracts[def.id]
				local label = if active and active.complete
					then "Completed"
					elseif active and active.progress >= def.target then "Claim reward"
					elseif active then `{active.progress} / {def.target}`
					elseif Catalog.tier(p.xp) < def.tier then `Unlock at tier {def.tier}`
					else "Accept contract"
				row(
					def.name,
					`{def.target} {def.metric} • {def.coins} coins + {def.xp} XP`,
					label,
					function()
						send(if active then "claim" else "accept", def.id)
					end,
					i
				)
			end
			for i, def in Catalog.Needles do
				row(
					def.name,
					`Collected: {p.collection[def.id] or 0} • Team reward: {def.value} coins`,
					nil,
					nil,
					8 + i
				)
			end
		elseif selected == "equipment" then
			heading.Text = "EQUIPMENT SHED"
			if not p then
				row(
					"Pack light",
					"Start an expedition to earn coins and buy equipment.",
					nil,
					nil,
					1
				)
				return
			end
			for i, id in Catalog.EquipmentOrder do
				local def = Catalog.Equipment[id]
				local level = p.equipment[id] or 0
				local price = def.prices[level + 1]
				row(
					`{def.name} • Level {level}`,
					def.description,
					if price then `Buy • {price} coins • Tier {def.tier}` else "Fully upgraded",
					function()
						send("buy", id)
					end,
					i
				)
			end
		elseif selected == "group" then
			heading.Text = "YOUR EXPEDITION"
			if state.mode == "field" then
				row(
					`Pile {state.field.pile} • {state.field.players} players`,
					`{state.field.needlesLeft} needles left • {state.field.remaining} hay`,
					if state.field.won then "Next pile (host)" else "Keep searching",
					function()
						send("next", nil)
					end,
					1
				)
				row(
					"Back to the village",
					"Your progress is saved in published games.",
					"Return to lobby",
					function()
						send("return", nil)
						panel(nil)
					end,
					2
				)
			elseif state.mode == "travel" then
				row(
					"Loading your field…",
					"Your group is traveling to its own server.",
					nil,
					nil,
					1
				)
			elseif state.square then
				local q = state.queues[state.square]
				local names = {}
				for _, member in q.members do
					table.insert(names, member.name)
				end
				row(
					`Square {state.square} • {#q.members} / {q.capacity}`,
					table.concat(names, ", "),
					if q.host == userId then "Start now" else "Waiting for host",
					function()
						send("start", nil)
					end,
					1
				)
				if q.host == userId then
					for capacity = 1, 6 do
						row(
							`Party size: {capacity}`,
							"The countdown starts when the first player joins.",
							`Set maximum to {capacity}`,
							function()
								send("capacity", capacity)
							end,
							capacity + 1
						)
					end
				end
				row(
					"Leave square",
					"Step into another square to create a new party.",
					"Leave queue",
					function()
						send("leaveQueue", nil)
						panel(nil)
					end,
					8
				)
			else
				for i, q in state.queues do
					row(
						`Square {i}`,
						`{#q.members} / {q.capacity} players • Walk into the square to join`,
						nil,
						nil,
						i
					)
				end
			end
		end
	end
	local function render(snapshot: any)
		local old = state
		state = snapshot
		groupButton.Text = if state.mode == "lobby" and state.square
			then `Square {state.square}`
			else "Expedition"
		if state.mode == "field" and state.profile then
			title.Text = `PILE {state.field.pile} • {state.field.needlesLeft} NEEDLES`
			subtitle.Text = `{state.field.remaining} hay • {state.field.players} players`
			coins.Text =
				`{state.profile.coins} coins\nTier {Catalog.tier(state.profile.xp)} • {state.profile.xp} XP`
			hint.Text = if state.field.won
				then "All needles found! Host: open Expedition for the next pile."
				else "Clear hay • Collect exposed needles • Claim contracts • Upgrade"
		elseif state.mode == "travel" then
			title.Text = "OFF TO THE HAYSTACK"
			subtitle.Text = "Preparing your private field"
			coins.Text = "Traveling…"
			hint.Text = "Your expedition is loading."
		else
			title.Text = "+1 COIN FOR HAY"
			coins.Text = if state.studio
				then "Studio practice\nProgress is temporary"
				else "Up to 6 friends"
			subtitle.Text = "Choose one of the four squares"
			local q = state.square and state.queues[state.square]
			hint.Text = if q
				then `Square {state.square} • {#q.members}/{q.capacity} • Starts in {q.seconds}s`
				else "Walk onto a colored square to form an expedition."
		end
		-- Preserve scroll position and button focus while periodic queue snapshots arrive.
		local changed = old.mode ~= state.mode or old.square ~= state.square
		if selected == "group" and state.square and old.square == state.square then
			local before, after = old.queues[state.square], state.queues[state.square]
			changed = changed
				or not before
				or before.host ~= after.host
				or #before.members ~= #after.members
				or before.capacity ~= after.capacity
		end
		if selected and old.profile and state.profile then
			changed = changed
				or HttpService:JSONEncode(old.profile) ~= HttpService:JSONEncode(state.profile)
		end
		if changed then
			draw()
		end
	end
	return { gui = gui, render = render, notify = notify, panel = panel }
end
return View
