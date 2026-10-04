--!strict
return function(H: any, shared: any, test: (string, () -> ()) -> ())
	test("unpublished Studio startup never acquires a MemoryStore map", function()
		local f = H.environment(shared, true)
		f.services.Players = { PlayerRemoving = H.signal() }
		f.services.TeleportService = { TeleportInitFailed = H.signal() }
		f.services.MemoryStoreService = {
			GetHashMap = function()
				error("unpublished Studio cannot use MemoryStore")
			end,
		}
		local travel = H.load("src/server/Travel.luau", f.env)
		assert(not travel.launch({}, 1))
	end)
	local function profileFixture()
		local f = H.environment(shared, false)
		local saved: any = nil
		local broken = false
		f.services.DataStoreService = {
			GetDataStore = function()
				return {
					UpdateAsync = function(_, _, callback)
						if broken then
							error("injected save outage")
						end
						local result = callback(saved)
						if result then
							saved = result
						end
						return result
					end,
				}
			end,
		}
		local profiles = H.load("src/server/Profiles.luau", f.env)
		return f,
			profiles,
			function(value)
				saved = value
			end,
			function(value)
				broken = value
			end,
			function()
				return saved
			end
	end
	test("production profile saves acquire ownership and restore a durable snapshot", function()
		local f, profiles, _, _, read = profileFixture()
		local p = profiles.load(1)
		assert(p)
		p.coins = 123
		assert(profiles.save(1) and read().data.coins == 123)
		p.coins = 200
		assert(read().data.coins == 123, "persisted snapshot aliased mutable gameplay")
		assert(profiles.save(1, true) and not read().lock)
		assert(profiles.load(1).coins == 200)
		f.advance(121)
		assert(not profiles.get(1) and not profiles.save(1))
	end)
	test("active owner and corrupt save data are never overwritten", function()
		local _, profiles, write = profileFixture()
		write({
			data = shared.GameState.profile(),
			lock = { token = "other-server", expires = 2000 },
		})
		assert(not profiles.load(1))
		write({ data = { version = 2 } })
		assert(not profiles.load(1))
	end)
	test("transient save failure preserves memory and permits retry", function()
		local _, profiles, _, outage, read = profileFixture()
		local p = profiles.load(1)
		p.coins = 44
		outage(true)
		assert(not profiles.save(1) and profiles.get(1).coins == 44)
		outage(false)
		assert(profiles.save(1) and read().data.coins == 44)
	end)
	test("ownership loss prevents an older server from saving", function()
		local _, profiles, write, _, read = profileFixture()
		assert(profiles.load(1))
		local other = shared.GameState.profile()
		other.coins = 999
		write({ data = other, lock = { token = "other", expires = 2000 } })
		assert(not profiles.save(1) and read().data.coins == 999)
	end)
	local function travelFixture()
		local f = H.environment(shared, false)
		local calls, errors, reservations = {}, {}, 0
		local values = {}
		local broken = false
		local players: any = { PlayerRemoving = H.signal() }
		f.services.Players = players
		f.services.MemoryStoreService = {
			GetHashMap = function()
				return {
					SetAsync = function(_, key, value)
						values[key] = value
					end,
					GetAsync = function(_, key)
						return values[key]
					end,
				}
			end,
		}
		f.services.TeleportService = {
			TeleportInitFailed = H.signal(),
			ReserveServerAsync = function()
				reservations += 1
				return "fixture-access"
			end,
			TeleportAsync = function(_, place, party, options)
				table.insert(calls, { place = place, party = party, options = options })
				if broken then
					error("injected travel outage")
				end
			end,
		}
		local travel = H.load("src/server/Travel.luau", f.env)
		travel.configure(function(player, message)
			table.insert(errors, { player, message })
		end)
		local function player(id)
			return {
				UserId = id,
				Parent = players,
				GetJoinData = function()
					return { SourcePlaceId = 999, TeleportData = { haySession = "fixture-1" } }
				end,
			}
		end
		return f,
			travel,
			calls,
			errors,
			player,
			function(value)
				broken = value
			end,
			function()
				return reservations
			end
	end
	test("group teleport reserves one server and sends all members together", function()
		local _, travel, calls, _, player, _, reserved = travelFixture()
		assert(travel.launch({ player(1), player(2), player(3) }, 1))
		assert(
			#calls == 1
				and #calls[1].party == 3
				and calls[1].options.ReservedServerAccessCode == "fixture-access"
				and reserved() == 1
		)
		assert(travel.admit(player(2)) and not travel.admit(player(9)))
	end)
	test("failed travel retries the same reservation with a strict attempt cap", function()
		local f, travel, calls, errors, player, outage, reserved = travelFixture()
		outage(true)
		assert(travel.launch({ player(1) }, 1))
		for _ = 1, 4 do
			f.advance(2)
		end
		assert(#calls == 3 and #errors == 1 and reserved() == 1)
		assert(calls[1].options == calls[2].options and calls[2].options == calls[3].options)
	end)
	test("late teleport failure retries the same field for just the stranded member", function()
		local f, travel, calls, _, player = travelFixture()
		local a, b = player(1), player(2)
		travel.launch({ a, b }, 1)
		f.services.TeleportService.TeleportInitFailed:Fire(b, "Failure", "injected", 999)
		f.advance(2)
		assert(#calls == 2 and #calls[2].party == 1 and calls[2].party[1] == b)
	end)
	test("travel watchdog restores stalled players and failed lobby returns", function()
		local f, travel, _, errors, player = travelFixture()
		local a = player(1)
		travel.launch({ a }, 1)
		f.tick(1)
		f.advance(31)
		f.tick(1)
		assert(#errors == 1)
		assert(travel.returnToLobby(a))
		f.services.TeleportService.TeleportInitFailed:Fire(a, "Failure", "injected", 999)
		assert(#errors == 2)
	end)
end
