local playerstats = {} -- Table other scripts will use.
local states = {} -- Holds the states for each player.

-- Returns all of a player's states.
function playerstats.ReturnStates(plr)
	return states[plr] -- Nil if the player has none.
end

-- Returns one state from a player.
function playerstats.GetState(plr, statekey)
	if states[plr] then -- If the player has states...
		return states[plr][statekey] -- Return the one asked for.
	end
	return nil -- No states, return nil.
end

-- Sets a state on a player, and removes it after a duration if one is given.
function playerstats.SetState(plr, statekey, value, duration)
	if not states[plr] then -- If the player has no table yet...
		states[plr] = {} -- Create one.
	end
	states[plr][statekey] = value -- Set the state.
	if duration and type(duration) == "number" then -- If a duration was given...
		task.delay(duration, function() -- Wait, then remove the state.
			if states[plr] and states[plr][statekey] == value then -- Make sure it still exists and wasn't changed.
				states[plr][statekey] = nil -- Remove the state.
				if next(states[plr]) == nil then -- If the player has no states left...
					states[plr] = nil -- Remove their table.
				end
			end
		end)
	end
end

-- Removes one state from a player, or all of them if no key is given.
function playerstats.RemoveStats(plr, statekey)
	if not states[plr] then return end -- Stop if the player has no states.
	if statekey then -- If a key was given...
		states[plr][statekey] = nil -- Remove that state.
		if next(states[plr]) == nil then -- If the player has no states left...
			states[plr] = nil -- Remove their table.
		end
	else
		states[plr] = nil -- No key, remove everything.
	end
end

-- Full reset for bugs, does nearly the same as RemoveStats.
function playerstats.ClearAllStats(plr)
	if states[plr] then -- If the player has states...
		for statekey in pairs(states[plr]) do -- Go through every state.
			plr:SetAttribute(statekey, nil) -- Clear the attribute with the same name.
		end
	end
	states[plr] = nil -- Remove the player's table.
end

game.Players.PlayerRemoving:Connect(function(plr)
	states[plr] = nil -- Clear their states when they leave.
end)

return playerstats -- Give the table to whoever requires this script.
