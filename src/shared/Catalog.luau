--!strict
local Catalog = {}
Catalog.MaxPlayers = 6
Catalog.QueueSeconds = 20
Catalog.Grid = 9
Catalog.CellSize = 5
Catalog.Needles = {
	{ id = "sewing", name = "Sewing Needle", color = { 210, 220, 232 }, value = 30 },
	{ id = "copper", name = "Copper Curl", color = { 218, 130, 72 }, value = 45 },
	{ id = "garden", name = "Garden Pin", color = { 95, 200, 133 }, value = 60 },
	{ id = "ice", name = "Frost Needle", color = { 92, 207, 239 }, value = 80 },
	{ id = "royal", name = "Royal Thread", color = { 172, 119, 233 }, value = 100 },
	{ id = "sun", name = "Sunburst Needle", color = { 255, 200, 65 }, value = 150 },
}
Catalog.Equipment = {
	rake = {
		name = "Rake",
		prices = { 60, 180, 450 },
		tier = 1,
		description = "Clear 3 / 6 / 10 extra hay per action",
	},
	blower = {
		name = "Leaf blower",
		prices = { 250 },
		tier = 2,
		description = "Also clear neighboring cells",
	},
	magnet = {
		name = "Needle magnet",
		prices = { 150 },
		tier = 1,
		description = "Collect exposed needles within 14 studs",
	},
	collector = {
		name = "Auto rake",
		prices = { 400 },
		tier = 3,
		description = "Clear the nearest hay every 2 seconds",
	},
}
Catalog.EquipmentOrder = { "rake", "magnet", "blower", "collector" }
Catalog.Contracts = {
	{
		id = "starter",
		name = "First handful",
		metric = "hay",
		target = 30,
		coins = 40,
		xp = 25,
		tier = 1,
	},
	{
		id = "clear",
		name = "Clear the field",
		metric = "hay",
		target = 180,
		coins = 120,
		xp = 60,
		tier = 1,
	},
	{
		id = "find",
		name = "Sharp eyes",
		metric = "needles",
		target = 1,
		coins = 90,
		xp = 40,
		tier = 1,
	},
	{
		id = "treasure",
		name = "Lost and found",
		metric = "discoveries",
		target = 1,
		coins = 100,
		xp = 50,
		tier = 2,
	},
	{
		id = "cooperate",
		name = "Helping hands",
		metric = "teamHay",
		target = 300,
		coins = 180,
		xp = 80,
		tier = 2,
	},
	{
		id = "copper",
		name = "Copper commission",
		metric = "copper",
		target = 1,
		coins = 220,
		xp = 100,
		tier = 3,
	},
	{
		id = "haul",
		name = "Big harvest",
		metric = "hay",
		target = 600,
		coins = 350,
		xp = 150,
		tier = 3,
	},
	{
		id = "collector",
		name = "Needle curator",
		metric = "needles",
		target = 5,
		coins = 500,
		xp = 200,
		tier = 4,
	},
}
function Catalog.tier(xp: number): number
	return if xp >= 325 then 4 elseif xp >= 175 then 3 elseif xp >= 100 then 2 else 1
end
export type ContractDefinition = {
	id: string,
	name: string,
	metric: string,
	target: number,
	coins: number,
	xp: number,
	tier: number,
}
function Catalog.contract(id: string): ContractDefinition?
	for _, contract in Catalog.Contracts do
		if contract.id == id then
			return contract
		end
	end
	return nil
end
return Catalog
