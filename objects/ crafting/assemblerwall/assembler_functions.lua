function scancontainer(x,y)			-- In Vec2 format
	local containerlist = {}
	local nearestcontainer = world.objectQuery(x, y, {order = "nearest"})
	for i,obj in pairs(nearestcontainer) do
		if obj ~= nil and obj ~= entity.id() and world.containerSize(obj) ~= nil then
			table.insert(containerlist, obj)
		end
	end
	return containerlist
end

function duplicate_table (source)
	local temp = {}
	for k,v in pairs(source) do
		temp[k] = v
	end
	return temp
end

function clear_table (source)
	if source ~= nil and #source > 0 then
		for i = 0, #source do source[i] = nil end
	end
end

-- Parameters: Containers(Table of Entity IDs), Item name(String); Return item count (number)
function containers_count_item (containers, item_name)
	local item_count = 0
	-- sb.logInfo("Calling containers_count_item, Parameters: %s, %s", containers, item_name)
	for i,container in ipairs(containers) do
		if world.containerSize(container) ~= nil then
			local items = world.containerItems(container)
			if items ~= nil and #items > 0 then
				for slot,item in pairs(items) do
					-- sb.logInfo("...Item: %s count: %s",item.name, item.count)
					if item_name == item.name then
						item_count = item_count + item.count
						-- sb.logInfo("...Counting: %s",item, container)
					end
				end
			end
		end
	end
	
	return item_count
end

-- Parameters: Containers(Table of Entity IDs), Items(Table of ItemDescriptors) --
function containers_consume_items (containers, items)
	if items ~= nil and #items > 0 then
		for i,item in ipairs(items) do
			-- sb.logInfo("Taking item: %s x %s", item.name, item.count)
			local leftover = duplicate_table(item)
			if containers ~= nil and #containers > 0 then
				for j,container in ipairs(containers) do
					if world.containerSize(container) ~= nil then
						-- sb.logInfo("...From ID: %s", container)
						local contains = duplicate_table(leftover)
						contains.count = containers_count_item ({container}, leftover.name)
						-- sb.logInfo("...Amount: %s", contains.count)
						if leftover.count > contains.count then
							world.containerConsume(container, contains)
							leftover.count = leftover.count - contains.count
						else
							world.containerConsume(container, leftover)
							break
						end
					end
				end
			end
		end
	end
end

-- Parameters: Containers(Table of Entity IDs), Items(Table of ItemDescriptors); Return leftover items (Table of ItemDescriptors) --
function containers_add_items (containers, items)		
	local overflow = {}
	if items ~= nil and #items > 0 then
		for i,item in ipairs(items) do
			-- sb.logInfo("Adding item: %s x %s", item.name, item.count)
			local leftover = duplicate_table(item)
			for i,container in ipairs(containers) do
				if world.containerSize(container) ~= nil then
					if leftover ~= nil and leftover.count > 0 then
						if world.containerSize(container) ~= nil then
							leftover = world.containerAddItems(container, leftover)
						end
					end
				end
			end
			if leftover ~= nil and leftover.count > 0 then
				overflow[#overflow + 1] = leftover
			end
		end
	end
	
	if #overflow > 0 then
		return overflow
	else
		return nil
	end
end
-- Parameters: Samples(Table of ItemDescriptors), Input_containers(Table of Entity IDs), Output_containers(Table of Entity IDs), Craft_missing_ingredients (Bool)
function craft_items (...)
	local stat = "none"
	local entity_self = nil
	local samples, input_containers, output_containers, craft_missing_ingredients = ... 
	
	if samples == nil or #samples <= 0 then samples = {world.containerItemAt(entity.id(), 0)} end
	if input_containers == nil or #input_containers <= 0 then input_containers = {entity.id()} end
	if output_containers == nil or #output_containers <= 0 then output_containers = {entity.id()} end
	if craft_missing_ingredients == nil then craft_missing_ingredients = false end
	
	-- sb.logInfo("Calling function: craft_items, Parameters: %s ; %s ; %s ; %s", samples, input_containers, output_containers, craft_missing_ingredients)
	
	if samples ~= nil and #samples > 0 then
		for i,sample in ipairs(samples) do
			local recipes = root.recipesForItem(sample.name)
			if recipes ~= nil and #recipes > 0 then
				for i,recipe in ipairs(recipes) do
					if stat == "succeed" then
						break
					elseif recipe ~= nil and #recipe.input == 1 and recipe.input[1].name == "money" then
						stat = "skip"
					else
						stat = "none"
					end
					
					if recipe ~= nil and #recipe.input > 0 and stat ~= "skip" then
						local table_available = {}
						local table_missing = {}
						::redo::
						
						-- sb.logInfo("Current recipe: %s", recipe)
						
						clear_table (table_missing)
						
						for i,item in ipairs(recipe.input) do
							-- sb.logInfo("Searching item: %s ...", item.name)
							local count_available = 0
							if input_containers ~= nil and #input_containers > 0 then
								for i,container in ipairs(input_containers) do
									-- sb.logInfo("...In object id: %s", container)
									count_available = count_available + containers_count_item ({container}, item.name)
								end
							else
								-- sb.logInfo("...No Available Object.")
								break
							end
							
							-- sb.logInfo("Total available item: %s", count_available)
							
							if item.count > 0 and count_available < item.count then
								local temp_item = duplicate_table(item)
								temp_item.count = item.count - count_available
								table_missing[#table_missing+1] = temp_item
							end
						end
						
						-- sb.logInfo("Missing: %s",table_missing)
						
						if #table_missing > 0 then
							if craft_missing_ingredients == true then
								-- sb.logInfo("Crafting missing ingredients...")
								craft_items (table_missing, input_containers, output_containers, craft_missing_ingredients)
								craft_missing_ingredients = false
								-- sb.logInfo("Redo recipe...")
								goto redo
							end
						else
							-- sb.logInfo("Beginning crafting sequence...")
							if recipe.output ~= nil and recipe.output.count > 0 then
								local overflow = duplicate_table(recipe.output)
								-- sb.logInfo("Checking overflow stat...", overflow)
								for i, container in ipairs(output_containers) do
									-- sb.logInfo("In container: %s", container)
									if overflow.count <= 0 then
										-- sb.logInfo("No overflow", overflow)
										break
									elseif world.containerSize(container) ~= nil then
										overflow.count = world.containerItemsFitWhere(container, overflow).leftover
										-- sb.logInfo("Overflow: %s", overflow)
									end
								end
								
								if overflow.count > 0 then
									stat = "overflow"
								end
								
								if stat ~= "overflow" then
									containers_consume_items (input_containers, recipe.input)
									containers_add_items(output_containers, {recipe.output})
									stat = "succeed"
								end
							end
						end
					end
				end
			end
		end
	end
end