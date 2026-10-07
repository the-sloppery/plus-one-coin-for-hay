--!strict
local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog)
local World = {}
export type Field = {
	model: Model,
	origin: Vector3,
	cells: { BasePart },
	needles: { [number]: BasePart },
	spawn: CFrame,
	sign: TextLabel,
}
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function label(p: BasePart, text: string): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 100)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 100
	gui.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamBold
	l.TextSize = 22
	l.TextColor3 = Color3.fromRGB(255, 244, 211)
	l.TextStrokeTransparency = 0.3
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(48, 54, 39)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = l
	l.Parent = gui
	return l
end
local function prompt(p: BasePart, text: string, callback: (Player) -> ())
	local item = Instance.new("ProximityPrompt")
	item.ActionText = text
	item.ObjectText = p.Name
	item.HoldDuration = 0.15
	item.MaxActivationDistance = 12
	item.RequiresLineOfSight = false
	item.Parent = p
	item.Triggered:Connect(callback)
end
function World.lobby(join: (Player, number) -> ())
	local model = Instance.new("Model")
	model.Name = "HayLobby"
	model.Parent = workspace
	part(
		model,
		"Village lawn",
		Vector3.new(100, 1, 100),
		Vector3.new(0, -0.5, 0),
		Color3.fromRGB(102, 143, 90)
	).Material =
		Enum.Material.Grass
	part(
		model,
		"Courtyard",
		Vector3.new(52, 0.2, 58),
		Vector3.new(0, 0.1, 0),
		Color3.fromRGB(205, 185, 148)
	).Material =
		Enum.Material.Cobblestone
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(6, 0.2, 6)
	spawn.Position = Vector3.new(0, 0.3, 21)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = model
	label(
		part(
			model,
			"Welcome",
			Vector3.new(24, 6, 1),
			Vector3.new(0, 7, -25),
			Color3.fromRGB(61, 83, 58)
		),
		"+1 COIN FOR HAY\nPick a square • Bring up to 5 friends"
	)
	local pads: { BasePart } = {}
	local labels: { TextLabel } = {}
	local colors = {
		Color3.fromRGB(225, 163, 66),
		Color3.fromRGB(87, 169, 157),
		Color3.fromRGB(149, 129, 199),
		Color3.fromRGB(205, 119, 103),
	}
	for i = 1, 4 do
		local x = if i % 2 == 1 then -13 else 13
		local z = if i <= 2 then -10 else 8
		local p =
			part(model, `Square {i}`, Vector3.new(16, 0.4, 14), Vector3.new(x, 0.4, z), colors[i])
		p.Material = Enum.Material.Neon
		local beacon = Instance.new("PointLight")
		beacon.Name = "FieldBeacon"
		beacon.Color = colors[i]
		beacon.Brightness = 0.45
		beacon.Range = 12
		beacon.Shadows = false
		beacon.Parent = p
		pads[i] = p
		labels[i] = label(p, `FIELD {i}\n0 / 6 • Walk in`)
		prompt(p, "Join expedition", function(player)
			join(player, i)
		end)
	end
	for i = 1, 8 do
		local x = if i <= 4 then -37 else 37
		local z = (i % 4) * 16 - 24
		part(
			model,
			"Tree trunk",
			Vector3.new(2, 9, 2),
			Vector3.new(x, 4, z),
			Color3.fromRGB(103, 76, 48)
		).Material =
			Enum.Material.Wood
		part(
			model,
			"Tree canopy",
			Vector3.new(12, 10, 12),
			Vector3.new(x, 12, z),
			Color3.fromRGB(67, 109, 65)
		).Shape =
			Enum.PartType.Ball
	end
	return pads, labels
end
function World.cellPosition(origin: Vector3, index: number): Vector3
	local x = (index - 1) % Catalog.Grid - 4
	local z = math.floor((index - 1) / Catalog.Grid) - 4
	return origin + Vector3.new(x * Catalog.CellSize, 0, z * Catalog.CellSize)
