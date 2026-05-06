--!strict

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local RespawnService = {}
RespawnService.Name = "RespawnService"

local TEMPLATE_ROOT_NAME = "FeedTheMouthObjectTemplates"
local OBJECT_TIER_AREAS_NAME = "ObjectTierAreas"
local SPAWN_AREA_NAME = "SpawnArea"
local MIN_RESPAWN_DELAY_SECONDS = 25
local MAX_RESPAWN_DELAY_SECONDS = 35
local DEFAULT_SPAWN_LIMIT = 6

function RespawnService:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.ObjectTiers = require(context.shared.ObjectTiers)
	self.Random = Random.new()
	self.SpawnCounter = 0
	self.RefillQueuedByTier = {}
	self.TemplateFoldersByTier = {}
end

function RespawnService:Start()
	self:BuildTemplateCache()
	self:ConnectTierFolders()
	self:RefillAllTiers()
end

function RespawnService:GetWorldFolder(): Folder?
	return Workspace:FindFirstChild(self.Constants.WORLD_FOLDER_NAME) :: Folder?
end

function RespawnService:GetFeedablesFolder(): Folder?
	local feedableService = self.Context.services.FeedableService
	if feedableService ~= nil then
		return feedableService:GetFeedablesFolder()
	end

	local world = self:GetWorldFolder()
	if world == nil then
		return nil
	end

	return world:FindFirstChild("FeedableObjects") :: Folder?
end

function RespawnService:GetTierFolder(tierName: string): Folder?
	local feedablesFolder = self:GetFeedablesFolder()
	if feedablesFolder == nil then
		return nil
	end

	local tierConfig = self.ObjectTiers[tierName]
	if tierConfig == nil then
		return nil
	end

	return feedablesFolder:FindFirstChild(tierConfig.folderName) :: Folder?
end

function RespawnService:GetSpawnArea(tierName: string): BasePart?
	local world = self:GetWorldFolder()
	if world == nil then
		return nil
	end

	local tierAreas = world:FindFirstChild(OBJECT_TIER_AREAS_NAME)
	local tierModel = if tierAreas ~= nil then tierAreas:FindFirstChild(tierName) else nil
	local spawnArea = if tierModel ~= nil then tierModel:FindFirstChild(SPAWN_AREA_NAME) else nil
	if spawnArea ~= nil and spawnArea:IsA("BasePart") then
		return spawnArea
	end

	return nil
end

function RespawnService:BuildTemplateCache()
	local templateRoot = ServerStorage:FindFirstChild(TEMPLATE_ROOT_NAME)
	if templateRoot ~= nil then
		templateRoot:Destroy()
	end

	templateRoot = Instance.new("Folder")
	templateRoot.Name = TEMPLATE_ROOT_NAME
	templateRoot.Parent = ServerStorage

	for tierName, tierConfig in pairs(self.ObjectTiers) do
		local tierFolder = self:GetTierFolder(tierName)
		if tierFolder == nil then
			warn(`[RespawnService] FeedableObjects.{tierConfig.folderName} not found`)
			continue
		end

		local templateFolder = Instance.new("Folder")
		templateFolder.Name = tierConfig.folderName
		templateFolder.Parent = templateRoot
		self.TemplateFoldersByTier[tierName] = templateFolder

		for _, feedable in ipairs(tierFolder:GetChildren()) do
			if feedable:IsA("BasePart") or feedable:IsA("Model") then
				local template = feedable:Clone()
				template.Parent = templateFolder
			end
		end

		tierFolder:ClearAllChildren()
	end
end

function RespawnService:ConnectTierFolders()
	for tierName, _tierConfig in pairs(self.ObjectTiers) do
		local tierFolder = self:GetTierFolder(tierName)
		if tierFolder == nil then
			continue
		end

		tierFolder.ChildRemoved:Connect(function()
			self:QueueRefill(tierName)
		end)
	end
end

function RespawnService:RefillAllTiers()
	for tierName, _tierConfig in pairs(self.ObjectTiers) do
		self:RefillTier(tierName)
	end
end

function RespawnService:QueueRefill(tierName: string)
	if self.RefillQueuedByTier[tierName] == true then
		return
	end

	self.RefillQueuedByTier[tierName] = true
	local respawnDelay = self.Random:NextNumber(MIN_RESPAWN_DELAY_SECONDS, MAX_RESPAWN_DELAY_SECONDS)
	task.delay(respawnDelay, function()
		self.RefillQueuedByTier[tierName] = nil
		self:RefillTier(tierName)
	end)
end

