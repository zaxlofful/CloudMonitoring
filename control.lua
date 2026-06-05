-- CloudMonitoring control.lua
-- Every 15 seconds, writes per-surface item production rates (items/minute)
-- to a new timestamped JSON file in script-output/.

local WRITE_INTERVAL = 900 -- 15 seconds * 60 ticks/second

local PRODUCTION_ENTITY_TYPES = {
    "assembling-machine",
    "furnace",
    "rocket-silo",
    "chemical-plant",
    "oil-refinery",
}

-- Returns a table of {item_name -> items_per_minute} for all actively
-- crafting production entities on the given surface.
local function calculate_production_rates(surface)
    local rates = {}

    local entities = surface.find_entities_filtered({
        type = PRODUCTION_ENTITY_TYPES,
    })

    for _, entity in pairs(entities) do
        if entity.valid and entity.status == defines.entity_status.working then
            local recipe = entity.get_recipe()
            if recipe then
                local crafting_speed = entity.crafting_speed
                local crafting_time = recipe.energy

                if crafting_time > 0 then
                    for _, product in pairs(recipe.products) do
                        if product.type == "item" then
                            -- Use fixed amount when available; otherwise take the
                            -- midpoint of the min/max range.
                            local amount
                            if product.amount then
                                amount = product.amount
                            else
                                amount = ((product.amount_min or 0) + (product.amount_max or 0)) / 2
                            end
                            -- Scale by probability (defaults to 1 = 100%).
                            amount = amount * (product.probability or 1)

                            local rate = (amount / crafting_time) * crafting_speed * 60
                            if rate > 0 then
                                rates[product.name] = (rates[product.name] or 0) + rate
                            end
                        end
                    end
                end
            end
        end
    end

    return rates
end

script.on_nth_tick(WRITE_INTERVAL, function(event)
    local surfaces_data = {}

    for _, surface in pairs(game.surfaces) do
        local rates = calculate_production_rates(surface)
        -- Only include surfaces that have active production.
        if next(rates) then
            surfaces_data[surface.name] = rates
        end
    end

    local output = {
        timestamp = game.tick,
        surfaces = surfaces_data,
    }

    local filename = "cloudmonitoring-data-" .. game.tick .. ".json"
    game.write_file(filename, game.table_to_json(output), false)
end)