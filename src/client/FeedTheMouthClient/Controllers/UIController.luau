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
	self.StruggleConnections = {}
end

function UIController:Start()
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui")
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
	self:BuildStruggleUI()
	self:BuildUpgradeLevelLabels()

	self.PlayerDataChanged.OnClientEvent:Connect(function(data)
		self:RenderPlayerData(data)
	end)

	localPlayer.CharacterAdded:Connect(function(character)
		self:BindStruggleCharacter(character)
	end)

	if localPlayer.Character ~= nil then
		self:BindStruggleCharacter(localPlayer.Character)
	else
		self:UpdateStruggleUI(nil)
	end
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

function UIController:BuildStruggleUI()
	if self.MainHUD == nil then
		return
	end

	local container = self.MainHUD:FindFirstChild("StruggleMeterContainer")
	if container == nil or not container:IsA("GuiObject") then
		warn("StruggleMeterContainer is missing from MainHUD")
		return
	end

	local fill = container:FindFirstChild("MeterFill")
	local fillGradient = if fill ~= nil then fill:FindFirstChild("MeterFillGradient") else nil
	local tapLabel = container:FindFirstChild("TapLabel")

	if fill == nil or not fill:IsA("ImageLabel") then
		warn("StruggleMeterContainer.MeterFill must be an ImageLabel")
		return
	end

	if fillGradient == nil or not fillGradient:IsA("UIGradient") then
		warn("StruggleMeterContainer.MeterFill.MeterFillGradient must be a UIGradient")
		return
	end

	if tapLabel == nil or not tapLabel:IsA("TextLabel") then
		warn("StruggleMeterContainer.TapLabel must be a TextLabel")
		return
	end

	container.Visible = false

	self.StruggleMeterContainer = container
	self.StruggleMeterFill = fill
	self.StruggleMeterFillGradient = fillGradient
	self.StruggleTapLabel = tapLabel
	self:UpdateStruggleFill(0)
end

function UIController:UpdateStruggleFill(progress: number)
	if self.StruggleMeterFillGradient == nil then
		return
	end

	if progress <= 0 then
		self.StruggleMeterFillGradient.Transparency = NumberSequence.new(1)
		return
	end

	if progress >= 1 then
		self.StruggleMeterFillGradient.Transparency = NumberSequence.new(0)
		return
	end

	local edge = 1 - progress
	local nextEdge = math.min(edge + 0.001, 1)
	if nextEdge >= 1 then
		self.StruggleMeterFillGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(edge, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
	else
		self.StruggleMeterFillGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(edge, 1),
			NumberSequenceKeypoint.new(nextEdge, 0),
			NumberSequenceKeypoint.new(1, 0),
		})
	end
end

function UIController:BindStruggleCharacter(character: Model)
	for _, connection in ipairs(self.StruggleConnections) do
		connection:Disconnect()
	end
	table.clear(self.StruggleConnections)

	table.insert(self.StruggleConnections, character:GetAttributeChangedSignal(self.Constants.ATTRIBUTES.IsGrabbed):Connect(function()
		self:UpdateStruggleUI(character)
	end))
	table.insert(
		self.StruggleConnections,
		character:GetAttributeChangedSignal(self.Constants.ATTRIBUTES.GrabStruggleProgress):Connect(function()
			self:UpdateStruggleUI(character)
		end)
	)
	table.insert(
		self.StruggleConnections,
		character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				self:UpdateStruggleUI(nil)
			end
		end)
	)

	self:UpdateStruggleUI(character)
end

function UIController:UpdateStruggleUI(character: Model?)
	if
		self.StruggleMeterContainer == nil
		or self.StruggleMeterFillGradient == nil
		or self.StruggleTapLabel == nil
	then
		return
	end

	if character == nil then
		self.StruggleMeterContainer.Visible = false
		self:UpdateStruggleFill(0)
		return
	end

	local isGrabbed = character:GetAttribute(self.Constants.ATTRIBUTES.IsGrabbed) == true
	local rawProgress = character:GetAttribute(self.Constants.ATTRIBUTES.GrabStruggleProgress)
	local progress = if typeof(rawProgress) == "number" then math.clamp(rawProgress, 0, 1) else 0
	self.StruggleMeterContainer.Visible = isGrabbed
	self:UpdateStruggleFill(progress)
	self.StruggleTapLabel.Text = if isGrabbed then "Tap!" else ""
end

return UIController
