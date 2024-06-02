-- Not technically shared, but this makes typing happy.

---@param source table
---@param dest table?
function shallowCopy(source, dest)
	dest = dest or {}
	for i, v in pairs(source) do
		dest[i] = v
	end
	return dest
end
