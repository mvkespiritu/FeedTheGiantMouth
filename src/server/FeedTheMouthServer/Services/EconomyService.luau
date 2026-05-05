--!strict

local EconomyService = {}
EconomyService.Name = "EconomyService"

function EconomyService:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
end

function EconomyService:GetObjectReward(feedable: Instance, player)
	local baseValue = feedable:GetAttribute(self.Constants.ATTRIBUTES.Value)
	local playerDataService = self.Context.services.PlayerDataService
	local valueLevel = playerDataService:GetUpgradeLevel(player, "ValueMultiplier")
	local numericBaseValue = if typeof(baseValue) == "number" then baseValue else 0

	return math.max(0, math.floor(numericBaseValue * (1 + ((valueLevel - 1) * 0.15))))
end

function EconomyService:AwardFeedReward(player, feedable: Instance): number
	local reward = self:GetObjectReward(feedable, player)
	self.Context.services.PlayerDataService:AddCoins(player, reward)
	return reward
end

return EconomyService
