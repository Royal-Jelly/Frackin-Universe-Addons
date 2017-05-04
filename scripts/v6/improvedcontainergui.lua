ic = {}
ic.clientVersion = 1

local timer = {
	time = 0
}
function timer.start()
	timer.time = os.clock()
end
function timer.stop(text)
	if text then
		sb.logInfo("[IC] [%s] Time elapsed: %s", text, os.clock()-timer.time)
	else
		sb.logInfo("[IC] Time elapsed: %s", os.clock()-timer.time)
	end
end

function init()
	world.sendEntityMessage(pane.containerEntityId(), "open")
	ic.eid = pane.containerEntityId()
	ic.buttons = { "icQuickstackButton", "icSortButton" }
	ic.equipSlots = { "head", "chest", "legs", "back", "headCosmetic", "chestCosmetic", "legsCosmetic", "backCosmetic" }
	--ic.locked = world.getObjectParameter(ic.eid, "icLocked") or 0
	ic.locked = 0
	ic.lock()
	ic.defaultMaxStack = root.assetJson("/items/defaultParameters.config:defaultMaxStack")
	ic.serverVersion = world.getObjectParameter(ic.eid, "icVersion", 0)
	ic.renameVisible = false
	ic.searchVisible = false
	ic.search = false
	ic.searchDt = 0
	ic.searchCache = {}
	ic.verify = false
	ic.verifyDt = 0
	ic.verifyCount = 0
	--ic.stackOrig = {}
	ic.stackCalc = {}
	ic.configCache = {}
	if ic.serverVersion == ic.clientVersion then
		widget.setButtonEnabled("icRenameButton", true)
	end

	-- same values means it will sort by rarity > name.
	ic.sortValues = {
		-- armor
		headwear = 11,
		headarmour = 11,
		headarmor = 11,
		chestwear = 11,
		chestarmour = 11,
		chestarmor = 11,
		legwear = 11,
		legarmour = 11,
		legarmor = 11,
		backwear = 11,
		enviroprotectionpack = 11,
		shield = 12,

		-- active items
		uniqueweapon = 20,
		assaultrifle = 20,
		boomerang = 20,
		chakram = 20,
		rocketlauncher = 20,
		sniperrifle = 20,
		pistol = 20,
		machinepistol = 20,
		shotgun = 20,
		grenadelauncher = 20,

		broadsword = 22,
		fistweapon = 22,
		axe = 22,
		dagger = 22,
		hammer = 22,
		shortsword = 22,
		spear = 22,
		whip = 22,

		staff = 24,
		wand = 24,

		bow = 26,
		throwableitem = 27,

		tool = 29,
		musicalinstrument = 30,
		toy = 31,

		vehiclecontroller = 35,

		-- objects

		crafting = 40,
		furniture = 40,
		storage = 40,
		fridgestorage = 40,
		decorative = 40,
		door = 40,
		light = 40,
		trophy = 40,
		other = 40, -- outpost stores, ancient con, mannequin, fountain
		teleportmarker = 40,
		actionfigure = 40,

		wire = 46,

		rail = 52,
		railplatform = 52,
		railpoint = 52,

		-- consumable
		mysteriousreward = 90,

		medicine = 95,
		preparedfood = 97,
		drink = 97,
		food = 97,

		shiplicense = 101,
		clothingdye = 105,
		eppaugment = 108,
		petcollar = 110,

		-- tiles / placeable
		block = 140,
		platform = 141,
		liquid = 144,

		sapling = 146,
		seed = 146,

		smallfossil = 150,
		mediumfossil = 150,
		largefossil = 150,

		-- crafting material
		currency = 160,
		["upgrade component"] = 160,
		upgradecomponent = 160,
		craftingmaterial = 160,
		cookingingredient = 162,

		tradingcard = 190,
		quest = 190,
		codex = 191,
		blueprint = 191,

		x = 200, -- item does not have a category

		generic = 300, -- PGI
		junk = 300,
		foodjunk = 300
	}
end

