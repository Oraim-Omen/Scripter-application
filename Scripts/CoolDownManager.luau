local CooldownManager = {}

local ABILITIES = {
	Dash 		= {maxCharges = 2, rechargeTime = 4 },
	DashInterrupt	= {maxCharges = 1, rechargeTime = 3 },
    Hang = {maxCharges = 1, rechargeTime = 0.1}, -- prevents spamming of hanging
	WallKick = { maxCharges = 3, rechargeTime = 5},
}

local charges = {} -- table to hold the current charges for each ability

local function getCharges(name) -- retrieves the current charges for a specific ability
	if charges[name] == nil then -- a check if the ablitiy exists in the charges table
		charges[name] = ABILITIES[name].maxCharges -- gets the max charges the ablity
	end
	return charges[name] -- return the current charges for the ability
end

function CooldownManager:Use(name)
	charges[name] -= 1 -- reduce the current charges for the ability by 1
	local ability = ABILITIES[name]

	task.delay(ability.rechargeTime, function() -- delay the recharge of the ability
		charges[name] = math.min(ability.maxCharges, charges[name] + 1) -- increase the current charges for the ability by 1, but not exceeding the max charges
	end)
end

function CooldownManager:CanUse(name) 
	if getCharges(name) > 0 then -- check if there are any charges available for the ability
		self:Use(name) -- use the ability if there are charges available
		return true -- return true to indicate that the ability can be used
	end
	return false -- return false to indicate that the ability cannot be used
end

function CooldownManager:ResetCharges(name) 
	local ability = ABILITIES[name]
	if ability then -- check if the ability exists in the ABILITIES table
		charges[name] = ability.maxCharges -- reset the current charges for the ability to its max charges
	end
end

return CooldownManager -- return the CooldownManager module so it can be used by other scripts