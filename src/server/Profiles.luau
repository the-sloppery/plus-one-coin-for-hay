--!strict
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local State = require(Shared.GameState)
local Config = require(Shared.Config)
type Profile = State.Profile
type Entry = { data: Profile, token: string, expires: number, busy: boolean }
local Profiles = {}
local entries: { [number]: Entry } = {}
local store = if RunService:IsStudio() then nil else DataStoreService:GetDataStore(Config.SaveStore)
function Profiles.load(userId: number): Profile?
	if entries[userId] then
		-- An expired local entry cannot be reintroduced as writable gameplay state.
		return Profiles.get(userId)
	end
	local token = HttpService:GenerateGUID(false)
	local now = os.time()
	local loaded: Profile? = nil
	if not store then
		loaded = State.profile()
	else
		local ok, result = pcall(function()
			return store:UpdateAsync(`player_{userId}`, function(old: any): any
				if old ~= nil and (type(old) ~= "table" or not State.validProfile(old.data)) then
					return nil
				end
				if old and old.lock and old.lock.expires > now and old.lock.token ~= token then
					return nil
				end
				return {
					data = if old then old.data else State.profile(),
					lock = { token = token, expires = now + Config.LeaseSeconds },
				}
			end)
		end)
		if ok and result and result.lock and result.lock.token == token then
			loaded = result.data
		end
	end
	if not loaded then
		return nil
	end
	entries[userId] =
		{ data = loaded, token = token, expires = now + Config.LeaseSeconds, busy = false }
	return loaded
end
function Profiles.get(userId: number): Profile?
	local entry = entries[userId]
	if entry and entry.expires > os.time() then
		return entry.data
	end
	return nil
end
function Profiles.save(userId: number, release: boolean?): boolean
	local entry = entries[userId]
	if not entry or entry.busy or entry.expires <= os.time() then
		return false
	end
	entry.busy = true
	local now = os.time()
	-- Take a deep snapshot before yielding, so concurrent gameplay cannot mutate the write.
	local snapshot = HttpService:JSONDecode(HttpService:JSONEncode(entry.data))
	local success = not store
	if store then
		local ok, result = pcall(function()
			return store:UpdateAsync(`player_{userId}`, function(old: any): any
				if
					not old
					or not old.lock
					or old.lock.token ~= entry.token
					or old.lock.expires <= now
				then
					return nil
				end
				return {
					data = snapshot,
					lock = if release
						then nil
						else { token = entry.token, expires = now + Config.LeaseSeconds },
				}
			end)
		end)
		success = ok
			and result ~= nil
			and (release == true or (result.lock and result.lock.token == entry.token))
	end
	entry.busy = false
	if success then
		entry.expires = now + Config.LeaseSeconds
		if release then
			entries[userId] = nil
		end
	end
	return success
end
function Profiles.release(userId: number): boolean
	-- Bound overlap with an autosave, then retry transient writes while the lease is valid.
	local deadline = os.clock() + 8
	while entries[userId] and entries[userId].busy and os.clock() < deadline do
		task.wait(0.1)
	end
	for _ = 1, 3 do
		if Profiles.save(userId, true) then
			return true
		end
		task.wait(1)
	end
	return false
end
return Profiles
