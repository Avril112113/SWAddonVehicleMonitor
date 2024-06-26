require("shallowcopy")
require("iostream")
require("binnet_short")

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

require("packets")


function onTick()
	__resolution = {input.getNumber(1), input.getNumber(2)}
	__input1 = {input.getNumber(3), input.getNumber(4), input.getBool(1)}
	__input2 = {input.getNumber(5), input.getNumber(6), input.getBool(2)}

	__values = {}
	__non_zero_n = false
	for i=1,INPUT_COUNT do
		__values[i] = input.getNumber(6+i)
		__non_zero_n = __non_zero_n or __values[1] ~= 0
	end
	Binnet:process(__values)

	function send_packet_if_tbl_neq(a, b, packet_id, ...)
		if b[1] ~= a[1] or b[2] ~= a[2] or b[3] ~= a[3] then
			Binnet:send(packet_id, ...)
		end
	end
	send_packet_if_tbl_neq(prev_resolution, __resolution, PACKET_RESOLUION, __resolution)
	send_packet_if_tbl_neq(prev_input1, __input1, PACKET_INPUT1, __input1)
	send_packet_if_tbl_neq(prev_input2, __input2, PACKET_INPUT2, __input2)

	output.setBool(2, #Binnet.outStream > 0 or __non_zero_n)
	for i,v in ipairs(Binnet:write(OUTPUT_COUNT)) do
		output.setNumber(i, v)
	end
	if __resolution[1] ~= 0 and __resolution[2] ~= 0 then
		prev_resolution = __resolution
		prev_input1 = __input1
		prev_input2 = __input2
	end
end

function onDraw()
	for i=0,255 do
		if cmd_groups[i] and cmd_groups[i].enabled then
			screen.setColor(255, 255, 255)
			for _, f in ipairs(cmd_groups[i]) do
				f(cmd_groups[i])
			end
		end
	end
end
