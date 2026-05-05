--!strict

local GrabService = {}
GrabService.Name = "GrabService"

function GrabService:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.RequestGrab = context.remotes:WaitForChild("RequestGrab")
	self.RequestRelease = context.remotes:WaitForChild("RequestRelease")
	self.RequestThrow = context.remotes:WaitForChild("RequestThrow")
end

function GrabService:Start()
	self.RequestGrab.OnServerEvent:Connect(function(player, feedable)
		self:RequestGrab(player, feedable)
	end)

	self.RequestRelease.OnServerEvent:Connect(function(player)
		self:RequestRelease(player)
	end)

	self.RequestThrow.OnServerEvent:Connect(function(player, direction)
		self:RequestThrow(player, direction)
	end)
end

function GrabService:RequestGrab(player, feedable)
	if typeof(feedable) ~= "Instance" then
		return
	end

	local feedableService = self.Context.services.FeedableService
	local upgradeService = self.Context.services.UpgradeService
	if not feedableService:IsFeedable(feedable) then
		return
	end

	local requiredStrength = feedable:GetAttribute(self.Constants.ATTRIBUTES.RequiredStrength) or 1
	if not upgradeService:CanHandleTier(player, requiredStrength) then
		self.Context.services.FeedbackService:Play(player, "LockedObject", {
			requiredStrength = requiredStrength,
		})
		return
	end

	feedable:SetAttribute(self.Constants.ATTRIBUTES.LastHolderUserId, player.UserId)
end

function GrabService:RequestRelease(_player) end

function GrabService:RequestThrow(_player, _direction) end

return GrabService
