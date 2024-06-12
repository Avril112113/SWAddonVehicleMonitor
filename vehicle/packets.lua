HALF_12P2 = (2^12)/2

DEFAULT_FMT_MAP = {
	-- expect number
	["A"]=0.0, ["a"]=0.0, ["E"]=0.0, ["e"]=0.0, ["f"]=0.0, ["G"]=0.0, ["g"]=0.0,
	-- expect integer
	["c"]=0, ["d"]=0, ["i"]=0, ["o"]=0, ["u"]=0, ["X"]=0, ["x"]=0,
	-- expect string
	["s"]="", ["q"]="",
}


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


if property.getBool("Mode") then
	PACKET_RESOLUION = Binnet:registerPacketWriter(1, function(_, writer, resolution)
		writeMonCoords(writer, resolution[1], resolution[2])
	end)
	Binnet:registerPacketReader(1, function(_, writer)
		Binnet:send(PACKET_RESOLUION, prev_resolution)
	end)
end

__PACKET_INPUT_WRITER_F = function(_, writer, touch)
	writeMonCoords(writer, touch[1] - MON_OFFSET_X, touch[2] - MON_OFFSET_Y)
	writer:writeUByte(touch[3] and 1 or 0)
end
PACKET_INPUT1 = Binnet:registerPacketWriter(2, __PACKET_INPUT_WRITER_F)
PACKET_INPUT2 = Binnet:registerPacketWriter(3, __PACKET_INPUT_WRITER_F)


-- FULL_RESET
Binnet:registerPacketReader(2, reset)

-- GROUP_RESET
---@param reader IOStream
Binnet:registerPacketReader(10, function(_, reader)
	cmd_group_idx = reader:readUByte()
	cmd_groups[cmd_group_idx] = {enabled=false,offset={0,0}}
	cmd_group_draw_idx = 1
end)

-- GROUP_SET
---@param reader IOStream
Binnet:registerPacketReader(11, function(_, reader)
	cmd_group_idx = reader:readUByte()
	cmd_group_draw_idx = reader:readUByte()
end)

function __packet_reader_enabled(_, reader, packet_id)
	cmd_groups[reader:readUByte()].enabled = packet_id == 12
end
-- GROUP_ENABLE
Binnet:registerPacketReader(12, __packet_reader_enabled)
-- GROUP_DISABLE
Binnet:registerPacketReader(13, __packet_reader_enabled)

-- GROUP_OFFSET
---@param reader IOStream
Binnet:registerPacketReader(14, function(_, reader)
	cmd_groups[reader:readUByte()].offset = {readMonCoord(reader), readMonCoord(reader)}
end)

PROPS_FUNCS = {
	--[[1]]
	IOStream.readString,
	--[[2]]
	IOStream.readUByte,
	--[[3]]
	readMonCoord,
	--[[4]]
	---@param reader IOStream
	function(reader, _mon_x)  -- MonX
		_mon_x = readMonCoord(reader)
		---@param group CmdGroup
		return function(group)
			return MON_OFFSET_X + group.offset[1] + _mon_x
		end
	end,
	--[[5]]
	---@param reader IOStream
	function(reader, _mon_y)  -- MonY
		_mon_y = readMonCoord(reader)
		---@param group CmdGroup
		return function(group)
			return MON_OFFSET_X + group.offset[2] + _mon_y
		end
	end,
	--[[6]]
	---@param reader IOStream
	function(reader, _db_idx, _fmt)  -- DBFmt
		_db_idx = reader:readUByte()
		_fmt = reader:readString()
		return function()
			__values = {}
			__i = 1
			for __fmt_spesifier in _fmt:gmatch("%%[-+ #0]?[%d.*]*([%w%%])") do
				table.insert(__values, db_values[_db_idx] and db_values[_db_idx][__i] or DEFAULT_FMT_MAP[__fmt_spesifier])
				__i = __i + 1
			end
			return _db_idx == 0 and _fmt or _fmt:format(table.unpack(__values))
		end
	end,
	--[[7]]
	---@param reader IOStream
	function(reader)  -- AlignByte
		return (reader:readUByte() or 0)-1
	end,
	--[[8]]
	---@param reader IOStream
	function(reader)  -- zsr_double
		while #reader < 8 do
			reader[#reader+1] = 0
		end
		__n = iostream_packunpack("BBBBBBBB", ">d", table.unpack(reader))
		return __n//1|0 == __n and __n|0 or __n
	end,
	--[[9]]
	---@param reader IOStream
	function(reader)  -- MapXZZoom
		-- 1.3e5 == 130000
		-- 1e-4 == 0.0001
		__x, __z = reader:readCustom(-1.3e5, 1.3e5, 1e-4), reader:readCustom(-1.3e5, 1.3e5, 1e-4)
		__zoom = reader:readCustom(0.1, 50, 0.00125)
		---@param group CmdGroup
		return function(group)
			return __x - ((MON_OFFSET_X + group.offset[1]) / prev_resolution[1] * __zoom * 1000), __z - ((MON_OFFSET_Y - group.offset[2]) / prev_resolution[1] * __zoom * 1000), __zoom
		end
	end,
}
for i=0,255 do
	local args = {}  -- Must be local
	for s in (property.getText(tostring(i)) or ""):gmatch("([^,]+)") do table.insert(args, s) end
	-- debug.log("[SW] " .. i .. " " .. table.concat(args, " "))
	if args[1] == "draw" then
		Binnet:registerPacketReader(i, function (_, reader, _read_args)
			_read_args = {}
			for arg_reader_i=4,#args do
				for _, v in ipairs({PROPS_FUNCS[tonumber(args[arg_reader_i])](reader)}) do
					table.insert(_read_args, v)
				end
			end
			---@param group CmdGroup
			cmd_groups[cmd_group_idx][cmd_group_draw_idx] = function(group)
				__draw_args = {}
				for arg_i,arg_v in ipairs(_read_args) do
					if type(arg_v) == "function" then
						for _, v in ipairs({arg_v(group)}) do
							table.insert(__draw_args, v)
						end
					else
						table.insert(__draw_args, arg_v)
					end
				end
				screen[args[3]](table.unpack(__draw_args))
			end
			cmd_group_draw_idx = cmd_group_draw_idx + 1
		end)
	elseif args[1] == "db" then
		Binnet:registerPacketReader(i, function(_, reader)
			__p_db_idx, __p_db_idy = reader:readUByte(), reader:readUByte()
			db_values[__p_db_idx] = db_values[__p_db_idx] or {}
			db_values[__p_db_idx][__p_db_idy] = PROPS_FUNCS[tonumber(args[3])](reader)
		end)
	end
end
