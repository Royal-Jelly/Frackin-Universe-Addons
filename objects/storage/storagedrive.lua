require "/scripts/util.lua"
require "/scripts/kheAA/transferUtil.lua"

ic = {}
ic.serverVersion = 1

local scanTimer

function init()
	transferUtil.init()
  object.setInteractive(true)
	ic.objectName = config.getParameter("shortdescription") or object.name()
	ic.locked = 0
	ic.eid = entity.id()
	ic.dt = 0
	object.setConfigParameter("icVersion", ic.serverVersion)
	message.setHandler("lock", ic.handlerLock)
	message.setHandler("rename", ic.handlerRename)
	message.setHandler("open", ic.handlerOpen)
	storage.receiveItems=true
	inDataNode=0
	outDataNode=0
end

--don't know why we need this snippit because the whole script will only run on SB 1.2+
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

function update(dt)
	-- Notify ITD but no faster than once per second.
	if not scanTimer or (scanTimer > 1) then
		transferUtil.loadSelfContainer()
		binInventoryChange()  --borrowed from gardenbot
		scanTimer = 0
	else
		scanTimer=scanTimer+dt
	end

	-- Persistant Inventory Script Credits to
	if icHookUpdate then
		icHookUpdate(dt)
	end
	script.setUpdateDelta(60)
	if not storage.fixBreak then
		object.setConfigParameter("smashOnBreak", true)
		storage.fixBreak = true
	end
	if not storage.init then
		local items = world.getObjectParameter(ic.eid, "content")
		if items and type(items) == "table" then
			for k,v in pairs(items) do
				local leftover = world.containerItemApply(ic.eid, v, k-1)
				if leftover then
					world.spawnItem(leftover.name, entity.position(), leftover.count, leftover.parameters)
				end
			end
		end
		object.setConfigParameter("content", {})
		storage.init = true
	end
	if ic.locked > 0 then
		ic.locked = ic.locked - dt
		if ic.locked <= 0 then
			ic.locked = 0
			object.setConfigParameter("icLocked", 0)
		end
	end
	ic.dt = ic.dt + dt
	if ic.dt > 2 then
		ic.dt = 0
		local items = world.containerItems(ic.eid)
		local pos = entity.position()
		pos[2] = pos[2] + 1
		for k,v in pairs(items) do
			if v.parameters.content then
				world.spawnItem(v.name, pos, v.count, v.parameters)
				world.containerTakeAt(ic.eid, k-1)
			end
		end
	end
end

--Animations from Gardenbot mod
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


-- More persistant storage code
function die()
	local newPrice = 0
	local countItems = 0
	local countSlots = 0
	local spawned = false
	local opened = world.getObjectParameter(ic.eid, "playerInteract")
	if opened then
		local items = world.containerItems(ic.eid)
		world.containerTakeAll(ic.eid)
		for slotId,slotItem in pairs(items) do
			local pc = root.itemConfig(slotItem)
			if pc and pc.config and pc.config.price then
				newPrice = newPrice + (pc.config.price * slotItem.count)
			end
			countSlots = countSlots + 1
			countItems = countItems + slotItem.count
			if slotItem.parameters and slotItem.parameters.content then
				world.spawnItem(slotItem.name, entity.position(), slotItem.count, slotItem.parameters)
				items[slotId] = nil
			end
		end
		if countSlots > 0 then
			local newObj = { shortdescription=ic.objectName, playerInteract=true, content=items }
			local iconf = root.itemConfig( object.name() )
			if iconf and iconf.config then
				if iconf.config.inventoryIcon then
					newObj.inventoryIcon = iconf.config.inventoryIcon.."?border=1;0f3c8f?fade=0f3c8fFF;0.1"
				end
				-- if iconf.config.itemAgeMultiplier then
				-- 	newObj.itemAgeMultiplier = iconf.config.itemAgeMultiplier
				-- end
				if newPrice > 0 then
					if iconf.config.price then
						newPrice = newPrice + iconf.config.price
					end
					newObj.price = newPrice
				end
			end
			newObj.description = "\n^green;storage used: ".. countSlots
			if countItems > countSlots then
				newObj.description = newObj.description .. "\nTotal items: ".. countItems
			end
			world.spawnItem(object.name(), entity.position(), 1, newObj)
			--object.smash(true)
			spawned = true
		end
	end
	if spawned == false then
		world.spawnItem(object.name(), entity.position(), 1)
	end
end

function ic.handlerLock()
	ic.locked = 1
	object.setConfigParameter("icLocked", ic.locked)
end

function ic.handlerRename(_, _, newName)
	if not newName or newName == "" then
		local default = root.itemConfig(object.name())
		newName = default.config.shortdescription
	end
	ic.objectName = newName
	object.setConfigParameter("shortdescription", newName)
end

function ic.handlerOpen()
	object.setConfigParameter("playerInteract", true)
end
