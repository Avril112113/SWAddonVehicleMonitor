require "iostream"
require "binnet"
local Packets = require "vehmon.packets"


---@generic T
---@param v? T
---@param message? any
---@param ... any
---@return T
---@return any ...
---@diagnostic disable-next-line: duplicate-set-field
local function assert(v, message, ...)
	if not v then
		AVCmds.log(("[SW] [error] %s"):format(tostring(message)))
		_ENV[message]()
	end
	return v, message, ...
end


---@class VehMon.Monitor
---@field width integer
---@field height integer
---@field touch1 {x:integer,y:integer,pressed:boolean,was_pressed:boolean}
---@field touch2 {x:integer,y:integer,pressed:boolean,was_pressed:boolean}

---@class VehMon
---@field vehicle_id integer
---@field _binnet Binnet_VehMon
---@field dial_count integer
---@field keypad_count integer
---@field alt_count integer
---@field initialized boolean
---@field state "inactive"|"deinit"|"waiting"|"ready"|"init"
---@field monitor VehMon.Monitor
local VehMon = {}
--- These are only a concern if they are constantly happening every tick.
--- It is normal to encounter these when updating large amount of info or during initial setup
VehMon.LOG_BINNET_OVERLOADS = true


function VehMon._create_default_group()
	return {enabled=false,offset={0,0}}
end
-- Do not modify!
VehMon._ref_default_group = VehMon._create_default_group()


---@param vehicle_id integer
---@param dial_count integer
---@param keypad_count integer
---@param alt_count integer? # Alts use the same keypads, but their own dials, they can be used to effectivelty have a larger monitor.
---@return VehMon
function VehMon.new(vehicle_id, dial_count, keypad_count, alt_count)
	local self = shallowCopy(VehMon, {
		vehicle_id = vehicle_id,
		dial_count = dial_count,
		keypad_count = keypad_count,
		alt_count = alt_count or 0,
		initialized = false,
		state = "inactive",
	})
	return self
end

function VehMon:onTickStart()
	local is_simulating, exists = server.getVehicleSimulating(self.vehicle_id)
	if not exists or not is_simulating then
		if self.initialized then
			log_debug(("%s - De-Init"):format(self.vehicle_id))
			self.state = "deinit"
			self:_deinit()
		elseif self.state ~= "inactive" then
			self.state = "inactive"
		end
		return false
	end

	if self.monitor == nil then
		log_debug(("%s - Init"):format(self.vehicle_id))
		self.state = "init"
		self:_init()
	elseif self.state ~= "waiting" and self.state ~= "ready" then
		self.state = "waiting"
	end

	self:_process()
	return true
end

function VehMon:onTickEnd()
	self:_write()
end

function VehMon:_init()
	self.initialized = true
	self.monitor = {
		width = 0,
		height = 0,
		touch1 = {x=0, y=0, pressed=false, was_pressed=false},
		touch2 = {x=0, y=0, pressed=false, was_pressed=true},
	}
	---@diagnostic disable-next-line: assign-type-mismatch
	self._binnet = Packets.BinnetBase:new()
	self._binnet.vehmon = self
	self._alt_binnets = {}
	self._resync_button = false
	for i=1,self.alt_count do
		self._alt_binnets[i] = Packets.BinnetBase:new()
		self._alt_binnets[i].vehmon = self
	end
	self:_reset_state()
	--- All players within 2k radius of the vehicle.
	---@type table<integer,number> # peer_id, distance
	self.players = {}
end

function VehMon:_deinit()
	self.initialized = false
	self.monitor = nil
	self._binnet = nil
	self._alt_binnets = nil
	self._resync_button = nil
	self._state = nil
	self.players = nil
end

function VehMon:_get_binnet_tick_used()
	local pending_bytes = #self._binnet.outStream
	for _, packet in ipairs(self._binnet.outPackets) do
		pending_bytes = pending_bytes + #packet
	end
	return pending_bytes
end
function VehMon:_get_binnet_tick_space()
	return self.keypad_count*3 - self:_get_binnet_tick_used()
end

