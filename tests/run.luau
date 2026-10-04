--!strict
local H = require("./Harness")
local S = H.shared()
local State, Queue, Catalog, Admission = S.GameState, S.Queue, S.Catalog, S.Admission
local passed, failed = 0, 0
local function test(name: string, callback: () -> ())
	local ok, err = pcall(callback)
	if ok then
		passed += 1
		print(`PASS {name}`)
	else
		failed += 1
		print(`FAIL {name}: {err}`)
	end
end
for count = 1, 6 do
	test(`queue launches {count} players exactly once`, function()
		local q = Queue.new()
		for id = 1, count do
			assert(Queue.join(q, id, 0))
		end
		assert(not Queue.take(q, 1, 999))
		local group = Queue.take(q, 1, 1)
		assert(group and #group == count and group[1] == 1)
		assert(not Queue.take(q, 99, 1))
		assert(not Queue.join(q, 7, 0))
	end)
end
test("seventh player and duplicate joins are rejected", function()
	local q = Queue.new()
	for id = 1, 6 do
		assert(Queue.join(q, id, 0))
	end
	assert(not Queue.join(q, 7, 0) and not Queue.join(q, 1, 0) and #q.members == 6)
end)
test("countdown starts with first entrant and launches at deadline", function()
	local q = Queue.new()
	Queue.join(q, 1, 10)
	Queue.join(q, 2, 18)
	assert(q.deadline == 30 and not Queue.take(q, 29, nil))
	assert(Queue.take(q, 30, nil))
end)
test("host departure hands ownership to next player", function()
	local q = Queue.new()
	Queue.join(q, 1, 0)
	Queue.join(q, 2, 1)
	Queue.leave(q, 1)
	assert(q.host == 2 and q.deadline == 20)
	assert(Queue.take(q, 2, 2))
end)
test("empty queue resets capacity and timer", function()
	local q = Queue.new()
	Queue.join(q, 1, 0)
	Queue.capacity(q, 1, 1)
	Queue.leave(q, 1)
	assert(q.host == nil and q.deadline == nil and q.capacity == 6)
end)
test("only host changes party size with bounded integers", function()
	local q = Queue.new()
	Queue.join(q, 1, 0)
	Queue.join(q, 2, 0)
	assert(not Queue.capacity(q, 2, 3))
	assert(not Queue.capacity(q, 1, 1))
	assert(not Queue.capacity(q, 1, 7))
	assert(not Queue.capacity(q, 1, 2.5))
	assert(Queue.capacity(q, 1, 2))
	assert(not Queue.join(q, 3, 0))
end)
test("fresh profiles do not share mutable tables", function()
	local a, b = State.profile(), State.profile()
	a.equipment.rake = 1
	assert(not b.equipment.rake)
end)
test("corrupt and future save data fail closed", function()
	local p = State.profile()
	assert(State.validProfile(p))
	p.coins = 0 / 0
	assert(not State.validProfile(p))
	p.coins = 0
	p.version = 2
	assert(not State.validProfile(p))
	p.version = 1
	p.equipment.rake = 4
	assert(not State.validProfile(p))
end)
test("unknown needles and invalid contract saves are rejected", function()
	local p = State.profile()
	p.collection.forged = 1
	assert(not State.validProfile(p))
	p.collection = {}
	p.contracts.starter = { progress = 31, complete = false }
	assert(not State.validProfile(p))
end)
test("dig clears bounded hay and grants precisely one coin per piece", function()
	local p, round = State.profile(), State.round(1, 42)
	local total = round.remaining
	assert(State.dig(round, p, 1) == 1)
	assert(round.remaining == total - 1 and p.coins == 1 and p.stats.hay == 1)
end)
test("empty hay cannot be farmed indefinitely", function()
	local p, round = State.profile(), State.round(1, 42)
	round.cells[1].discovery = false
	local initial = round.cells[1].hay
	for _ = 1, initial + 10 do
		State.dig(round, p, 1)
	end
	assert(p.coins == initial and round.cells[1].hay == 0)
end)
test("hidden and duplicate needle collections do not grant rewards", function()
	local p, round = State.profile(), State.round(1, 1)
	local index = 1
	while not round.cells[index].needle do
		index += 1
	end
	assert(not State.collect(round, { p }, index))
	round.cells[index].hay = 0
	assert(State.collect(round, { p }, index))
	local coins = p.coins
	assert(not State.collect(round, { p }, index) and p.coins == coins)
end)
for count = 1, 6 do
	test(`needle grants the collection to all {count} members`, function()
		local profiles = {}
		for _ = 1, count do
			table.insert(profiles, State.profile())
		end
		local round = State.round(1, 42)
		local at = 1
		while not round.cells[at].needle do
			at += 1
		end
		round.cells[at].hay = 0
		local id = State.collect(round, profiles, at)
		assert(id)
		for _, p in profiles do
			assert(p.collection[id] == 1 and p.stats.needles == 1 and p.coins > 0)
		end
	end)
end
test("three needles win and freeze the pile", function()
	local p, round = State.profile(), State.round(1, 55)
	for i, cell in round.cells do
		if cell.needle then
			cell.hay = 0
			State.collect(round, { p }, i)
		end
	end
	assert(round.won and round.needlesLeft == 0)
	assert(State.dig(round, p, 1) == 0)
end)
test("contracts count events after acceptance and claim once", function()
	local p = State.profile()
	State.progress(p, "hay", 100)
	assert(State.accept(p, "starter"))
	assert(p.contracts.starter.progress == 0)
	assert(not State.claim(p, "starter"))
	State.progress(p, "hay", 30)
	assert(State.claim(p, "starter") and p.coins == 40 and p.xp == 25)
	assert(not State.claim(p, "starter") and not State.accept(p, "starter"))
end)
test("three active contract limit and tier locks hold", function()
	local p = State.profile()
	assert(not State.accept(p, "treasure"))
	p.xp = 1000
	assert(State.accept(p, "starter") and State.accept(p, "find") and State.accept(p, "clear"))
	assert(not State.accept(p, "treasure"))
	State.progress(p, "hay", 30)
	State.claim(p, "starter")
	assert(State.accept(p, "treasure"))
end)
test("starting contracts unlock tier two without a progression dead end", function()
	local p = State.profile()
	for _, id in { "starter", "clear", "find" } do
		assert(State.accept(p, id))
	end
	State.progress(p, "hay", 180)
	State.progress(p, "needles", 1)
	for _, id in { "starter", "clear", "find" } do
		assert(State.claim(p, id))
	end
	assert(Catalog.tier(p.xp) >= 2 and State.accept(p, "treasure"))
end)
test("team contract excludes the player's own digging metric", function()
	local p = State.profile()
	p.xp = 150
	State.accept(p, "cooperate")
	State.progress(p, "hay", 300)
	assert(p.contracts.cooperate.progress == 0)
	State.progress(p, "teamHay", 300)
	assert(State.claim(p, "cooperate"))
end)
test("specific needle commission only counts copper", function()
	local p = State.profile()
	p.xp = 300
	State.accept(p, "copper")
	State.progress(p, "sun", 1)
	assert(p.contracts.copper.progress == 0)
	State.progress(p, "copper", 1)
	assert(State.claim(p, "copper"))
end)
test("equipment purchase is atomic and bounded by tier, money and level", function()
	local p = State.profile()
	assert(not State.buy(p, "rake"))
	p.coins = 1000
	assert(not State.buy(p, "blower"))
	assert(State.buy(p, "rake") and p.coins == 940)
	assert(State.buy(p, "rake") and State.buy(p, "rake"))
	assert(not State.buy(p, "rake"))
	assert(not State.buy(p, "forged"))
end)
test("rake upgrades and automation increase clearing without excess payout", function()
	local p, round = State.profile(), State.round(1, 20)
	p.equipment.rake = 3
	assert(State.dig(round, p, 1) == 11)
	assert(State.dig(round, p, 2, true) == 2)
end)
test("buried discoveries pay only once", function()
	local p, round = State.profile(), State.round(1, 42)
	round.cells[1].hay = 1
	round.cells[1].discovery = true
	assert(State.dig(round, p, 1) == 1 and p.coins == 51 and p.stats.discoveries == 1)
	State.dig(round, p, 1)
	assert(p.coins == 51)
end)
test("all needle types are reachable across sequential piles", function()
	local types = {}
	for number = 1, 6 do
		for _, cell in State.round(number, 42).cells do
			if cell.needle then
				types[cell.needle] = true
			end
		end
	end
	for index = 1, #Catalog.Needles do
		assert(types[index])
	end
end)
test("seeded piles conserve hay and always expose three attainable needles", function()
	for seed = 1, 50 do
		local p, round = State.profile(), State.round(seed, seed * 213)
		local hay, needles = 0, 0
		for i, cell in round.cells do
			hay += cell.hay
			if cell.needle then
				needles += 1
			end
			while cell.hay > 0 do
				State.dig(round, p, i)
			end
		end
		assert(hay == round.total and round.remaining == 0 and needles == 3)
		for i, cell in round.cells do
			if cell.needle then
				assert(State.collect(round, { p }, i))
			end
		end
		assert(round.won and State.validProfile(p))
	end
end)
test("reserved admission requires live server-owned roster and matching source", function()
	local m = { ids = { 1, 2 }, host = 1, sourcePlace = 999, expires = 100 }
	assert(Admission.valid(m, 1, 999, 50))
	assert(not Admission.valid(m, 3, 999, 50))
	assert(not Admission.valid(m, 1, 100, 50))
	assert(not Admission.valid(m, 1, 999, 100))
	m.ids = { 1, 1 }
	assert(not Admission.valid(m, 1, 999, 50))
	m.ids = { 1, 2, 3, 4, 5, 6, 7 }
	assert(not Admission.valid(m, 1, 999, 50))
end)
require("./service-tests")(H, S, test)
test("solo contract progression reaches the auto rake tier without team hay", function()
	local p = State.profile()
	for _, id in { "starter", "clear", "find", "treasure", "haul" } do
		local def = Catalog.contract(id)
		assert(State.accept(p, id))
		State.progress(p, def.metric, def.target)
		assert(State.claim(p, id))
	end
	assert(Catalog.tier(p.xp) == 4 and State.buy(p, "collector"))
end)
print(`RESULT {passed} passed, {failed} failed`)
assert(failed == 0 and passed >= 40, "test suite failed or did not execute the expected cases")
