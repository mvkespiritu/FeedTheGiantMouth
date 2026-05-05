--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MouthService = {}
MouthService.Name = "MouthService"

local FEEDER_FALLBACK_RADIUS = 40

function MouthService:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
end

function MouthService:Start()
	local eatZone = self:GetEatZone()
	if eatZone == nil then
		warn("[MouthService] EatZone not found")
		return
	end

	eatZone.CanTouch = true
	eatZone.Touched:Connect(function(hit)
		self:TryEat(hit)
	end)
end

function MouthService:GetEatZone(): BasePart?
	local world = Workspace:FindFirstChild(self.Constants.WORLD_FOLDER_NAME)
	local mouth = if world ~= nil then world:FindFirstChild("Mouth") else nil
	local eatZone = if mouth ~= nil then mouth:FindFirstChild("EatZone") else nil

	if eatZone ~= nil and eatZone:IsA("BasePart") then
		return eatZone
	end

	return nil
end

function MouthService:TryEat(hit: BasePart)
	local feedableService = self.Context.services.FeedableService
	local feedable = feedableService:FindFeedableFromInstance(hit)
	if feedable == nil then
		return
	end

	local attributes = self.Constants.ATTRIBUTES
	if feedable:GetAttribute(attributes.Consumed) == true then
		return
	end

	self:MarkConsumed(feedable)

	local player = self:GetFeeder(feedable, hit.Position)
	local reward = 0
	if player ~= nil then
		reward = self.Context.services.EconomyService:AwardFeedReward(player, feedable)
		self.Context.services.FeedbackService:Play(player, "Reward", {
			amount = reward,
			tier = feedable:GetAttribute(attributes.Tier),
		})
	end

	self.Context.services.FeedbackService:PlayForAll("MouthEat", {
		position = hit.Position,
		reward = reward,
		tier = feedable:GetAttribute(attributes.Tier),
	})

	task.defer(function()
		if feedable.Parent ~= nil then
			feedable:Destroy()
		end
	end)
end

function MouthService:MarkConsumed(feedable: Instance)
	local attributes = self.Constants.ATTRIBUTES
	feedable:SetAttribute(attributes.Consumed, true)

	local feedableService = self.Context.services.FeedableService
	for _, part in ipairs(feedableService:GetBaseParts(feedable)) do
		part.CanTouch = false
		part.CanCollide = false
		part:SetAttribute(attributes.Consumed, true)
	end
end

function MouthService:GetFeeder(feedable: Instance, position: Vector3): Player?
	local userId = feedable:GetAttribute(self.Constants.ATTRIBUTES.LastHolderUserId)
	if typeof(userId) == "number" then
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			return player
		end
	end

	return self:GetNearestPlayer(position, FEEDER_FALLBACK_RADIUS)
end

function MouthService:GetNearestPlayer(position: Vector3, maxDistance: number): Player?
	local nearestPlayer = nil
	local nearestDistance = maxDistance

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if rootPart ~= nil and rootPart:IsA("BasePart") then
			local distance = (rootPart.Position - position).Magnitude
			if distance <= nearestDistance then
				nearestPlayer = player
				nearestDistance = distance
			end
		end
	end

	return nearestPlayer
end

return MouthService
