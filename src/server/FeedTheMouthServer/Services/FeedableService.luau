--!strict

local Workspace = game:GetService("Workspace")

local FeedableService = {}
FeedableService.Name = "FeedableService"

function FeedableService:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.ObjectTiers = require(context.shared.ObjectTiers)
end

function FeedableService:Start()
	self:TagInitialFeedables()
end

function FeedableService:GetFeedablesFolder(): Folder?
	local world = Workspace:FindFirstChild(self.Constants.WORLD_FOLDER_NAME)
	if world == nil then
		return nil
	end

	return world:FindFirstChild("FeedableObjects") :: Folder?
end

function FeedableService:TagInitialFeedables()
	local feedablesFolder = self:GetFeedablesFolder()
	if feedablesFolder == nil then
		return
	end

	for tierName, tierConfig in pairs(self.ObjectTiers) do
		local tierFolder = feedablesFolder:FindFirstChild(tierConfig.folderName)
		if tierFolder == nil then
			continue
		end

		for _, feedable in ipairs(tierFolder:GetChildren()) do
			self:ApplyFeedableAttributes(feedable, tierName)
		end
	end
end

function FeedableService:ApplyFeedableAttributes(feedable: Instance, tierName: string)
	local tierConfig = self.ObjectTiers[tierName]
	if tierConfig == nil then
		return
	end

	local attributes = self.Constants.ATTRIBUTES
	feedable:SetAttribute(attributes.Feedable, true)
	feedable:SetAttribute(attributes.Tier, tierName)
	feedable:SetAttribute(attributes.Value, feedable:GetAttribute(attributes.Value) or tierConfig.baseReward)
	feedable:SetAttribute(attributes.Weight, feedable:GetAttribute(attributes.Weight) or tierConfig.weight)
	feedable:SetAttribute(
		attributes.RequiredStrength,
		feedable:GetAttribute(attributes.RequiredStrength) or tierConfig.requiredStrength
	)
	feedable:SetAttribute(attributes.Consumed, false)
end

function FeedableService:IsFeedable(instance: Instance): boolean
	return instance:GetAttribute(self.Constants.ATTRIBUTES.Feedable) == true
end

return FeedableService
