--[[
	Version: 0.1
	Limited range of 0-255 for packet ids.
	Packets don't require a writer to be sent, it'll just be an empty packet.
	If a packet is missing a reader, it is silently ignored.

	CUSTOM MODIFIED, see sections which start with 'START CUSTOM MODIFIED'
	The modification is used for debugging sent packets.
	This this version of binnet isn't be used for vehicles, char count is of no concern.
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
	local a, b, c = iostream_packunpack("<f", "BBBB", f)
	---@diagnostic disable-next-line: return-type-mismatch, missing-return-value
	return a, b, c
end


---@alias PacketReadHandlerFunc fun(binnet:Binnet, reader:IOStream, packetId:integer)
---@alias PacketWriteHandlerFunc fun(binnet:Binnet, writer:IOStream, ...)


-- NOTE: ALL binnets share readers/writers!
---@class Binnet
---@field inStream IOStream
---@field outStream IOStream
---@field outPackets IOStream[]
Binnet = {
	---@type PacketReadHandlerFunc[]
	packetReaders={},
	---@type PacketWriteHandlerFunc[]
	packetWriters={},
}

---@return Binnet
function Binnet.new(self)
	self = shallowCopy(self, {})
	self.packetReaders = shallowCopy(self.packetReaders, {})
	self.packetWriters = shallowCopy(self.packetWriters, {})
	self.inStream = IOStream.new()
	self.outStream = IOStream.new()
	self.outPackets = {}
	return self
end

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
	local writer = IOStream.new()
	-- START CUSTOM MODIFIED
	if BINNET_DEBUG_PACKETS then
		BINNET_DEBUG_PACKETS_MSGS = BINNET_DEBUG_PACKETS_MSGS or {}
		local parts = {}
		for i, v in ipairs({...}) do
			parts[i] = tostring(v)
		end
		local msg = ("BINNET WRITE %s(%s)"):format(tostring(BINNET_DEBUG_PACKETS[packetWriterId]), table.concat(parts, " "))
		if BINNET_DEBUG_PACKETS_MODE == "send" then
			debug.log("[SW] [DEBUG] " .. msg)
		else
			BINNET_DEBUG_PACKETS_MSGS[writer] = msg
		end
	end
	-- END CUSTOM MODIFIED
	writer:writeUByte(packetWriterId)
	_ = self.packetWriters[packetWriterId] and self.packetWriters[packetWriterId](self, writer, ...)
	table.insert(writer, 1, #writer+1)  -- `writer:writeUByte` only appends, not prepend.
	table.insert(self.outPackets, writer)
end

function Binnet.setLastUrgent(self)
	table.insert(self.outPackets, 1, table.remove(self.outPackets, #self.outPackets))
end

---@param values number[]
---@return integer byteCount, integer packetCount
function Binnet.process(self, values)
	for _, v in ipairs(values) do
		table.move({binnet_decode(v)}, 1, 3, #self.inStream+1, self.inStream)
	end

	local totalByteCount, packetCount = 0, 0
	while self.inStream[1] ~= nil do
		local byteCount = self.inStream[1]
		if byteCount == 0 then
			self.inStream:readUByte()
		elseif #self.inStream >= byteCount then
			local reader = IOStream.new(self.inStream:readUBytes(byteCount))
			reader:readUByte()  -- We already peeked the byte count.
			local packetId = reader:readUByte()
			_ = self.packetReaders[packetId] and self.packetReaders[packetId](self, reader, packetId)
			totalByteCount = totalByteCount + byteCount
			packetCount = packetCount + 1
		else
			break
		end
	end
	return totalByteCount, packetCount
end

---@param valueCount integer # The amount of values we can send out.
---@return number[]
function Binnet.write(self, valueCount)
	local maxByteCount = valueCount*3
	local valuesBytes = {}
	while #valuesBytes < maxByteCount do
		if #self.outStream <= 0 then
			local writer = table.remove(self.outPackets, 1)
			if writer == nil then
				break
			end
			self.outStream:writeStream(writer)
			-- START CUSTOM MODIFIED
			if BINNET_DEBUG_PACKETS_MSGS and BINNET_DEBUG_PACKETS_MSGS[writer] then
				debug.log("[SW] [DEBUG] " .. BINNET_DEBUG_PACKETS_MSGS[writer])
				BINNET_DEBUG_PACKETS_MSGS[writer] = nil
			end
			-- END CUSTOM MODIFIED
		end
		for i=1,math.min(#self.outStream,maxByteCount-#valuesBytes) do
			table.insert(valuesBytes, table.remove(self.outStream, 1))
		end
	end

	local values = {}
	for i=1,#valuesBytes,3 do
		table.insert(values, binnet_encode(valuesBytes[i], valuesBytes[i+1] or 0, valuesBytes[i+2] or 0))
	end

	return values
end
