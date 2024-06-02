require "iostream"
require "binnet"
local Packets = require "vehmon.packets"


---@class VehMon.Monitor
---@field width integer
---@field height integer
---@field touch1 {x:integer,y:integer,pressed:boolean,was_pressed:boolean}
---@field touch2 {x:integer,y:integer,pressed:boolean,was_pressed:boolean}

---@class VehMon
---@field vehicle_id integer
---@field binnet Binnet_VehMon
---@field dial_count integer
---@field keypad_count integer
---@field alt_count integer
---@field initialized boolean
---@field monitor VehMon.Monitor
local VehMon = {}


---@param vehicle_id integer
---@param dial_count integer
---@param keypad_count integer
---@param alt_count integer? # Alts use the same keypads, but their own dials, they can be used to effectivelty have a larger monitor.
---@return VehMon?
function VehMon.new(vehicle_id, dial_count, keypad_count, alt_count)
	local self = shallowCopy(VehMon, {
		vehicle_id=vehicle_id,
		dial_count=dial_count,
		keypad_count=keypad_count,
		alt_count=alt_count or 0,
		initialized=false,
	})
	return self
end

function VehMon:tick()
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
end

function VehMon:init()
	self.initialized = true
	self.monitor = {
		width = 0,
		height = 0,
		touch1 = {x=0, y=0, pressed=false, was_pressed=false},
		touch2 = {x=0, y=0, pressed=false, was_pressed=true},
	}
	---@diagnostic disable-next-line: assign-type-mismatch
	self.binnet = Packets.BinnetBase:new()
	self.binnet.vehmon = self
	self.binnet:send(Packets.reset)  -- The packet can fit into 1 tick, meaning if the vehicle isn't ready, it won't get it, which is fine.
	self.alt_binnets = {}
	for i=1,self.alt_count do
		self.alt_binnets[i] = Packets.BinnetBase:new()
		self.alt_binnets[i].vehmon = self
	end
end

function VehMon:deinit()
	self.initialized = false
	self.monitor = nil
	self.binnet = nil
	self.alt_binnets = nil
end

