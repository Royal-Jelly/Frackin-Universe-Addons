require "/scripts/items/rotting.lua"

local icHookAgeItem = ageItem
function ageItem(baseItem, aging)
  if baseItem.parameters.content then
    aging = aging * (baseItem.parameters.itemAgeMultiplier or 1)
    for k,v in pairs(baseItem.parameters.content) do
      if v.parameters.timeToRot then
        baseItem.parameters.content[k] = icHookAgeItem(baseItem.parameters.content[k], aging)
      end
    end
  end
  return baseItem
end