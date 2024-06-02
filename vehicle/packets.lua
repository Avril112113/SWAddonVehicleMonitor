---@param writer IOStream
---@param x integer
---@param y integer
function writePosition(writer, x, y)
	writer:writeCustom(x, 0, (2^16)-1, 1)
	writer:writeCustom(y, 0, (2^16)-1, 1)
end

---@param reader IOStream
function read2ByteUInt(reader)
	return reader:readCustom(0, (2^16)-1, 1)
end

---@param reader IOStream
function readAlignByte(reader)
	return reader:readUByte()-1
end

function from_zsr_double(bytes)
	while #bytes < 8 do
		bytes[#bytes+1] = 0
	end
	__n = iostream_packunpack("BBBBBBBB", ">d", table.unpack(bytes))
	return __n//1|0 == __n and __n|0 or __n
end

function addDBPacketHandler(packet_id, f)
	Binnet:registerPacketReader(packet_id, function(_, reader)
		local db_idx, db_idy = reader:readUByte(), reader:readUByte()
		db_values[db_idx] = db_values[db_idx] or {}
		db_values[db_idx][db_idy] = f(reader)
	end)
end

function addDrawPacketReader(packet_id, f, ...)
	local readers = {...}
	Binnet:registerPacketReader(packet_id, function (_, reader)
		local args = {}
		for _, reader_f in ipairs(readers) do
			for _, v in ipairs({reader_f(reader)}) do
				table.insert(args, v)
			end
		end
		cmd_groups[cmd_group_idx][cmd_group_draw_idx] = function()
			f(table.unpack(args))
		end
		cmd_group_draw_idx = cmd_group_draw_idx + 1
	end)
end


PACKET_RESOLUION = Binnet:registerPacketWriter(1, function(_, writer, resolution)
	writePosition(writer, resolution[1], resolution[2])
end)

PACKET_INPUT1 = Binnet:registerPacketWriter(2, function(_, writer, input1)
	writePosition(writer, input1[1], input1[2])
	writer:writeUByte(input1[3] and 1 or 0)
end)

PACKET_INPUT2 = Binnet:registerPacketWriter(3, function(_, writer, input2)
	writePosition(writer, input2[1], input2[2])
	writer:writeUByte(input2[3] and 1 or 0)
end)


Binnet:registerPacketReader(1, function(_, writer)
	Binnet:send(PACKET_RESOLUION, prev_resolution)
end)

Binnet:registerPacketReader(2, reset)

-- GROUP_RESET
---@param reader IOStream
Binnet:registerPacketReader(10, function(_, reader)
	cmd_group_idx = reader:readUByte()
	cmd_groups[cmd_group_idx] = {enabled=false}
	cmd_group_draw_idx = 1
end)
-- GROUP_SYNC
---@param reader IOStream
Binnet:registerPacketReader(11, function(_, reader)
	cmd_group_idx = reader:readUByte()
	cmd_groups[cmd_group_idx].enabled = reader:readUByte() > 0
	cmd_group_draw_idx = 1
end)
-- GROUP_ENABLE
---@param reader IOStream
Binnet:registerPacketReader(12, function(_, reader)
	cmd_groups[reader:readUByte()].enabled = true
end)
-- GROUP_DISABLE
---@param reader IOStream
Binnet:registerPacketReader(13, function(_, reader)
	cmd_groups[reader:readUByte()].enabled = false
end)

-- DB_SET_STRING
addDBPacketHandler(30, IOStream.readString)
-- DB_SET_NUMBER
addDBPacketHandler(31, from_zsr_double)

-- DRAW_COLOR
addDrawPacketReader(100, screen.setColor, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte)
-- DRAW_RECT
addDrawPacketReader(101, screen.drawRect, read2ByteUInt, read2ByteUInt, read2ByteUInt, read2ByteUInt)
-- DRAW_RECTF
addDrawPacketReader(102, screen.drawRectF, read2ByteUInt, read2ByteUInt, read2ByteUInt, read2ByteUInt)
-- DRAW_CIRCLE
addDrawPacketReader(103, screen.drawCircle, read2ByteUInt, read2ByteUInt, read2ByteUInt)
-- DRAW_CIRCLEF
addDrawPacketReader(104, screen.drawCircleF, read2ByteUInt, read2ByteUInt, read2ByteUInt)
-- DRAW_TRIANGLE
addDrawPacketReader(105, screen.drawTriangle, read2ByteUInt, read2ByteUInt, read2ByteUInt, read2ByteUInt, read2ByteUInt, read2ByteUInt)
-- DRAW_TRIANGLEF
addDrawPacketReader(106, screen.drawTriangleF, read2ByteUInt, read2ByteUInt, read2ByteUInt, read2ByteUInt, read2ByteUInt, read2ByteUInt)
-- DRAW_LINE
addDrawPacketReader(107, screen.drawLine, read2ByteUInt, read2ByteUInt, read2ByteUInt, read2ByteUInt)
-- DRAW_TEXT
addDrawPacketReader(108, function(x, y, db_idx, fmt)
	screen.drawText(x, y, db_idx == 0 and fmt or fmt:format(table.unpack(db_values[db_idx])))
end, read2ByteUInt, read2ByteUInt, IOStream.readUByte, IOStream.readString)
-- DRAW_TEXTBOX
addDrawPacketReader(109, function(x, y, w, h, db_idx, fmt, ...)
	screen.drawTextBox(x, y, w, h, db_idx == 0 and fmt or fmt:format(table.unpack(db_values[db_idx])), ...)
end, read2ByteUInt, read2ByteUInt, read2ByteUInt, read2ByteUInt, IOStream.readUByte, IOStream.readString, readAlignByte, readAlignByte)


-- DRAW_MAP
---@param reader IOStream
function readMapPos(reader) return reader:readCustom(-130000, 130000, 0.0001) end
---@param reader IOStream
addDrawPacketReader(110, screen.drawMap, readMapPos, readMapPos, function(reader) return reader:readCustom(0.1, 50, 0.00125) end)
addDrawPacketReader(111, screen.setMapColorGrass, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte)
addDrawPacketReader(112, screen.setMapColorLand, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte)
addDrawPacketReader(113, screen.setMapColorOcean, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte)
addDrawPacketReader(114, screen.setMapColorSand, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte)
addDrawPacketReader(115, screen.setMapColorShallows, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte)
addDrawPacketReader(116, screen.setMapColorSnow, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte, IOStream.readUByte)
