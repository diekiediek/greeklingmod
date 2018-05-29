local Relations = require 'lib.player.relations'

local GoblinCampDepartsScript = class()

--When the camp departs, no matter how the player interacted with these goblins, 
--set amenity for all goblins back to hostile. 

function GoblinCampDepartsScript:start(ctx)
   stonehearth.player:set_neutral_to_everyone('goblins', false)
end

return GoblinCampDepartsScript