AVCmds.createCommand{name="tp"}
	:registerGlobalCommand()
	:setPermission("admin")
	:addHandler{
		AVCmds.player{},
		AVCmds.optional(AVCmds.player{}, nil),
		---@param ctx AVCommandContext
		---@param a SWPlayer
		---@param b SWPlayer
		function(ctx, a, b)
			local target, to
			if b == nil then
				target = ctx.player
				to = a
			else
				target = a
				to = b
			end
			local pos = server.getPlayerPos(to.id)
			server.setPlayerPos(target.id, pos)
		end
	}