function RespawnService:RefillTier(tierName: string)
	local tierConfig = self.ObjectTiers[tierName]
	if tierConfig == nil then
		return
	end

	local tierFolder = self:GetTierFolder(tierName)
	local spawnArea = self:GetSpawnArea(tierName)
	if tierFolder == nil or spawnArea == nil then
		warn(`[RespawnService] Missing spawn setup for tier {tierName}`)
		return
	end

	local spawnLimit = self:GetSpawnLimit(tierConfig)
	local liveCount = self:CountLiveFeedables(tierFolder)
	while liveCount < spawnLimit do
		local spawned = self:SpawnOne(tierName, tierFolder, spawnArea)
		if spawned == nil then
			break
		end

		liveCount += 1
	end
end

function RespawnService:GetSpawnLimit(tierConfig): number
	local spawnLimit = tierConfig.spawnLimit
	if typeof(spawnLimit) == "number" then
		return math.max(0, math.floor(spawnLimit))
	end

	return DEFAULT_SPAWN_LIMIT
end

function RespawnService:CountLiveFeedables(tierFolder: Folder): number
	local count = 0
	local attributes = self.Constants.ATTRIBUTES

	for _, child in ipairs(tierFolder:GetChildren()) do
		if child:GetAttribute(attributes.Consumed) ~= true then
			count += 1
		end
	end

	return count
end

function RespawnService:SpawnOne(tierName: string, tierFolder: Folder, spawnArea: BasePart): Instance?
	local template = self:GetRandomTemplate(tierName)
	if template == nil then
		warn(`[RespawnService] No feedable templates found for tier {tierName}`)
		return nil
	end

	local feedable = template:Clone()
	self.SpawnCounter += 1
	feedable.Name = `{template.Name}_Spawned_{self.SpawnCounter}`
	feedable.Parent = tierFolder

	self.Context.services.FeedableService:ApplyFeedableAttributes(feedable, tierName)
	self:PrepareSpawnedFeedable(feedable)
	self:PlaceFeedable(feedable, spawnArea)

	return feedable
end

function RespawnService:GetRandomTemplate(tierName: string): Instance?
	local templateFolder = self.TemplateFoldersByTier[tierName]
	if templateFolder == nil then
		return nil
	end

	local templates = templateFolder:GetChildren()
	if #templates == 0 then
		return nil
	end

	return templates[self.Random:NextInteger(1, #templates)]
end

function RespawnService:PrepareSpawnedFeedable(feedable: Instance)
	local attributes = self.Constants.ATTRIBUTES
	feedable:SetAttribute(attributes.Consumed, false)
	feedable:SetAttribute(attributes.LastHolderUserId, nil)

	local feedableService = self.Context.services.FeedableService
	for _, part in ipairs(feedableService:GetBaseParts(feedable)) do
		part.Anchored = true
		part.CanCollide = true
		part.CanTouch = true
		part.Massless = false
		part:SetAttribute(attributes.Consumed, nil)
	end
end

function RespawnService:PlaceFeedable(feedable: Instance, spawnArea: BasePart)
	local feedableSize = self:GetFeedableSize(feedable)
	local pivotToBottomOffset = self:GetPivotToBottomOffset(feedable)
	local paddingX = math.min(spawnArea.Size.X * 0.45, (feedableSize.X * 0.5) + 2)
	local paddingZ = math.min(spawnArea.Size.Z * 0.45, (feedableSize.Z * 0.5) + 2)
	local usableX = math.max(0, (spawnArea.Size.X * 0.5) - paddingX)
	local usableZ = math.max(0, (spawnArea.Size.Z * 0.5) - paddingZ)
	local localX = self.Random:NextNumber(-usableX, usableX)
	local localZ = self.Random:NextNumber(-usableZ, usableZ)
	local y = (spawnArea.Size.Y * 0.5) + pivotToBottomOffset + 0.1
	local yaw = math.rad(self.Random:NextNumber(0, 360))
	local cframe = spawnArea.CFrame * CFrame.new(localX, y, localZ) * CFrame.Angles(0, yaw, 0)

	if feedable:IsA("Model") then
		feedable:PivotTo(cframe)
	elseif feedable:IsA("BasePart") then
		feedable.CFrame = cframe
	end
end

function RespawnService:GetFeedableSize(feedable: Instance): Vector3
	if feedable:IsA("BasePart") then
		return feedable.Size
	end

	if feedable:IsA("Model") then
		local _cframe, size = feedable:GetBoundingBox()
		return size
	end

	return Vector3.one
end

function RespawnService:GetPivotToBottomOffset(feedable: Instance): number
	if feedable:IsA("BasePart") then
		return feedable.Size.Y * 0.5
	end

	if feedable:IsA("Model") then
		local cframe, size = feedable:GetBoundingBox()
		local bottomY = cframe.Position.Y - (size.Y * 0.5)
		return feedable:GetPivot().Position.Y - bottomY
	end

	return 0.5
end

return RespawnService