function VehMon:_reset_state()
	---@alias VehMon._State.Draw any[] # [1]=PacketID, ...=args
	-- `enabled_defer` is only used for changes.
	---@alias VehMon._State.Group {enabled:boolean, enabled_defer:boolean, offset:{[1]:number,[2]:number}}|VehMon._State.Draw[]

	self._state = {
		do_reset = false,
		---@type table<integer,integer> # <peer_id,ticks_in_sync_radius>
		players_synced = {},

		group_id = -1,
		group_draw_idx = 1,
		---@type table<integer, VehMon._State.Group>
		groups = {},
		---@type table<integer,VehMon.DBValue[]>
		db = {},

		remote_group_id = -1,
		remote_group_draw_idx = 1,
		---@type table<integer, VehMon._State.Group>
		prev_groups = {},
		---@type table<integer,VehMon.DBValue[]>
		prev_db = {},

		---@type table<integer,boolean> # Stuff marked to be checked or synced.
		changed_groups = {},
		---@type table<integer,boolean> # Stuff marked to be checked or synced.
		changed_db = {},
	}
	for i=-1,255 do
		self._state.groups[i] = VehMon._create_default_group()
	end
end

function VehMon:_state_mark_everything_to_sync()
	log_info(("VehMon for %s is resyncing."):format(self.vehicle_id))
	-- Groups prioritize changed status
	for group_id, group in pairs(self._state.groups) do
		if #group > 0 and self._state.changed_groups[group_id] ~= true then
			self._state.changed_groups[group_id] = false
		end
	end
	-- DB Values prioritize sync status
	for db_idx, values in pairs(self._state.db) do
		if #values > 0 then
			self._state.changed_db[db_idx] = false
		end
	end
end

