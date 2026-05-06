--!strict

local Players = game:GetService("Players")

local UIController = {}
UIController.Name = "UIController"

function UIController:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.UpgradeConfig = require(context.shared.UpgradeConfig)
	self.PlayerDataChanged = context.remotes:WaitForChild("PlayerDataChanged")
	self.RewardMessageId = 0
	self.StatusMessageId = 0
	self.CurrentPlayerData = nil
	self.UpgradeLevelLabelsById = {}
end

function UIController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.MainHUD = playerGui:WaitForChild(self.Constants.MAIN_HUD_NAME)
	self.HUDFrame = self.MainHUD:WaitForChild("HUDFrame")
	self.CoinsLabel = self.HUDFrame:WaitForChild("CoinsLabel")
	local upgradeLevelsFrame = self.HUDFrame:FindFirstChild("UpgradeLevelsFrame")
	if upgradeLevelsFrame ~= nil and upgradeLevelsFrame:IsA("GuiObject") then
		upgradeLevelsFrame.Visible = false
	end

	self.UpgradeStatsPanel = self.MainHUD:WaitForChild("UpgradeStatsPanel")
	self.UpgradeShopFrame = self.MainHUD:WaitForChild("UpgradeShopFrame")
	self.FeedbackFrame = self.MainHUD:WaitForChild("FeedbackFrame")
	self.RewardPopupTemplate = self.FeedbackFrame:WaitForChild("RewardPopupTemplate")
	self.LockMessageLabel = self.FeedbackFrame:WaitForChild("LockMessageLabel")
	self:BuildUpgradeLevelLabels()

	self.PlayerDataChanged.OnClientEvent:Connect(function(data)
		self:RenderPlayerData(data)
	end)
end

function UIController:RenderPlayerData(data)
	self.CurrentPlayerData = data

	if self.CoinsLabel ~= nil then
		local coins = if data ~= nil and typeof(data.coins) == "number" then data.coins else 0
		self.CoinsLabel.Text = `Coins: {coins}`
	end

	self:RenderUpgradeLevels(data)
end

function UIController:BuildUpgradeLevelLabels()
	if self.UpgradeStatsPanel == nil then
		return
	end

	for _, upgradeId in ipairs(self.UpgradeConfig.Order) do
		local card = self.UpgradeStatsPanel:FindFirstChild(`{upgradeId}StatCard`, true)
		if card ~= nil then
			local label = card:FindFirstChild("LevelValue")
			if label ~= nil and label:IsA("TextLabel") then
				self.UpgradeLevelLabelsById[upgradeId] = label
			end
		end
	end

	self:RenderUpgradeLevels(self.CurrentPlayerData)
end

function UIController:RenderUpgradeLevels(data)
	local upgrades = if data ~= nil and data.upgrades ~= nil then data.upgrades else {}

	for _, upgradeId in ipairs(self.UpgradeConfig.Order) do
		local label = self.UpgradeLevelLabelsById[upgradeId]
		local definition = self.UpgradeConfig.Definitions[upgradeId]
		if label == nil or not label:IsA("TextLabel") or definition == nil then
			continue
		end

		local level = upgrades[upgradeId] or definition.defaultLevel
		label.Text = `Lv {level}`
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
	self:ShowStatusMessage(`Requires Strength {requiredStrength}`)
end

function UIController:ShowStatusMessage(message: string)
	self.StatusMessageId += 1
	local messageId = self.StatusMessageId

	if self.LockMessageLabel ~= nil and self.LockMessageLabel:IsA("TextLabel") then
		self.LockMessageLabel.Text = message
		self.LockMessageLabel.Visible = true
	end

	task.delay(1.5, function()
		if self.StatusMessageId == messageId and self.LockMessageLabel ~= nil then
			self.LockMessageLabel.Text = ""
		end
	end)
end

return UIController
