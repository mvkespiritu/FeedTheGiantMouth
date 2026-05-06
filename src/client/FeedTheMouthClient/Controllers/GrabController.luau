--!strict

local Players = game:GetService("Players")

local GrabController = {}
GrabController.Name = "GrabController"

local BASE_THROW_SPEED = 93.75
local THROW_POWER_PER_LEVEL = 12.5
local THROW_UPWARD_SPEED = 50
local STRENGTH_WEIGHT_REDUCTION_PER_LEVEL = 6
local THROW_WEIGHT_PENALTY_PER_UNIT = 0.015
local MIN_THROW_SPEED_MULTIPLIER = 0.55
local HOLD_WELD_NAME = "FeedTheMouthHoldWeld"

function GrabController:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.LocalPlayer = Players.LocalPlayer
	self.RequestGrabRemote = context.remotes:WaitForChild("RequestGrab")
	self.RequestReleaseRemote = context.remotes:WaitForChild("RequestRelease")
	self.RequestThrowRemote = context.remotes:WaitForChild("RequestThrow")
end

function GrabController:Start() end

function GrabController:RequestGrab(feedable: Instance)
	self.RequestGrabRemote:FireServer(feedable)
end

function GrabController:RequestRelease()
	self.RequestReleaseRemote:FireServer()
end

function GrabController:FindFeedableFromInstance(instance: Instance): Instance?
	local current: Instance? = instance
	while current ~= nil and current.Parent ~= nil do
		if current:GetAttribute(self.Constants.ATTRIBUTES.Feedable) == true then
			return current
		end

		current = current.Parent
	end

	return nil
end

function GrabController:GetHeldRootPartAndWeld(): (BasePart?, WeldConstraint?)
	local character = self.LocalPlayer.Character
	if character == nil then
		return nil, nil
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart == nil or not humanoidRootPart:IsA("BasePart") then
		return nil, nil
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("WeldConstraint") and descendant.Name == HOLD_WELD_NAME then
			local part0 = descendant.Part0
			local part1 = descendant.Part1
			if part0 == humanoidRootPart and part1 ~= nil and part1:IsA("BasePart") then
				return part1, descendant
			end
		end
	end

	return nil, nil
end

function GrabController:GetPredictedThrowSpeed(feedable: Instance?): number
	local throwPowerLevel = 1
	local strengthLevel = 1
	local uiController = self.Context.controllers.UIController
	local data = if uiController ~= nil then uiController.CurrentPlayerData else nil
	if typeof(data) == "table" and typeof(data.Upgrades) == "table" then
		if typeof(data.Upgrades.ThrowPower) == "number" then
			throwPowerLevel = data.Upgrades.ThrowPower
		end

		if typeof(data.Upgrades.Strength) == "number" then
			strengthLevel = data.Upgrades.Strength
		end
	end

	local heldWeight = 1
	if feedable ~= nil then
		local weight = feedable:GetAttribute(self.Constants.ATTRIBUTES.Weight)
		if typeof(weight) == "number" then
			heldWeight = math.max(0, weight)
		end
	end

	local speed = BASE_THROW_SPEED + ((throwPowerLevel - 1) * THROW_POWER_PER_LEVEL)
	local strengthReduction = math.max(0, strengthLevel - 1) * STRENGTH_WEIGHT_REDUCTION_PER_LEVEL
	local effectiveWeight = math.max(0, heldWeight - strengthReduction)
	local throwMultiplier = math.clamp(1 - (effectiveWeight * THROW_WEIGHT_PENALTY_PER_UNIT), MIN_THROW_SPEED_MULTIPLIER, 1)
	return speed * throwMultiplier
end

function GrabController:PredictLocalThrow(direction: Vector3)
	local rootPart, holdWeld = self:GetHeldRootPartAndWeld()
	if rootPart == nil then
		return
	end

	if holdWeld ~= nil and holdWeld.Parent ~= nil then
		holdWeld:Destroy()
	end

	local feedable = self:FindFeedableFromInstance(rootPart)
	local speed = self:GetPredictedThrowSpeed(feedable)
	rootPart.AssemblyLinearVelocity = (direction.Unit * speed) + Vector3.new(0, THROW_UPWARD_SPEED, 0)
end

function GrabController:RequestThrow(direction: Vector3)
	if direction.Magnitude > 0.05 then
		self:PredictLocalThrow(direction)
	end

	self.RequestThrowRemote:FireServer(direction)
end

return GrabController
