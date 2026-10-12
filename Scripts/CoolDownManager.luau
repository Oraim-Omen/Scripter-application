local RunService = game:GetService("RunService") -- Used to check server or client.
local debris = game:GetService("Debris") -- Used to remove sounds later.
local replicatedstorage = game:GetService("ReplicatedStorage") -- Where the events are.

local emitsound = replicatedstorage:WaitForChild("events"):WaitForChild("EmitSound") -- Event for one-shot sounds.
local loopsoundevent = replicatedstorage:WaitForChild("events"):WaitForChild("LoopSound") -- Event for looping sounds.

local sound = {} -- Table other scripts will use.

-- Randomizes the pitch of a sound.
local function soundspeed(soundobj)
	local base = soundobj:GetAttribute("BaseSpeed") -- Get the saved original speed.
	if not base then -- If no speed was saved yet...
		base = soundobj.PlaybackSpeed -- Use the current speed.
		soundobj:SetAttribute("BaseSpeed", base) -- Save it for next time.
	end

	local randompitch = math.random(9, 11) / 10 -- Random value from 0.9 to 1.1.
	soundobj.PlaybackSpeed = base * randompitch -- Apply the new speed.
end

-- Plays a sound from a part, or from workspace if no part is given.
function sound.play(name, part, loop)
	if not name then return end -- Stop if there is no sound.
	local soundobj = name:Clone() -- Clone so it can play multiple times at once.
	if not part then
		soundobj.Parent = workspace -- No part, play from workspace.
	else
		soundobj.Parent = part -- Play from the part.
	end
	soundspeed(soundobj) -- Randomize the pitch.
	if not soundobj.IsLoaded then -- If the sound isn't loaded yet...
		soundobj.Loaded:Wait() -- Wait for it to load.
	end
	soundobj:Play() -- Play the sound.
	if loop then return end -- Looping sounds are not deleted.
	debris:AddItem(soundobj, soundobj.TimeLength / soundobj.PlaybackSpeed) -- Delete it when it finishes.
end

-- Stops a looping sound on a part.
function sound.stoploop(name, part)
	local soundobj = part:FindFirstChild(name) -- Find the sound in the part.
	debris:AddItem(soundobj, 0) -- Remove it right away.
end

-- Starts or stops a looping sound for everyone.
function sound.loopserver(name, part, loop)
	if not name then return end -- Stop if there is no sound.
	if not loop then
		sound.stoploop(name, part) -- Stop the loop on this client.
	end
	loopsoundevent:FireServer(name, part, loop) -- Tell the server.
end

-- Plays a one-shot sound for everyone.
function sound.EmitServer(name, part, loop)
	if not name then return end -- Stop if there is no sound.
	emitsound:FireServer(name, part, loop) -- Tell the server.
end

if RunService:IsServer() then -- If this is the server...
	emitsound.OnServerEvent:Connect(function(_, name, part, loop)
		emitsound:FireAllClients(name, part, loop) -- Tell every client to play the sound.
	end)
else
	emitsound.OnClientEvent:Connect(sound.play) -- Client plays the sound.
end

if RunService:IsServer() then -- If this is the server...
	loopsoundevent.OnServerEvent:Connect(function(_, name, part, loop)
		if not loop then return end -- Only pass on loops that are starting.
		loopsoundevent:FireAllClients(name, part, loop) -- Tell every client to loop the sound.
	end)
else
	loopsoundevent.OnClientEvent:Connect(sound.play) -- Client plays the looping sound.
end

return sound -- Give the table to whoever requires this script.