function update(dt)
	if ic.locked > 0 then
		ic.locked = ic.locked - dt
		if ic.locked <= 0 then
			ic.lock(false)
		end
	end
	if ic.verify then
		ic.verifyDt = ic.verifyDt + dt
		if ic.verifyDt > 0.2 then
			ic.verifyCount = ic.verifyCount + 1
			ic.verifyDt = 0
			if ic.verifyCount >= 7 then
				ic.verify = false
				ic.verifyCount = 0
				ic.giveBack()
			else
				ic.checkStack()
			end
		end
	end
	if ic.search then
		ic.searchDt = ic.searchDt + dt
		if ic.searchDt > 2 then
			ic.searchDt = 0
			ic.searchBox()
		end
	end
end

function ic.renameButton(widgetName)
	ic.renameVisible = not ic.renameVisible
	widget.setVisible("icSearchButton", not ic.renameVisible)
	widget.setVisible("icSearchBox", false)
	widget.setVisible("icSearchBoxBg", false)
	widget.setVisible("icRenameBox", ic.renameVisible)
	widget.setVisible("icRenameBoxBg", ic.renameVisible)
	widget.focus( ic.renameVisible and "icRenameBox" or "icRenameButton" )
end

function ic.renameThis(widgetName)
	widget.setVisible("icSearchButton", true)
	ic.renameVisible = false
	widget.setVisible("icRenameBox", false)
	widget.setVisible("icRenameBoxBg", false)
	widget.focus("icRenameButton")
	local newName = widget.getText("icRenameBox")
	if newName then
		world.sendEntityMessage(pane.containerEntityId(), "rename", newName)
	end
	pane.dismiss()
end

function ic.searchButton()
	ic.searchVisible = not ic.searchVisible
	if ic.searchVisible then
		widget.setText("icSearchBox", "")
	end
	widget.setVisible("icSearchBox", ic.searchVisible)
	widget.setVisible("icSearchBoxBg", ic.searchVisible)
	widget.focus( ic.searchVisible and "icSearchBox" or "icSearchButton" )
end

-- search uses different data from stacking so it gets its own function
-- 1000 loop, generated gun
-- root.itemConfig(items.name) -- 3 (generates new values)
-- root.itemConfig(items) -- 2.5
-- root.itemType(items.name) -- 0.001
-- root.itemTags(items.name) -- 0.007
function ic.getSearchData(itemDesc)
	if not itemDesc or type(itemDesc) ~= "table" then
		return
	end
	if not ic.searchCache[ itemDesc.name ] then
		local c = root.itemConfig(itemDesc)
		if not c then
			sb.logWarn("[IC] Failed getting item config for: %s", itemDesc)
			ic.searchCache[ itemDesc.name ] = {}
		else
			-- only cache what we need, those configs are huge!
			ic.searchCache[ itemDesc.name ] = {
					name = itemDesc.name,
					shortdescription = c.config.shortdescription,
					type = root.itemType(itemDesc.name),
					category = c.config.category,
					colonyTags = c.config.colonyTags,
					race = c.config.race,
					tags = root.itemTags(itemDesc.name),
					objectType = c.config.objectType,
			}
		end
	end
	return ic.searchCache[ itemDesc.name ]
end

