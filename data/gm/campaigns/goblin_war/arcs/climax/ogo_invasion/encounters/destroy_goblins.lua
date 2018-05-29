local Relations = require 'lib.player.relations'

local DestroyGoblins = class()

--When the camp departs, no matter how the player interacted with these goblins, 
--set amenity for all goblins back to hostile. 

function DestroyGoblins:start(ctx)
   stonehearth.player:set_neutral_to_everyone(ctx.npc_player_id, false)
end

return DestroyGoblins