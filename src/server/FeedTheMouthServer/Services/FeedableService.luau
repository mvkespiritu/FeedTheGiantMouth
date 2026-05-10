--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FeedableService = {}
FeedableService.Name = "FeedableService"

function FeedableService:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.ObjectTiers = require(context.shared.ObjectTiers)
end

function FeedableService:Start()
	self:EnsureTierFolders()
	self:TagInitialFeedables()
end

function FeedableService:GetFeedablesFolder(): Folder?
	local world = Workspace:FindFirstChild(self.Constants.WORLD_FOLDER_NAME)
	if world == nil or not world:IsA("Folder") then
		return nil
	end

	local feedablesFolder = world:FindFirstChild(self.Constants.FEEDABLES_FOLDER_NAME)
	if feedablesFolder == nil then
		feedablesFolder = Instance.new("Folder")
		feedablesFolder.Name = self.Constants.FEEDABLES_FOLDER_NAME
		feedablesFolder.Parent = world
	end

	if feedablesFolder:IsA("Folder") then
		return feedablesFolder
	end

	return nil
end

function FeedableService:GetTemplateFeedablesFolder(): Folder?
	local root = ReplicatedStorage:FindFirstChild(self.Constants.ROOT_FOLDER_NAME)
	if root == nil then
		return nil
	end

	return root:FindFirstChild(self.Constants.FEEDABLES_FOLDER_NAME) :: Folder?
end

function FeedableService:EnsureTierFolders()
	local feedablesFolder = self:GetFeedablesFolder()
	if feedablesFolder == nil then
		return
	end

	for _, tierConfig in pairs(self.ObjectTiers) do
		local existing = feedablesFolder:FindFirstChild(tierConfig.folderName)
		if existing == nil then
			local tierFolder = Instance.new("Folder")
			tierFolder.Name = tierConfig.folderName
			tierFolder.Parent = feedablesFolder
		end
	end
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
	feedable:SetAttribute(attributes.ItemId, self:GetFeedableItemId(feedable))
	feedable:SetAttribute(attributes.DisplayName, self:GetFeedableDisplayName(feedable))
	feedable:SetAttribute(attributes.Consumed, false)
end

function FeedableService:GetFeedableItemId(feedable: Instance): string
	local rawItemId = feedable:GetAttribute(self.Constants.ATTRIBUTES.ItemId)
	if typeof(rawItemId) == "string" and rawItemId ~= "" then
		return rawItemId
	end

	return self:GetBaseFeedableName(feedable)
end

function FeedableService:GetFeedableDisplayName(feedable: Instance): string
	local rawDisplayName = feedable:GetAttribute(self.Constants.ATTRIBUTES.DisplayName)
	if typeof(rawDisplayName) == "string" and rawDisplayName ~= "" then
		return rawDisplayName
	end

	local baseName = self:GetBaseFeedableName(feedable)
	local displayName = string.gsub(baseName, "_", " ")
	displayName = string.gsub(displayName, "(%l)(%u)", "%1 %2")
	return displayName
end

function FeedableService:GetBaseFeedableName(feedable: Instance): string
	local baseName = string.gsub(feedable.Name, "_Spawned_%d+$", "")
	return baseName
end

function FeedableService:IsFeedable(instance: Instance): boolean
	return instance:GetAttribute(self.Constants.ATTRIBUTES.Feedable) == true
end

function FeedableService:FindFeedableFromInstance(instance: Instance): Instance?
	local current: Instance? = instance
	local candidate: Instance? = nil

	while current ~= nil and current ~= Workspace do
		if self:IsFeedable(current) then
			candidate = current
		end

		current = current.Parent
	end

	return candidate
end

function FeedableService:GetRootPart(feedable: Instance): BasePart?
	if feedable:IsA("BasePart") then
		return feedable
	end

	if not feedable:IsA("Model") then
		return nil
	end

	if feedable.PrimaryPart ~= nil then
		return feedable.PrimaryPart
	end

	local rootPart = feedable:FindFirstChildWhichIsA("BasePart", true)
	if rootPart ~= nil then
		feedable.PrimaryPart = rootPart
	end

	return rootPart
end

function FeedableService:GetBaseParts(feedable: Instance): {BasePart}
	if feedable:IsA("BasePart") then
		return { feedable }
	end

	if not feedable:IsA("Model") then
		return {}
	end

	local parts = {}
	for _, descendant in ipairs(feedable:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

return FeedableService