end
function World.field(
	id: number,
	origin: Vector3,
	dig: (Player, number) -> (),
	throw: (Player, BasePart) -> ()
): Field
	local model = Instance.new("Model")
	model.Name = `HayField{id}`
	model.Parent = workspace
	part(
		model,
		"Meadow",
		Vector3.new(88, 1, 94),
		origin - Vector3.new(0, 0.5, 0),
		Color3.fromRGB(103, 141, 76)
	).Material =
		Enum.Material.Grass
	part(model, "Pile foundation", Vector3.new(48, 0.2, 48), origin, Color3.fromRGB(130, 96, 52)).Material =
		Enum.Material.Ground
	local cells: { BasePart } = {}
	for i = 1, Catalog.Grid * Catalog.Grid do
		local p = part(
			model,
			`Hay {i}`,
			Vector3.new(4.8, 4, 4.8),
			World.cellPosition(origin, i) + Vector3.new(0, 2, 0),
			Color3.fromRGB(218, 176, 77)
		)
		p.Material = Enum.Material.Sand
		p:SetAttribute("CellIndex", i)
		p:SetAttribute("FieldId", id)
		prompt(p, "Clear hay (+1 coin)", function(player)
			dig(player, i)
		end)
		cells[i] = p
		for strand = 1, 4 do
			local straw = part(
				p,
				`Straw{strand}`,
				Vector3.new(0.12, 0.12, 4.4),
				p.Position + Vector3.new(strand - 2.5, 2.1, 0),
				Color3.fromRGB(249, 213, 119)
			)
			straw.CanCollide = false
			straw.Material = Enum.Material.Wood
			straw:SetAttribute("Strand", strand)
		end
	end
	for side = -1, 1, 2 do
		for j = -3, 3 do
			part(
				model,
				"Fence post",
				Vector3.new(0.7, 4, 0.7),
				origin + Vector3.new(side * 36, 2, j * 12),
				Color3.fromRGB(140, 103, 58)
			).Material =
				Enum.Material.Wood
		end
		part(
			model,
			"Fence rail",
			Vector3.new(0.5, 0.5, 78),
			origin + Vector3.new(side * 36, 2.6, 0),
			Color3.fromRGB(166, 125, 68)
		).Material =
			Enum.Material.Wood
	end
	local stall = part(
		model,
		"Equipment & contracts",
		Vector3.new(12, 4, 6),
		origin + Vector3.new(-16, 2, 33),
		Color3.fromRGB(48, 102, 90)
	)
	label(stall, "CONTRACTS + EQUIPMENT\nUse the field journal")
	local sign = label(
		part(
			model,
			"Expedition board",
			Vector3.new(12, 5, 1),
			origin + Vector3.new(16, 3, 34),
			Color3.fromRGB(86, 64, 43)
		),
		"Search every corner"
	)
	for i = 1, 4 do
		local p = part(
			model,
			"Throwable hay bale",
			Vector3.new(3, 2, 2),
			origin + Vector3.new(i * 5 - 10, 2, -33),
			Color3.fromRGB(220, 184, 96)
		)
		p.Anchored = false
		p:SetAttribute("FieldId", id)
		prompt(p, "Toss bale", function(player)
			throw(player, p)
		end)
	end
	-- A discoverable ornament away from the main pile.
	local boot = part(
		model,
		"Lost farmer's boot",
		Vector3.new(2, 1.5, 3),
		origin + Vector3.new(29, 1, -29),
		Color3.fromRGB(79, 62, 45)
	)
	boot:SetAttribute("FieldId", id)
	return {
		model = model,
		origin = origin,
		cells = cells,
		needles = {},
		spawn = CFrame.new(origin + Vector3.new(0, 4, 31)),
		sign = sign,
	}
end
function World.update(field: Field, round: any, collect: (Player, number) -> ())
	field.sign.Text =
		`PILE {round.number}\n{round.needlesLeft} needles left • {round.remaining} hay`
	for i, cell in round.cells do
		local p = field.cells[i]
		local height = math.max(0.2, math.min(8, cell.initial / 6) * cell.hay / cell.initial)
		p.Size = Vector3.new(4.8, height, 4.8)
		p.Position = World.cellPosition(field.origin, i) + Vector3.new(0, height / 2, 0)
		p.Transparency = if cell.hay == 0 then 1 else 0
		p.CanCollide = cell.hay > 0
		for _, straw in p:GetChildren() do
			if straw:IsA("BasePart") then
				local strand = straw:GetAttribute("Strand")
				assert(type(strand) == "number", "Straw needs numeric strand index")
				straw.CFrame = CFrame.new(
					World.cellPosition(field.origin, i) + Vector3.new(strand - 2.5, height + 0.1, 0)
				) * CFrame.Angles(0, math.rad(strand * 9 - 18), 0)
				straw.Transparency = p.Transparency
			end
		end
		local digPrompt = p:FindFirstChildOfClass("ProximityPrompt")
		if digPrompt then
			digPrompt.Enabled = cell.hay > 0
		end
		if cell.needle and cell.hay == 0 and not cell.collected and not field.needles[i] then
			local def = Catalog.Needles[cell.needle]
			local needle = part(
				field.model,
				def.name,
				Vector3.new(0.22, 2.4, 0.22),
				World.cellPosition(field.origin, i) + Vector3.new(0, 1.4, 0),
				Color3.fromRGB(table.unpack(def.color))
			)
			needle.Material = Enum.Material.Neon
			needle.CanCollide = false
			local eye = part(
				needle,
				"Needle eye",
				Vector3.new(0.65, 0.65, 0.18),
				needle.Position + Vector3.new(0, 1.3, 0),
				needle.Color
			)
			eye.Shape = Enum.PartType.Ball
			eye.CanCollide = false
			label(needle, def.name)
			prompt(needle, "Collect needle", function(player)
				collect(player, i)
			end)
			field.needles[i] = needle
		end
		if cell.collected and field.needles[i] then
			field.needles[i]:Destroy()
			field.needles[i] = nil
		end
	end
end
function World.resetNeedles(field: Field)
	for _, needle in field.needles do
		needle:Destroy()
	end
	table.clear(field.needles)
end
return World
