local MakeOrcNPCsFriendly = class()

function MakeOrcNPCsFriendly:start(ctx, data)
   stonehearth.player:set_amenity(ctx.player_id, 'orc_npcs', 'friendly')
end

return MakeOrcNPCsFriendly