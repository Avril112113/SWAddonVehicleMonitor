---@diagnostic disable
--#region SSSWTool-Tracing-src
---@source <SSSWTOOL>/src/tracing.lua:9:0
local SS_SW_DBG = {}
---@source <SSSWTOOL>/src/tracing.lua:11:0
SS_SW_DBG._stack = {}
---@source <SSSWTOOL>/src/tracing.lua:12:0
SS_SW_DBG._server = {
	announce = server.announce,
	getAddonData = server.getAddonData,
	getAddonIndex = server.getAddonIndex,
	httpGet = server.httpGet,
}
---@source <SSSWTOOL>/src/tracing.lua:19:0
function SS_SW_DBG._trace_enter(id)
	table.insert(SS_SW_DBG._stack, #SS_SW_DBG._stack + 1, id)
end
---@source <SSSWTOOL>/src/tracing.lua:23:0
function SS_SW_DBG._trace_exit(id)
	---@source <SSSWTOOL>/src/tracing.lua:24:1
	local removed_id = table.remove(SS_SW_DBG._stack, #SS_SW_DBG._stack)
	if removed_id ~= id then
		---@source <SSSWTOOL>/src/tracing.lua:26:2
		local msg = ("Attempt to exit trace '%s' but found '%s' instead."):format(id, removed_id)
		debug.log("[SW] [ERROR] " .. msg)
		SS_SW_DBG._server.announce(SS_SW_DBG._server.getAddonData((SS_SW_DBG._server.getAddonIndex())).name, msg, -1)
	end
end
---@source <SSSWTOOL>/src/tracing.lua:32:0
function SS_SW_DBG._trace_func(id, f, ...)
	SS_SW_DBG._trace_enter(id)
	---@source <SSSWTOOL>/src/tracing.lua:34:1
	local results = {
		f(...),
	}
	SS_SW_DBG._trace_exit(id)
	return table.unpack(results)
end
---@source <SSSWTOOL>/src/tracing.lua:41:0
function SS_SW_DBG._hook_tbl(tbl, path)
	for i, v in pairs(tbl) do
		if type(i) == "string" and type(v) == "function" then
			---@source <SSSWTOOL>/src/tracing.lua:44:3
			local nindex = SS_SW_DBG._nindex
			---@source <SSSWTOOL>/src/tracing.lua:45:3
			SS_SW_DBG._info[nindex] = {
				["name"] = path .. "." .. i,
				["line"] = 1,
				["column"] = 1,
				["file"] = "{_ENV}",
			}
			---@source <SSSWTOOL>/src/tracing.lua:51:3
			tbl[i] = function(...)
				return SS_SW_DBG._trace_func(nindex, v, ...)
			end
			---@source <SSSWTOOL>/src/tracing.lua:54:3
			SS_SW_DBG._nindex = SS_SW_DBG._nindex - 1
		end
	end
end
---@source <SSSWTOOL>/src/tracing.lua:59:0
function SS_SW_DBG._sendCheckStackHttp()
	SS_SW_DBG._server.httpGet(0, "SSSWTool-tracing-check_stack")
end
---@source <SSSWTOOL>/src/tracing.lua:63:0
function SS_SW_DBG._handleHttp(port, request)
	if port == 0 and request == "SSSWTool-tracing-check_stack" then
		SS_SW_DBG.check_stack(0)
		return true
	end
	return false
end
---@source <SSSWTOOL>/src/tracing.lua:72:0
function SS_SW_DBG.stacktrace(depth)
	---@source <SSSWTOOL>/src/tracing.lua:73:1
	depth = depth or #SS_SW_DBG._stack
	---@source <SSSWTOOL>/src/tracing.lua:74:1
	local lines = {}
	---@source <SSSWTOOL>/src/tracing.lua:75:1
	local prev_file
	for i=depth,1,-1 do
		---@source <SSSWTOOL>/src/tracing.lua:77:2
		local id = SS_SW_DBG._stack[i]
		---@source <SSSWTOOL>/src/tracing.lua:78:2
		local trace = SS_SW_DBG._info[id]
		if trace.file ~= prev_file then
			---@source <SSSWTOOL>/src/tracing.lua:80:3
			prev_file = trace.file
			table.insert(lines, ("   '%s'"):format(trace.file))
		end
		table.insert(lines, ("%s %s @ %s:%s"):format(i, trace.name, trace.line, trace.column))
	end
	return lines
end
---@source <SSSWTOOL>/src/tracing.lua:90:0
function SS_SW_DBG.check_stack(expected_depth)
	if #SS_SW_DBG._stack > expected_depth then
		---@source <SSSWTOOL>/src/tracing.lua:92:2
		local lines = SS_SW_DBG.stacktrace(#SS_SW_DBG._stack - expected_depth)
		table.insert(lines, 1, "Detected unwound stacktrace:")
		for i=#SS_SW_DBG._stack - expected_depth,1,-1 do
			table.remove(SS_SW_DBG._stack, i)
		end
		for _, s in ipairs(lines) do
			debug.log("[SW] [ERROR] " .. s)
		end
		SS_SW_DBG._server.announce(SS_SW_DBG._server.getAddonData((SS_SW_DBG._server.getAddonIndex())).name, table.concat(lines, "\n"), -1)
		return true
	end
	return false
end
---@source <SSSWTOOL>/src/tracing.lua:105:0
function SS_SW_DBG.get_current_info()
	return SS_SW_DBG._info[SS_SW_DBG._stack[#SS_SW_DBG._stack]]
end
---@source <SSSWTOOL>/src/tracing.lua:110:0
SS_SW_DBG._nindex = -1
---@source <SSSWTOOL>/src/tracing.lua:112:0
SS_SW_DBG._info = {}
SS_SW_DBG._hook_tbl(server, "server")
--#endregion
--#region SSSWTool-Tracing-info
---@source .././script.lua:8:1
SS_SW_DBG._info[1] = {
	["name"] = "require",
	["line"] = 4,
	["column"] = 17,
	["file"] = "./{SSSWTOOL}/src/require.lua",
}
---@source .././script.lua:6:13
SS_SW_DBG._info[2] = {
	["name"] = "assert",
	["line"] = 5,
	["column"] = 23,
	["file"] = "logging.lua",
}
---@source .././script.lua:22:0
SS_SW_DBG._info[3] = {
	["name"] = "_argsToStrTable",
	["line"] = 28,
	["column"] = 32,
	["file"] = "logging.lua",
}
---@source .././script.lua:28:24
SS_SW_DBG._info[4] = {
	["name"] = "_log",
	["line"] = 38,
	["column"] = 15,
	["file"] = "logging.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[5] = {
	["name"] = "log_setContext",
	["line"] = 83,
	["column"] = 25,
	["file"] = "logging.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[6] = {
	["name"] = "log_debug",
	["line"] = 87,
	["column"] = 20,
	["file"] = "logging.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[7] = {
	["name"] = "log_info",
	["line"] = 91,
	["column"] = 19,
	["file"] = "logging.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[8] = {
	["name"] = "log_warn",
	["line"] = 96,
	["column"] = 19,
	["file"] = "logging.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[9] = {
	["name"] = "log_error",
	["line"] = 100,
	["column"] = 20,
	["file"] = "logging.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[10] = {
	["name"] = "log_call",
	["line"] = 104,
	["column"] = 19,
	["file"] = "logging.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[11] = {
	["name"] = "log_sendPeer",
	["line"] = 108,
	["column"] = 23,
	["file"] = "logging.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[12] = {
	["name"] = "log_cmdResponse",
	["line"] = 112,
	["column"] = 26,
	["file"] = "logging.lua",
}
---@source .././script.lua:1:0
SS_SW_DBG._info[13] = {
	["name"] = '__SSSWTOOL_REQUIRES["logging"]',
	["line"] = 1,
	["column"] = 1,
	["file"] = "script.lua",
}
---@source .././script.lua:20:47
SS_SW_DBG._info[14] = {
	["name"] = "assert",
	["line"] = 15,
	["column"] = 16,
	["file"] = "helpers.lua",
}
---@source .././script.lua:34:4
SS_SW_DBG._info[15] = {
	["name"] = "toStringRepr",
	["line"] = 29,
	["column"] = 22,
	["file"] = "helpers.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[16] = {
	["name"] = "shallowCopy",
	["line"] = 74,
	["column"] = 21,
	["file"] = "helpers.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[17] = {
	["name"] = "simpleDeepCopy",
	["line"] = 86,
	["column"] = 24,
	["file"] = "helpers.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[18] = {
	["name"] = "arg_truthy",
	["line"] = 102,
	["column"] = 20,
	["file"] = "helpers.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[19] = {
	["name"] = "fmtRate",
	["line"] = 109,
	["column"] = 17,
	["file"] = "helpers.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[20] = {
	["name"] = "round",
	["line"] = 132,
	["column"] = 15,
	["file"] = "helpers.lua",
}
---@source .././script.lua:1:0
SS_SW_DBG._info[21] = {
	["name"] = '__SSSWTOOL_REQUIRES["helpers"]',
	["line"] = 1,
	["column"] = 1,
	["file"] = "script.lua",
}
---@source .././script.lua:26:38
SS_SW_DBG._info[22] = {
	["name"] = "VehMon.new",
	["line"] = 28,
	["column"] = 20,
	["file"] = "vehmon/init.lua",
}
---@source .././script.lua:36:0
SS_SW_DBG._info[23] = {
	["name"] = "VehMon:tick",
	["line"] = 38,
	["column"] = 21,
	["file"] = "vehmon/init.lua",
}
---@source .././script.lua:55:1
SS_SW_DBG._info[24] = {
	["name"] = "VehMon:init",
	["line"] = 56,
	["column"] = 21,
	["file"] = "vehmon/init.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[25] = {
	["name"] = "VehMon:deinit",
	["line"] = 70,
	["column"] = 23,
	["file"] = "vehmon/init.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[26] = {
	["name"] = "VehMon:update",
	["line"] = 76,
	["column"] = 23,
	["file"] = "vehmon/init.lua",
}
---@source .././script.lua:1:0
SS_SW_DBG._info[27] = {
	["name"] = '__SSSWTOOL_REQUIRES["vehmon"]',
	["line"] = 1,
	["column"] = 1,
	["file"] = "script.lua",
}
---@source .././script.lua:14:13
SS_SW_DBG._info[28] = {
	["name"] = "iostream_packunpack",
	["line"] = 10,
	["column"] = 29,
	["file"] = "../shared/iostream.lua",
}
---@source .././script.lua:25:27
SS_SW_DBG._info[29] = {
	["name"] = "IOStream.new",
	["line"] = 29,
	["column"] = 22,
	["file"] = "../shared/iostream.lua",
}
---@source .././script.lua:32:7
SS_SW_DBG._info[30] = {
	["name"] = "IOStream.writeStream",
	["line"] = 34,
	["column"] = 30,
	["file"] = "../shared/iostream.lua",
}
---@source .././script.lua:36:0
SS_SW_DBG._info[31] = {
	["name"] = "IOStream.readUBytes",
	["line"] = 40,
	["column"] = 29,
	["file"] = "../shared/iostream.lua",
}
---@source .././script.lua:48:11
SS_SW_DBG._info[32] = {
	["name"] = "IOStream.readUByte",
	["line"] = 48,
	["column"] = 28,
	["file"] = "../shared/iostream.lua",
}
---@source .././script.lua:52:19
SS_SW_DBG._info[33] = {
	["name"] = "IOStream.writeUByte",
	["line"] = 52,
	["column"] = 29,
	["file"] = "../shared/iostream.lua",
}
---@source .././script.lua:58:1
SS_SW_DBG._info[34] = {
	["name"] = "IOStream.readCustom",
	["line"] = 59,
	["column"] = 29,
	["file"] = "../shared/iostream.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[35] = {
	["name"] = "IOStream.writeCustom",
	["line"] = 70,
	["column"] = 30,
	["file"] = "../shared/iostream.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[36] = {
	["name"] = "IOStream.readString",
	["line"] = 81,
	["column"] = 29,
	["file"] = "../shared/iostream.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[37] = {
	["name"] = "IOStream.writeString",
	["line"] = 87,
	["column"] = 30,
	["file"] = "../shared/iostream.lua",
}
---@source .././script.lua:1:0
SS_SW_DBG._info[38] = {
	["name"] = '__SSSWTOOL_REQUIRES["iostream"]',
	["line"] = 1,
	["column"] = 1,
	["file"] = "script.lua",
}
---@source .././script.lua:20:36
SS_SW_DBG._info[39] = {
	["name"] = "binnet_encode",
	["line"] = 17,
	["column"] = 23,
	["file"] = "../shared/binnet.lua",
}
---@source .././script.lua:25:11
SS_SW_DBG._info[40] = {
	["name"] = "binnet_decode",
	["line"] = 24,
	["column"] = 23,
	["file"] = "../shared/binnet.lua",
}
---@source .././script.lua:54:48
SS_SW_DBG._info[41] = {
	["name"] = "Binnet.new",
	["line"] = 48,
	["column"] = 20,
	["file"] = "../shared/binnet.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[42] = {
	["name"] = "Binnet.registerPacketReader",
	["line"] = 60,
	["column"] = 37,
	["file"] = "../shared/binnet.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[43] = {
	["name"] = "Binnet.registerPacketWriter",
	["line"] = 67,
	["column"] = 37,
	["file"] = "../shared/binnet.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[44] = {
	["name"] = "Binnet.send",
	["line"] = 74,
	["column"] = 21,
	["file"] = "../shared/binnet.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[45] = {
	["name"] = "Binnet.setLastUrgent",
	["line"] = 82,
	["column"] = 30,
	["file"] = "../shared/binnet.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[46] = {
	["name"] = "Binnet.process",
	["line"] = 88,
	["column"] = 24,
	["file"] = "../shared/binnet.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[47] = {
	["name"] = "Binnet.write",
	["line"] = 117,
	["column"] = 22,
	["file"] = "../shared/binnet.lua",
}
---@source .././script.lua:1:0
SS_SW_DBG._info[48] = {
	["name"] = '__SSSWTOOL_REQUIRES["binnet"]',
	["line"] = 1,
	["column"] = 1,
	["file"] = "script.lua",
}
---@source .././script.lua:8:0
SS_SW_DBG._info[49] = {
	["name"] = "write2ByteUInt",
	["line"] = 5,
	["column"] = 30,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:15:38
SS_SW_DBG._info[50] = {
	["name"] = "writeDBStr",
	["line"] = 12,
	["column"] = 26,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:20:35
SS_SW_DBG._info[51] = {
	["name"] = "writeAlignByte",
	["line"] = 19,
	["column"] = 30,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:21:0
SS_SW_DBG._info[52] = {
	["name"] = "to_zsr_double",
	["line"] = 24,
	["column"] = 29,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:28:20
SS_SW_DBG._info[53] = {
	["name"] = "from_zsr_double",
	["line"] = 33,
	["column"] = 31,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:54:21
SS_SW_DBG._info[54] = {
	["name"] = "anonymous:54",
	["line"] = 53,
	["column"] = 44,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[55] = {
	["name"] = "anonymous:55",
	["line"] = 59,
	["column"] = 69,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[56] = {
	["name"] = "anonymous:56",
	["line"] = 63,
	["column"] = 44,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[57] = {
	["name"] = "anonymous:57",
	["line"] = 72,
	["column"] = 44,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[58] = {
	["name"] = "anonymous:58",
	["line"] = 81,
	["column"] = 65,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[59] = {
	["name"] = "anonymous:59",
	["line"] = 84,
	["column"] = 67,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[60] = {
	["name"] = "anonymous:60",
	["line"] = 87,
	["column"] = 66,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[61] = {
	["name"] = "anonymous:61",
	["line"] = 91,
	["column"] = 68,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[62] = {
	["name"] = "anonymous:62",
	["line"] = 94,
	["column"] = 69,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[63] = {
	["name"] = "anonymous:63",
	["line"] = 98,
	["column"] = 69,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[64] = {
	["name"] = "anonymous:64",
	["line"] = 103,
	["column"] = 69,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[65] = {
	["name"] = "anonymous:65",
	["line"] = 111,
	["column"] = 68,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[66] = {
	["name"] = "anonymous:66",
	["line"] = 116,
	["column"] = 68,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[67] = {
	["name"] = "anonymous:67",
	["line"] = 121,
	["column"] = 67,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[68] = {
	["name"] = "anonymous:68",
	["line"] = 127,
	["column"] = 66,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[69] = {
	["name"] = "anonymous:69",
	["line"] = 133,
	["column"] = 67,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[70] = {
	["name"] = "anonymous:70",
	["line"] = 139,
	["column"] = 68,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[71] = {
	["name"] = "anonymous:71",
	["line"] = 144,
	["column"] = 69,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[72] = {
	["name"] = "anonymous:72",
	["line"] = 149,
	["column"] = 70,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[73] = {
	["name"] = "anonymous:73",
	["line"] = 157,
	["column"] = 71,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[74] = {
	["name"] = "anonymous:74",
	["line"] = 165,
	["column"] = 66,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[75] = {
	["name"] = "anonymous:75",
	["line"] = 171,
	["column"] = 66,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[76] = {
	["name"] = "anonymous:76",
	["line"] = 176,
	["column"] = 69,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:65:0
SS_SW_DBG._info[77] = {
	["name"] = "anonymous:77",
	["line"] = 185,
	["column"] = 65,
	["file"] = "vehmon/packets.lua",
}
---@source .././script.lua:1:0
SS_SW_DBG._info[78] = {
	["name"] = '__SSSWTOOL_REQUIRES["vehmon.packets"]',
	["line"] = 1,
	["column"] = 1,
	["file"] = "script.lua",
}
---@source .././script.lua:15:27
SS_SW_DBG._info[79] = {
	["name"] = "createVehMon",
	["line"] = 15,
	["column"] = 28,
	["file"] = "script.lua",
}
---@source .././script.lua:26:27
SS_SW_DBG._info[80] = {
	["name"] = "removeVehMon",
	["line"] = 26,
	["column"] = 28,
	["file"] = "script.lua",
}
---@source .././script.lua:32:17
SS_SW_DBG._info[81] = {
	["name"] = "onCreate",
	["line"] = 32,
	["column"] = 18,
	["file"] = "script.lua",
}
---@source .././script.lua:41:15
SS_SW_DBG._info[82] = {
	["name"] = "onTick",
	["line"] = 41,
	["column"] = 16,
	["file"] = "script.lua",
}
---@source .././script.lua:53:23
SS_SW_DBG._info[83] = {
	["name"] = "onVehicleSpawn",
	["line"] = 53,
	["column"] = 24,
	["file"] = "script.lua",
}
---@source .././script.lua:62:25
SS_SW_DBG._info[84] = {
	["name"] = "onVehicleDespawn",
	["line"] = 62,
	["column"] = 26,
	["file"] = "script.lua",
}
--#endregion
---@source .././script.lua:1:0
httpReply = function(...)
	if SS_SW_DBG._handleHttp(...) then
		return
	end
end
--#region SSSWTool-Require-src
---@source <SSSWTOOL>/src/require.lua:1:0
__SSSWTOOL_REQUIRES = {}
---@source <SSSWTOOL>/src/require.lua:2:0
__SSSWTOOL_MOD_TO_FILEPATH = {}
---@source <SSSWTOOL>/src/require.lua:3:0
__SSSWTOOL_RESULTS = {}
---@source <SSSWTOOL>/src/require.lua:4:0
function require(...)
	return SS_SW_DBG._trace_func(1, function(modpath)
		if __SSSWTOOL_RESULTS[modpath] == nil then
			---@source <SSSWTOOL>/src/require.lua:6:2
			__SSSWTOOL_RESULTS[modpath] = __SSSWTOOL_REQUIRES[modpath](modpath, __SSSWTOOL_MOD_TO_FILEPATH[modpath])
			if __SSSWTOOL_RESULTS[modpath] == nil then
				---@source <SSSWTOOL>/src/require.lua:8:3
				__SSSWTOOL_RESULTS[modpath] = true
			end
		end
		return __SSSWTOOL_RESULTS[modpath]
	end, ...)
end
--#endregion
---@source .././script.lua:1:0
__SSSWTOOL_MOD_TO_FILEPATH["logging"] = "logging.lua"
---@source .././script.lua:1:0
__SSSWTOOL_REQUIRES["logging"] = function(...)
	return SS_SW_DBG._trace_func(13, function(...)
		do
			---@source .././logging.lua:4:1
			local SCRIPT_PREFIX = "AVM"
			---@source .././logging.lua:5:1
			local function assert(...)
				return SS_SW_DBG._trace_func(2, function(v, msg, ...)
					if not v then
						debug.log(("[SW-%s] [ERROR] Assertion failed: %s"):format(SCRIPT_PREFIX, msg or "<NO_MSG>"))
						error()
					end
					return v, msg, ...
				end, ...)
			end
			---@source .././logging.lua:13:1
			local LOG_LEVEL_NAMES = {
				"error",
				"warn",
				"info",
				"debug",
			}
			---@source .././logging.lua:19:1
			local LOG_LEVEL_INDICES = {}
			for i, name in ipairs(LOG_LEVEL_NAMES) do
				---@source .././logging.lua:21:2
				LOG_LEVEL_INDICES[name] = i
			end
			---@source .././logging.lua:25:1
			local additionalGlobalContext = {}
			---@source .././logging.lua:28:1
			local function _argsToStrTable(...)
				return SS_SW_DBG._trace_func(3, function(...)
					---@source .././logging.lua:29:2
					local args = {
						...,
					}
					for i=1,#args do
						---@source .././logging.lua:31:3
						args[i] = tostring(args[i])
					end
					return args
				end, ...)
			end
			---@source .././logging.lua:38:1
			function _log(...)
				return SS_SW_DBG._trace_func(4, function(tbl)
					---@source .././logging.lua:39:2
					g_savedata.log_level = g_savedata.log_level or DEFAULT_LOG_LEVEL
					---@source .././logging.lua:41:2
					local level = tbl.level or -1
					---@source .././logging.lua:42:2
					local peer_id = tbl.peer_id or -1
					---@source .././logging.lua:43:2
					local additionalContext = tbl.additionalContext or {}
					debug.log("[LB] [debug] !!! " .. tostring(level) .. " >= " .. tostring(g_savedata.log_level))
					if type(level) == "string" then
						---@source .././logging.lua:48:3
						level = assert(LOG_LEVEL_INDICES[level], "Invalid log level '" .. level .. "'")
					end
					---@source .././logging.lua:51:2
					local args = _argsToStrTable(table.unpack(tbl))
					---@source .././logging.lua:52:2
					local msg = table.concat(args, " ")
					if level <= 0 or level <= g_savedata.log_level then
						---@source .././logging.lua:55:3
						local nameParts = {
							SCRIPT_PREFIX,
							level <= 0 and "" or " - " .. assert(LOG_LEVEL_NAMES[level], "Invalid log level " .. tostring(level)),
						}
						server.announce(table.concat(nameParts), msg, peer_id)
					end
					---@source .././logging.lua:61:2
					local debugLogLinePrefix = "[SW-" .. SCRIPT_PREFIX .. "] " .. (level <= 0 and "" or ("%-8s"):format("[" .. assert(LOG_LEVEL_NAMES[level], "Invalid log level " .. tostring(level)) .. "]"))
					---@source .././logging.lua:62:2
					local debugLogPartsPrefixParts = {
						peer_id < 0 and "" or "[->" .. server.getPlayerName(peer_id) .. "] ",
					}
					for _, s in pairs(additionalGlobalContext) do
						table.insert(debugLogPartsPrefixParts, ("[%s] "):format(s))
					end
					for _, s in ipairs(additionalContext) do
						table.insert(debugLogPartsPrefixParts, ("[%s] "):format(s))
					end
					---@source .././logging.lua:71:2
					local debugLogPrefix = table.concat(debugLogPartsPrefixParts)
					---@source .././logging.lua:72:2
					local debugLogParts = {
						debugLogLinePrefix,
						debugLogPrefix,
						msg,
					}
					---@source .././logging.lua:77:2
					local debugLog = table.concat(debugLogParts):gsub("\n", "\n" .. debugLogLinePrefix .. string.rep(" ", #debugLogPrefix))
					debug.log(debugLog)
				end, ...)
			end
			---@source .././logging.lua:83:1
			function log_setContext(...)
				return SS_SW_DBG._trace_func(5, function(id, s)
					---@source .././logging.lua:84:2
					additionalGlobalContext[id] = s
				end, ...)
			end
			---@source .././logging.lua:87:1
			function log_debug(...)
				return SS_SW_DBG._trace_func(6, function(...)
					_log({
						level = 4,
						...,
					})
				end, ...)
			end
			---@source .././logging.lua:91:1
			function log_info(...)
				return SS_SW_DBG._trace_func(7, function(...)
					_log({
						level = 3,
						...,
					})
				end, ...)
			end
			---@source .././logging.lua:94:1
			log = log_info
			---@source .././logging.lua:96:1
			function log_warn(...)
				return SS_SW_DBG._trace_func(8, function(...)
					_log({
						level = 2,
						...,
					})
				end, ...)
			end
			---@source .././logging.lua:100:1
			function log_error(...)
				return SS_SW_DBG._trace_func(9, function(...)
					_log({
						level = 1,
						...,
					})
				end, ...)
			end
			---@source .././logging.lua:104:1
			function log_call(...)
				return SS_SW_DBG._trace_func(10, function(name, ...)
					_log({
						level = 4,
						name .. "(" .. table.concat(_argsToStrTable(...), ", ") .. ")",
					})
				end, ...)
			end
			---@source .././logging.lua:108:1
			function log_sendPeer(...)
				return SS_SW_DBG._trace_func(11, function(peer_id, ...)
					_log({
						peer_id = peer_id,
						...,
					})
				end, ...)
			end
			---@source .././logging.lua:112:1
			function log_cmdResponse(...)
				return SS_SW_DBG._trace_func(12, function(command, peer_id, ...)
					_log({
						peer_id = peer_id,
						additionalContext = {
							command,
						},
						...,
					})
				end, ...)
			end
		end
	end, ...)
end
---@source .././script.lua:1:0
__SSSWTOOL_MOD_TO_FILEPATH["helpers"] = "helpers.lua"
---@source .././script.lua:1:0
__SSSWTOOL_REQUIRES["helpers"] = function(...)
	return SS_SW_DBG._trace_func(21, function(...)
		---@source .././helpers.lua:1:0
		DT = 1 / 60
		---@source .././helpers.lua:15:0
		function assert(...)
			return SS_SW_DBG._trace_func(14, function(v, message, ...)
				if not v then
					error(message or "assertion failed!")
				end
				return v, message, ...
			end, ...)
		end
		---@source .././helpers.lua:29:0
		function toStringRepr(...)
			return SS_SW_DBG._trace_func(15, function(t, maxdepth, indent, seen)
				---@source .././helpers.lua:30:1
				seen = seen or {}
				---@source .././helpers.lua:31:1
				indent = (indent or 0) + 1
				---@source .././helpers.lua:32:1
				maxdepth = maxdepth or math.maxinteger
				---@source .././helpers.lua:34:1
				local typeof = type(t)
				if typeof == "table" then
					---@source .././helpers.lua:36:2
					local existing = seen[t]
					if existing then
						return "{REF-" .. tostring(t) .. "}"
					elseif indent > maxdepth + 1 then
						return "{" .. tostring(t) .. "}"
					else
						---@source .././helpers.lua:42:3
						seen[t] = true
						---@source .././helpers.lua:44:3
						local s = {}
						for k, v in pairs(t) do
							---@source .././helpers.lua:46:4
							local kType = type(k)
							if kType == "string" then
								---@source .././helpers.lua:48:5
								s[#s + 1] = string.rep(" ", indent * 4) .. "" .. tostring(k) .. " = " .. toStringRepr(v, maxdepth, indent, seen)
							elseif kType ~= "number" or k < 1 or k > #t then
								---@source .././helpers.lua:50:5
								s[#s + 1] = string.rep(" ", indent * 4) .. "[" .. tostring(k) .. "] = " .. toStringRepr(v, maxdepth, indent, seen)
							end
						end
						for i=1,#t do
							---@source .././helpers.lua:56:4
							s[#s + 1] = string.rep(" ", indent * 4) .. toStringRepr(t[i], maxdepth, indent, seen)
						end
						if #s > 0 then
							return "{<" .. tostring(t) .. ">\n" .. table.concat(s, ",\n") .. "\n" .. string.rep(" ", (indent - 1) * 4) .. "}"
						else
							return "{<" .. tostring(t) .. ">}"
						end
					end
				elseif typeof == "string" then
					return "\"" .. t .. "\""
				else
					return tostring(t)
				end
			end, ...)
		end
		---@source .././helpers.lua:74:0
		function shallowCopy(...)
			return SS_SW_DBG._trace_func(16, function(source, dest)
				---@source .././helpers.lua:75:1
				dest = dest or {}
				for i, v in pairs(source) do
					---@source .././helpers.lua:77:2
					dest[i] = v
				end
				return dest
			end, ...)
		end
		---@source .././helpers.lua:86:0
		function simpleDeepCopy(...)
			return SS_SW_DBG._trace_func(17, function(source, dest)
				if source == nil then
					return nil
				end
				---@source .././helpers.lua:90:1
				dest = dest or {}
				for i, v in pairs(source) do
					if type(v) == "table" then
						---@source .././helpers.lua:93:3
						v = simpleDeepCopy(v, dest[i] or {})
					end
					---@source .././helpers.lua:95:2
					dest[i] = v
				end
				return dest
			end, ...)
		end
		---@source .././helpers.lua:100:0
		local TRUTHY_VALUES = {
			t = true,
			tr = true,
			tru = true,
			["true"] = true,
			y = true,
			ye = true,
			yes = true,
		}
		---@source .././helpers.lua:102:0
		function arg_truthy(...)
			return SS_SW_DBG._trace_func(18, function(s)
				return s ~= nil and TRUTHY_VALUES[s:lower()] or false
			end, ...)
		end
		---@source .././helpers.lua:109:0
		function fmtRate(...)
			return SS_SW_DBG._trace_func(19, function(seconds)
				---@source .././helpers.lua:110:1
				local hours = 0
				---@source .././helpers.lua:111:1
				local days = 0
				if seconds >= 60 then
					---@source .././helpers.lua:113:2
					hours = seconds // 60
					---@source .././helpers.lua:114:2
					seconds = seconds - hours * 60
					if hours >= 24 then
						---@source .././helpers.lua:116:3
						days = hours // 24
						---@source .././helpers.lua:117:3
						hours = hours - hours * 24
					end
				end
				---@source .././helpers.lua:120:1
				local parts = {
					("%.0fs"):format(seconds),
				}
				if hours > 0 then
					table.insert(parts, ("%.0fh"):format(hours))
				end
				if days > 0 then
					table.insert(parts, ("%.0fdays"):format(days))
				end
				return table.concat(parts, " ")
			end, ...)
		end
		---@source .././helpers.lua:132:0
		function round(...)
			return SS_SW_DBG._trace_func(20, function(value, decimals)
				return tonumber(string.format("%." .. decimals // 1 .. "f", value))
			end, ...)
		end
	end, ...)
end
---@source .././script.lua:1:0
__SSSWTOOL_MOD_TO_FILEPATH["vehmon"] = "vehmon/init.lua"
---@source .././script.lua:1:0
__SSSWTOOL_REQUIRES["vehmon"] = function(...)
	return SS_SW_DBG._trace_func(27, function(...)
		require("iostream")
		require("binnet")
		---@source .././vehmon/init.lua:3:0
		local Packets = require("vehmon.packets")
		---@source .././vehmon/init.lua:21:0
		local VehMon = {}
		---@source .././vehmon/init.lua:28:0
		function VehMon.new(...)
			return SS_SW_DBG._trace_func(22, function(vehicle_id, dial_count, keypad_count)
				---@source .././vehmon/init.lua:29:1
				local self = shallowCopy(VehMon, {
					vehicle_id = vehicle_id,
					dial_count = dial_count,
					keypad_count = keypad_count,
					initialized = false,
				})
				return self
			end, ...)
		end
		---@source .././vehmon/init.lua:38:0
		function VehMon:tick(...)
			return SS_SW_DBG._trace_func(23, function()
				---@source .././vehmon/init.lua:39:1
				local is_simulating, exists = server.getVehicleSimulating(self.vehicle_id)
				if not exists or not is_simulating then
					if self.initialized then
						log_debug(("%s - De-Init"):format(self.vehicle_id))
						self:deinit()
					end
					return
				end
				if self.monitor == nil then
					log_debug(("%s - Init"):format(self.vehicle_id))
					self:init()
				end
				self:update()
			end, ...)
		end
		---@source .././vehmon/init.lua:56:0
		function VehMon:init(...)
			return SS_SW_DBG._trace_func(24, function()
				---@source .././vehmon/init.lua:57:1
				self.initialized = true
				---@source .././vehmon/init.lua:58:1
				self.monitor = {
					width = 0,
					height = 0,
					touch1 = {
						x = 0,
						y = 0,
						pressed = false,
						was_pressed = false,
					},
					touch2 = {
						x = 0,
						y = 0,
						pressed = false,
						was_pressed = true,
					},
				}
				---@source .././vehmon/init.lua:65:1
				self.binnet = Packets.BinnetBase:new()
				---@source .././vehmon/init.lua:66:1
				self.binnet.vehmon = self
				self.binnet:send(Packets.reset)
			end, ...)
		end
		---@source .././vehmon/init.lua:70:0
		function VehMon:deinit(...)
			return SS_SW_DBG._trace_func(25, function()
				---@source .././vehmon/init.lua:71:1
				self.initialized = false
				---@source .././vehmon/init.lua:72:1
				self.monitor = nil
				---@source .././vehmon/init.lua:73:1
				self.binnet = nil
			end, ...)
		end
		---@source .././vehmon/init.lua:76:0
		function VehMon:update(...)
			return SS_SW_DBG._trace_func(26, function()
				if not self.initialized then
					return
				end
				---@source .././vehmon/init.lua:79:1
				self.monitor.touch1.was_pressed = self.monitor.touch1.pressed
				---@source .././vehmon/init.lua:80:1
				self.monitor.touch2.was_pressed = self.monitor.touch2.pressed
				---@source .././vehmon/init.lua:82:1
				local read_values = {}
				for i=1,self.dial_count do
					---@source .././vehmon/init.lua:84:2
					local data, ok = server.getVehicleDial(self.vehicle_id, "vehmon_" .. i)
					if not ok then
						return
					end
					---@source .././vehmon/init.lua:86:2
					read_values[i] = data.value
				end
				---@source .././vehmon/init.lua:88:1
				local byte_count, packet_count = self.binnet:process(read_values)
				if byte_count > 0 then
					log_debug(("%s - %s bytes, %s packets"):format(self.vehicle_id, byte_count, packet_count))
				end
				---@source .././vehmon/init.lua:93:1
				local write_values = self.binnet:write(self.keypad_count)
				for i=1,self.keypad_count do
					server.setVehicleKeypad(self.vehicle_id, "vehmon_" .. i, write_values[i])
				end
				---@source .././vehmon/init.lua:98:1
				local GROUP_IDXS = {
					MAP = 0,
					TOP_BAR = 1,
					PLAYER_INFO = 2,
				}
				---@source .././vehmon/init.lua:103:1
				local DB_IDXS = {
					COMPANY_NAME = 1,
					MONEY = 2,
					PLAYER_NAME = 3,
					PLAYER_POS = 4,
					SERVER_TIME = 5,
				}
				if self.monitor.width ~= 0 and not self._sent_setup then
					---@source .././vehmon/init.lua:112:2
					self._sent_setup = true
					log_debug(("%s - Sending setup packets."):format(self.vehicle_id))
					self.binnet:send(Packets.FULL_RESET)
					self.binnet:send(Packets.GROUP_RESET, GROUP_IDXS.MAP)
					---@source .././vehmon/init.lua:118:2
					local vehPos = server.getVehiclePos(self.vehicle_id)
					self.binnet:send(Packets.DRAW_MAP, vehPos[13], vehPos[15], 5)
					self.binnet:send(Packets.GROUP_ENABLE, GROUP_IDXS.MAP)
					self.binnet:send(Packets.GROUP_RESET, GROUP_IDXS.TOP_BAR)
					self.binnet:send(Packets.DRAW_COLOR, 0, 0, 0)
					self.binnet:send(Packets.DRAW_RECTF, 0, 0, 1000, 40)
					self.binnet:send(Packets.DRAW_COLOR, 255, 255, 255)
					self.binnet:send(Packets.DRAW_RECT, 0, 8, 288, 0)
					self.binnet:send(Packets.DRAW_TEXT, 1, 1, DB_IDXS.COMPANY_NAME, "%s")
					self.binnet:send(Packets.DB_SET_STRING, DB_IDXS.COMPANY_NAME, 1, "")
					self.binnet:send(Packets.DRAW_TEXT, 199, 1, DB_IDXS.MONEY, "$%s")
					self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.MONEY, 1, 0)
					self.binnet:send(Packets.GROUP_ENABLE, GROUP_IDXS.TOP_BAR)
					self.binnet:send(Packets.GROUP_RESET, GROUP_IDXS.PLAYER_INFO)
					self.binnet:send(Packets.DRAW_TEXT, 1, 14, DB_IDXS.PLAYER_NAME, "Name: %s")
					self.binnet:send(Packets.DB_SET_STRING, DB_IDXS.PLAYER_NAME, 1, server.getPlayerName(0) or "<NO_PLAYER>")
					self.binnet:send(Packets.DRAW_TEXT, 1, 14 + 8, DB_IDXS.PLAYER_POS, "Pos: %s, %s, %s")
					self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 1, 0)
					self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 2, 0)
					self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 3, 0)
					self.binnet:send(Packets.DRAW_TEXT, 1, 14 + 8 + 8, DB_IDXS.SERVER_TIME, "server time: %s")
					self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.SERVER_TIME, 1, 0)
					self.binnet:send(Packets.GROUP_ENABLE, GROUP_IDXS.PLAYER_INFO)
					self.binnet:send(Packets.DB_SET_STRING, DB_IDXS.COMPANY_NAME, 1, "Test company INC")
					self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.MONEY, 1, 12345678987654321)
				end
				if self.monitor.width ~= 0 then
					---@source .././vehmon/init.lua:148:2
					local pending_bytes = #self.binnet.outStream
					for _, packet in ipairs(self.binnet.outPackets) do
						---@source .././vehmon/init.lua:149:53
						pending_bytes = pending_bytes + #packet
					end
					if pending_bytes <= self.keypad_count * 3 then
						---@source .././vehmon/init.lua:152:3
						local pos = server.getPlayerPos(0)
						---@source .././vehmon/init.lua:153:3
						local pos_floored = {
							pos[13] // 1,
							pos[14] // 1,
							pos[15] // 1,
						}
						if not self._last_pos_floored or self._last_pos_floored[1] ~= pos_floored[1] or self._last_pos_floored[2] ~= pos_floored[2] or self._last_pos_floored[3] ~= pos_floored[3] then
							self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 1, pos_floored[1])
							self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 2, pos_floored[2])
							self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 3, pos_floored[3])
						end
						---@source .././vehmon/init.lua:160:3
						self._last_pos_floored = pos_floored
						self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.SERVER_TIME, 1, server.getTimeMillisec() / 1000)
					end
				end
				if self.monitor.width == 0 and not self._sent_setup and not self._sent_resolution_request then
					---@source .././vehmon/init.lua:166:2
					self._sent_resolution_request = true
					self.binnet:send(Packets.GET_RESOLUTION)
				end
			end, ...)
		end
		return VehMon
	end, ...)
end
---@source .././script.lua:1:0
__SSSWTOOL_MOD_TO_FILEPATH["iostream"] = "../shared/iostream.lua"
---@source .././script.lua:1:0
__SSSWTOOL_REQUIRES["iostream"] = function(...)
	return SS_SW_DBG._trace_func(38, function(...)
		---@source ../../shared/iostream.lua:10:0
		function iostream_packunpack(...)
			return SS_SW_DBG._trace_func(28, function(from, to, ...)
				return string.unpack(to, string.pack(from, ...))
			end, ...)
		end
		---@source ../../shared/iostream.lua:25:0
		IOStream = {}
		---@source ../../shared/iostream.lua:29:0
		function IOStream.new(...)
			return SS_SW_DBG._trace_func(29, function(bytes)
				return shallowCopy(IOStream, bytes or {})
			end, ...)
		end
		---@source ../../shared/iostream.lua:34:0
		function IOStream.writeStream(...)
			return SS_SW_DBG._trace_func(30, function(self, stream)
				table.move(stream, 1, #stream, #self + 1, self)
			end, ...)
		end
		---@source ../../shared/iostream.lua:40:0
		function IOStream.readUBytes(...)
			return SS_SW_DBG._trace_func(31, function(self, count)
				---@source ../../shared/iostream.lua:41:1
				__bytes = table.move(self, 1, count, 1, {})
				for i=1,count do
					table.remove(self, 1)
				end
				return __bytes
			end, ...)
		end
		---@source ../../shared/iostream.lua:48:0
		function IOStream.readUByte(...)
			return SS_SW_DBG._trace_func(32, function(self)
				return table.remove(self, 1)
			end, ...)
		end
		---@source ../../shared/iostream.lua:52:0
		function IOStream.writeUByte(...)
			return SS_SW_DBG._trace_func(33, function(self, ubyte)
				return table.insert(self, ubyte)
			end, ...)
		end
		---@source ../../shared/iostream.lua:59:0
		function IOStream.readCustom(...)
			return SS_SW_DBG._trace_func(34, function(self, min, max, precision)
				---@source ../../shared/iostream.lua:62:1
				__bitCount = math.floor(math.log((max - min) / precision, 2) + 0.5)
				---@source ../../shared/iostream.lua:63:1
				__byteCount = math.ceil(__bitCount / 8)
				---@source ../../shared/iostream.lua:64:1
				__quant, __frac = math.modf((iostream_packunpack((string.rep("B", __byteCount) .. string.rep("x", 8 - __byteCount)), "J", table.unpack(self:readUBytes(__byteCount))) * 2 ^ -__bitCount * (max - min) + min) / precision)
				return precision * (__quant + (__frac > 0 and 1 or 0))
			end, ...)
		end
		---@source ../../shared/iostream.lua:70:0
		function IOStream.writeCustom(...)
			return SS_SW_DBG._trace_func(35, function(self, value, min, max, precision)
				---@source ../../shared/iostream.lua:73:1
				__bitCount = math.floor(math.log((max - min) / precision, 2) + 0.5)
				---@source ../../shared/iostream.lua:74:1
				__precision = 2 ^ -__bitCount * (max - min)
				---@source ../../shared/iostream.lua:75:1
				__bytes = {
					iostream_packunpack("J", string.rep("B", math.ceil(__bitCount / 8)), math.floor((value - min) / __precision)),
				}
				table.remove(__bytes, #__bytes)
				self:writeStream(__bytes)
			end, ...)
		end
		---@source ../../shared/iostream.lua:81:0
		function IOStream.readString(...)
			return SS_SW_DBG._trace_func(36, function(self)
				---@source ../../shared/iostream.lua:82:1
				__size = self:readUByte()
				return (iostream_packunpack(string.rep("B", __size), "c" .. __size, table.unpack(self:readUBytes(__size))))
			end, ...)
		end
		---@source ../../shared/iostream.lua:87:0
		function IOStream.writeString(...)
			return SS_SW_DBG._trace_func(37, function(self, s)
				self:writeUByte(#s)
				---@source ../../shared/iostream.lua:89:1
				__bytes = {
					iostream_packunpack("c" .. #s, string.rep("B", #s), s),
				}
				table.remove(__bytes, #__bytes)
				self:writeStream(__bytes)
			end, ...)
		end
	end, ...)
end
---@source .././script.lua:1:0
__SSSWTOOL_MOD_TO_FILEPATH["binnet"] = "../shared/binnet.lua"
---@source .././script.lua:1:0
__SSSWTOOL_REQUIRES["binnet"] = function(...)
	return SS_SW_DBG._trace_func(48, function(...)
		---@source ../../shared/binnet.lua:17:0
		function binnet_encode(...)
			return SS_SW_DBG._trace_func(39, function(a, b, c)
				return (iostream_packunpack("BBBB", "<f", a, b, c, 1))
			end, ...)
		end
		---@source ../../shared/binnet.lua:24:0
		function binnet_decode(...)
			return SS_SW_DBG._trace_func(40, function(f)
				---@source ../../shared/binnet.lua:25:1
				local a, b, c = iostream_packunpack("<f", "BBBB", f)
				return a or 0, b or 0, c or 0
			end, ...)
		end
		---@source ../../shared/binnet.lua:40:0
		Binnet = {
			packetReaders = {},
			packetWriters = {},
		}
		---@source ../../shared/binnet.lua:48:0
		function Binnet.new(...)
			return SS_SW_DBG._trace_func(41, function(self)
				---@source ../../shared/binnet.lua:49:1
				self = shallowCopy(self, {})
				---@source ../../shared/binnet.lua:50:1
				self.packetReaders = shallowCopy(self.packetReaders, {})
				---@source ../../shared/binnet.lua:51:1
				self.packetWriters = shallowCopy(self.packetWriters, {})
				---@source ../../shared/binnet.lua:52:1
				self.inStream = IOStream.new()
				---@source ../../shared/binnet.lua:53:1
				self.outStream = IOStream.new()
				---@source ../../shared/binnet.lua:54:1
				self.outPackets = {}
				return self
			end, ...)
		end
		---@source ../../shared/binnet.lua:60:0
		function Binnet.registerPacketReader(...)
			return SS_SW_DBG._trace_func(42, function(self, packetId, handler)
				---@source ../../shared/binnet.lua:61:1
				self.packetReaders[packetId] = handler
			end, ...)
		end
		---@source ../../shared/binnet.lua:67:0
		function Binnet.registerPacketWriter(...)
			return SS_SW_DBG._trace_func(43, function(self, packetId, handler)
				---@source ../../shared/binnet.lua:68:1
				self.packetWriters[packetId] = handler
				return packetId
			end, ...)
		end
		---@source ../../shared/binnet.lua:74:0
		function Binnet.send(...)
			return SS_SW_DBG._trace_func(44, function(self, packetWriterId, ...)
				---@source ../../shared/binnet.lua:75:1
				local writer = IOStream.new()
				writer:writeUByte(packetWriterId)
				---@source ../../shared/binnet.lua:77:1
				_ = self.packetWriters[packetWriterId] and self.packetWriters[packetWriterId](self, writer, ...)
				table.insert(writer, 1, #writer + 1)
				table.insert(self.outPackets, writer)
			end, ...)
		end
		---@source ../../shared/binnet.lua:82:0
		function Binnet.setLastUrgent(...)
			return SS_SW_DBG._trace_func(45, function(self)
				table.insert(self.outPackets, 1, table.remove(self.outPackets, #self.outPackets))
			end, ...)
		end
		---@source ../../shared/binnet.lua:88:0
		function Binnet.process(...)
			return SS_SW_DBG._trace_func(46, function(self, values)
				for _, v in ipairs(values) do
					---@source ../../shared/binnet.lua:90:2
					local a, b, c = binnet_decode(v)
					table.insert(self.inStream, a)
					table.insert(self.inStream, b)
					table.insert(self.inStream, c)
				end
				---@source ../../shared/binnet.lua:96:1
				local totalByteCount, packetCount = 0, 0
				while self.inStream[1] ~= nil do
					---@source ../../shared/binnet.lua:98:2
					local byteCount = self.inStream[1]
					if byteCount == 0 then
						self.inStream:readUByte()
					elseif #self.inStream >= byteCount then
						---@source ../../shared/binnet.lua:102:3
						local reader = IOStream.new(self.inStream:readUBytes(byteCount))
						reader:readUByte()
						---@source ../../shared/binnet.lua:104:3
						local packetId = reader:readUByte()
						---@source ../../shared/binnet.lua:105:3
						_ = self.packetReaders[packetId] and self.packetReaders[packetId](self, reader, packetId)
						---@source ../../shared/binnet.lua:106:3
						totalByteCount = totalByteCount + byteCount
						---@source ../../shared/binnet.lua:107:3
						packetCount = packetCount + 1
					else
						break
					end
				end
				return totalByteCount, packetCount
			end, ...)
		end
		---@source ../../shared/binnet.lua:117:0
		function Binnet.write(...)
			return SS_SW_DBG._trace_func(47, function(self, valueCount)
				---@source ../../shared/binnet.lua:118:1
				local maxByteCount = valueCount * 3
				---@source ../../shared/binnet.lua:119:1
				local valuesBytes = {}
				while #valuesBytes < maxByteCount do
					if #self.outStream <= 0 then
						---@source ../../shared/binnet.lua:122:3
						local writer = table.remove(self.outPackets, 1)
						if writer == nil then
							break
						end
						self.outStream:writeStream(writer)
					end
					for i=1,math.min(#self.outStream, maxByteCount - #valuesBytes) do
						table.insert(valuesBytes, table.remove(self.outStream, 1))
					end
				end
				---@source ../../shared/binnet.lua:133:1
				local values = {}
				for i=1,#valuesBytes,3 do
					table.insert(values, binnet_encode(valuesBytes[i], valuesBytes[i + 1] or 0, valuesBytes[i + 2] or 0))
				end
				return values
			end, ...)
		end
	end, ...)
end
---@source .././script.lua:1:0
__SSSWTOOL_MOD_TO_FILEPATH["vehmon.packets"] = "vehmon/packets.lua"
---@source .././script.lua:1:0
__SSSWTOOL_REQUIRES["vehmon.packets"] = function(...)
	return SS_SW_DBG._trace_func(78, function(...)
		require("iostream")
		---@source .././vehmon/packets.lua:5:0
		local function write2ByteUInt(...)
			return SS_SW_DBG._trace_func(49, function(writer, x)
				writer:writeCustom(x, 0, 2 ^ 16 - 1, 1)
			end, ...)
		end
		---@source .././vehmon/packets.lua:12:0
		local function writeDBStr(...)
			return SS_SW_DBG._trace_func(50, function(writer, db_idx, fmt)
				writer:writeUByte(db_idx)
				writer:writeString(fmt)
			end, ...)
		end
		---@source .././vehmon/packets.lua:19:0
		local function writeAlignByte(...)
			return SS_SW_DBG._trace_func(51, function(writer, align)
				writer:writeUByte(align + 1)
			end, ...)
		end
		---@source .././vehmon/packets.lua:24:0
		local function to_zsr_double(...)
			return SS_SW_DBG._trace_func(52, function(n)
				---@source .././vehmon/packets.lua:25:1
				local bytes = {
					iostream_packunpack(">d", "BBBBBBBB", n),
				}
				table.remove(bytes, #bytes)
				while bytes[#bytes] == 0 do
					table.remove(bytes, #bytes)
				end
				return bytes
			end, ...)
		end
		---@source .././vehmon/packets.lua:33:0
		local function from_zsr_double(...)
			return SS_SW_DBG._trace_func(53, function(bytes)
				while #bytes < 8 do
					---@source .././vehmon/packets.lua:35:2
					bytes[#bytes + 1] = 0
				end
				---@source .././vehmon/packets.lua:37:1
				local n = iostream_packunpack("BBBBBBBB", ">d", table.unpack(bytes))
				return n // 1 | 0 == n and n | 0 or n
			end, ...)
		end
		---@source .././vehmon/packets.lua:44:0
		local Packets = {}
		---@source .././vehmon/packets.lua:48:0
		local BinnetBase = Binnet:new()
		---@source .././vehmon/packets.lua:49:0
		Packets.BinnetBase = BinnetBase
		BinnetBase:registerPacketReader(1, function(...)
			return SS_SW_DBG._trace_func(54, function(binnet, reader)
				---@source .././vehmon/packets.lua:54:1
				local vehmon = binnet.vehmon
				---@source .././vehmon/packets.lua:55:1
				vehmon.monitor.width = reader:readCustom(0, 2 ^ 16 - 1, 1)
				---@source .././vehmon/packets.lua:56:1
				vehmon.monitor.height = reader:readCustom(0, 2 ^ 16 - 1, 1)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:59:0
		Packets.GET_RESOLUTION = BinnetBase:registerPacketWriter(1, function(...)
			return SS_SW_DBG._trace_func(55, function(binnet, writer)
				
			end, ...)
		end)
		BinnetBase:registerPacketReader(2, function(...)
			return SS_SW_DBG._trace_func(56, function(binnet, reader)
				---@source .././vehmon/packets.lua:64:1
				local vehmon = binnet.vehmon
				---@source .././vehmon/packets.lua:65:1
				vehmon.monitor.touch1.x = reader:readCustom(0, 2 ^ 16 - 1, 1)
				---@source .././vehmon/packets.lua:66:1
				vehmon.monitor.touch1.y = reader:readCustom(0, 2 ^ 16 - 1, 1)
				---@source .././vehmon/packets.lua:67:1
				vehmon.monitor.touch1.pressed = reader:readUByte() ~= 0
			end, ...)
		end)
		BinnetBase:registerPacketReader(3, function(...)
			return SS_SW_DBG._trace_func(57, function(binnet, reader)
				---@source .././vehmon/packets.lua:73:1
				local vehmon = binnet.vehmon
				---@source .././vehmon/packets.lua:74:1
				vehmon.monitor.touch2.x = reader:readCustom(0, 2 ^ 16 - 1, 1)
				---@source .././vehmon/packets.lua:75:1
				vehmon.monitor.touch2.y = reader:readCustom(0, 2 ^ 16 - 1, 1)
				---@source .././vehmon/packets.lua:76:1
				vehmon.monitor.touch2.pressed = reader:readUByte() ~= 0
			end, ...)
		end)
		---@source .././vehmon/packets.lua:81:0
		Packets.FULL_RESET = BinnetBase:registerPacketWriter(2, function(...)
			return SS_SW_DBG._trace_func(58, function(binnet, writer)
				
			end, ...)
		end)
		---@source .././vehmon/packets.lua:84:0
		Packets.GROUP_RESET = BinnetBase:registerPacketWriter(10, function(...)
			return SS_SW_DBG._trace_func(59, function(binnet, writer, group_id)
				writer:writeUByte(group_id)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:87:0
		Packets.GROUP_SYNC = BinnetBase:registerPacketWriter(11, function(...)
			return SS_SW_DBG._trace_func(60, function(binnet, writer, group_id, enabled)
				writer:writeUByte(group_id)
				writer:writeUByte(enabled and 1 or 0)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:91:0
		Packets.GROUP_ENABLE = BinnetBase:registerPacketWriter(12, function(...)
			return SS_SW_DBG._trace_func(61, function(binnet, writer, group_id)
				writer:writeUByte(group_id)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:94:0
		Packets.GROUP_DISABLE = BinnetBase:registerPacketWriter(13, function(...)
			return SS_SW_DBG._trace_func(62, function(binnet, writer, group_id)
				writer:writeUByte(group_id)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:98:0
		Packets.DB_SET_STRING = BinnetBase:registerPacketWriter(30, function(...)
			return SS_SW_DBG._trace_func(63, function(binnet, writer, db_idx, db_idy, s)
				writer:writeUByte(db_idx)
				writer:writeUByte(db_idy)
				writer:writeString(s)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:103:0
		Packets.DB_SET_NUMBER = BinnetBase:registerPacketWriter(31, function(...)
			return SS_SW_DBG._trace_func(64, function(binnet, writer, db_idx, db_idy, n)
				writer:writeUByte(db_idx)
				writer:writeUByte(db_idy)
				for _, byte in ipairs(to_zsr_double(n)) do
					writer:writeUByte(byte)
				end
			end, ...)
		end)
		---@source .././vehmon/packets.lua:111:0
		Packets.DB_SET_POS_N = BinnetBase:registerPacketWriter(33, function(...)
			return SS_SW_DBG._trace_func(65, function(binnet, writer, db_idx, db_idy, n, precision)
				writer:writeUByte(db_idx)
				writer:writeUByte(db_idy)
				writer:writeUByte(1 / precision)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:116:0
		Packets.DB_SET_NEG_N = BinnetBase:registerPacketWriter(34, function(...)
			return SS_SW_DBG._trace_func(66, function(binnet, writer, db_idx, db_idy, n, precision)
				writer:writeUByte(db_idx)
				writer:writeUByte(db_idy)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:121:0
		Packets.DRAW_COLOR = BinnetBase:registerPacketWriter(100, function(...)
			return SS_SW_DBG._trace_func(67, function(binnet, writer, r, g, b, a)
				writer:writeUByte(r)
				writer:writeUByte(g)
				writer:writeUByte(b)
				writer:writeUByte(a)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:127:0
		Packets.DRAW_RECT = BinnetBase:registerPacketWriter(101, function(...)
			return SS_SW_DBG._trace_func(68, function(binnet, writer, x, y, w, h)
				write2ByteUInt(writer, x)
				write2ByteUInt(writer, y)
				write2ByteUInt(writer, w)
				write2ByteUInt(writer, h)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:133:0
		Packets.DRAW_RECTF = BinnetBase:registerPacketWriter(102, function(...)
			return SS_SW_DBG._trace_func(69, function(binnet, writer, x, y, w, h)
				write2ByteUInt(writer, x)
				write2ByteUInt(writer, y)
				write2ByteUInt(writer, w)
				write2ByteUInt(writer, h)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:139:0
		Packets.DRAW_CIRCLE = BinnetBase:registerPacketWriter(103, function(...)
			return SS_SW_DBG._trace_func(70, function(binnet, writer, x, y, r)
				write2ByteUInt(writer, x)
				write2ByteUInt(writer, y)
				write2ByteUInt(writer, r)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:144:0
		Packets.DRAW_CIRCLEF = BinnetBase:registerPacketWriter(104, function(...)
			return SS_SW_DBG._trace_func(71, function(binnet, writer, x, y, r)
				write2ByteUInt(writer, x)
				write2ByteUInt(writer, y)
				write2ByteUInt(writer, r)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:149:0
		Packets.DRAW_TRIANGLE = BinnetBase:registerPacketWriter(105, function(...)
			return SS_SW_DBG._trace_func(72, function(binnet, writer, x1, y1, x2, y2, x3, y3)
				write2ByteUInt(writer, x1)
				write2ByteUInt(writer, y1)
				write2ByteUInt(writer, x2)
				write2ByteUInt(writer, y2)
				write2ByteUInt(writer, x3)
				write2ByteUInt(writer, y3)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:157:0
		Packets.DRAW_TRIANGLEF = BinnetBase:registerPacketWriter(106, function(...)
			return SS_SW_DBG._trace_func(73, function(binnet, writer, x1, y1, x2, y2, x3, y3)
				write2ByteUInt(writer, x1)
				write2ByteUInt(writer, y1)
				write2ByteUInt(writer, x2)
				write2ByteUInt(writer, y2)
				write2ByteUInt(writer, x3)
				write2ByteUInt(writer, y3)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:165:0
		Packets.DRAW_LINE = BinnetBase:registerPacketWriter(107, function(...)
			return SS_SW_DBG._trace_func(74, function(binnet, writer, x1, y1, x2, y2)
				write2ByteUInt(writer, x1)
				write2ByteUInt(writer, y1)
				write2ByteUInt(writer, x2)
				write2ByteUInt(writer, y2)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:171:0
		Packets.DRAW_TEXT = BinnetBase:registerPacketWriter(108, function(...)
			return SS_SW_DBG._trace_func(75, function(binnet, writer, x, y, db_idx, fmt)
				write2ByteUInt(writer, x)
				write2ByteUInt(writer, y)
				writeDBStr(writer, db_idx, fmt)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:176:0
		Packets.DRAW_TEXTBOX = BinnetBase:registerPacketWriter(109, function(...)
			return SS_SW_DBG._trace_func(76, function(binnet, writer, x, y, w, h, db_idx, fmt, h_align, v_align)
				write2ByteUInt(writer, x)
				write2ByteUInt(writer, y)
				write2ByteUInt(writer, w)
				write2ByteUInt(writer, h)
				writeDBStr(writer, db_idx, fmt)
				writeAlignByte(writer, h_align)
				writeAlignByte(writer, v_align)
			end, ...)
		end)
		---@source .././vehmon/packets.lua:185:0
		Packets.DRAW_MAP = BinnetBase:registerPacketWriter(110, function(...)
			return SS_SW_DBG._trace_func(77, function(binnet, writer, x, y, zoom)
				writer:writeCustom(x, -130000, 130000, 0.0001)
				writer:writeCustom(y, -130000, 130000, 0.0001)
				writer:writeCustom(zoom, 0.1, 50, 0.00125)
			end, ...)
		end)
		return Packets
	end, ...)
end
---@source .././script.lua:1:0
g_savedata = {}
---@source .././script.lua:3:0
DEFAULT_LOG_LEVEL = 2
require("logging")
require("helpers")
---@source .././script.lua:8:0
local VehMon = require("vehmon")
---@source .././script.lua:12:0
local vehmons = {}
---@source .././script.lua:15:0
local function createVehMon(...)
	return SS_SW_DBG._trace_func(79, function(vehicle_id)
		---@source .././script.lua:16:1
		local vehmon = VehMon.new(vehicle_id, 5, 25)
		---@source .././script.lua:17:1
		vehmons[vehicle_id] = vehmon
		if vehmon then
			---@source .././script.lua:19:2
			g_savedata.vehmons[vehicle_id] = true
			log_debug(("Created VehMon for vehid %s with %s dials and %s keypads"):format(vehicle_id, vehmon.dial_count, vehmon.keypad_count))
		else
			log_debug(("Failed to create VehMon for vehid %s"):format(vehicle_id))
		end
	end, ...)
end
---@source .././script.lua:26:0
local function removeVehMon(...)
	return SS_SW_DBG._trace_func(80, function(vehicle_id)
		---@source .././script.lua:27:1
		vehmons[vehicle_id] = nil
		---@source .././script.lua:28:1
		g_savedata.vehmons[vehicle_id] = nil
	end, ...)
end
---@source .././script.lua:32:0
function onCreate(...)
	return SS_SW_DBG._trace_func(81, function()
		---@source .././script.lua:33:1
		g_savedata.vehmons = g_savedata.vehmons or {}
		for vehicle_id, _ in pairs(g_savedata.vehmons) do
			createVehMon(vehicle_id)
		end
	end, ...)
end
---@source .././script.lua:41:0
function onTick(...)
	SS_SW_DBG.check_stack(0)
	SS_SW_DBG._sendCheckStackHttp()
	return SS_SW_DBG._trace_func(82, function(game_ticks)
		for _, vehmon in pairs(vehmons) do
			vehmon:tick()
		end
	end, ...)
end
---@source .././script.lua:53:0
function onVehicleSpawn(...)
	return SS_SW_DBG._trace_func(83, function(vehicle_id, peer_id, x, y, z, cost)
		if peer_id >= 0 then
			createVehMon(vehicle_id)
		end
	end, ...)
end
---@source .././script.lua:62:0
function onVehicleDespawn(...)
	return SS_SW_DBG._trace_func(84, function(vehicle_id, peer_id)
		removeVehMon(vehicle_id)
	end, ...)
end