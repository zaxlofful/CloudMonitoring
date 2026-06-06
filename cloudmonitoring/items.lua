local Items = {}

local function is_table(value)
  return type(value) == "table"
end

function Items.rebuild_cache()
  global.cloudmonitoring_item_names = {}
  for name, _ in pairs(game.item_prototypes) do
    global.cloudmonitoring_item_names[#global.cloudmonitoring_item_names + 1] = name
  end
  table.sort(global.cloudmonitoring_item_names)
end

function Items.get_all_names()
  if not is_table(global.cloudmonitoring_item_names) then
    Items.rebuild_cache()
  end
  return global.cloudmonitoring_item_names
end

local function split_tokens(text)
  local tokens = {}
  if type(text) ~= "string" then
    return tokens
  end
  text = text:lower()
  for token in text:gmatch("[^,%s]+") do
    tokens[#tokens + 1] = token
  end
  return tokens
end

function Items.filter_names(all_names, search_text)
  local tokens = split_tokens(search_text)
  if #tokens == 0 then
    return all_names
  end

  local matches = {}
  for _, name in ipairs(all_names) do
    local lower = name:lower()
    for _, token in ipairs(tokens) do
      if lower:find(token, 1, true) then
        matches[#matches + 1] = name
        break
      end
    end
  end
  return matches
end

function Items.production_preset_items()
  local desired = {
    "iron-plate",
    "copper-plate",
    "steel-plate",
    "stone-brick",
    "plastic-bar",
    "electronic-circuit",
    "advanced-circuit",
    "processing-unit",
    "battery",
    "engine-unit",
  }

  local out = {}
  for _, name in ipairs(desired) do
    if game.item_prototypes[name] then
      out[#out + 1] = name
    end
  end
  return out
end

return Items
