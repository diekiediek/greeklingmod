local Relations = require 'lib.player.relations'

local GoblinCampDepartsScript = class()

--When the camp departs, no matter how the player interacted with these goblins, 
--set amenity for all goblins back to hostile. 

function GoblinCampDepartsScript:start(ctx)
   stonehearth.player:set_neutral_to_everyone(ctx.npc_player_id, false)

   local boss = ctx:get('goblin_raiding_camp_1.boss')
   if boss then
      radiant.events.trigger(boss, 'stonehearth:chieftain_camp_moving_on')
   end
end

return GoblinCampDepartsScript