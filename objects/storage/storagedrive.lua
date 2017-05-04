function configParameter(name, default)
  if entity.configParameter then
    return entity.configParameter(name,default)--Glad
  else
    return config.getParameter(name,default)--Cheerful
  end
end

function setAnimationState(name, default)
  if entity.setAnimationState then
    return entity.setAnimationState(name,default)--Glad
  else
    return animator.setAnimationState(name,default)--Cheerful
  end
end

function update() -- cheerful doesnt have container callback :( poll it every half sec then
  script.setUpdateDelta(30)
  binInventoryChange()
end

function binInventoryChange()
  if entity.id() then
    local container = entity.id()
    local frames = configParameter("binFrames", 9)
    local fill = math.ceil(frames * fillPercent(container))
    if self.fill ~= fill then
      self.fill = fill
      setAnimationState("fill", tostring(fill))
    end
  end
end

function fillPercent(container)
  if type(container) ~= "number" then return nil end
  local size = world.containerSize(container)
  local count = 0
  for i = 0,size,1 do
    local item = world.containerItemAt(container, i)
    if item ~= nil then
      count = count + 1
    end
  end
  return (count/size)
end
