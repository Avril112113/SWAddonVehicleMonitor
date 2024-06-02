---@diagnostic disable: lowercase-global

---@alias byte integer


---@param from string
---@param to string
---@param ... number|string
---@return number|string ...
function iostream_packunpack(from, to, ...)
	return string.unpack(to, string.pack(from, ...))
end

-- Inlined at use location.
-- ---@param value number
-- ---@param quantum number
-- function iostream_ceil(value, quantum)
--     local quant, frac = math.modf(value/quantum)
--     return quantum * (quant + (frac > 0 and 1 or 0))
-- end


---@class IOStream
---@field [integer] byte
IOStream = {}

---@param bytes byte[]?
---@return IOStream
function IOStream.new(bytes)
	return shallowCopy(IOStream, bytes or {})
end

---@param stream IOStream|IOStream
function IOStream.writeStream(self, stream)
	table.move(stream, 1, #stream, #self+1, self)
end

---@param count integer
---@return byte[]
function IOStream.readUBytes(self, count)
	__bytes = table.move(self, 1, count, 1, {})
	for i=1,count do
		table.remove(self, 1)
	end
	return __bytes
end
---@return byte
function IOStream.readUByte(self)
	return table.remove(self, 1)
end
---@param ubyte byte
function IOStream.writeUByte(self, ubyte)
	return table.insert(self, ubyte)
end

---@param min number
---@param max number
---@param precision number  # Represented as `0.01`
function IOStream.readCustom(self, min, max, precision)
	-- https://github.com/martindevans/StormPack/blob/master/Stormpack/PackSpec.cs#L53
	-- local range = max-min
	__bitCount = math.floor(math.log((max-min)/precision, 2) + 0.5)
	__byteCount = math.ceil(__bitCount/8)
	__quant, __frac = math.modf((iostream_packunpack(string.rep("B", __byteCount) .. string.rep("x", 8-__byteCount), "J", table.unpack(self:readUBytes(__byteCount)))*((2 ^ -__bitCount) * (max-min)) + min)/precision)
	return precision * (__quant + (__frac > 0 and 1 or 0))
end
---@param min number
---@param max number
---@param precision number  # Represented as `0.01`
function IOStream.writeCustom(self, value, min, max, precision)
	-- https://github.com/martindevans/StormPack/blob/master/Stormpack/PackSpec.cs#L53
	-- local range = max-min
	__bitCount = math.floor(math.log((max-min)/precision, 2) + 0.5)
	__precision = (2 ^ -__bitCount) * (max-min)
	__bytes = {iostream_packunpack("J", string.rep("B", math.ceil(__bitCount/8)), math.floor((value-min)/__precision))}
	table.remove(__bytes, #__bytes)
	self:writeStream(__bytes)
end

---@return string
function IOStream.readString(self)
	__size = self:readUByte()
	---@diagnostic disable-next-line: return-type-mismatch
	return (iostream_packunpack(string.rep("B", __size), "c"..__size, table.unpack(self:readUBytes(__size))))
end
---@param s string
function IOStream.writeString(self, s)
	self:writeUByte(#s)
	__bytes = {iostream_packunpack("c"..#s, string.rep("B", #s), s)}
	table.remove(__bytes, #__bytes)
	self:writeStream(__bytes)
end
