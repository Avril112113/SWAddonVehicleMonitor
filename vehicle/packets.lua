HALF_12P2 = (2^12)/2

---@param writer IOStream
---@param x integer
---@param y integer
function writeMonCoords(writer, x, y)
	writer:writeCustom(x, -HALF_12P2+2, HALF_12P2, 0.125)
	writer:writeCustom(y, -HALF_12P2+2, HALF_12P2, 0.125)
end

---@param reader IOStream
function readMonCoord(reader)
	return reader:readCustom(-HALF_12P2+2, HALF_12P2, 0.125)
end


PACKET_RESOLUION = Binnet:registerPacketWriter(1, function(_, writer, resolution)
	writeMonCoords(writer, resolution[1], resolution[2])
end)

__PACKET_INPUT_WRITER_F = function(_, writer, touch)
	writeMonCoords(writer, touch[1], touch[2])
	writer:writeUByte(touch[3] and 1 or 0)
end
PACKET_INPUT1 = Binnet:registerPacketWriter(2, __PACKET_INPUT_WRITER_F)
PACKET_INPUT2 = Binnet:registerPacketWriter(3, __PACKET_INPUT_WRITER_F)


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

PROPS_FUNCS = {
	["String"]=IOStream.readString,
	["UByte"]=IOStream.readUByte,
	["MonCoord"]=readMonCoord,
	---@param reader IOStream
	["MonX"]=function(reader)
		return readMonCoord(reader)
	end,
	---@param reader IOStream
	["MonY"]=function(reader)
		return readMonCoord(reader)
	end,
	---@param reader IOStream
	["DBFmt"]=function(reader)
		__db_idx = reader:readUByte()
		__fmt = reader:readString()
		return __db_idx == 0 and __fmt or __fmt:format(table.unpack(db_values[__db_idx]))
	end,
	---@param reader IOStream
	["AlignByte"]=function(reader)
		return reader:readUByte()-1
	end,
	---@param reader IOStream
	["zsr_double"]=function(reader)
		while #reader < 8 do
			reader[#reader+1] = 0
		end
		__n = iostream_packunpack("BBBBBBBB", ">d", table.unpack(reader))
		return __n//1|0 == __n and __n|0 or __n
	end,
	---@param reader IOStream
	["MapPos"]=function(reader) return reader:readCustom(-130000, 130000, 0.0001) end,
	---@param reader IOStream
	["MapZoom"]=function(reader) return reader:readCustom(0.1, 50, 0.00125) end,
}
for i=0,255 do
	local args = {}
	for s in (property.getText(tostring(i)) or ""):gmatch("([^,]+)") do table.insert(args, s) end
	-- debug.log("[SW] " .. i .. " " .. table.concat(args, " "))
	if args[1] == "draw" then
		Binnet:registerPacketReader(i, function (_, reader)
			cmd_groups[cmd_group_idx][cmd_group_draw_idx] = function()
				local draw_args = {}
				local reader_cpy = shallowCopy(reader, {})
				for arg_reader_i=4,#args do
					for _, v in ipairs({PROPS_FUNCS[args[arg_reader_i]](reader_cpy)}) do
						table.insert(draw_args, v)
					end
				end
				screen[args[3]](table.unpack(draw_args))
			end
			cmd_group_draw_idx = cmd_group_draw_idx + 1
		end)
	elseif args[1] == "db" then
		Binnet:registerPacketReader(i, function(_, reader)
			local db_idx, db_idy = reader:readUByte(), reader:readUByte()
			db_values[db_idx] = db_values[db_idx] or {}
			db_values[db_idx][db_idy] = PROPS_FUNCS[args[3]](reader)
		end)
	end
end
