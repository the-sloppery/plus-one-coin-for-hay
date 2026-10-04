--!strict
local Catalog = require(script.Parent.Catalog)
export type Contract = { progress: number, complete: boolean }
export type Profile = {
	version: number,
	coins: number,
	xp: number,
	equipment: { [string]: number },
	collection: { [string]: number },
	contracts: { [string]: Contract },
	stats: { [string]: number },
}
export type Cell = {
	hay: number,
	initial: number,
	needle: number?,
	collected: boolean,
	discovery: boolean,
}
export type Round = {
	cells: { Cell },
	number: number,
	remaining: number,
	total: number,
	needlesLeft: number,
	won: boolean,
}
local GameState = {}
function GameState.profile(): Profile
	return {
		version = 1,
		coins = 0,
		xp = 0,
		equipment = {},
		collection = {},
		contracts = {},
		stats = {},
	}
end
local function finiteInteger(value: any, max: number): boolean
	return type(value) == "number"
		and value == value
		and value >= 0
		and value <= max
		and value % 1 == 0
end
function GameState.validProfile(p: any): boolean
	if
		type(p) ~= "table"
		or p.version ~= 1
		or not finiteInteger(p.coins, 1e12)
		or not finiteInteger(p.xp, 1e9)
	then
		return false
	end
	for _, key in { "equipment", "collection", "contracts", "stats" } do
		if type(p[key]) ~= "table" then
			return false
		end
	end
	for key, level in p.equipment do
		local def = Catalog.Equipment[key]
		if not def or not finiteInteger(level, #def.prices) then
			return false
		end
	end
	for key, count in p.collection do
		local known = false
		for _, def in Catalog.Needles do
			if def.id == key then
				known = true
			end
		end
		if not known or not finiteInteger(count, 1e9) then
			return false
		end
	end
	for key, contract in p.contracts do
		local def = Catalog.contract(key)
		if
			not def
			or type(contract) ~= "table"
			or not finiteInteger(contract.progress, def.target)
			or type(contract.complete) ~= "boolean"
		then
			return false
		end
	end
	for key, value in p.stats do
		if type(key) ~= "string" or not finiteInteger(value, 1e12) then
			return false
		end
	end
	return true
end
function GameState.round(number: number, seed: number): Round
	local cells: { Cell } = {}
	local total = 0
	-- Portable deterministic generator: no replicated needle locations until uncovered.
	local state = seed % 2147483647
	local function random(max: number): number
		state = (state * 48271 + 1) % 2147483647
		return state % max + 1
	end
	for index = 1, Catalog.Grid * Catalog.Grid do
		local x = (index - 1) % Catalog.Grid - 4
		local z = math.floor((index - 1) / Catalog.Grid) - 4
		local depth = 4 - math.max(math.abs(x), math.abs(z))
		local hay = 10 + depth * 6 + math.min(number, 20) * 2 + random(8)
		table.insert(
			cells,
			{ hay = hay, initial = hay, needle = nil, collected = false, discovery = false }
		)
		total += hay
	end
	for index = 1, 3 do
		local at = random(#cells)
		while cells[at].needle do
			at = at % #cells + 1
		end
		-- Round one teaches three types, later piles cycle through the full collection.
		cells[at].needle = (number + index - 2) % #Catalog.Needles + 1
	end
	for _ = 1, 3 do
		local at = random(#cells)
		while cells[at].discovery or cells[at].needle do
			at = at % #cells + 1
		end
		cells[at].discovery = true
	end
	return {
		cells = cells,
		number = number,
		remaining = total,
		total = total,
		needlesLeft = 3,
		won = false,
	}
end
function GameState.progress(p: Profile, metric: string, amount: number)
	p.stats[metric] = (p.stats[metric] or 0) + amount
	for id, active in p.contracts do
		local def = Catalog.contract(id)
		if def and not active.complete and def.metric == metric then
			active.progress = math.min(def.target, active.progress + amount)
		end
	end
end
function GameState.accept(p: Profile, id: string): boolean
	local def = Catalog.contract(id)
	local count = 0
	for _, active in p.contracts do
		if not active.complete then
			count += 1
		end
	end
	if not def or def.tier > Catalog.tier(p.xp) or p.contracts[id] or count >= 3 then
		return false
	end
	p.contracts[id] = { progress = 0, complete = false }
	return true
end
function GameState.claim(p: Profile, id: string): boolean
	local def, active = Catalog.contract(id), p.contracts[id]
	if not def or not active or active.complete or active.progress < def.target then
		return false
	end
	active.complete = true
	p.coins += def.coins
	p.xp += def.xp
	return true
end
function GameState.buy(p: Profile, id: string): boolean
	local def = Catalog.Equipment[id]
	if not def or def.tier > Catalog.tier(p.xp) then
		return false
	end
	local level = p.equipment[id] or 0
	local price = def.prices[level + 1]
	if not price or p.coins < price then
		return false
	end
	p.coins -= price
	p.equipment[id] = level + 1
	return true
end
function GameState.dig(round: Round, p: Profile, index: number, automated: boolean?): number
	local cell = round.cells[index]
	if not cell or round.won or cell.hay == 0 then
		return 0
	end
	local power = if automated then 2 else ({ 1, 4, 7, 11 })[(p.equipment.rake or 0) + 1]
	local amount = math.min(cell.hay, power)
	cell.hay -= amount
	round.remaining -= amount
	p.coins += amount
	GameState.progress(p, "hay", amount)
	if cell.hay == 0 and cell.discovery then
		cell.discovery = false
		p.coins += 50
		GameState.progress(p, "discoveries", 1)
	end
	return amount
end
function GameState.collect(round: Round, profiles: { Profile }, index: number): string?
	local cell = round.cells[index]
	if not cell or cell.hay > 0 or not cell.needle or cell.collected or round.won then
		return nil
	end
	cell.collected = true
	round.needlesLeft -= 1
	local needle = Catalog.Needles[cell.needle]
	for _, p in profiles do
		p.collection[needle.id] = (p.collection[needle.id] or 0) + 1
		p.coins += needle.value
		GameState.progress(p, "needles", 1)
		GameState.progress(p, needle.id, 1)
	end
	round.won = round.needlesLeft == 0
	return needle.id
end
return GameState
