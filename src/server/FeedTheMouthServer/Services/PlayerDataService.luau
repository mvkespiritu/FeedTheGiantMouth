--!strict

local Players = game:GetService("Players")

local PlayerDataService = {}
PlayerDataService.Name = "PlayerDataService"

local function createDefaultData()
	return {
		coins = 0,
		upgrades = {
			Strength = 1,
			CarryCapacity = 1,
			ThrowPower = 1,
			ValueMultiplier = 1,
		},
	}
end

function PlayerDataService:Init(context)
	self.Context = context
	self.PlayerDataChanged = context.remotes:WaitForChild("PlayerDataChanged")
	self.DataByPlayer = {}
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:LoadPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.DataByPlayer[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:LoadPlayer(player)
	end
end

function PlayerDataService:LoadPlayer(player)
	self.DataByPlayer[player] = createDefaultData()
	self:PushData(player)
end

function PlayerDataService:GetData(player)
	local data = self.DataByPlayer[player]
	if data == nil then
		data = createDefaultData()
		self.DataByPlayer[player] = data
	end

	return data
end

function PlayerDataService:GetUpgradeLevel(player, upgradeId: string): number
	local data = self:GetData(player)
	return data.upgrades[upgradeId] or 1
end

function PlayerDataService:AddCoins(player, amount: number)
	local data = self:GetData(player)
	data.coins += amount
	self:PushData(player)
end

function PlayerDataService:TrySpendCoins(player, amount: number): boolean
	local data = self:GetData(player)
	if data.coins < amount then
		return false
	end

	data.coins -= amount
	self:PushData(player)
	return true
end

function PlayerDataService:SetUpgradeLevel(player, upgradeId: string, level: number)
	local data = self:GetData(player)
	data.upgrades[upgradeId] = level
	self:PushData(player)
end

function PlayerDataService:PushData(player)
	self.PlayerDataChanged:FireClient(player, self:GetData(player))
end

return PlayerDataService
