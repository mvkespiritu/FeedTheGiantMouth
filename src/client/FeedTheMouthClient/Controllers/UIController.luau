--!strict

local Players = game:GetService("Players")

local UIController = {}
UIController.Name = "UIController"

function UIController:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.PlayerDataChanged = context.remotes:WaitForChild("PlayerDataChanged")
end

function UIController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.MainHUD = playerGui:WaitForChild(self.Constants.MAIN_HUD_NAME)
	self.HUDFrame = self.MainHUD:WaitForChild("HUDFrame")
	self.CoinsLabel = self.HUDFrame:WaitForChild("CoinsLabel")
	self.UpgradeShopFrame = self.MainHUD:WaitForChild("UpgradeShopFrame")
	self.FeedbackFrame = self.MainHUD:WaitForChild("FeedbackFrame")

	self.PlayerDataChanged.OnClientEvent:Connect(function(data)
		self:RenderPlayerData(data)
	end)
end

function UIController:RenderPlayerData(data)
	if self.CoinsLabel ~= nil then
		self.CoinsLabel.Text = `Coins: {data.coins or 0}`
	end
end

function UIController:ShowReward(amount: number)
	print(`+{amount} coins`)
end

function UIController:ShowLockMessage(requiredStrength: number)
	print(`Requires Strength {requiredStrength}`)
end

return UIController
