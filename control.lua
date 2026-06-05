local WRITE_INTERVAL = 900 -- 15 seconds * 60 ticks/second

local function accumulate_counts(destination, source)
    for name, amount in pairs(source) do
        destination[name] = (destination[name] or 0) + amount
    end
end

script.on_nth_tick(WRITE_INTERVAL, function(event)
    local item_production_totals = {}
    local item_consumption_totals = {}
    local fluid_production_totals = {}
    local fluid_consumption_totals = {}

    for _, force in pairs(game.forces) do
        accumulate_counts(item_production_totals, force.item_production_statistics.output_counts)
        accumulate_counts(item_consumption_totals, force.item_production_statistics.input_counts)
        accumulate_counts(fluid_production_totals, force.fluid_production_statistics.output_counts)
        accumulate_counts(fluid_consumption_totals, force.fluid_production_statistics.input_counts)
    end

    local output = {
        timestamp = game.tick,
        item_production_totals = item_production_totals,
        item_consumption_totals = item_consumption_totals,
        fluid_production_totals = fluid_production_totals,
        fluid_consumption_totals = fluid_consumption_totals,
    }

    local filename = "cloudmonitoring-data-" .. game.tick .. ".json"
    game.write_file(filename, game.table_to_json(output), false)
end)