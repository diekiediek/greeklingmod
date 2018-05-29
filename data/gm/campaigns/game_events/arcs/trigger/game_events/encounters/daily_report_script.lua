local Point2 = _radiant.csg.Point2
local Point3 = _radiant.csg.Point3
local Cube3 = _radiant.csg.Cube3
local game_master_lib = require 'lib.game_master.game_master_lib'
local log = radiant.log.create_logger('immigration_scenario')

--[[
   Immigration Synopsis

   Once a day, we run this scenario. It pops up a dialog showing your settlemet's core stats. 
   If your settlement meets certain conditions, cool people might want to join up. 

   The people who join are now always workers. 
]]

local Immigration = class()

function Immigration:initialize()
   self._sv.player_id = nil
   self._sv.immigration_data = nil
   self._sv.ctx = nil
   self._sv.timer = nil
   self._sv.immigration_bulletin = nil
   self._sv.searcher = nil
end

function Immigration:restore()
   --self:_load_trade_data()

   --If we made an expire timer then we're waiting for the player to acknowledge the traveller
   --Start a timer that will expire at that time
   if self._sv.timer then
      self._sv.timer:bind(function()
            self:_timer_callback()
         end)
   end
end


function Immigration:start(ctx, data)
   self._sv.player_id = ctx.player_id
   self._sv.immigration_data = data
   self._sv.ctx = ctx

   --Show a bulletin with food/net worth stats
   local message, success = self:_compose_town_report()
   local data = {
      title = self._sv.immigration_data.update_title,
      message = message
   }

   if success then
      data.conclusion = self._sv.immigration_data.conclusion_positive
      data.accepted_callback = "_on_accepted"
      data.declined_callback = "_on_declined"
   else
      data.conclusion = self._sv.immigration_data.conclusion_negative
      data.ok_callback = "_on_declined"
   end

   self._sv.immigration_bulletin = stonehearth.bulletin_board:post_bulletin(self._sv.player_id)
      :set_ui_view('StonehearthImmigrationReportDialog')
      :set_callback_instance(self)
      :set_sticky(true)
      :set_data(data)

   --Make sure it times out if we don't get to it
   local wait_duration = self._sv.immigration_data.expiration_timeout
   self:_create_timer(wait_duration)
end

function Immigration:_compose_town_report()
   local town_name = stonehearth.town:get_town(self._sv.player_id):get_town_name()
   local num_citizens = stonehearth.population:get_population_size(self._sv.player_id)
   local summation = self:_eval_requirement(num_citizens)

   local message = {
      date = stonehearth.calendar:get_date_data(), 
      town_name = town_name,
      town_size = num_citizens,
      food_data = summation.food_data, 
      net_worth_data = summation.net_worth_data
   }
   local success = summation.success
   return message, success
end

function Immigration:_eval_requirement(num_citizens)
   --TODO: the score data should come from all food, not just food in stockpiles
   local score_data = stonehearth.score:get_scores_for_player(self._sv.player_id):get_score_data()
   if log:is_enabled(radiant.log.DETAIL) then
      log:detail('caculating immigration data %s', radiant.util.table_tostring(score_data))
   end

   --Get data for food
   local available_food = 0
   if score_data.total_scores:contains('edibles') then
      available_food = score_data.total_scores:get('edibles')
   end
   local food_success, food_data = self:_find_requirements_by_type_and_pop(available_food, 'food', num_citizens)
   log:detail('Food result: %s', radiant.util.table_tostring(food_data))

   --Get data for net worth
   local net_worth = 0
   if score_data.total_scores:contains('net_worth') then
      net_worth = score_data.total_scores:get('net_worth')
   end
   local _, net_worth_data = self:_find_requirements_by_type_and_pop(net_worth, 'net_worth', num_citizens)
   -- Some town bonuses give extra net worth.
   local bonus_net_worth = 0
   local town = stonehearth.town:get_town(self._sv.player_id)
   if town then
      for _, bonus in pairs(town:get_active_town_bonuses()) do
         if bonus.get_net_worth_bonus then
            bonus_net_worth = bonus_net_worth + bonus:get_net_worth_bonus() 
         end
      end
   end
   net_worth_data.base_value = math.floor(net_worth_data.available)
   net_worth_data.bonus = math.floor(bonus_net_worth)
   net_worth_data.available = net_worth_data.base_value + net_worth_data.bonus
   local net_worth_success = net_worth_data.available >= net_worth_data.target
   log:detail('Net Worth result: %s', radiant.util.table_tostring(net_worth_data))

   local summation = {
      food_data = food_data,
      net_worth_data = net_worth_data, 
      success = food_success and net_worth_success
   }

   if (not summation.success) then
      log:debug("Immigration unsuccessful.")
   end

   return summation