function ic.searchBox()
	local text = widget.getText("icSearchBox")
	-- reset search
	local maxSlots = 32
	for i=1, maxSlots do
		widget.setVisible("icSearchBorder"..i, false)
	end
	local over = false
	-- new search
	if string.len(text) > 0 then
		text = string.lower(text)
		ic.search = true
		local items = world.containerItems(ic.eid)
		local slots = {}
		for k,v in pairs(items) do
			local match = false
			local sc = ic.getSearchData(v)
			-- matching special tags
			if string.find(text, "^#") then
				if string.len(text) > 2 then
					local text = string.gsub(text, "(#)", "")
					if not match and sc.category and string.find(sc.category, text) then
						match = true
					end
					if not match and sc.type and string.find( sc.type, text) then
						match = true
					end
					if not match and sc.race and string.find( sc.race, text) then
						match = true
					end
					if not match and sc.objectType and string.find( sc.objectType, text) then
						match = true
					end
					if not match and type(sc.tags) == "table" then
						for _,tag in pairs( sc.tags ) do
							if string.find(tag, text) then
								match = true
							end
						end
					end
					if not match and type(sc.colonyTags) == "table" then
						for _,tag in pairs( sc.colonyTags ) do
							if string.find(tag, text) then
								match = true
							end
						end
					end
				end
			-- matching names
			-- matching item name
			elseif (string.find(v.name, text)) then
				match = true
			-- matching full names on generated items
			elseif (v.parameters.shortdescription and string.find(string.lower(v.parameters.shortdescription), text) ~= nil) then
 				match = true
			-- matching full names on non-generated items
			elseif (not v.parameters.shortdescription and sc.shortdescription and string.find(string.lower(sc.shortdescription), text) ~= nil) then
				match = true
			end
			if match then
				table.insert(slots, k)
			end
		end
		local i = 1
		for _,slot in pairs(slots) do
			if i > maxSlots then
				over = true
				break
			end
			local curGrid = nil
			local grids = { "itemGrid", "itemGrid2" }
			local g
			for k,v in pairs(grids) do
				g = config.getParameter("gui."..v)
				local lowest = (g.slotOffset or 0) +1
				local highest = lowest + (g.dimensions[1]*g.dimensions[2]) -1
				if slot >= lowest and slot <= highest then
					curGrid = v
					break
				end
			end
			local o = g.slotOffset or 0
			local s = g.spacing[1]
			local x = g.position[1]
			local y = g.position[2]
			local w = g.dimensions[1]
			local h = g.dimensions[2]
			local hor = x+(((slot-1)%w)*s)
			local row = math.ceil( ((slot-o) / w) )*19
			local ver = (y+(h*s)) - row
			widget.setPosition("icSearchBorder"..i, {hor, ver})
			widget.setVisible("icSearchBorder"..i, true)
			i = i + 1
		end
	else
		ic.search = false
	end
	if over then
		widget.setImage("icSearchBg", "/interface/chests/textboxbg.png?multiply=FF0000FF")
	else
		widget.setImage("icSearchBg", "/interface/chests/textboxbg.png")
	end
end

function ic.amountEquipped(itemDesc, amount)
	local equipped = nil
	if not amount then
		amount = player.hasCountOfItem(itemDesc)
	end
	if amount > 0 then
		equipped = 0
		for _,v in pairs(ic.equipSlots) do
			local compItem = player.equippedItem(v)
			if compItem then
				if compItem.name == itemDesc.name then
					equipped = equipped + 1
				end
			end
		end
		local pHand = player.primaryHandItem()
		local aHand = player.altHandItem()
		if pHand and pHand.name == itemDesc.name then equipped = amount end
		if aHand and aHand.name == itemDesc.name then equipped = amount end
	end
	return equipped
end

function ic.itemAmount(itemDesc)
	local amount = player.hasCountOfItem(itemDesc)
	if amount > 0 then
		local equipped = ic.amountEquipped(itemDesc, amount)
		if equipped and equipped > 0 then
			amount = amount - equipped
		end
	end
	return amount
end

function ic.giveBack()
	local eid = pane.containerEntityId()
	local size = world.containerSize(eid)
	sb.logError("[IC] Failed to match")
	for i=0, size-1 do
		local slotItem = world.containerItemAt(eid, i)
		if ic.stackCalc[i] then
			if not slotItem then
				sb.logWarn("[IC] Item missing, giving: %s", ic.stackCalc[i])
				player.giveItem(ic.stackCalc[i])
			elseif slotItem.count < ic.stackCalc[i].count then
				ic.stackCalc[i].count = ic.stackCalc[i].count - (slotItem.count or 0)
				sb.logWarn("[IC] Item amount mismatch, giving: %s", ic.stackCalc[i])
				player.giveItem(ic.stackCalc[i])
			end
		end
	end
end

