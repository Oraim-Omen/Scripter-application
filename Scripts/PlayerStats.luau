local playerstats = {} -- module table to hold the functions and data for player stats
local states = {} -- table to hold the states for each player

function playerstats.ReturnStates(plr)
	return states[plr] -- returns the table of states for the player, or nil if no states exist
end

function playerstats.GetState(plr, statekey)
	if states[plr] then -- check if the player has any states	
		return states[plr][statekey] -- return the value of the specific statekey
	end
	return nil -- return nil if the player has no states
end

function playerstats.SetState(plr, statekey, value, duration)
	if not states[plr] then -- check if the player is in the states table, if not create a new table for them
		states[plr] = {} -- create a new table for the player to hold their states
	end
	states[plr][statekey] = value -- set the value of the specific statekey for the player
	if duration and type(duration) == "number" then -- check if a duration is provided and is a number
		task.delay(duration, function() -- delays the next funaction for removing the state
			if states[plr] and states[plr][statekey] == value then -- A check to prevent an error
				states[plr][statekey] = nil -- remove the statekey from the player's states table
				if next(states[plr]) == nil then -- check if the player's states table is empty
					states[plr] = nil -- remove the player's states table if it's empty
				end
			end
		end)
	end
end

function playerstats.RemoveStats(plr, statekey)
	if not states[plr] then return end -- check if the player has any states, if not return
	if statekey then  -- check if a statekey is provided
		states[plr][statekey] = nil -- remove the specific statekey from the player's states table
		if next(states[plr]) == nil then -- check if the player's states table is empty
			states[plr] = nil -- remove the player's states table if it's empty
		end
	else
		states[plr] = nil -- remove the player's states table if no statekey is provided
	end
end
-- this is meant is a true reset for bugs ... reading back  i don't know why i writen 2 funactions doing nearly identical things
function playerstats.ClearAllStats(plr)
	if states[plr] then -- check if the player has any states
		for statekey in pairs(states[plr]) do -- a loop to iterate through all the statekeys for the player
			plr:SetAttribute(statekey, nil) -- remove the attribute for the statekey from the player
		end
	end
	states[plr] = nil -- remove the player's states table from the states table
end

game.Players.PlayerRemoving:Connect(function(plr)
	states[plr] = nil -- clear the states for the player when they leave the game (avoids memory leaks)
end)

return playerstats -- return the playerstats module so it can return values to other scripts that require it
