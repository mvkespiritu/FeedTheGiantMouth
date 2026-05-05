--!strict

local Workspace = game:GetService("Workspace")

local MouthService = {}
MouthService.Name = "MouthService"

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
	local feedable = hit:FindFirstAncestorWhichIsA("Model") or hit
	local feedableService = self.Context.services.FeedableService
	if not feedableService:IsFeedable(feedable) then
		return
	end

	local attributes = self.Constants.ATTRIBUTES
	if feedable:GetAttribute(attributes.Consumed) == true then
		return
	end

	feedable:SetAttribute(attributes.Consumed, true)

	local userId = feedable:GetAttribute(attributes.LastHolderUserId)
	local player = if typeof(userId) == "number" then game.Players:GetPlayerByUserId(userId) else nil
	if player ~= nil then
		local reward = self.Context.services.EconomyService:AwardFeedReward(player, feedable)
		self.Context.services.FeedbackService:Play(player, "Reward", {
			amount = reward,
		})
	end

	self.Context.services.FeedbackService:PlayForAll("MouthEat", {
		position = hit.Position,
	})

	feedable:Destroy()
end

return MouthService
