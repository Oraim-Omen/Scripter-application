local UserInputService = game:GetService("UserInputService")

local Inputs = {}

local actions = {
	Catch = {Enum.KeyCode.F, Enum.KeyCode.ButtonX},
	CancelCharge = {Enum.KeyCode.V, Enum.KeyCode.DPadUp},
	TogglePass = {Enum.KeyCode.R, Enum.KeyCode.ButtonL2},
	Dash = {Enum.KeyCode.Q, Enum.KeyCode.ButtonB},
	Run = {Enum.KeyCode.Q, Enum.KeyCode.ButtonB},
	Crouch = {Enum.KeyCode.C, Enum.KeyCode.ButtonL3}, -- also slide and knee tuck
	Jump = {Enum.KeyCode.Space, Enum.KeyCode.ButtonA}, -- also ledge grab and wall kick
}

-- keeps track of every button that is currently being held
local held = {}
UserInputService.InputBegan:Connect(function(input)
	held[input.KeyCode] = true
end)
UserInputService.InputEnded:Connect(function(input)
	held[input.KeyCode] = false
end)

function Inputs.Is(input, actionName)
	local list = actions[actionName]
	return table.find(list, input.KeyCode) or table.find(list, input.UserInputType)
end

-- true while any button of the action is being held
function Inputs.IsDown(actionName)
	for _, key in actions[actionName] do
		if held[key] then
			return true
		end
	end
	return false
end

return Inputs