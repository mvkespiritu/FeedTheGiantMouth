--!strict

local UserInputService = game:GetService("UserInputService")

local InputController = {}
InputController.Name = "InputController"

function InputController:Init(context)
	self.Context = context
end

function InputController:Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.E then
			-- Grab targeting will be wired once feedable selection is implemented.
		end
	end)
end

return InputController
