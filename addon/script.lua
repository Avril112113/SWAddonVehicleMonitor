g_savedata = {}

DEFAULT_LOG_LEVEL = 2

require "logging"
require "helpers"
-- require "avcmds"
local VehMon = require "vehmon"


---@type table<integer,VehMon>
local vehmons = {}

---@param vehicle_id integer
local function createVehMon(vehicle_id)
	local vehmon = VehMon.new(vehicle_id, 5, 25, 2)
	vehmons[vehicle_id] = vehmon
	if vehmon then
		g_savedata.vehmons[vehicle_id] = true
		log_debug(("Created VehMon for vehid %s with %s dials and %s keypads"):format(vehicle_id, vehmon.dial_count, vehmon.keypad_count))
	else
		log_debug(("Failed to create VehMon for vehid %s"):format(vehicle_id))
	end
end
---@param vehicle_id integer
local function removeVehMon(vehicle_id)
	vehmons[vehicle_id] = nil
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
	for _, vehmon in pairs(vehmons) do
		vehmon:tick()
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
