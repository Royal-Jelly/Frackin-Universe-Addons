require "/scripts/kheAA/transferUtil.lua"
local deltaTime=1

function init()
	transferUtil.init()
	storage.receiveItems=true
	inDataNode=0
	outDataNode=0
end

function update(dt)
	if deltaTime > 1 then
		deltaTime=0
		transferUtil.loadSelfContainer()
	else
		deltaTime=deltaTime+dt
	end
end
