local TownProgressionI18NDataScript = class()

function TownProgressionI18NDataScript:start(ctx)
   ctx.town_serial_number = stonehearth.town:get_town(ctx.player_id):get_town_serial_number()
   ctx.english_town_ordinal_suffix = english_number_ordinal_suffix(ctx.town_serial_number)
end

function english_number_ordinal_suffix(number)
  local n = ""..number
  local ordinal, digit = {"st", "nd", "rd"}, string.sub(n, -1)
  if tonumber(digit) > 0 and tonumber(digit) <= 3 and string.sub(n,-2) ~= 11 and string.sub(n,-2) ~= 12 and string.sub(n,-2) ~= 13 then
    return ordinal[tonumber(digit)]
  else
    return "th"
  end
end


return TownProgressionI18NDataScript