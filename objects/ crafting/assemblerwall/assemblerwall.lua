require "/scripts/kheAA/transferUtil.lua"
local deltaTime=1

function init()
	transferUtil.init()
	storage.receiveItems=true
	inDataNode=0
	outDataNode=0

	timer = 60
	tic = 60
end

function update(dt)
	if tic == 0 then
		craft_items ({world.containerItemAt(entity.id(), 0)},{entity.id()},{entity.id()},true)
		tic = timer
	else
		tic = tic - 1
	end
	if deltaTime > 1 then
		deltaTime=0
		transferUtil.loadSelfContainer()
	else
		deltaTime=deltaTime+dt
	end
end
