require "iostream"

---@param reader IOStream
local function readMonCoord(reader)
	return reader:readCustom(-(2^12)/2+2, (2^12)/2, 0.125)
end

---@param writer IOStream
---@param x integer
local function writeMonCoord(writer, x)
	writer:writeCustom(x, -(2^12)/2+2, (2^12)/2, 0.125)
end

---@param writer IOStream
---@param db_idx integer
---@param fmt string
local function writeDBStr(writer, db_idx, fmt)
	writer:writeUByte(db_idx)
	writer:writeString(fmt)
end

---@param writer IOStream
---@param align integer -1, 0 or 1
local function writeAlignByte(writer, align)
	writer:writeUByte(align+1)
end

---@return integer[]
local function to_zsr_double(n)
	local bytes = {iostream_packunpack(">d", "BBBBBBBB", n)}
	table.remove(bytes, #bytes)
	while bytes[#bytes] == 0 do
		table.remove(bytes, #bytes)
	end
	return bytes
end

local function from_zsr_double(bytes)
	while #bytes < 8 do
		bytes[#bytes+1] = 0
	end
	local n = iostream_packunpack("BBBBBBBB", ">d", table.unpack(bytes))
	return n//1|0 == n and n|0 or n
end


-- Due to how binnet is setup, we can create a binnet, and use that to create more binnets with the packet readers and writers.

local Packets = {}

---@class Binnet_VehMon : Binnet
---@field vehmon VehMon
local BinnetBase = Binnet:new()
Packets.BinnetBase = BinnetBase


---@param binnet Binnet_VehMon
BinnetBase:registerPacketReader(1, function(binnet, reader)
	local vehmon = binnet.vehmon
	vehmon.monitor.width = readMonCoord(reader)
	vehmon.monitor.height = readMonCoord(reader)
	-- log_debug(("%s - resolution %s %s"):format(vehmon.vehicle_id, vehmon.monitor.width, vehmon.monitor.height))
end)
Packets.GET_RESOLUTION = BinnetBase:registerPacketWriter(1, function(binnet, writer)
end)

---@param binnet Binnet_VehMon
BinnetBase:registerPacketReader(2, function(binnet, reader)
	local vehmon = binnet.vehmon
	vehmon.monitor.touch1.x = reader:readCustom(0, (2^16)-1, 1)
	vehmon.monitor.touch1.y = reader:readCustom(0, (2^16)-1, 1)
	vehmon.monitor.touch1.pressed = reader:readUByte() ~= 0
	-- log_debug(("%s - touch1 %s %s %s"):format(vehmon.vehicle_id, vehmon.monitor.touch1.x, vehmon.monitor.touch1.y, vehmon.monitor.touch1.pressed))
end)

---@param binnet Binnet_VehMon
BinnetBase:registerPacketReader(3, function(binnet, reader)
	local vehmon = binnet.vehmon
	vehmon.monitor.touch2.x = reader:readCustom(0, (2^16)-1, 1)
	vehmon.monitor.touch2.y = reader:readCustom(0, (2^16)-1, 1)
	vehmon.monitor.touch2.pressed = reader:readUByte() ~= 0
	-- log_debug(("%s - touch2 %s %s %s"):format(vehmon.vehicle_id, vehmon.monitor.touch2.x, vehmon.monitor.touch2.y, vehmon.monitor.touch2.pressed))
end)


Packets.FULL_RESET = BinnetBase:registerPacketWriter(2, function(binnet, writer)
end)

Packets.GROUP_RESET = BinnetBase:registerPacketWriter(10, function(binnet, writer, group_id)
	writer:writeUByte(group_id)
end)
Packets.GROUP_SYNC = BinnetBase:registerPacketWriter(11, function(binnet, writer, group_id, enabled)
	writer:writeUByte(group_id)
	writer:writeUByte(enabled and 1 or 0)
end)
Packets.GROUP_ENABLE = BinnetBase:registerPacketWriter(12, function(binnet, writer, group_id)
	writer:writeUByte(group_id)
end)
Packets.GROUP_DISABLE = BinnetBase:registerPacketWriter(13, function(binnet, writer, group_id)
	writer:writeUByte(group_id)
end)

Packets.DB_SET_STRING = BinnetBase:registerPacketWriter(30, function(binnet, writer, db_idx, db_idy, s)
	writer:writeUByte(db_idx)
	writer:writeUByte(db_idy)
	writer:writeString(s)
end)
Packets.DB_SET_NUMBER = BinnetBase:registerPacketWriter(31, function(binnet, writer, db_idx, db_idy, n)
	writer:writeUByte(db_idx)
	writer:writeUByte(db_idy)
	for _, byte in ipairs(to_zsr_double(n)) do
		writer:writeUByte(byte)
	end
end)

Packets.DB_SET_POS_N = BinnetBase:registerPacketWriter(33, function(binnet, writer, db_idx, db_idy, n, precision)
	writer:writeUByte(db_idx)
	writer:writeUByte(db_idy)
	writer:writeUByte(1/precision)
end)
Packets.DB_SET_NEG_N = BinnetBase:registerPacketWriter(34, function(binnet, writer, db_idx, db_idy, n, precision)
	writer:writeUByte(db_idx)
	writer:writeUByte(db_idy)
end)

Packets.DRAW_COLOR = BinnetBase:registerPacketWriter(100, function(binnet, writer, r, g, b, a)
	writer:writeUByte(r)
	writer:writeUByte(g)
	writer:writeUByte(b)
	writer:writeUByte(a)
end)
Packets.DRAW_RECT = BinnetBase:registerPacketWriter(101, function(binnet, writer, x, y, w, h)
	writeMonCoord(writer, x)
	writeMonCoord(writer, y)
	writeMonCoord(writer, w)
	writeMonCoord(writer, h)
end)
Packets.DRAW_RECTF = BinnetBase:registerPacketWriter(102, function(binnet, writer, x, y, w, h)
	writeMonCoord(writer, x)
	writeMonCoord(writer, y)
	writeMonCoord(writer, w)
	writeMonCoord(writer, h)
end)
Packets.DRAW_CIRCLE = BinnetBase:registerPacketWriter(103, function(binnet, writer, x, y, r)
	writeMonCoord(writer, x)
	writeMonCoord(writer, y)
	writeMonCoord(writer, r)
end)
Packets.DRAW_CIRCLEF = BinnetBase:registerPacketWriter(104, function(binnet, writer, x, y, r)
	writeMonCoord(writer, x)
	writeMonCoord(writer, y)
	writeMonCoord(writer, r)
end)
Packets.DRAW_TRIANGLE = BinnetBase:registerPacketWriter(105, function(binnet, writer, x1, y1, x2, y2, x3, y3)
	writeMonCoord(writer, x1)
	writeMonCoord(writer, y1)
	writeMonCoord(writer, x2)
	writeMonCoord(writer, y2)
	writeMonCoord(writer, x3)
	writeMonCoord(writer, y3)
end)
Packets.DRAW_TRIANGLEF = BinnetBase:registerPacketWriter(106, function(binnet, writer, x1, y1, x2, y2, x3, y3)
	writeMonCoord(writer, x1)
	writeMonCoord(writer, y1)
	writeMonCoord(writer, x2)
	writeMonCoord(writer, y2)
	writeMonCoord(writer, x3)
	writeMonCoord(writer, y3)
end)
Packets.DRAW_LINE = BinnetBase:registerPacketWriter(107, function(binnet, writer, x1, y1, x2, y2)
	writeMonCoord(writer, x1)
	writeMonCoord(writer, y1)
	writeMonCoord(writer, x2)
	writeMonCoord(writer, y2)
end)
Packets.DRAW_TEXT = BinnetBase:registerPacketWriter(108, function(binnet, writer, x, y, db_idx, fmt)
	writeMonCoord(writer, x)
	writeMonCoord(writer, y)
	writeDBStr(writer, db_idx, fmt)
end)
Packets.DRAW_TEXTBOX = BinnetBase:registerPacketWriter(109, function(binnet, writer, x, y, w, h, db_idx, fmt, h_align, v_align)
	writeMonCoord(writer, x)
	writeMonCoord(writer, y)
	writeMonCoord(writer, w)
	writeMonCoord(writer, h)
	writeDBStr(writer, db_idx, fmt)
	writeAlignByte(writer, h_align)
	writeAlignByte(writer, v_align)
end)
Packets.DRAW_MAP = BinnetBase:registerPacketWriter(110, function(binnet, writer, x, y, zoom)
	writer:writeCustom(x, -130000, 130000, 0.0001)
	writer:writeCustom(y, -130000, 130000, 0.0001)
	writer:writeCustom(zoom, 0.1, 50, 0.00125)
end)


return Packets
