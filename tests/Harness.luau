--!strict
-- Explicit offline boundaries. These fixtures execute production modules, not the Roblox engine.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local H = { roblox = roblox }
function H.signal(): any
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, callback in table.clone(callbacks) do
				callback(...)
			end
		end,
	}
end
local signals: { [any]: { [string]: any } } = {}
function H.event(instance: any, name: string): any
	signals[instance] = signals[instance] or {}
	signals[instance][name] = signals[instance][name] or H.signal()
	return signals[instance][name]
end
for class, names in
	{
		GuiButton = { "Activated" },
		ProximityPrompt = { "Triggered" },
		RemoteEvent = { "OnServerEvent", "OnClientEvent" },
	}
do
	for _, name in names do
		roblox.implementProperty(class, name, function(instance)
			return H.event(instance, name)
		end)
	end
end
roblox.implementMethod("TeleportOptions", "SetTeleportData", function() end)
function H.load(path: string, env: any): any
	return luau.load(
		fs.readFile(path),
		{ debugName = path, environment = env, injectGlobals = true }
	)()
end
function H.shared(): any
	local modules = {}
	for _, name in { "Catalog", "Config", "Queue", "GameState", "Admission" } do
		modules[name] = H.load(`src/shared/{name}.luau`, {
			script = { Parent = modules },
			require = function(value)
				return value
			end,
		})
	end
	return modules
end
function H.environment(shared: any, studio: boolean?): any
	local now = 1000
	local delayed = {}
	local threads = {}
	local ids = 0
	local services: any = {
		GuiService = {},
		ReplicatedStorage = { Shared = shared },
		RunService = {
			IsStudio = function()
				return studio ~= false
			end,
		},
	}
	services.HttpService = {
		GenerateGUID = function()
			ids += 1
			return `fixture-{ids}`
		end,
		JSONEncode = function(_, value)
			return serde.encode("json", value)
		end,
		JSONDecode = function(_, value)
			return serde.decode("json", value)
		end,
	}
	local env = table.clone(roblox)
	env.require = function(value)
		return value
	end
	env.game = {
		PlaceId = 999,
		PrivateServerId = "",
		PrivateServerOwnerId = 0,
		GetService = function(_, name)
			assert(services[name], `unmocked service {name}`)
			return services[name]
		end,
	}
	env.os = {
		clock = function()
			return now
		end,
		time = function()
			return math.floor(now)
		end,
	}
	env.task = {
		spawn = function(callback, ...)
			local thread = coroutine.create(callback)
			table.insert(threads, { thread, { ... } })
			return thread
		end,
		delay = function(seconds, callback)
			table.insert(delayed, { at = now + seconds, callback = callback })
		end,
		wait = function(_)
			coroutine.yield()
		end,
	}
	return {
		env = env,
		services = services,
		threads = threads,
		advance = function(seconds)
			now += seconds
			local ready = {}
			for i = #delayed, 1, -1 do
				if delayed[i].at <= now then
					table.insert(ready, table.remove(delayed, i).callback)
				end
			end
			for _, callback in ready do
				callback()
			end
		end,
		tick = function(index)
			local row = threads[index]
			local ok, err = coroutine.resume(row[1], table.unpack(row[2]))
			row[2] = {}
			assert(ok, err)
		end,
	}
end
return H
