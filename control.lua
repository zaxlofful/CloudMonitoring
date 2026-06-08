-- CloudMonitoring: Export production data to JSON for external monitoring
-- Outputs to script-output/cloudmonitoring-data-{timestamp}.json every 15 seconds

local function export_production_data()
  local timestamp = os.time()
  local data = {
    timestamp = timestamp,
    tick = game.tick,
    items = {}
  }

  -- Aggregate production data across all forces
  for _, force in pairs(game.forces) do
    -- Item production (output_counts = production)
    for item, count in pairs(force.item_production_statistics.output_counts) do
      if not data.items[item] then
        data.items[item] = {
          name = item,
          production_count = 0,
          consumption_count = 0
        }
      end
      data.items[item].production_count = data.items[item].production_count + count
    end

    -- Item consumption (input_counts = consumption)
    for item, count in pairs(force.item_production_statistics.input_counts) do
      if not data.items[item] then
        data.items[item] = {
          name = item,
          production_count = 0,
          consumption_count = 0
        }
      end
      data.items[item].consumption_count = data.items[item].consumption_count + count
    end

    -- Fluid production
    for fluid, count in pairs(force.fluid_production_statistics.output_counts) do
      if not data.items[fluid] then
        data.items[fluid] = {
          name = fluid,
          production_count = 0,
          consumption_count = 0
        }
      end
      data.items[fluid].production_count = data.items[fluid].production_count + count
    end

    -- Fluid consumption
    for fluid, count in pairs(force.fluid_production_statistics.input_counts) do
      if not data.items[fluid] then
        data.items[fluid] = {
          name = fluid,
          production_count = 0,
          consumption_count = 0
        }
      end
      data.items[fluid].consumption_count = data.items[fluid].consumption_count + count
    end
  end

  -- Convert items table to array for JSON
  local items_array = {}
  for _, item_data in pairs(data.items) do
    table.insert(items_array, item_data)
  end
  data.items = items_array

  -- Write to JSON file
  local filename = "cloudmonitoring-data-" .. timestamp .. ".json"
  game.write_file(filename, game.table_to_json(data), false)
end

-- Export production data every 15 seconds (900 ticks)
script.on_nth_tick(900, export_production_data)