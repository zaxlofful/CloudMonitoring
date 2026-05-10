local function safe_string(value)
  if value == nil then
    return nil
  end
  return tostring(value)
end

local function entity_summary(entity)
  if not (entity and entity.valid) then
    return nil
  end

  return {
    name = safe_string(entity.name),
    type = safe_string(entity.type),
    force = entity.force and safe_string(entity.force.name) or nil,
    surface = entity.surface and safe_string(entity.surface.name) or nil,
    position = entity.position and { x = entity.position.x, y = entity.position.y } or nil
  }
end

local function write_event(event_name, payload)
  local record = payload or {}
  record.event = event_name
  record.tick = game and game.tick or nil

  local line = game.table_to_json(record)
  game.write_file("mod_events.jsonl", line .. "\n", true)
end

local function format_time_hhmm(ticks)
  local total_seconds = math.floor((ticks or 0) / 60)
  local total_minutes = math.floor(total_seconds / 60)
  local hours = math.floor(total_minutes / 60)
  local minutes = total_minutes % 60
  return string.format("%d:%02d", hours, minutes)
end

local function get_primary_force()
  if game.forces.player then
    return game.forces.player
  end

  for _, force in pairs(game.forces) do
    return force
  end

  return nil
end

remote.add_interface("factorio-monitor", {
  get_state = function()
    local force = get_primary_force()
    local research_name = nil
    local research_progress = nil
    if force and force.current_research then
      research_name = safe_string(force.current_research.name)
      research_progress = force.research_progress
    end

    local state = {
      players_online = #game.connected_players,
      research = {
        name = research_name,
        progress = research_progress
      },
      game_time = {
        tick = game.tick,
        hhmm = format_time_hhmm(game.tick)
      }
    }

    return game.table_to_json(state)
  end
})

script.on_init(function()
  global.last_attack_tick = global.last_attack_tick or 0
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  local player = game.get_player(event.player_index)
  write_event("player_joined", {
    player = player and safe_string(player.name) or nil,
    player_index = event.player_index
  })
end)

script.on_event(defines.events.on_player_left_game, function(event)
  local player = game.get_player(event.player_index)
  write_event("player_left", {
    player = player and safe_string(player.name) or nil,
    player_index = event.player_index
  })
end)

script.on_event(defines.events.on_pre_player_died, function(event)
  local player = game.get_player(event.player_index)
  write_event("player_died", {
    player = player and safe_string(player.name) or nil,
    player_index = event.player_index,
    cause = entity_summary(event.cause)
  })
end)

script.on_event(defines.events.on_rocket_launched, function(event)
  local player = event.player_index and game.get_player(event.player_index) or nil
  write_event("rocket_launched", {
    player = player and safe_string(player.name) or nil,
    player_index = event.player_index,
    rocket = entity_summary(event.rocket),
    rocket_silo = entity_summary(event.rocket_silo)
  })
end)

script.on_event(defines.events.on_entity_damaged, function(event)
  if not (event.entity and event.entity.valid and event.entity.force) then
    return
  end

  local damaged_force = event.entity.force.name
  if damaged_force == "enemy" or damaged_force == "neutral" then
    return
  end

  if not (event.cause and event.cause.valid and event.cause.force and event.cause.force.name == "enemy") then
    return
  end

  local last_tick = global.last_attack_tick or 0
  if (game.tick - last_tick) < 300 then
    return
  end
  global.last_attack_tick = game.tick

  write_event("base_under_attack", {
    entity = entity_summary(event.entity),
    cause = entity_summary(event.cause),
    damage = event.final_damage_amount,
    damage_type = event.damage_type and safe_string(event.damage_type.name) or nil
  })
end)

