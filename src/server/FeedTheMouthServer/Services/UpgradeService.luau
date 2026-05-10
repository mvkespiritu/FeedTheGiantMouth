--!strict

local UpgradeService = {}
UpgradeService.Name = "UpgradeService"

function UpgradeService:Init(context)
	self.Context = context
	self.UpgradeConfig = require(context.shared.UpgradeConfig)
	self.RequestUpgradeRemote = context.remotes:WaitForChild("RequestUpgrade")
end

function UpgradeService:Start()
	self.RequestUpgradeRemote.OnServerEvent:Connect(function(player, upgradeId)
		if typeof(upgradeId) ~= "string" then
			return
		end

		self:RequestUpgrade(player, upgradeId)
	end)
end

function UpgradeService:RequestUpgrade(player, upgradeId: string): boolean
	local definition = self.UpgradeConfig.Definitions[upgradeId]
	if definition == nil then
		self.Context.services.FeedbackService:Play(player, "InvalidUpgrade", {})
		return false
	end

	local playerDataService = self.Context.services.PlayerDataService
	local currentLevel = playerDataService:GetUpgradeLevel(player, upgradeId)
	local cost = self.UpgradeConfig.getCost(upgradeId, currentLevel)
	if cost == nil then
		self.Context.services.FeedbackService:Play(player, "UpgradeMaxed", {
			upgradeId = upgradeId,
			displayName = definition.displayName,
		})
		return false
	end

	if not playerDataService:TryPurchaseUpgrade(player, upgradeId, cost, currentLevel + 1) then
		self.Context.services.FeedbackService:Play(player, "NotEnoughCoins", {
			upgradeId = upgradeId,
			displayName = definition.displayName,
			cost = cost,
		})
		return false
	end

	self.Context.services.FeedbackService:Play(player, "UpgradePurchased", {
		upgradeId = upgradeId,
		displayName = definition.displayName,
		level = currentLevel + 1,
		cost = cost,
	})
	return true
end

function UpgradeService:CanHandleTier(player, requiredStrength: number): boolean
	return self.Context.services.PlayerDataService:GetUpgradeLevel(player, "Strength") >= requiredStrength
end

return UpgradeService
