--!strict

local Players = game:GetService("Players")

local GrabService = {}
GrabService.Name = "GrabService"

local HOLD_DISTANCE = 6
local MAX_GRAB_DISTANCE = 24
local INTERNAL_WELD_NAME = "FeedTheMouthInternalWeld"
local HOLD_WELD_NAME = "FeedTheMouthHoldWeld"

function GrabService:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.RequestGrabRemote = context.remotes:WaitForChild("RequestGrab")
	self.RequestReleaseRemote = context.remotes:WaitForChild("RequestRelease")
	self.RequestThrowRemote = context.remotes:WaitForChild("RequestThrow")
	self.HeldByPlayer = {}
end

function GrabService:Start()
	self.RequestGrabRemote.OnServerEvent:Connect(function(player, feedable)
		self:RequestGrab(player, feedable)
	end)

	self.RequestReleaseRemote.OnServerEvent:Connect(function(player)
		self:RequestRelease(player)
	end)

	self.RequestThrowRemote.OnServerEvent:Connect(function(player, direction)
		self:RequestThrow(player, direction)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:ClearHeld(player)
	end)
end

function GrabService:RequestGrab(player, feedable)
	if typeof(feedable) ~= "Instance" then
		return
	end

	local feedableService = self.Context.services.FeedableService
	local upgradeService = self.Context.services.UpgradeService
	feedable = feedableService:FindFeedableFromInstance(feedable)
	if feedable == nil then
		return
	end

	if not feedableService:IsFeedable(feedable) then
		return
	end

	if feedable:GetAttribute(self.Constants.ATTRIBUTES.Consumed) == true then
		return
	end

	local requiredStrength = feedable:GetAttribute(self.Constants.ATTRIBUTES.RequiredStrength) or 1
	if not upgradeService:CanHandleTier(player, requiredStrength) then
		self.Context.services.FeedbackService:Play(player, "LockedObject", {
			requiredStrength = requiredStrength,
		})
		return
	end

	local character = player.Character
	local humanoidRootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoidRootPart == nil or not humanoidRootPart:IsA("BasePart") then
		return
	end

	local rootPart = feedableService:GetRootPart(feedable)
	if rootPart == nil then
		return
	end

	if (rootPart.Position - humanoidRootPart.Position).Magnitude > MAX_GRAB_DISTANCE then
		return
	end

	self:ClearHeld(player)
	self:PrepareFeedableForHold(feedable, rootPart)
	self:AttachInFrontOfCharacter(player, feedable, rootPart, humanoidRootPart)
	feedable:SetAttribute(self.Constants.ATTRIBUTES.LastHolderUserId, player.UserId)
end

function GrabService:PrepareFeedableForHold(feedable: Instance, rootPart: BasePart)
	local feedableService = self.Context.services.FeedableService
	local parts = feedableService:GetBaseParts(feedable)

	for _, part in ipairs(parts) do
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true

		if part ~= rootPart then
			local alreadyWelded = false
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("WeldConstraint") and child.Name == INTERNAL_WELD_NAME then
					alreadyWelded = true
					break
				end
			end

			if not alreadyWelded then
				local weld = Instance.new("WeldConstraint")
				weld.Name = INTERNAL_WELD_NAME
				weld.Part0 = rootPart
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
end

function GrabService:AttachInFrontOfCharacter(player, feedable: Instance, rootPart: BasePart, humanoidRootPart: BasePart)
	if feedable:IsA("Model") then
		feedable:PivotTo(humanoidRootPart.CFrame * CFrame.new(0, 0, -HOLD_DISTANCE))
	else
		rootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, 0, -HOLD_DISTANCE)
	end

	local weld = Instance.new("WeldConstraint")
	weld.Name = HOLD_WELD_NAME
	weld.Part0 = humanoidRootPart
	weld.Part1 = rootPart
	weld.Parent = rootPart

	pcall(function()
		rootPart:SetNetworkOwner(player)
	end)

	self.HeldByPlayer[player] = {
		feedable = feedable,
		holdWeld = weld,
	}
end

function GrabService:ClearHeld(player)
	local held = self.HeldByPlayer[player]
	if held == nil then
		return
	end

	local holdWeld = held.holdWeld
	if typeof(holdWeld) == "Instance" and holdWeld.Parent ~= nil then
		holdWeld:Destroy()
	end

	self.HeldByPlayer[player] = nil
end

function GrabService:RequestRelease(_player) end

function GrabService:RequestThrow(_player, _direction) end

return GrabService
