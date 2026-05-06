--!strict

local Players = game:GetService("Players")

local GrabService = {}
GrabService.Name = "GrabService"

local HOLD_DISTANCE = 6
local MAX_GRAB_DISTANCE = 24
local HOLD_HORIZONTAL_SPACING = 3.25
local HOLD_VERTICAL_SPACING = 2.25
local HOLD_DEPTH_SPACING = 1.25
local BASE_THROW_SPEED = 75
local THROW_POWER_PER_LEVEL = 10
local THROW_UPWARD_SPEED = 14
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

	if self:GetHeldEntry(player, feedable) ~= nil then
		self:RequestThrow(player, nil, feedable)
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

	local heldList = self:GetHeldList(player)
	local carryCapacity = self:GetCarryCapacity(player)
	if #heldList >= carryCapacity then
		self:RequestThrow(player)
		return
	end

	if (rootPart.Position - humanoidRootPart.Position).Magnitude > MAX_GRAB_DISTANCE then
		return
	end

	self:PrepareFeedableForHold(feedable, rootPart)
	self:AddHeldObject(player, feedable, rootPart, humanoidRootPart)
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

function GrabService:AddHeldObject(player, feedable: Instance, rootPart: BasePart, humanoidRootPart: BasePart)
	local heldList = self:GetHeldList(player)
	table.insert(heldList, {
		feedable = feedable,
		rootPart = rootPart,
	})

	self:RepositionHeldObjects(player, humanoidRootPart)
end

function GrabService:RepositionHeldObjects(player, humanoidRootPart: BasePart?)
	humanoidRootPart = humanoidRootPart or self:GetHumanoidRootPart(player)
	if humanoidRootPart == nil then
		return
	end

	local heldList = self:GetHeldList(player)
	for index = #heldList, 1, -1 do
		local held = heldList[index]
		if not self:IsHeldEntryValid(held) then
			table.remove(heldList, index)
		end
	end

	for index, held in ipairs(heldList) do
		local rootPart = held.rootPart
		local oldWeld = held.holdWeld
		if typeof(oldWeld) == "Instance" and oldWeld.Parent ~= nil then
			oldWeld:Destroy()
		end

		local offset = self:GetHoldOffset(index)
		if held.feedable:IsA("Model") then
			held.feedable:PivotTo(humanoidRootPart.CFrame * offset)
		else
			rootPart.CFrame = humanoidRootPart.CFrame * offset
		end

		local weld = Instance.new("WeldConstraint")
		weld.Name = HOLD_WELD_NAME
		weld.Part0 = humanoidRootPart
		weld.Part1 = rootPart
		weld.Parent = rootPart
		held.holdWeld = weld

		pcall(function()
			rootPart:SetNetworkOwner(player)
		end)
	end
end

function GrabService:GetHoldOffset(index: number): CFrame
	if index == 1 then
		return CFrame.new(0, 0, -HOLD_DISTANCE)
	end

	local adjustedIndex = index - 2
	local row = math.floor(adjustedIndex / 3)
	local column = adjustedIndex % 3
	local x = ({ -1, 1, 0 })[column + 1] * HOLD_HORIZONTAL_SPACING
	local y = 0.75 + ((row + 1) * HOLD_VERTICAL_SPACING)
	local z = -HOLD_DISTANCE - ((row + 1) * HOLD_DEPTH_SPACING)

	return CFrame.new(x, y, z)
end

function GrabService:RestoreFeedablePhysics(feedable: Instance)
	local feedableService = self.Context.services.FeedableService
	local parts = feedableService:GetBaseParts(feedable)

	for _, part in ipairs(parts) do
		part.CanCollide = true
		part.Massless = false
	end
end

function GrabService:GetHeldList(player): {any}
	local heldList = self.HeldByPlayer[player]
	if heldList == nil then
		heldList = {}
		self.HeldByPlayer[player] = heldList
	end

	return heldList
end

function GrabService:GetCarryCapacity(player): number
	local level = self.Context.services.PlayerDataService:GetUpgradeLevel(player, "CarryCapacity")
	return math.max(1, math.floor(level))
end

function GrabService:GetHumanoidRootPart(player): BasePart?
	local character = player.Character
	local humanoidRootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoidRootPart ~= nil and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart
	end

	return nil
end

function GrabService:IsHeldEntryValid(held): boolean
	return typeof(held) == "table"
		and typeof(held.feedable) == "Instance"
		and typeof(held.rootPart) == "Instance"
		and held.feedable.Parent ~= nil
		and held.rootPart:IsA("BasePart")
		and held.rootPart.Parent ~= nil
end

function GrabService:GetHeldEntry(player, feedable: Instance): any?
	local heldList = self:GetHeldList(player)
	for _, held in ipairs(heldList) do
		if held.feedable == feedable then
			return held
		end
	end

	return nil
end

function GrabService:RemoveHeldEntry(player, targetFeedable: Instance?): any?
	local heldList = self:GetHeldList(player)
	if #heldList == 0 then
		return nil
	end

	local removeIndex = #heldList
	if targetFeedable ~= nil then
		for index, held in ipairs(heldList) do
			if held.feedable == targetFeedable then
				removeIndex = index
				break
			end
		end
	end

	local held = table.remove(heldList, removeIndex)
	if held == nil then
		return nil
	end

	self:DetachHeldEntry(held)
	self:RepositionHeldObjects(player)
	return held
end

function GrabService:DetachHeldEntry(held)
	local holdWeld = held.holdWeld
	if typeof(holdWeld) == "Instance" and holdWeld.Parent ~= nil then
		holdWeld:Destroy()
	end

	if typeof(held.feedable) == "Instance" and held.feedable.Parent ~= nil then
		self:RestoreFeedablePhysics(held.feedable)
	end
end

function GrabService:ClearHeld(player): {any}
	local heldList = self:GetHeldList(player)
	local released = {}

	for index = #heldList, 1, -1 do
		local held = table.remove(heldList, index)
		if held ~= nil then
			self:DetachHeldEntry(held)
			table.insert(released, held)
		end
	end

	self.HeldByPlayer[player] = nil
	return released
end

function GrabService:RequestRelease(player)
	self:ClearHeld(player)
end

function GrabService:GetThrowDirection(player, direction): Vector3
	local humanoidRootPart = self:GetHumanoidRootPart(player)
	if typeof(direction) == "Vector3" and direction.Magnitude > 0.05 then
		return direction.Unit
	end

	if humanoidRootPart ~= nil then
		return humanoidRootPart.CFrame.LookVector
	end

	return Vector3.new(0, 0, -1)
end

function GrabService:ApplyThrowVelocity(player, held, direction)
	local rootPart = held.rootPart
	if typeof(rootPart) ~= "Instance" or not rootPart:IsA("BasePart") or rootPart.Parent == nil then
		return
	end

	local throwDirection = self:GetThrowDirection(player, direction)
	local throwPowerLevel = self.Context.services.PlayerDataService:GetUpgradeLevel(player, "ThrowPower")
	local speed = BASE_THROW_SPEED + ((throwPowerLevel - 1) * THROW_POWER_PER_LEVEL)
	rootPart.AssemblyLinearVelocity = (throwDirection * speed) + Vector3.new(0, THROW_UPWARD_SPEED, 0)

	pcall(function()
		rootPart:SetNetworkOwner(nil)
	end)
end

function GrabService:RequestThrow(player, direction, targetFeedable: Instance?)
	local held = self:RemoveHeldEntry(player, targetFeedable)
	if held == nil then
		return
	end

	self:ApplyThrowVelocity(player, held, direction)
end

return GrabService
