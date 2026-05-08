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

	local container = Instance.new("Frame")
	container.Name = "StruggleMeterContainer"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.new(0.75, 0, 0.5, 0)
	container.Size = UDim2.fromOffset(138, 138)
	container.BackgroundColor3 = Color3.fromRGB(24, 30, 39)
	container.BackgroundTransparency = 0.35
	container.BorderSizePixel = 0
	container.ClipsDescendants = true
	container.Visible = false
	container.Parent = self.MainHUD
	local containerAspect = Instance.new("UIAspectRatioConstraint")
	containerAspect.AspectRatio = 1
	containerAspect.Parent = container
	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(1, 0)
	containerCorner.Parent = container
	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = Color3.fromRGB(255, 255, 255)
	containerStroke.Thickness = 2
	containerStroke.Transparency = 0.25
	containerStroke.Parent = container

	local fill = Instance.new("Frame")
	fill.Name = "MeterFill"
	fill.AnchorPoint = Vector2.new(0, 0)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 130, 76)
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = container
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 88, 88)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 220, 110)),
	})
	fillGradient.Rotation = 90
	fillGradient.Parent = fill

	local tapLabel = Instance.new("TextLabel")
	tapLabel.Name = "TapLabel"
	tapLabel.BackgroundTransparency = 1
	tapLabel.Size = UDim2.fromScale(1, 1)
	tapLabel.Font = Enum.Font.GothamBlack
	tapLabel.Text = "Tap!"
	tapLabel.TextSize = 34
	tapLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	tapLabel.TextStrokeColor3 = Color3.fromRGB(13, 15, 20)
	tapLabel.TextStrokeTransparency = 0.35
	tapLabel.ZIndex = 3
	tapLabel.Parent = container

	self.StruggleMeterContainer = container
	self.StruggleMeterFill = fill
	self.StruggleTapLabel = tapLabel
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
	if self.StruggleMeterContainer == nil or self.StruggleMeterFill == nil or self.StruggleTapLabel == nil then
		return
	end

	if character == nil then
		self.StruggleMeterContainer.Visible = false
		self.StruggleMeterFill.Position = UDim2.fromScale(0, 1)
		return
	end

	local isGrabbed = character:GetAttribute(self.Constants.ATTRIBUTES.IsGrabbed) == true
	local rawProgress = character:GetAttribute(self.Constants.ATTRIBUTES.GrabStruggleProgress)
	local progress = if typeof(rawProgress) == "number" then math.clamp(rawProgress, 0, 1) else 0
	self.StruggleMeterContainer.Visible = isGrabbed
	self.StruggleMeterFill.Position = UDim2.fromScale(0, 1 - progress)
	self.StruggleTapLabel.Text = if isGrabbed then "Tap!" else ""
end

return UIController
