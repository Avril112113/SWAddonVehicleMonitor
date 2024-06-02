--[[
	Version: 0.1 (Short version 0.1)
	Limited range of 0-255 for packet ids.
	Packets don't require a writer to be sent, it'll just be an empty packet.
	If a packet is missing a reader, it is silently ignored.

	Shorter version differences:
		There is only a single global instance, you can't create multiple.
		Packet data is added directly to the output stream, there is no separate packet buffer. (TLDR; no packet priorities)
		A lot of locals are now global variables starting with "__"
]]

---@diagnostic disable: lowercase-global
---@diagnostic disable: duplicate-set-field
---@diagnostic disable: duplicate-doc-alias


---@param a byte
---@param b byte
---@param c byte
---@return number
function binnet_encode(a, b, c)
	---@diagnostic disable-next-line: return-type-mismatch
	return (iostream_packunpack("BBBB", "<f", a, b, c, 1))
end

---@param f number
---@return byte, byte, byte
function binnet_decode(f)
	__a, __b, __c = iostream_packunpack("<f", "BBBB", f)
	---@diagnostic disable-next-line: return-type-mismatch, missing-return-value
	return __a or 0, __b or 0, __c or 0
end


---@alias PacketReadHandlerFunc fun(binnet:Binnet_Short, reader:IOStream, packetId:integer)
---@alias PacketWriteHandlerFunc fun(binnet:Binnet_Short, writer:IOStream, ...)


-- NOTE: ALL binnets share readers/writers!
---@class Binnet_Short
---@field inStream IOStream
---@field outStream IOStream
-- ---@field outPackets IOStream[]
Binnet = {
	---@type PacketReadHandlerFunc[]
	packetReaders={},
	---@type PacketWriteHandlerFunc[]
	packetWriters={},

	inStream=IOStream.new(),  -- Added by short version
	outStream=IOStream.new(),  -- Added by short version
}

-- ---@return Binnet
-- function Binnet.new(self)
-- 	self = shallowCopy(self, {})
-- 	self.packetReaders = shallowCopy(self.packetReaders, {})
-- 	self.packetWriters = shallowCopy(self.packetWriters, {})
-- 	self.inStream = IOStream.new()
-- 	self.outStream = IOStream.new()
-- 	self.outPackets = {}
-- 	return self
-- end

---@param handler PacketReadHandlerFunc
---@param packetId integer # Range: 0-255
function Binnet.registerPacketReader(self, packetId, handler)
	self.packetReaders[packetId] = handler
end

---@param handler PacketWriteHandlerFunc
---@param packetId integer # Range: 0-255
---@return integer packetWriterId
function Binnet.registerPacketWriter(self, packetId, handler)
	self.packetWriters[packetId] = handler
	return packetId
end

---@param packetWriterId integer
---@param ... any
function Binnet.send(self, packetWriterId, ...)
	__send_writer = IOStream.new()
	__send_writer:writeUByte(packetWriterId)
	_ = self.packetWriters[packetWriterId] and self.packetWriters[packetWriterId](self, __send_writer, ...)
	table.insert(__send_writer, 1, #__send_writer+1)  -- `writer:writeUByte` only appends, not prepend.
	-- table.insert(self.outPackets, writer)
	self.outStream:writeStream(__send_writer)
end

-- function Binnet.setLastUrgent(self)
-- 	table.insert(self.outPackets, 1, table.remove(self.outPackets, #self.outPackets))
-- end

---@param values number[]
-- ---@return integer byteCount, integer packetCount
function Binnet.process(self, values)
	for _, v in ipairs(values) do
		__a, __b, __c = binnet_decode(v)
		table.insert(self.inStream, __a)
		table.insert(self.inStream, __b)
		table.insert(self.inStream, __c)
	end

	__packetProcessed = 0
	-- local totalByteCount, packetCount = 0, 0
	while self.inStream[1] ~= nil do
		__byteCount = self.inStream[1]
		if __byteCount == 0 then
			self.inStream:readUByte()
		elseif #self.inStream >= __byteCount then
			__process_reader = IOStream.new(self.inStream:readUBytes(__byteCount))
			__process_reader:readUByte()  -- We already peeked the byte count.
			__packetId = __process_reader:readUByte()
			_ = self.packetReaders[__packetId] and self.packetReaders[__packetId](self, __process_reader, __packetId)
			__packetProcessed = 1
			-- packetCount = packetCount + 1
		else
			break
		end
	end
	return __packetProcessed
	-- return totalByteCount, packetCount
end

---@param valueCount integer # The amount of values we can send out.
---@return number[]
function Binnet.write(self, valueCount)
	-- SHORTER VERSION: Numerous changes, so no commented out original code.
	__write_values = {}
	while #__write_values < valueCount do
		table.insert(__write_values, binnet_encode(table.remove(self.outStream, 1) or 0, table.remove(self.outStream, 1) or 0, table.remove(self.outStream, 1) or 0))
	end
	return __write_values
end
