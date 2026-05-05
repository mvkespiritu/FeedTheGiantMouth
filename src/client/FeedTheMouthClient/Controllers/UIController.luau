--!strict

local Players = game:GetService("Players")

local UIController = {}
UIController.Name = "UIController"

function UIController:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.PlayerDataChanged = context.remotes:WaitForChild("PlayerDataChanged")
	self.RewardMessageId = 0
	self.LockMessageId = 0
end

function UIController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.MainHUD = playerGui:WaitForChild(self.Constants.MAIN_HUD_NAME)
	self.HUDFrame = self.MainHUD:WaitForChild("HUDFrame")
	self.CoinsLabel = self.HUDFrame:WaitForChild("CoinsLabel")
	self.UpgradeShopFrame = self.MainHUD:WaitForChild("UpgradeShopFrame")
	self.FeedbackFrame = self.MainHUD:WaitForChild("FeedbackFrame")
	self.RewardPopupTemplate = self.FeedbackFrame:WaitForChild("RewardPopupTemplate")
	self.LockMessageLabel = self.FeedbackFrame:WaitForChild("LockMessageLabel")

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
	self.RewardMessageId += 1
	local messageId = self.RewardMessageId

	if self.RewardPopupTemplate ~= nil and self.RewardPopupTemplate:IsA("TextLabel") then
		self.RewardPopupTemplate.Text = `+{amount} coins`
		self.RewardPopupTemplate.Visible = true
	end

	task.delay(1.25, function()
		if self.RewardMessageId == messageId and self.RewardPopupTemplate ~= nil then
			self.RewardPopupTemplate.Visible = false
		end
	end)
end

function UIController:ShowLockMessage(requiredStrength: number)
	self.LockMessageId += 1
	local messageId = self.LockMessageId

	if self.LockMessageLabel ~= nil and self.LockMessageLabel:IsA("TextLabel") then
		self.LockMessageLabel.Text = `Requires Strength {requiredStrength}`
		self.LockMessageLabel.Visible = true
	end

	task.delay(1.5, function()
		if self.LockMessageId == messageId and self.LockMessageLabel ~= nil then
			self.LockMessageLabel.Text = ""
		end
	end)
end

return UIController
