--!strict

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local FeedbackController = {}
FeedbackController.Name = "FeedbackController"

local DISCOVERY_HIGHLIGHT_NAME = "NewItemDiscoveryHighlight"
local DISCOVERY_SPARKLES_NAME = "NewItemDiscoverySparkles"
local DISCOVERY_LIGHT_NAME = "NewItemDiscoveryLight"
local DISCOVERY_COLOR = Color3.fromRGB(255, 221, 94)
local DISCOVERY_DURATION = 1.25

function FeedbackController:Init(context)
	self.Context = context
	self.PlayFeedback = context.remotes:WaitForChild("PlayFeedback")
end

function FeedbackController:Start()
	self.PlayFeedback.OnClientEvent:Connect(function(feedbackName, payload)
		self:HandleFeedback(feedbackName, payload)
	end)
end

function FeedbackController:HandleFeedback(feedbackName: string, payload)
	payload = payload or {}

	if feedbackName == "Reward" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowReward(payload.amount or 0)
		end
	elseif feedbackName == "LockedObject" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowLockMessage(payload.requiredStrength or 1)
		end
	elseif feedbackName == "NotEnoughCoins" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowStatusMessage(`Need {payload.cost or 0} coins`)
		end
	elseif feedbackName == "UpgradeMaxed" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowStatusMessage(`{payload.displayName or "Upgrade"} maxed`)
		end
	elseif feedbackName == "UpgradePurchased" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowStatusMessage(`{payload.displayName or "Upgrade"} level {payload.level or "?"}`)
		end
	elseif feedbackName == "StatusMessage" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowStatusMessage(payload.message or "")
		end
	elseif feedbackName == "NewItemDiscovered" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowNewItem(payload.itemName or "Object")
		end

		self:PlayDiscoveryEffects(payload.feedable)
	end
end

function FeedbackController:PlayDiscoveryEffects(feedable)
	if typeof(feedable) ~= "Instance" then
		return
	end

	local rootPart = self:GetRootPart(feedable)
	if rootPart == nil then
		return
	end

	self:CreateDiscoveryHighlight(feedable)
	self:CreateDiscoverySparkles(rootPart)
	self:CreateDiscoveryLight(rootPart)
end

function FeedbackController:GetRootPart(feedable: Instance): BasePart?
	if feedable:IsA("BasePart") then
		return feedable
	end

	if not feedable:IsA("Model") then
		return nil
	end

	if feedable.PrimaryPart ~= nil then
		return feedable.PrimaryPart
	end

	return feedable:FindFirstChildWhichIsA("BasePart", true)
end

function FeedbackController:CreateDiscoveryHighlight(feedable: Instance)
	local highlight = Instance.new("Highlight")
	highlight.Name = DISCOVERY_HIGHLIGHT_NAME
	highlight.Adornee = feedable
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = DISCOVERY_COLOR
	highlight.FillTransparency = 0.35
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0
	highlight.Parent = feedable

	TweenService:Create(
		highlight,
		TweenInfo.new(DISCOVERY_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			FillTransparency = 1,
			OutlineTransparency = 1,
		}
	):Play()

	Debris:AddItem(highlight, DISCOVERY_DURATION + 0.1)
end

function FeedbackController:CreateDiscoverySparkles(rootPart: BasePart)
	local sparkles = Instance.new("Sparkles")
	sparkles.Name = DISCOVERY_SPARKLES_NAME
	sparkles.SparkleColor = DISCOVERY_COLOR
	sparkles.Parent = rootPart

	task.delay(0.85, function()
		if sparkles.Parent ~= nil then
			sparkles.Enabled = false
		end
	end)

	Debris:AddItem(sparkles, DISCOVERY_DURATION + 0.35)
end

function FeedbackController:CreateDiscoveryLight(rootPart: BasePart)
	local light = Instance.new("PointLight")
	light.Name = DISCOVERY_LIGHT_NAME
	light.Color = DISCOVERY_COLOR
	light.Brightness = 2.5
	light.Range = 10
	light.Parent = rootPart

	TweenService:Create(
		light,
		TweenInfo.new(DISCOVERY_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Brightness = 0,
			Range = 4,
		}
	):Play()

	Debris:AddItem(light, DISCOVERY_DURATION + 0.1)
end

return FeedbackController
