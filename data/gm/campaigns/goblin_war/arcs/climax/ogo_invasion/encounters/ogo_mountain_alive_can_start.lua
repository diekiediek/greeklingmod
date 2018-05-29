local OgoMountainCanStart = class()

function OgoMountainCanStart:start(ctx, info)
	--If Ogo is still alive, return true
	--TODO: find out how to get to first individual in the array
	if ctx.ogo_army_raid.ogo_skullbonker and ctx.ogo_army_raid.ogo_skullbonker:is_valid() then
		return true
	end

	--Otherwise, return false
	return false
end

return OgoMountainCanStart