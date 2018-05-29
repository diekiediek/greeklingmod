local OgoDeadCanStart = class()

function OgoDeadCanStart:start(ctx, info)
	--If Ogo is still alive, return true
	--TODO: find out how to get to first individual in the array
	if not ctx.ogo_army_raid.ogo_skullbonker or not ctx.ogo_army_raid.ogo_skullbonker:is_valid() then
		return true
	end

	--Otherwise, return false
	return false
end

return OgoDeadCanStart