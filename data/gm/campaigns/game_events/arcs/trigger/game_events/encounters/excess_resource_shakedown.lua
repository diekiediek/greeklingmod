local entity_forms = require 'lib.entity_forms.entity_forms_lib'
local rng = _radiant.math.get_default_rng()
local Relations = require 'lib.player.relations'
local DEFAULT_TRIBUTE_VALUE = 50

local ExcessResourceShakedown = class()

function ExcessResourceShakedown:initialize()
   self._sv.ctx = nil
   self._sv.reward_items = nil
   self._sv.tribute_value = DEFAULT_TRIBUTE_VALUE
end

function ExcessResourceShakedown:create(ctx, info)
   self._sv.ctx = ctx

   local town_name = stonehearth.town:get_town(ctx.player_id):get_town_name()
   ctx.town_name = town_name

   local matching_item_count = ctx.matching_item_count

   local tribute_value = DEFAULT_TRIBUTE_VALUE
   if matching_item_count then
      tribute_value = rng:get_int(0.125 * matching_item_count, 0.25 * matching_item_count)
   end
   self._sv.tribute_value = tribute_value
   self._sv.reward_items = info.reward_items

end

function ExcessResourceShakedown:destroy()
   local bulletin = self._sv.bulletin
   if bulletin then
      stonehearth.bulletin_board:remove_bulletin(bulletin)
      self._sv.bulletin = nil
      self.__saved_variables:mark_changed()
   end
end

function ExcessResourceShakedown:on_transition(transition)
end

-- return a table containing the tribute information needed for the
-- demand tribute encounter
function ExcessResourceShakedown:get_tribute_demand()
   local ctx = self._sv.ctx
   local player_id = ctx.player_id
   local matching_items = ctx.matching_items

   local inventory = stonehearth.inventory:get_inventory(player_id)
   if not inventory or not matching_items then
      return
   end
   
   local items = inventory:get_item_tracker('stonehearth:usable_item_tracker')
                              :get_tracking_data()

   local remaining_value = self._sv.tribute_value
   local tribute = {}
   local reward_gold = 0

   for uri, entry in pairs(matching_items) do
      if remaining_value <= 0 then
         break
      end
      local info = items:get(uri)
      if info and not tribute[uri] then
         local item_count = math.min(info.count, remaining_value)
         tribute[uri] = {
            uri = uri,
            count = item_count
         }
         remaining_value = remaining_value - item_count
         reward_gold = reward_gold + self:_get_gold_value(uri) * item_count
      end
   end

   local rnd_offset = rng:get_int(0.01 * reward_gold, 0.08 * reward_gold) * ((rng:get_int(0, 1) * 2) - 1)
   ctx.donation_gold = math.max(reward_gold + math.ceil(rnd_offset), 1)
   self._sv.ctx.__saved_variables:mark_changed()

   return tribute
end

function ExcessResourceShakedown:revenge(demands, options)
   local revenge_data = options.revenge_data
   assert(revenge_data.tribute_percentage, 'tribute_percentage field missing for resource shakedown')
   local value = math.ceil(self._sv.tribute_value * revenge_data.tribute_percentage)
   local stolen_items = {}

   local tracking_data = options.tracking_data

   for uri, entry in pairs(demands) do
      local entities = tracking_data:get(uri).items
      local gold_value = self:_get_gold_value(uri)
      for i=1, entry.count do
         if value > 0 then
            local id, entity = next(entities)
            if entity then
               local destroyed_count = stolen_items[uri] and stolen_items[uri].count or 0
               stolen_items[uri] = {
                  uri = uri,
                  count = destroyed_count + 1,
                  icon = entry.icon,
                  display_name = entry.display_name
               }
               radiant.entities.kill_entity(entity)
               value = value - gold_value
            end
         else
            break
         end
      end
   end

   if options.bulletin_data then
      options.bulletin_data.demands = {
         items = stolen_items
      }
   end
end

function ExcessResourceShakedown:_get_gold_value(uri)
   local net_worth = radiant.entities.get_net_worth(uri)
   return net_worth or 0
end

return ExcessResourceShakedown
