local MakeGoblinsNeutral = class()

function MakeGoblinsNeutral:initialize()
	self._sv.ctx = nil
end

function MakeGoblinsNeutral:restore()
end

function MakeGoblinsNeutral:activate()
	if self._sv.ctx then
	end
end

--Makes the goblins neutral to everyone
function MakeGoblinsNeutral:start(ctx, data)
	self._sv.ctx = ctx
	stonehearth.player:set_neutral_to_everyone(ctx.npc_player_id, data.make_neutral)
end

function MakeGoblinsNeutral:get_out_edge(out_edge)
end

return MakeGoblinsNeutral