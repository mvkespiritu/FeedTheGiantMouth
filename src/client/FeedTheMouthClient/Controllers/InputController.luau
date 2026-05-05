--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local InputController = {}
InputController.Name = "InputController"

function InputController:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.LocalPlayer = Players.LocalPlayer
	self.LastGrabRequest = 0
end

function InputController:Start()
	local mouse = self.LocalPlayer:GetMouse()
	mouse.Button1Down:Connect(function()
		self:HandlePrimaryAction(mouse.Target)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.E then
			self:HandlePrimaryAction(mouse.Target)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			self:HandlePrimaryActionFromScreenPosition(input.Position)
		end
	end)
end

function InputController:HandlePrimaryActionFromScreenPosition(screenPosition: Vector3)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local character = self.LocalPlayer.Character
	if character ~= nil then
		raycastParams.FilterDescendantsInstances = { character }
	end

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
	if result ~= nil then
		self:HandlePrimaryAction(result.Instance)
	else
		self:RequestThrow()
	end
end

function InputController:HandlePrimaryAction(instance: Instance?)
	local now = os.clock()
	if now - self.LastGrabRequest < 0.15 then
		return
	end

	self.LastGrabRequest = now

	if instance == nil then
		self:RequestThrow()
		return
	end

	local feedable = self:FindFeedable(instance)
	if feedable == nil then
		self:RequestThrow()
		return
	end

	self.Context.controllers.GrabController:RequestGrab(feedable)
end

function InputController:RequestThrow()
	local camera = Workspace.CurrentCamera
	local direction = if camera ~= nil then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
	self.Context.controllers.GrabController:RequestThrow(direction)
end

function InputController:FindFeedable(instance: Instance): Instance?
	local attributes = self.Constants.ATTRIBUTES
	local current: Instance? = instance
	local candidate: Instance? = nil

	while current ~= nil and current ~= Workspace do
		if current:GetAttribute(attributes.Feedable) == true then
			candidate = current
		end

		current = current.Parent
	end

	return candidate
end

return InputController