function ic.checkStack()
	local eid = pane.containerEntityId()
	local size = world.containerSize(eid)
	local allmatch = true
	for i=0, size-1 do
		local slotItem = world.containerItemAt(eid, i)
		if ic.stackCalc[i] then
			if not slotItem then
				allmatch = false
			elseif slotItem.count < ic.stackCalc[i].count then
				allmatch = false
			else
				 -- match
				ic.stackCalc[i] = nil
			end
		end
	end
	if allmatch then
		ic.verify = false
		ic.verifyCount = 0
	end
end

local function copy(o)
  if o == nil then return nil end
  local no
  if type(o) == 'table' then
    no = {}
    for k, v in next, o, nil do
      no[copy(k)] = copy(v)
    end
  else
    no = o
  end
  return no
end

function ic.itemConfig(itemDesc)
	if not itemDesc or type(itemDesc) ~= "table" then
		return
	end
	if not ic.configCache[ itemDesc.name ] then
		local c = root.itemConfig(itemDesc)
		if not c then
			sb.logWarn("[IC] Failed getting item config for: %s", itemDesc)
			ic.configCache[ itemDesc.name ] = { config = {} }
		else
			-- only cache what we need, those configs are huge!
			ic.configCache[ itemDesc.name ] = {
				config = {
					category = c.config.category,
					slotCount = c.config.slotCount,
					maxStack = c.config.maxStack,
					rarity = c.config.rarity,
					shortdescription = c.config.shortdescription
				}
			}
		end
	end
	return ic.configCache[ itemDesc.name ]
end

function ic.quickstack()
	timer.start()
	if not ic.lock() then
		ic.lock(true)
		local eid = pane.containerEntityId()
		local items = world.containerItems(eid)
		local size = world.containerSize(eid)
		local free = {}
		local calc = {}
		--local orig = {}
		for i=0, size-1 do
			local slotItem = world.containerItemAt(eid, i)
			if not slotItem then
				table.insert(free, i)
			else
				local amount = ic.itemAmount(slotItem)
				local iconf = ic.itemConfig(slotItem)
				--local iconf = root.itemConfig(slotItem)
				local maxStack = (iconf.config.category and iconf.config.category=="Blueprint" and 1) or slotItem.parameters.maxStack or iconf.config.maxStack or ic.defaultMaxStack
				local missing = maxStack - slotItem.count
				if slotItem.name ~= "money" and not iconf.config.slotCount then
					if missing > 0 and amount > 0 then
						--orig[i] = world.containerItemAt(eid, i)
						calc[i] = world.containerItemAt(eid, i)
						local consume = math.min(missing, amount)
						slotItem.count = consume
						local attempt = player.consumeItem(slotItem)
						if attempt and attempt.count == slotItem.count then
							calc[i].count = calc[i].count + consume
							world.containerItemApply(eid, calc[i], i)
						else
							sb.logError("[IC] Unable to consume: %s | %s", amount, slotItem)
						end
					end
				end
			end
		end
		if #free > 0 then
			for k,slotItem in pairs(items) do
				local iconf = ic.itemConfig(slotItem)
				--local iconf = root.itemConfig(slotItem)
				if slotItem.name ~= "money" and not iconf.config.slotCount then
					while #free > 0 and ic.itemAmount(slotItem) > 0 do
						local amount = ic.itemAmount(slotItem)
						local maxStack = (iconf.config.category and iconf.config.category=="Blueprint" and 1) or slotItem.parameters.maxStack or iconf.config.maxStack or ic.defaultMaxStack
						local consume = math.min(amount, maxStack)
						slotItem.count = consume
						local attempt = player.consumeItem(slotItem)
						if attempt and attempt.count == slotItem.count then
							world.containerItemApply(eid, slotItem, free[1])
							calc[free[1]] = slotItem
							table.remove(free, 1)
						else
							sb.logError("[IC] Unable to consume: %s | %s", amount, slotItem)
						end
					end
				end
			end
		end
		--ic.stackOrig = orig
		ic.stackCalc = calc
		ic.verify = true
	end
	timer.stop("Stack")
end