function VehMon:update()
	---@param alt integer?
	local function binnet_process(alt)
		local binnet = alt == nil and self.binnet or self.alt_binnets[alt]
		local read_values = {}
		for i=1,self.dial_count do
			local data, ok = server.getVehicleDial(self.vehicle_id, alt == nil and "vehmon_"..i or "vehmon_" .. (alt|0) .. "_"..i)
			if not ok then return end
			read_values[i] = data.value
		end
		local byte_count, packet_count = binnet:process(read_values)
		-- if byte_count > 0 then
		-- 	log_debug(("%s - %s bytes, %s packets"):format(self.vehicle_id, byte_count, packet_count))
		-- end
	end

	if not self.initialized then return end

	self.monitor.touch1.was_pressed = self.monitor.touch1.pressed
	self.monitor.touch2.was_pressed = self.monitor.touch2.pressed

	binnet_process()
	for i=1,self.alt_count do
		binnet_process(i)
	end

	local GROUP_IDXS = {
		MAP = 0,
		TOP_BAR = 1,
		INFO = 2,
	}
	local DB_IDXS = {
		COMPANY_NAME = 1,
		MONEY = 2,
		PLAYER_NAME = 3,
		PLAYER_POS = 4,
		SERVER_TIME = 5,
	}

	if self.monitor.touch1.pressed and not self.monitor.touch1.was_pressed then
		log_debug(self.monitor.touch1.y, self.monitor.height/2)
		if self.monitor.touch1.y < self.monitor.height/2 then
			self.__yoff = (self.__yoff or 0) - 5
		else
			self.__yoff = (self.__yoff or 0) + 5
		end
		self.binnet:send(Packets.GROUP_OFFSET, GROUP_IDXS.INFO, 0, self.__yoff)
	end
	if self.monitor.width ~= 0 and not self._sent_setup then
		self._sent_setup = true
		log_debug(("%s - Sending setup packets."):format(self.vehicle_id))

		self.binnet:send(Packets.FULL_RESET)

		self.binnet:send(Packets.GROUP_RESET, GROUP_IDXS.MAP)
		local vehPos = server.getVehiclePos(self.vehicle_id)
		self.binnet:send(Packets.DRAW_MAP, vehPos[13], vehPos[15], 5)
		self.binnet:send(Packets.GROUP_ENABLE, GROUP_IDXS.MAP)

		self.binnet:send(Packets.GROUP_RESET, GROUP_IDXS.TOP_BAR)
		self.binnet:send(Packets.DRAW_COLOR, 0, 0, 0)
		self.binnet:send(Packets.DRAW_RECTF, 0, 0, self.monitor.width, 40)
		self.binnet:send(Packets.DRAW_COLOR, 255, 255, 255)
		self.binnet:send(Packets.DRAW_RECT, 0, 8, self.monitor.width-1, 0)
		self.binnet:send(Packets.DRAW_TEXT, 1, 1, DB_IDXS.COMPANY_NAME, "%s")
		self.binnet:send(Packets.DB_SET_STRING, DB_IDXS.COMPANY_NAME, 1, "")
		self.binnet:send(Packets.DRAW_TEXT, 199, 1, DB_IDXS.MONEY, "$%s")
		self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.MONEY, 1, 0)
		self.binnet:send(Packets.GROUP_ENABLE, GROUP_IDXS.TOP_BAR)

		self.binnet:send(Packets.GROUP_RESET, GROUP_IDXS.INFO)
		self.binnet:send(Packets.DRAW_TEXT, 1, 14, DB_IDXS.PLAYER_NAME, "Name: %s")
		self.binnet:send(Packets.DB_SET_STRING, DB_IDXS.PLAYER_NAME, 1, server.getPlayerName(0) or "<NO_PLAYER>")
		self.binnet:send(Packets.DRAW_TEXT, 1, 14+8, DB_IDXS.PLAYER_POS, "Pos: %s, %s, %s")
		self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 1, 0)
		self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 2, 0)
		self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 3, 0)
		self.binnet:send(Packets.DRAW_TEXT, 1, 14+8+8, DB_IDXS.SERVER_TIME, "server time: %s")
		self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.SERVER_TIME, 1, 0)
		self.binnet:send(Packets.GROUP_ENABLE, GROUP_IDXS.INFO)

		self.binnet:send(Packets.DB_SET_STRING, DB_IDXS.COMPANY_NAME, 1, "Test company INC")
		self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.MONEY, 1, 12345678987654321)
	end
	if self.monitor.width ~= 0 then
		local pending_bytes = #self.binnet.outStream
		for _, packet in ipairs(self.binnet.outPackets) do pending_bytes = pending_bytes + #packet end
		if pending_bytes <= self.keypad_count*3 then
			-- Stuff to update but not overflow.
			local pos = server.getPlayerPos(0)
			local pos_floored = {pos[13]//1, pos[14]//1, pos[15]//1}
			-- Only send the position if the player have moved.
			if not self._last_pos_floored or self._last_pos_floored[1] ~= pos_floored[1] or self._last_pos_floored[2] ~= pos_floored[2] or self._last_pos_floored[3] ~= pos_floored[3] then
				self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 1, pos_floored[1])
				self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 2, pos_floored[2])
				self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.PLAYER_POS, 3, pos_floored[3])
			end
			self._last_pos_floored = pos_floored
			self.binnet:send(Packets.DB_SET_NUMBER, DB_IDXS.SERVER_TIME, 1, server.getTimeMillisec()/1000)
		end
	end

	if self.monitor.width == 0 and not self._sent_setup and not self._sent_resolution_request then
		self._sent_resolution_request = true
		self.binnet:send(Packets.GET_RESOLUTION)
	end

	local write_values = self.binnet:write(self.keypad_count)
	for i=1,self.keypad_count do
		server.setVehicleKeypad(self.vehicle_id, "vehmon_"..i, write_values[i])
	end
end


return VehMon
