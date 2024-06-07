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


---@param self table|{vehmon:VehMon}
local function create_test_vehmon(self)
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

	self.zoom = 5

	function self:redraw_map()
		self.vehmon:GroupReset(GROUP_IDXS.MAP)
		local vehPos = server.getVehiclePos(self.vehmon.vehicle_id)
		self.vehmon:DrawMap(vehPos[13], vehPos[15], self.zoom)
		self.vehmon:GroupEnabled(GROUP_IDXS.MAP, true)
	end

	function self:setup()
		log_debug(("%s - VehMon handler setup."):format(self.vehmon.vehicle_id))

		self:redraw_map()

		self.vehmon:GroupReset(GROUP_IDXS.TOP_BAR)
		self.vehmon:DrawColor(0, 0, 0)
		self.vehmon:DrawRectF(0, 0, self.vehmon.monitor.width, 40)
		self.vehmon:DrawColor(255, 255, 255)
		self.vehmon:DrawRectF(0, 8, self.vehmon.monitor.width, 1)
		self.vehmon:DrawText(1, 1, DB_IDXS.COMPANY_NAME, "%s")
		self.vehmon:DrawText(199, 1, DB_IDXS.MONEY, "$%s")
		self.vehmon:GroupEnabled(GROUP_IDXS.TOP_BAR, true)

		self.vehmon:GroupReset(GROUP_IDXS.INFO)
		self.vehmon:DrawText(1, 14, DB_IDXS.PLAYER_NAME, "Name: %s")
		self.vehmon:DrawText(1, 14+8, DB_IDXS.PLAYER_POS, "Pos: %s, %s, %s")
		self.vehmon:DrawText(1, 14+8+8, DB_IDXS.SERVER_TIME, "server time: %s")
		self.vehmon:GroupEnabled(GROUP_IDXS.INFO, true)

		self.vehmon:SetDBValue(DB_IDXS.PLAYER_NAME, 1, server.getPlayerName(0) or "<NO_PLAYER>")
		self.vehmon:SetDBValue(DB_IDXS.COMPANY_NAME, 1, "Test company INC")
		self.vehmon:SetDBValue(DB_IDXS.MONEY, 1, 12345678987654321)
	end

	function self:tick()
		if self.vehmon.monitor.touch1.pressed and not self.vehmon.monitor.touch1.was_pressed then
			if self.vehmon.monitor.touch1.y < self.vehmon.monitor.height/2 then
				self.zoom = self.zoom / 1.5
			else
				self.zoom = self.zoom * 1.5
			end
			self.zoom = math.min(math.max(self.zoom, 0.1), 50)

			self:redraw_map()
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
