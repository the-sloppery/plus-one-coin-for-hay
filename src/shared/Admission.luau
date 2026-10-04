--!strict
local Admission = {}
export type Manifest = { ids: { number }, host: number, sourcePlace: number, expires: number }
function Admission.valid(manifest: any, userId: number, sourcePlace: number, now: number): boolean
	if
		type(manifest) ~= "table"
		or type(manifest.ids) ~= "table"
		or #manifest.ids < 1
		or #manifest.ids > 6
	then
		return false
	end
	if
		manifest.sourcePlace ~= sourcePlace
		or type(manifest.expires) ~= "number"
		or manifest.expires ~= manifest.expires
		or manifest.expires == math.huge
		or manifest.expires <= now
	then
		return false
	end
	local seen: { [number]: boolean } = {}
	for _, id in manifest.ids do
		if type(id) ~= "number" or id ~= id or id % 1 ~= 0 or seen[id] then
			return false
		end
		seen[id] = true
	end
	return seen[userId] == true and seen[manifest.host] == true
end
return Admission