end

function Immigration:_find_requirements_by_type_and_pop(available, type, num_citizens)
   local equation = stonehearth.constants.immigration_requirements[type]
   equation = string.gsub(equation, 'num_citizens', num_citizens)
   local target = self:_evaluate_equation(equation)
   local label = self._sv.immigration_data[type .. '_label']

   local data = {
      label = label,
      available = available, 
      target = target
   }
   local success = available >= target
   return success, data
end

function Immigration:_evaluate_equation(equation)
   local fn = loadstring('return ' .. equation)
   return fn()
end

function Immigration:_get_fallback_spawn_location()
   local territory = stonehearth.terrain:get_territory(self._sv.player_id)
   local town_center = territory:get_centroid()

   -- search from max_y to avoid tunnels
   local max_y = radiant.terrain.get_terrain_component():get_bounds().max.y
   local proposed_location = radiant.terrain.get_point_on_terrain(Point3(town_center.x, max_y, town_center.y))
   local spawn_location = radiant.terrain.find_placement_point(proposed_location, 20, 30)
   return spawn_location
end

function Immigration:_find_location_callback(op, location)
   if op == 'check_location' then
      return self:_check_location(location)
   elseif op == 'set_location' then
      self:_place_citizen(location)
   elseif op == 'abort' then
      local fallback_location = self:_get_fallback_spawn_location()
      self:_place_citizen(fallback_location)
   else
      radiant.error('unknown op "%s" in choose_location_outside_town callback', op)
   end
end

function Immigration:_check_location(location)
   local r = stonehearth.terrain:get_sight_radius()
   local sight_radius = Point3(r, r, r)
   local cube = Cube3(location):inflated(sight_radius)
   local entities = radiant.terrain.get_entities_in_cube(cube)

   -- check for anything nearby that might attack the new citizen
   for _, entity in pairs(entities) do
      if entity:get_component('stonehearth:ai') then
         local player_id = radiant.entities.get_player_id(entity)
         if stonehearth.player:are_player_ids_hostile(player_id, self._sv.player_id) then
            return false
         end
      end
   end

   return true
end

function Immigration:_find_spawn_location()
   self._sv.searcher = radiant.create_controller('stonehearth:game_master:util:choose_location_outside_town',
                                              64, 128,
                                              radiant.bind(self, '_find_location_callback'))
end

function Immigration:_create_citizen()
   local pop = stonehearth.population:get_population(self._sv.player_id)
   local citizen = pop:create_new_citizen()

   citizen:add_component('stonehearth:job')
               :promote_to('stonehearth:jobs:worker')

   return citizen
end

function Immigration:_place_citizen(location)
   local citizen = self:_create_citizen()
   radiant.terrain.place_entity(citizen, location)

   local town = stonehearth.town:get_town(self._sv.player_id)
   --Give the entity the task to run to the banner
   self._approach_task = citizen:get_component('stonehearth:ai')
                              :get_task_group('stonehearth:task_groups:solo:unit_control')
                                 :create_task('stonehearth:goto_town_center', {town = town})
                                 :once()
                                 :start()

   self:_inform_player(citizen)
   self:_destroy_node()
   --TODO: attach particle effect
end

function Immigration:_inform_player(citizen)
   --Send another bulletin with to inform player someone has joined their town
   local title = self._sv.immigration_data.success_title
   local pop = stonehearth.population:get_population(self._sv.player_id)
   pop:show_notification_for_citizen(citizen, title)
end

--- Only actually spawn the object after the user clicks OK
function Immigration:_on_accepted()
   self:_find_spawn_location()
end

function Immigration:_on_declined()
   if self._sv.timer then
      self._sv.timer:destroy()
   end
   self:_destroy_node()
end

function Immigration:_create_timer(duration)
   self._sv.timer = stonehearth.calendar:set_persistent_timer("Immigration remove bulletin", duration, function() 
      self:_timer_callback()
   end)
end

function Immigration:_timer_callback()
   if self._sv.immigration_bulletin then
      local bulletin_id = self._sv.immigration_bulletin:get_id()
      stonehearth.bulletin_board:remove_bulletin(bulletin_id)
      self:_destroy_node()
   end
end

function Immigration:_destroy_node()
   self:destroy()
   -- Remove ourselves from the lib because we don't need the data
   game_master_lib.destroy_node(self._sv.ctx.encounter, self._sv.ctx.parent_node)
end

function Immigration:destroy()
   if self._sv.timer then
      self._sv.timer:destroy()
      self._sv.timer = nil
   end

   if self._sv.searcher then
      self._sv.searcher:destroy()
      self._sv.searcher = nil
   end
end


return Immigration