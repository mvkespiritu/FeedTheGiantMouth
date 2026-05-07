--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local InputController = {}
InputController.Name = "InputController"

local TOUCH_TAP_MAX_MOVEMENT = 18
local TOUCH_TAP_MAX_DURATION = 0.75

function InputController:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.LocalPlayer = Players.LocalPlayer
	self.LastGrabRequest = 0
	self.ActiveTouches = {}
end

function InputController:Start()
	local mouse = self.LocalPlayer:GetMouse()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.E then
			self:HandlePrimaryAction(mouse.Target)
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:HandlePrimaryAction(mouse.Target)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			self:TrackTouchStart(input)
		end
	end)

	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:TrackTouchMove(input, gameProcessed)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:TrackTouchEnd(input)
		end
	end)
end

function InputController:TrackTouchStart(input: InputObject)
	self.ActiveTouches[input] = {
		startPosition = input.Position,
		lastPosition = input.Position,
		startTime = os.clock(),
		moved = false,
	}
end

function InputController:TrackTouchMove(input: InputObject, gameProcessed: boolean)
	local touch = self.ActiveTouches[input]
	if touch == nil then
		return
	end

	touch.lastPosition = input.Position
	if gameProcessed or (input.Position - touch.startPosition).Magnitude > TOUCH_TAP_MAX_MOVEMENT then
		touch.moved = true
	end
end

function InputController:TrackTouchEnd(input: InputObject)
	local touch = self.ActiveTouches[input]
	self.ActiveTouches[input] = nil

	if touch == nil then
		return
	end

	if touch.moved then
		return
	end

	if os.clock() - touch.startTime > TOUCH_TAP_MAX_DURATION then
		return
	end

	self:HandlePrimaryActionFromScreenPosition(touch.lastPosition)
end

function InputController:ClearActiveTouches()
	for input in pairs(self.ActiveTouches) do
		self.ActiveTouches[input] = nil
	end
end

function InputController:HandlePrimaryActionFromScreenPosition(screenPosition: Vector3)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
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
	self:QueueMarkerRefresh()
end

function InputController:RequestThrow()
	local character = self.LocalPlayer.Character
	local humanoidRootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local direction = if humanoidRootPart ~= nil and humanoidRootPart:IsA("BasePart")
		then humanoidRootPart.CFrame.LookVector
		else Vector3.new(0, 0, -1)
	self.Context.controllers.GrabController:RequestThrow(direction)
	self:QueueMarkerRefresh()
end

function InputController:QueueMarkerRefresh()
	local lockedObjectController = self.Context.controllers.LockedObjectController
	if lockedObjectController ~= nil then
		lockedObjectController:QueueRefresh()
	end
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
