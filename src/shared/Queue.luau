--!strict
local Catalog = require(script.Parent.Catalog)
export type Queue = {
	members: { number },
	host: number?,
	deadline: number?,
	locked: boolean,
	capacity: number,
}
local Queue = {}
function Queue.new(): Queue
	return {
		members = {},
		host = nil,
		deadline = nil,
		locked = false,
		capacity = Catalog.MaxPlayers,
	}
end
function Queue.join(q: Queue, userId: number, now: number): boolean
	if q.locked or #q.members >= q.capacity or table.find(q.members, userId) then
		return false
	end
	table.insert(q.members, userId)
	if not q.host then
		q.host = userId
		q.deadline = now + Catalog.QueueSeconds
	end
	return true
end
function Queue.leave(q: Queue, userId: number): boolean
	if q.locked then
		return false
	end
	local index = table.find(q.members, userId)
	if not index then
		return false
	end
	table.remove(q.members, index)
	if q.host == userId then
		q.host = q.members[1]
	end
	if #q.members == 0 then
		q.deadline = nil
		q.capacity = Catalog.MaxPlayers
	end
	return true
end
function Queue.capacity(q: Queue, userId: number, value: number): boolean
	if q.locked or q.host ~= userId or value % 1 ~= 0 or value < #q.members or value > 6 then
		return false
	end
	q.capacity = value
	return true
end
function Queue.take(q: Queue, now: number, requester: number?): { number }?
	if q.locked or #q.members == 0 then
		return nil
	end
	if requester ~= q.host and (not q.deadline or now < q.deadline) then
		return nil
	end
	q.locked = true
	return table.clone(q.members)
end
return Queue
