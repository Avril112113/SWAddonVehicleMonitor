g_savedata = {}

DEFAULT_LOG_LEVEL = 2

require "logging"
require "helpers"
require "avcmds"
require "commands"
local VehMon = require "vehmon"

-- Custom added feature to `binnet.lua`
-- Allows debugging of all packets being sent
BINNET_DEBUG_PACKETS = require("vehmon.packets").NamesMap
-- "send" means do the log upon binnet:send() being called, otherwise it'll log when it's written to the output stream.
-- "send" is helpful with `VehMon.LOG_BINNET_OVERLOADS = true`
BINNET_DEBUG_PACKETS_MODE = "send"

-- Inclusive
local function inside_rect(x, y, minx, miny, maxx, maxy)
	return x >= minx and x <= maxx and y >= miny and y <= maxy
end


---@param self table|{vehmon:VehMon}
local function create_test_vehmon(self)
	---@alias CustomVehMonButton {vehmon:VehMon,group_id:VehMon.GroupID,get_bounds:(fun(self):number,number,number,number),draw:fun(self),is_inside:(fun(self,x:number,y:number):boolean),x:number,y:number,w:number,h:number}
	---@param tbl {vehmon:VehMon,group_id:VehMon.GroupID,get_bounds:(fun(self):number,number,number,number),draw:fun(self)}
	---@return CustomVehMonButton
	local function create_button(tbl)
		---@cast tbl CustomVehMonButton
		function tbl:is_inside(x, y)
			local ox, oy = self.vehmon:GetGroupOffset(self.group_id)
			local t = inside_rect(x, y, self.x+ox, self.y+oy, self.x+ox+self.w-1, self.y+oy+self.h-1)
			return t
		end
		local original_draw = tbl.draw
		function tbl:draw()
			---@diagnostic disable-next-line: inject-field
			tbl.x, tbl.y, tbl.w, tbl.h = tbl:get_bounds()
			original_draw(self)
		end
		return tbl
	end

	local GROUP_IDXS = {
		MAP = 0,
		MAP_OVERLAY = 1,
		TOP_BAR = 10,
		INFO = 20,
		TEST = 255,
	}
	local DB_IDXS = {
		COMPANY_NAME = 1,
		MONEY = 2,
		PLAYER_NAME = 3,
		PLAYER_POS = 4,
		SERVER_TIME = 5,
	}
	local TOP_BAR_HEIGHT = 40

	local map_zoom_in_btn = create_button {
		vehmon=self.vehmon,
		group_id=GROUP_IDXS.MAP_OVERLAY,
		draw=function(btn)
			self.vehmon:DrawText(btn.x, btn.y, 0, "/")
			self.vehmon:DrawText(btn.x+2, btn.y, 0, "\\")
		end,
		get_bounds=function(btn)
			return self.vehmon.monitor.width-9, 30, 5, 5
		end,
	}
	local map_zoom_out_btn = create_button {
		vehmon=self.vehmon,
		group_id=GROUP_IDXS.MAP_OVERLAY,
		draw=function(btn)
			self.vehmon:DrawText(btn.x, btn.y, 0, "\\")
			self.vehmon:DrawText(btn.x+2, btn.y, 0, "/")
		end,
		get_bounds=function(btn)
			return self.vehmon.monitor.width-9, 30+9, 5, 5
		end,
	}

	self.map_zoom = 2
	self.map_x, self.map_z = 0, 0
	function self:redraw_map()
		self.vehmon:GroupReset(GROUP_IDXS.MAP)
		self.vehmon:GroupOffset(GROUP_IDXS.MAP, 0, TOP_BAR_HEIGHT/3)
		self.vehmon:GroupEnabled(GROUP_IDXS.MAP, true, false)

		local vehPos = server.getVehiclePos(self.vehmon.vehicle_id)
		if self.map_x == 0 and self.map_z == 0 then
			-- We use ScreenMapToWorld instead of using vehPos directly, so we account for group offset.
			-- self.map_x, self.map_z = self.vehmon:ScreenMapToWorld(self.vehmon.monitor.width/2, self.vehmon.monitor.height/2, vehPos[13], vehPos[15], self.map_zoom, GROUP_IDXS.MAP)
			self.map_x, self.map_z = vehPos[13], vehPos[15]
		end
		self.vehmon:DrawMap(self.map_x, self.map_z, self.map_zoom)

		-- Circle for vehicle pos on map
		self.vehmon:DrawColor(0, 255, 0, 100)
		local smx, smy = self.vehmon:WorldToScreenMap(vehPos[13], vehPos[15], self.map_x, self.map_z, self.map_zoom)
		self.vehmon:DrawCircle(smx, smy, 3)

		-- Dot for center of map
		self.vehmon:DrawColor(255, 0, 0, 50)
		self.vehmon:DrawRectF(self.vehmon.monitor.width/2, self.vehmon.monitor.height/2, 1, 1)
	end

	function self:setup()
		log_debug(("%s - VehMon handler setup."):format(self.vehmon.vehicle_id))

		self:redraw_map()

		self.vehmon:GroupReset(GROUP_IDXS.MAP_OVERLAY)
		self.vehmon:GroupEnabled(GROUP_IDXS.MAP_OVERLAY, true)
		self.vehmon:GroupOffset(GROUP_IDXS.MAP_OVERLAY, 0, TOP_BAR_HEIGHT)
		map_zoom_in_btn:draw()
		map_zoom_out_btn:draw()

		self.vehmon:GroupReset(GROUP_IDXS.TOP_BAR)
		self.vehmon:GroupEnabled(GROUP_IDXS.TOP_BAR, true)
		self.vehmon:DrawColor(0, 0, 0)
		self.vehmon:DrawRectF(0, 0, self.vehmon.monitor.width, TOP_BAR_HEIGHT)
		self.vehmon:DrawColor(255, 255, 255)
		self.vehmon:DrawRectF(0, 8, self.vehmon.monitor.width, 1)
		self.vehmon:DrawText(1, 1, DB_IDXS.COMPANY_NAME, "%s")
		self.vehmon:DrawText(199, 1, DB_IDXS.MONEY, "$%s")

		self.vehmon:GroupReset(GROUP_IDXS.INFO)
		self.vehmon:GroupEnabled(GROUP_IDXS.INFO, true)
		self.vehmon:DrawText(1, 14, DB_IDXS.PLAYER_NAME, "Name: %s")
		self.vehmon:DrawText(1, 14+8, DB_IDXS.PLAYER_POS, "Pos: %s, %s, %s")
		self.vehmon:DrawText(1, 14+8+8, DB_IDXS.SERVER_TIME, "server time: %s")

		self.vehmon:SetDBValue(DB_IDXS.PLAYER_NAME, 1, server.getPlayerName(0) or "<NO_PLAYER>")
		self.vehmon:SetDBValue(DB_IDXS.COMPANY_NAME, 1, "Test company INC")
		self.vehmon:SetDBValue(DB_IDXS.MONEY, 1, 12345678987654321)

		-- -- Test to ensure `is_inside` is correct, can also be used to ensure drawing fits within button bounds. 
		-- self.vehmon:GroupReset(GROUP_IDXS.TEST)
		-- self.vehmon:GroupEnabled(GROUP_IDXS.TEST, true)
		-- local ox, oy = self.vehmon:GetGroupOffset(GROUP_IDXS.MAP_OVERLAY)
		-- for tx=-1,map_zoom_in_btn.w do
		-- 	for ty=-1,map_zoom_in_btn.h do
		-- 		local bx, by = map_zoom_in_btn.x+ox+tx, map_zoom_in_btn.y+oy+ty
		-- 		if map_zoom_in_btn:is_inside(bx, by) then
		-- 			self.vehmon:DrawColor(0, 255, 0, 200)
		-- 		else
		-- 			self.vehmon:DrawColor(255, 0, 0, 200)
		-- 		end
		-- 		self.vehmon:DrawRectF(bx, by, 1, 1)
		-- 	end
		-- end
	end

	---@param zoom number # 0.1-50
	function self:set_zoom(zoom)
		zoom = math.min(math.max(zoom, 0.1), 50)
		-- -- The following 3 liens are required to fix the zoom due to group offsets.
		-- -- Read the comments for VehMon:DrawMap
		-- local ox, oy = self.vehmon:GetGroupOffset(GROUP_IDXS.MAP)
		-- local wx, wz = self.vehmon:ScreenMapToWorld(self.vehmon.monitor.width/2+ox, self.vehmon.monitor.height/2+oy, self.map_x, self.map_z, self.map_zoom)
		-- self.map_x, self.map_z = self.vehmon:ScreenMapToWorld(self.vehmon.monitor.width/2-ox, self.vehmon.monitor.height/2-oy, wx, wz, zoom)
		self.map_zoom = zoom
		self:redraw_map()
	end

	function self:tick()
		local touch1 = self.vehmon.monitor.touch1
		if touch1.pressed and not touch1.was_pressed then
			log_debug("Touch", touch1.x, touch1.y)
			if touch1.y < TOP_BAR_HEIGHT-1 then
				-- Do nothing
			elseif map_zoom_in_btn:is_inside(touch1.x, touch1.y) then
				self:set_zoom(self.map_zoom - 0.5)
			elseif map_zoom_out_btn:is_inside(touch1.x, touch1.y) then
				self:set_zoom(self.map_zoom + 0.5)
			else
				-- twx/twy is world position of the touch.
				local twx, twz = self.vehmon:ScreenMapToWorld(touch1.x, touch1.y, self.map_x, self.map_z, self.map_zoom, GROUP_IDXS.MAP)
				-- We could check here if something was pressed in world space.
				self.map_x, self.map_z = twx, twz
				self:redraw_map()
			end
		end

		local pos = server.getPlayerPos(0)
		local pos_floored = {pos[13]//1, pos[14]//1, pos[15]//1}
		self.vehmon:SetDBValue(DB_IDXS.PLAYER_POS, pos_floored)
		self.vehmon:SetDBValue(DB_IDXS.SERVER_TIME, 1, math.floor(server.getTimeMillisec()/1000))
	end
end


---@type table<integer,table|{vehmon:VehMon}>
local vehmon_handlers = {}

---@param vehicle_id integer
local function createVehMon(vehicle_id)
	local vehmon = VehMon.new(vehicle_id, 5, 25, 2)
	vehmon_handlers[vehicle_id] = {vehmon=vehmon}
	create_test_vehmon(vehmon_handlers[vehicle_id])
	if vehmon then
		g_savedata.vehmons[vehicle_id] = true
		log_debug(("Created VehMon handler for vehid %s with %s dials and %s keypads"):format(vehicle_id, vehmon.dial_count, vehmon.keypad_count))
	else
		log_debug(("Failed to create VehMon handler for vehid %s"):format(vehicle_id))
	end
end
---@param vehicle_id integer
local function removeVehMon(vehicle_id)
	vehmon_handlers[vehicle_id] = nil
	g_savedata.vehmons[vehicle_id] = nil
end


function onCreate()
	g_savedata.vehmons = g_savedata.vehmons or {}
	for vehicle_id, _ in pairs(g_savedata.vehmons) do
		createVehMon(vehicle_id)
	end
end


---@param game_ticks number
function onTick(game_ticks)
	for _, vehmon_handler in pairs(vehmon_handlers) do
		if vehmon_handler.vehmon:onTickStart() then
			if vehmon_handler.vehmon.state == "init" then
				-- VehMon has just initialised, vehicle was loaded.
			elseif vehmon_handler.vehmon.state == "waiting" then
				-- Waiting for vehicle to be ready, this is while VehMon is loading on the vehicle.
			elseif vehmon_handler.vehmon.state == "ready" then
				-- It's ready to recive data and will be sending monitor info like size and touch.
				if vehmon_handler.__has_done_setup == nil then
					vehmon_handler.__has_done_setup = true
					vehmon_handler:setup()
				end
				vehmon_handler:tick()
			end
			vehmon_handler.vehmon:onTickEnd()
		elseif vehmon_handler.vehmon.state == "deinit" then
			-- Has just been deinitialised, vehicle has unloaded or despawned.
			-- For despawned, `onTickStart()` must be called AFTER `onVehicleDespawn` for this state to be reached.
			vehmon_handler.__has_done_setup = nil
		elseif vehmon_handler.vehmon.state == "inactive" then
			-- Vehicle is not loaded.
		end
	end
end

---@param vehicle_id number
---@param peer_id number
---@param x number
---@param y number
---@param z number
---@param cost number
function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
	-- For testing, any player spawned vehicle is a vehmon.
	if peer_id >= 0 then
		createVehMon(vehicle_id)
	end
end

---@param vehicle_id number
---@param peer_id number
function onVehicleDespawn(vehicle_id, peer_id)
	removeVehMon(vehicle_id)
end

---@param full_message string
---@param peer_id number
---@param is_admin boolean
---@param is_auth boolean
---@param command string
---@param ... string
function onCustomCommand(full_message, peer_id, is_admin, is_auth, command, ...)
	if AVCmds.onCustomCommand(full_message, peer_id) then return end
end