---@param is_sync_pass boolean
function VehMon:_update_state_changes(is_sync_pass)
	if self._state.do_reset or not self._state.has_done_initial_reset then
		self._binnet:send(Packets.FULL_RESET)
		if self._state.do_reset then
			self:_reset_state()
		end
		self._state.has_done_initial_reset = true
	end

	local tick_bytes_remaining = self:_get_binnet_tick_space()

	for group_id, has_changed in pairs(self._state.changed_groups) do
		if tick_bytes_remaining <= 0 then
			if not is_sync_pass and self.LOG_BINNET_OVERLOADS then
				log_info(("VehMon for %s was overloaded this tick with %s/%s bytes"):format(self.vehicle_id, self:_get_binnet_tick_used(), self.keypad_count*3))
			end
			return
		end
		-- `current` is not to be modified!
		local current = self._state.groups[group_id]
		-- `prev` is to be updated to new values.
		local prev = self._state.prev_groups[group_id]
		if prev == nil then
			prev = VehMon._create_default_group()
			self._state.prev_groups[group_id] = prev
		end
		-- `compare` is not to be modified!
		local compare = is_sync_pass and self._ref_default_group or prev

		local changes = {}
		local consider_reset = true
		for draw_idx, current_packet in ipairs(current) do
			if compare[draw_idx] == nil then
				table.insert(changes, draw_idx)
			else
				local compare_packet = compare[draw_idx]
				local found_difference = false
				for i, v in ipairs(current_packet) do
					if v ~= compare_packet[i] then
						table.insert(changes, draw_idx)
						found_difference = true
						break
					end
				end
				if not found_difference then
					consider_reset = false
				end
			end
		end
		if not is_sync_pass and #changes > 0 then
			if (consider_reset and current.enabled ~= compare.enabled) or (#compare > #current) then
				self._binnet:send(Packets.GROUP_RESET, group_id)
				tick_bytes_remaining = tick_bytes_remaining - #self._binnet.outPackets[#self._binnet.outPackets]
				prev.enabled = false
				self._state.remote_group_id = group_id
				self._state.remote_group_draw_idx = 1
			end
		end
		if (is_sync_pass or not current.enabled_defer) and current.enabled ~= compare.enabled then
			if current.enabled then
				self._binnet:send(Packets.GROUP_ENABLE, group_id)
			else
				self._binnet:send(Packets.GROUP_DISABLE, group_id)
			end
			tick_bytes_remaining = tick_bytes_remaining - #self._binnet.outPackets[#self._binnet.outPackets]
			prev.enabled = current.enabled
		end
		if #changes > 0 then
			for _, draw_idx in ipairs(changes) do
				if tick_bytes_remaining <= 0 then
					if not is_sync_pass and self.LOG_BINNET_OVERLOADS then
						log_info(("VehMon for %s was overloaded this tick with %s/%s bytes"):format(self.vehicle_id, self:_get_binnet_tick_used(), self.keypad_count*3))
					end
					return
				end
				local current_packet = current[draw_idx]
				---@cast current_packet VehMon._State.Draw
				if is_sync_pass or self._state.remote_group_id ~= group_id or self._state.remote_group_draw_idx ~= draw_idx then
					self._binnet:send(Packets.GROUP_SET, group_id, draw_idx)
					tick_bytes_remaining = tick_bytes_remaining - #self._binnet.outPackets[#self._binnet.outPackets]
					self._state.remote_group_id = group_id
					self._state.remote_group_draw_idx = draw_idx
				end
				self._binnet:send(table.unpack(current_packet))
				tick_bytes_remaining = tick_bytes_remaining - #self._binnet.outPackets[#self._binnet.outPackets]
				prev[draw_idx] = current_packet
				self._state.remote_group_draw_idx = self._state.remote_group_draw_idx + 1
			end
		end
		if current.offset[1] ~= compare.offset[1] or current.offset[2] ~= compare.offset[2] then
			self._binnet:send(Packets.GROUP_OFFSET, group_id, current.offset[1], current.offset[2])
			tick_bytes_remaining = tick_bytes_remaining - #self._binnet.outPackets[#self._binnet.outPackets]
			prev.offset = current.offset
		end
		if not is_sync_pass and current.enabled ~= compare.enabled then
			if current.enabled then
				self._binnet:send(Packets.GROUP_ENABLE, group_id)
			else
				self._binnet:send(Packets.GROUP_DISABLE, group_id)
			end
			tick_bytes_remaining = tick_bytes_remaining - #self._binnet.outPackets[#self._binnet.outPackets]
			prev.enabled = current.enabled
		end
		if not has_changed == is_sync_pass then
			self._state.changed_groups[group_id] = nil
		end
	end

	for db_idx, has_changed in pairs(self._state.changed_db) do
		if tick_bytes_remaining <= 0 then
			if not is_sync_pass and self.LOG_BINNET_OVERLOADS then
				log_info(("VehMon for %s was overloaded this tick with %s/%s bytes"):format(self.vehicle_id, self:_get_binnet_tick_used(), self.keypad_count*3))
			end
			return
		end
		-- `current` is not to be modified!
		local current = self._state.db[db_idx]
		-- `prev` is to be updated to new values.
		local prev = self._state.prev_db[db_idx]
		if prev == nil then
			prev = {}
			self._state.prev_db[db_idx] = prev
		end
		for db_idy, v in pairs(current) do
			if is_sync_pass or (has_changed and v ~= prev[db_idy]) then
				if type(v) == "string" then
					self._binnet:send(Packets.DB_SET_STRING, db_idx, db_idy, v)
				elseif type(v) == "number" then
					self._binnet:send(Packets.DB_SET_NUMBER, db_idx, db_idy, v)
				else
					assert(false, ("Invalid db value of type '%s'"):format(type(v)))
				end
				tick_bytes_remaining = tick_bytes_remaining - #self._binnet.outPackets[#self._binnet.outPackets]
				prev[db_idy] = v
			end
		end
		if is_sync_pass or not has_changed == is_sync_pass then
			self._state.changed_db[db_idx] = nil
		end
	end
end

function VehMon:_process()
	---@param alt integer?
	local function binnet_process(alt)
		local binnet = alt == nil and self._binnet or self._alt_binnets[alt]
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

	if self.state ~= "ready" and self.monitor.width ~= 0 and self.monitor.height ~= 0 then
		self.state = "ready"
	end

	local vehPos = server.getVehiclePos(self.vehicle_id)
	if vehPos ~= nil then
		local players_synced = self._state.players_synced
		for _, player in pairs(server.getPlayers()) do
			local playerPos = server.getPlayerPos(player.id)
			local dist = matrix.distance(vehPos, playerPos)
			if dist < 2000 then
				players_synced[player.id] = (players_synced[player.id] or 0) + 1
				-- Give the player 5 seconds to load the vehicle.
				if players_synced[player.id] == 60*5 then
					self:_state_mark_everything_to_sync()
				end
				self.players[player.id] = dist
			else
				players_synced[player.id] = nil
				self.players[player.id] = nil
			end
		end
	end
end

function VehMon:_write()
	if self.state == "ready" then
		local btn = server.getVehicleButton(self.vehicle_id, "vehmon_resync")
		if btn ~= nil then
			if self._resync_button == false and btn.on == true then
				self:_state_mark_everything_to_sync()
			end
			self._resync_button = btn.on
		end

		self:_update_state_changes(false)
		self:_update_state_changes(true)
	end

	if self.monitor.width == 0 and not self._sent_resolution_request then
		self._sent_resolution_request = true
		self._binnet:send(Packets.GET_RESOLUTION)  -- The packet can fit into 1 tick, meaning if the vehicle isn't ready, it won't get it, which is fine.
		self._binnet:setLastUrgent()
	end

	local write_values = self._binnet:write(self.keypad_count)
	for i=1,self.keypad_count do
		server.setVehicleKeypad(self.vehicle_id, "vehmon_"..i, write_values[i])
	end
end

---@param db_idx integer
---@param db_idy integer
---@param value VehMon.DBValue
function VehMon:_state_set_db(db_idx, db_idy, value)
	assert(type(db_idx) == "number" and db_idx >= 0 and db_idx <= 255, "Invalid db_idx, expected integer of range 0-255.")
	assert(type(db_idy) == "number" and db_idy >= 0 and db_idy <= 255, "Invalid db_idy, expected integer of range 0-255.")
	-- Sync status takes priority
	if self._state.changed_db[db_idx] ~= false then
		self._state.changed_db[db_idx] = true
	end
	self._state.db[db_idx] = self._state.db[db_idx] or {}
	self._state.db[db_idx][db_idy] = value
end

---@param packet_id integer
---@param ... any
function VehMon:_state_draw(packet_id, ...)
	self._state.changed_groups[self._state.group_id] = true
	self._state.groups[self._state.group_id][self._state.group_draw_idx] = {packet_id, ...}
	self._state.group_draw_idx = self._state.group_draw_idx + 1
end


---@alias VehMon.GroupID integer # 0 - 255 integer
---@alias VehMon.DrawIDX integer # 0 - 255 integer
---@alias VehMon.MonCoord number # -2046 - 2048 with 0.125 precision
---@alias VehMon.DBIndex integer # 1 - 255 integer, '0' is used for no db index
---@alias VehMon.DBValue string|number
---@alias VehMon.MapCoord number # -130000 - 130000 with 0.0001 precision
---@alias VehMon.MapZoom number # 0.1 - 50 with 0.00125 precision

--- Resets everything.
function VehMon:FullReset()
	self._state.do_reset = true
end

--- Resets the group and selects it.
---@param group_id VehMon.GroupID
function VehMon:GroupReset(group_id)
	self._state.group_id = group_id
	self._state.changed_groups[group_id] = true
	self._state.groups[group_id] = VehMon._create_default_group()
	self._state.group_draw_idx = 1
end

--- Resets the group and selects it.
---@param group_id VehMon.GroupID
---@param draw_idx VehMon.DrawIDX?
function VehMon:GroupSet(group_id, draw_idx)
	self._state.group_id = group_id
	self._state.group_draw_idx = draw_idx or 1
end

--- Sets weather a group is enabled or not.
---@param group_id VehMon.GroupID
---@param enabled boolean
---@param defer boolean? # Default `true`, will not set enabled state unless all other info is already sent, `false` means the player may observe partial UI.
function VehMon:GroupEnabled(group_id, enabled, defer)
	self._state.changed_groups[group_id] = true
	local group = self._state.groups[group_id]
	group.enabled = enabled
	group.enabled_defer = not (defer == false)
end

--- Sets the groups position offset.
---@param group_id VehMon.GroupID
---@param x VehMon.MonCoord?
---@param y VehMon.MonCoord?
function VehMon:GroupOffset(group_id, x, y)
	self._state.changed_groups[group_id] = true
	local group = self._state.groups[group_id]
	if x then
		group.offset[1] = x
	end
	if y then
		group.offset[2] = y
	end
end

--- Sets a string into the DB values.
--- Value can be;
--- - string of length 0-255
--- - double precision number
---@param db_idx VehMon.DBIndex
---@param db_idy VehMon.DBIndex
---@param value VehMon.DBValue
---@overload fun(self,db_idx:VehMon.DBIndex,values:VehMon.DBValue[])
function VehMon:SetDBValue(db_idx, db_idy, value)
	if value == nil and type(db_idy) == "table" then
		for i, v in pairs(db_idy) do
			if type(i) == "number" then
				self:_state_set_db(db_idx, i, v)
			end
		end
	else
		self:_state_set_db(db_idx, db_idy, value)
	end
end

--- Set/Adds the draw call to the current group.
---@param r integer 0-255
---@param g integer 0-255
---@param b integer 0-255
---@param a integer? 0-255
function VehMon:DrawColor(r, g, b, a)
	self:_state_draw(Packets.DRAW_COLOR, r, g, b, a or 255)
end

--- Set/Adds the draw call to the current group.
---@param x VehMon.MonCoord
---@param y VehMon.MonCoord
---@param w VehMon.MonCoord
---@param h VehMon.MonCoord
function VehMon:DrawRect(x, y, w, h)
	self:_state_draw(Packets.DRAW_RECT, x, y, w, h)
end

--- Set/Adds the draw call to the current group.
---@param x VehMon.MonCoord
---@param y VehMon.MonCoord
---@param w VehMon.MonCoord
---@param h VehMon.MonCoord
function VehMon:DrawRectF(x, y, w, h)
	self:_state_draw(Packets.DRAW_RECTF, x, y, w, h)
end

--- Set/Adds the draw call to the current group.
---@param x VehMon.MonCoord
---@param y VehMon.MonCoord
---@param r VehMon.MonCoord
function VehMon:DrawCircle(x, y, r)
	self:_state_draw(Packets.DRAW_CIRCLE, x, y, r)
end

--- Set/Adds the draw call to the current group.
---@param x VehMon.MonCoord
---@param y VehMon.MonCoord
---@param r VehMon.MonCoord
function VehMon:DrawCircleF(x, y, r)
	self:_state_draw(Packets.DRAW_CIRCLEF, x, y, r)
end

--- Set/Adds the draw call to the current group.
---@param x1 VehMon.MonCoord
---@param y1 VehMon.MonCoord
---@param x2 VehMon.MonCoord
---@param y2 VehMon.MonCoord
---@param x3 VehMon.MonCoord
---@param y3 VehMon.MonCoord
function VehMon:DrawTriangle(x1, y1, x2, y2, x3, y3)
	self:_state_draw(Packets.DRAW_TRIANGLE, x1, y1, x2, y2, x3, y3)
end


--- Set/Adds the draw call to the current group.
---@param x1 VehMon.MonCoord
---@param y1 VehMon.MonCoord
---@param x2 VehMon.MonCoord
---@param y2 VehMon.MonCoord
---@param x3 VehMon.MonCoord
---@param y3 VehMon.MonCoord
function VehMon:DrawTriangleF(x1, y1, x2, y2, x3, y3)
	self:_state_draw(Packets.DRAW_TRIANGLEF, x1, y1, x2, y2, x3, y3)
end

--- Set/Adds the draw call to the current group.
---@param x1 VehMon.MonCoord
---@param y1 VehMon.MonCoord
---@param x2 VehMon.MonCoord
---@param y2 VehMon.MonCoord
function VehMon:DrawLine(x1, y1, x2, y2)
	self:_state_draw(Packets.DRAW_LINE, x1, y1, x2, y2)
end

--- Set/Adds the draw call to the current group.
---@param x VehMon.MonCoord
---@param y VehMon.MonCoord
---@param db_idx VehMon.DBIndex
---@param fmt string
function VehMon:DrawText(x, y, db_idx, fmt)
	self:_state_draw(Packets.DRAW_TEXT, x, y, db_idx, fmt)
end

--- Set/Adds the draw call to the current group.
---@param x VehMon.MonCoord
---@param y VehMon.MonCoord
---@param w VehMon.MonCoord
---@param h VehMon.MonCoord
---@param db_idx VehMon.DBIndex
---@param fmt string
---@param horizontal_align integer? -1 left, 0 center, 1 right
---@param vertical_align integer? -1 top, 0 center, 1 bottom
function VehMon:DrawTextBox(x, y, w, h, db_idx, fmt, horizontal_align, vertical_align)
	self:_state_draw(Packets.DRAW_TEXTBOX, x, y, w, h, db_idx, fmt, horizontal_align or -1, vertical_align or -1)
end

--- Set/Adds the draw call to the current group.
---@param x VehMon.MapCoord
---@param y VehMon.MapCoord
---@param zoom VehMon.MapZoom
function VehMon:DrawMap(x, y, zoom)
	self:_state_draw(Packets.DRAW_MAP, x, y, zoom)
end


return VehMon
