require("shallowcopy")
require("iostream")
require("binnet_short")
require("packets")

INPUT_COUNT = property.getNumber("Inputs")
OUTPUT_COUNT = property.getNumber("Outputs")
-- Static offsets might be handy for debugging. Touch is also offset by this.
MON_OFFSET_X = property.getNumber("OffX")
MON_OFFSET_Y = property.getNumber("OffY")


---@class CmdGroup
---@field enabled boolean
---@field offset {[1]:number,[2]:number}
---@field [integer] fun(group:CmdGroup)


function reset()
	---@type CmdGroup[] # Group -1 is only used as a default which isn't drawn and can't be set besides with a full reset.
	cmd_groups = {}
	for i=-1,255 do
		cmd_groups[i] = {enabled=false,offset={0,0}}
	end
	cmd_group_idx = -1
	cmd_group_draw_idx = 1

	db_values = {}

	prev_resolution = {0,0}
	prev_input1 = {0,0,false}
	prev_input2 = {0,0,false}
end
reset()

-- tick = 0

monitor_on = true
function onTick()
	-- tick = tick + 1
	-- if tick < 60 then
	-- 	return
	-- end

	cmd_groups[cmd_group_idx] = cmd_groups[cmd_group_idx] or {enabled=false}

	local resolution = {input.getNumber(1), input.getNumber(2)}
	local input1 = {input.getNumber(3), input.getNumber(4), input.getBool(1)}
	local input2 = {input.getNumber(5), input.getNumber(6), input.getBool(2)}

	local values = {}
	for i=1,INPUT_COUNT do
		values[i] = input.getNumber(6+i)
	end
	local packet_processed = Binnet:process(values)

	if prev_resolution[1] ~= resolution[1] or prev_resolution[2] ~= resolution[2] then
		Binnet:send(PACKET_RESOLUION, resolution)
	end
	if prev_input1[1] ~= input1[1] or prev_input1[2] ~= input1[2] or prev_input1[3] ~= input1[3] then
		Binnet:send(PACKET_INPUT1, input1)
	end
	if prev_input2[1] ~= input2[1] or prev_input2[2] ~= input2[2] or prev_input2[3] ~= input2[3] then
		Binnet:send(PACKET_INPUT2, input2)
	end

	output.setBool(2, #Binnet.outStream > 0 or packet_processed > 0)
	local output_values = Binnet:write(OUTPUT_COUNT)
	for i=1,#output_values do
		output.setNumber(i, output_values[i])
	end
	if resolution[1] ~= 0 and resolution[2] ~= 0 then
		prev_resolution = resolution
		prev_input1 = input1
		prev_input2 = input2
	end
	output.setBool(1, monitor_on)
end

function onDraw()
	for i=0,255 do
		if cmd_groups[i] and cmd_groups[i].enabled then
			for _, f in ipairs(cmd_groups[i]) do
				f(cmd_groups[i])
			end
		end
	end
end
