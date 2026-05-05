--!strict

local EconomyService = {}
EconomyService.Name = "EconomyService"

function EconomyService:Init(context)
	self.Context = context
end

function EconomyService:GetObjectReward(feedable: Instance, player)
	local attributes = require(self.Context.shared.Constants).ATTRIBUTES
	local baseValue = feedable:GetAttribute(attributes.Value)
	local playerDataService = self.Context.services.PlayerDataService
	local valueLevel = playerDataService:GetUpgradeLevel(player, "ValueMultiplier")

	return math.max(0, math.floor((baseValue or 0) * (1 + ((valueLevel - 1) * 0.15))))
end

function EconomyService:AwardFeedReward(player, feedable: Instance): number
	local reward = self:GetObjectReward(feedable, player)
	self.Context.services.PlayerDataService:AddCoins(player, reward)
	return reward
end

return EconomyService
