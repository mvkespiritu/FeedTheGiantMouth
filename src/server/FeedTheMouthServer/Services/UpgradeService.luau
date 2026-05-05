--!strict

local UpgradeService = {}
UpgradeService.Name = "UpgradeService"

function UpgradeService:Init(context)
	self.Context = context
	self.UpgradeConfig = require(context.shared.UpgradeConfig)
	self.RequestUpgrade = context.remotes:WaitForChild("RequestUpgrade")
end

function UpgradeService:Start()
	self.RequestUpgrade.OnServerEvent:Connect(function(player, upgradeId)
		if typeof(upgradeId) ~= "string" then
			return
		end

		self:RequestUpgrade(player, upgradeId)
	end)
end

function UpgradeService:RequestUpgrade(player, upgradeId: string): boolean
	local definition = self.UpgradeConfig.Definitions[upgradeId]
	if definition == nil then
		return false
	end

	local playerDataService = self.Context.services.PlayerDataService
	local currentLevel = playerDataService:GetUpgradeLevel(player, upgradeId)
	local cost = self.UpgradeConfig.getCost(upgradeId, currentLevel)
	if cost == nil then
		return false
	end

	if not playerDataService:TrySpendCoins(player, cost) then
		return false
	end

	playerDataService:SetUpgradeLevel(player, upgradeId, currentLevel + 1)
	return true
end

function UpgradeService:CanHandleTier(player, requiredStrength: number): boolean
	return self.Context.services.PlayerDataService:GetUpgradeLevel(player, "Strength") >= requiredStrength
end

return UpgradeService
