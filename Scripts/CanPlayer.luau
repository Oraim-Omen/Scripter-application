-- to sum up this module is to check if a player can do an action 
--based on their current state and cooldowns
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playerstats = require(ReplicatedStorage.Scripts.PlayerStats)
local cooldownmanger = require(ReplicatedStorage.Scripts.CoolDownManager)

local CanPlayer = {} -- ta

function CanPlayer.CanDash(plr) -- a check to see if the player can dash it is on the name
	if playerstats.GetState(plr, "Dashing") then return false end -- blow it is list of the things of the states that returns false
	if playerstats.GetState(plr, "Vaulting") then return false end
    if playerstats.GetState(plr, "Sliding") then return false end
    if playerstats.GetState(plr, "Unbalance") then return false end
    if playerstats.GetState(plr, "StanceTaken") then return false end
    if playerstats.GetState(plr, "Catching") then return false end
    if playerstats.GetState(plr, "Hanging") then return false end
    if playerstats.GetState(plr, "WallKicking") then return false end
    if playerstats.GetState(plr, "Bumbed") then return false end
	return cooldownmanger:CanUse("Dash") -- is a check for ablities  that have cooldown and use it,
end

function CanPlayer.CanDashInterrupt(plr)
	if playerstats.GetState(plr, "Vaulting") then return false end
    if playerstats.GetState(plr, "Sliding") then return false end
    if playerstats.GetState(plr, "Unbalance") then return false end
    if playerstats.GetState(plr, "StanceTaken") then return false end
    if playerstats.GetState(plr, "Catching") then return false end
    if playerstats.GetState(plr, "Hanging") then return false end
    if playerstats.GetState(plr, "WallKicking") then return false end
    if playerstats.GetState(plr, "Bumbed") then return false end
	return cooldownmanger:CanUse("DashInterrupt")
end

function CanPlayer.CanCatch(plr)
	if playerstats.GetState(plr, "Dashing") then return false end
	if playerstats.GetState(plr, "Sliding") then return false end
    if playerstats.GetState(plr, "Vaulting") then return false end
    if playerstats.GetState(plr, "Unbalance") then return false end
    if playerstats.GetState(plr, "StanceTaken") then return false end
    if playerstats.GetState(plr, "Catching") then return false end
    if playerstats.GetState(plr, "Bumbed") then return false end 
	return true
end

function CanPlayer.CanVault(plr)
    if playerstats.GetState(plr, "Dashing") then return false end
    if playerstats.GetState(plr, "Sliding") then return false end
    if playerstats.GetState(plr, "Vaulting") then return false end
    if playerstats.GetState(plr, "Catching") then return false end
    if playerstats.GetState(plr, "StanceTaken") then return false end
    if playerstats.GetState(plr, "Unbalance") then return false end
    if playerstats.GetState(plr, "Bumbed") then return false end 
    return true
end
function CanPlayer.CanSlide(plr)
	if playerstats.GetState(plr, "Sliding") then return false end
	if playerstats.GetState(plr, "Dashing") then return false end
	if playerstats.GetState(plr, "Vaulting") then return false end
    if playerstats.GetState(plr, "Catching") then return false end
    if playerstats.GetState(plr, "StanceTaken") then return false end
    if playerstats.GetState(plr, "Unbalance") then return false end
    if playerstats.GetState(plr, "Bumbed") then return false end     
	return true
end

function CanPlayer.CanHang(plr)
    if playerstats.GetState(plr, "Dashing") then return false end
    if playerstats.GetState(plr, "Sliding") then return false end
    if playerstats.GetState(plr, "Vaulting") then return false end
    if playerstats.GetState(plr, "Catching") then return false end
    if playerstats.GetState(plr, "StanceTaken") then return false end
    if playerstats.GetState(plr, "Unbalance") then return false end
    if playerstats.GetState(plr, "Bumbed") then return false end     
    if playerstats.GetState(plr, "Hanging") then return false end
    return cooldownmanger:CanUse("Hang")
end

function CanPlayer.CanWallKick(plr)
    if playerstats.GetState(plr, "Dashing") then return false end
    if playerstats.GetState(plr, "Sliding") then return false end
    if playerstats.GetState(plr, "Vaulting") then return false end
    if playerstats.GetState(plr, "Catching") then return false end
    if playerstats.GetState(plr, "StanceTaken") then return false end
    if playerstats.GetState(plr, "Unbalance") then return false end
    if playerstats.GetState(plr, "Hanging") then return false end
    if playerstats.GetState(plr, "Bumbed") then return false end     
    return cooldownmanger:CanUse("WallKick")
end

function CanPlayer.CanThrow(plr)
    if playerstats.GetState(plr, "Dashing") then return false end
    if playerstats.GetState(plr, "Sliding") then return false end
    if playerstats.GetState(plr, "Vaulting") then return false end
    if playerstats.GetState(plr, "Catching") then return false end
    if playerstats.GetState(plr, "StanceTaken") then return false end
    if playerstats.GetState(plr, "Unbalance") then return false end
    if playerstats.GetState(plr, "Hanging") then return false end
    if playerstats.GetState(plr, "Bumbed") then return false end     
    return true
end

return CanPlayer