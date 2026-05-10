--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIController = {}
UIController.Name = "UIController"

local NEW_ITEM_POPUP_NAME = "NewItemPopup"
local NEW_ITEM_POPUP_HOLD_SECONDS = 1.65

function UIController:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.UpgradeConfig = require(context.shared.UpgradeConfig)
	self.PlayerDataChanged = context.remotes:WaitForChild("PlayerDataChanged")
	self.RewardMessageId = 0
	self.StatusMessageId = 0
	self.NewItemMessageId = 0
	self.CurrentPlayerData = nil
	self.UpgradeLevelLabelsById = {}
	self.StruggleConnections = {}
	self.IsStruggleUIVisible = false
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
	self:BuildNewItemPopup()
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

function UIController:BuildNewItemPopup()
	if self.FeedbackFrame == nil then
		return
	end

	local popup = self.FeedbackFrame:FindFirstChild(NEW_ITEM_POPUP_NAME)
	if popup == nil then
		popup = Instance.new("TextLabel")
		popup.Name = NEW_ITEM_POPUP_NAME
		popup.AnchorPoint = Vector2.new(0.5, 0)
		popup.Position = UDim2.fromScale(0.5, 0.08)
		popup.Size = UDim2.new(0.72, 0, 0, 76)
		popup.BackgroundColor3 = Color3.fromRGB(18, 22, 31)
		popup.BackgroundTransparency = 0.04
		popup.BorderSizePixel = 0
		popup.Font = Enum.Font.GothamBlack
		popup.RichText = true
		popup.TextColor3 = Color3.fromRGB(255, 255, 255)
		popup.TextStrokeTransparency = 0.9
		popup.TextScaled = false
		popup.TextSize = 24
		popup.TextWrapped = true
		popup.LineHeight = 0.92
		popup.Visible = false
		popup.ZIndex = 20
		popup.Parent = self.FeedbackFrame

		local sizeConstraint = Instance.new("UISizeConstraint")
		sizeConstraint.MinSize = Vector2.new(240, 68)
		sizeConstraint.MaxSize = Vector2.new(460, 76)
		sizeConstraint.Parent = popup

		local textConstraint = Instance.new("UITextSizeConstraint")
		textConstraint.MinTextSize = 14
		textConstraint.MaxTextSize = 24
		textConstraint.Parent = popup

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = popup

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(105, 64, 18)
		stroke.Thickness = 1.5
		stroke.Transparency = 0.18
		stroke.Parent = popup

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 16)
		padding.PaddingRight = UDim.new(0, 16)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = popup
	end

	if popup:IsA("TextLabel") then
		self.NewItemPopup = popup
	end
end

function UIController:EscapeRichText(text: string): string
	local escaped = string.gsub(text, "&", "&amp;")
	escaped = string.gsub(escaped, "<", "&lt;")
	escaped = string.gsub(escaped, ">", "&gt;")
	return escaped
end

function UIController:ShowNewItem(itemName: string)
	self.NewItemMessageId += 1
	local messageId = self.NewItemMessageId

	if self.NewItemPopup == nil then
		self:BuildNewItemPopup()
	end

	local popup = self.NewItemPopup
	if popup == nil or not popup:IsA("TextLabel") then
		return
	end

	local escapedItemName = self:EscapeRichText(itemName)
	popup.Text = `<font size="20" color="#FFE36A">NEW ITEM!</font>\n<font size="28" color="#FFFFFF">{escapedItemName}</font>`
	popup.Visible = true
	popup.TextTransparency = 1
	popup.BackgroundTransparency = 1
	popup.Position = UDim2.fromScale(0.5, 0.055)

	local stroke = popup:FindFirstChildOfClass("UIStroke")
	if stroke ~= nil then
		stroke.Transparency = 1
	end

	TweenService:Create(
		popup,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			TextTransparency = 0,
			BackgroundTransparency = 0.04,
			Position = UDim2.fromScale(0.5, 0.08),
		}
	):Play()

	if stroke ~= nil then
		TweenService:Create(
			stroke,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Transparency = 0.18 }
		):Play()
	end

	task.delay(NEW_ITEM_POPUP_HOLD_SECONDS, function()
		if self.NewItemMessageId ~= messageId or popup.Parent == nil then
			return
		end

		local fadeTween = TweenService:Create(
			popup,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				TextTransparency = 1,
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.055),
			}
		)
		fadeTween:Play()
		if stroke ~= nil then
			TweenService:Create(
				stroke,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1 }
			):Play()
		end
		fadeTween.Completed:Connect(function()
			if self.NewItemMessageId == messageId then
				popup.Visible = false
			end
		end)
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
	local pulseScale = container:FindFirstChild("PulseScale")

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

	if pulseScale == nil then
		pulseScale = Instance.new("UIScale")
		pulseScale.Name = "PulseScale"
		pulseScale.Parent = container
	end

	if not pulseScale:IsA("UIScale") then
		warn("StruggleMeterContainer.PulseScale must be a UIScale")
		return
	end

	container.Visible = false
	tapLabel.Rotation = 0
	pulseScale.Scale = 1

	self.StruggleMeterContainer = container
	self.StruggleMeterFill = fill
	self.StruggleMeterFillGradient = fillGradient
	self.StrugglePulseScale = pulseScale
	self.StruggleTapLabel = tapLabel
	self:UpdateStruggleFill(0)
end

function UIController:StartStruggleAnimations()
	if self.StruggleTapLabel == nil or self.StrugglePulseScale == nil then
		return
	end

	self:StopStruggleAnimations()

	self.StruggleTapLabel.Rotation = -7
	self.StruggleTapWiggleTween = TweenService:Create(
		self.StruggleTapLabel,
		TweenInfo.new(0.11, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Rotation = 7 }
	)
	self.StruggleTapWiggleTween:Play()

	self.StrugglePulseScale.Scale = 1
	self.StrugglePulseTween = TweenService:Create(
		self.StrugglePulseScale,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true),
		{ Scale = 1.08 }
	)
	self.StrugglePulseTween:Play()
end

function UIController:StopStruggleAnimations()
	if self.StruggleTapWiggleTween ~= nil then
		self.StruggleTapWiggleTween:Cancel()
		self.StruggleTapWiggleTween = nil
	end

	if self.StrugglePulseTween ~= nil then
		self.StrugglePulseTween:Cancel()
		self.StrugglePulseTween = nil
	end

	if self.StruggleTapLabel ~= nil then
		self.StruggleTapLabel.Rotation = 0
	end

	if self.StrugglePulseScale ~= nil then
		self.StrugglePulseScale.Scale = 1
	end
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
		if self.IsStruggleUIVisible then
			self:StopStruggleAnimations()
			self.IsStruggleUIVisible = false
		end
		self:UpdateStruggleFill(0)
		return
	end

	local isGrabbed = character:GetAttribute(self.Constants.ATTRIBUTES.IsGrabbed) == true
	local rawProgress = character:GetAttribute(self.Constants.ATTRIBUTES.GrabStruggleProgress)
	local progress = if typeof(rawProgress) == "number" then math.clamp(rawProgress, 0, 1) else 0
	self.StruggleMeterContainer.Visible = isGrabbed
	if isGrabbed and not self.IsStruggleUIVisible then
		self:StartStruggleAnimations()
		self.IsStruggleUIVisible = true
	elseif not isGrabbed and self.IsStruggleUIVisible then
		self:StopStruggleAnimations()
		self.IsStruggleUIVisible = false
	end
	self:UpdateStruggleFill(if isGrabbed then progress else 0)
	self.StruggleTapLabel.Text = if isGrabbed then "Tap!" else ""
end

return UIController