function ic.lock(arg)
	local eid = pane.containerEntityId()
	if arg == nil then
		local locked = world.getObjectParameter(eid, "icLocked")
		if locked and locked > 0 then
			ic.locked = locked
			for k,v in pairs(ic.buttons) do
				widget.setButtonEnabled(v, false)
			end
		end
		return (locked and locked > 0) and true or false
	elseif arg == true then
		ic.locked = 1.5
		world.sendEntityMessage(eid, "lock")
		for k,v in pairs(ic.buttons) do
			widget.setButtonEnabled(v, false)
		end
	elseif arg == false then
		ic.locked = 0
		for k,v in pairs(ic.buttons) do
			widget.setButtonEnabled(v, true)
		end
	end
end

function ic.stripColor(textString)
	if textString then
		return string.gsub(textString, "(^[#a-zA-Z0-9]+;)", "")
	end
	return nil
end

function ic.getQuality(rarity)
	local quality = { common=1, uncommon=2, rare=3, legendary=4, essential=5 }
	if rarity and quality[rarity] then
		return quality[rarity]
	end
	return 0
end

function ic.sortFunc(a,b)
	if a.sort1 ~= b.sort1 then
		return a.sort1 < b.sort1
	-- elseif a.parameters.timeToRot and b.parameters.timeToRot and a.parameters.timeToRot ~= b.parameters.timeToRot then
	-- 	return a.parameters.timeToRot < b.parameters.timeToRot
	elseif ic.getQuality(a.parameters.rarity) ~= ic.getQuality(b.parameters.rarity) then
		return ic.getQuality(a.parameters.rarity) > ic.getQuality(b.parameters.rarity)
	elseif a.parameters.shortdescription == b.parameters.shortdescription then
 		return a.count > b.count
 	end
	return a.parameters.shortdescription < b.parameters.shortdescription
end

function ic.sort_relative(ref, t, cmp)
    local n = #ref
    assert(#t == n)
    local r = {}
    for i=1,n do r[i] = i end
    if not cmp then cmp = function(a, b) return a < b end end
    table.sort(r, function(a, b) return cmp(ref[a], ref[b]) end)
    for i=1,n do r[i] = t[r[i]] end
    return r
end

function ic.sort(widgetName)
	timer.start()
	if not ic.lock() then
		ic.lock(true)
		local eid = pane.containerEntityId()
		local check = world.containerItems(eid)
		if type(check)=="table" and next(check) then
			local items = {}
			local sortBy = {}
			for i=0, world.containerSize(eid)-1 do
				local slotItem = world.containerItemAt(eid, i)
				if slotItem then

					table.insert(items, slotItem)
					-- make a fake sortItem so we don't change any parameters
					local sortItem = { count=slotItem.count, parameters={} }
					--local iconf = root.itemConfig(slotItem)
					local iconf = ic.itemConfig(slotItem)
					if not iconf then iconf = { config = {} } end
					sortItem.parameters.shortdescription = slotItem.parameters.shortdescription or iconf.config.shortdescription or "x"
					sortItem.parameters.shortdescription = ic.stripColor(sortItem.parameters.shortdescription)
					sortItem.parameters.category = (slotItem.parameters.category and string.lower(slotItem.parameters.category)) or (iconf.config.category and string.lower(iconf.config.category)) or "x"
					sortItem.parameters.rarity = (slotItem.parameters.rarity and string.lower(slotItem.parameters.rarity)) or (iconf.config.rarity and string.lower(iconf.config.rarity)) or "common"
					sortItem.sort1 = ic.sortValues[sortItem.parameters.category] or 200
					sortItem.parameters.timeToRot = slotItem.parameters.timeToRot
					if not ic.sortValues[sortItem.parameters.category] then
						sb.logWarn("[IC] No sort value for: %s", sortItem.parameters.category)
					end
					table.insert(sortBy, sortItem)
				end
			end
			if #items > 0 then
				items = ic.sort_relative(sortBy, items, ic.sortFunc)
				world.containerTakeAll(eid)
				for _,itemDesc in ipairs(items) do
					world.containerAddItems(eid, itemDesc)
				end
			end
		end
	end
	timer.stop("Sort")
end
