--!strict

local Workspace = game:GetService("Workspace")

local LockedObjectController = {}
LockedObjectController.Name = "LockedObjectController"

local HIGHLIGHT_NAME = "LockedObjectHighlight"
local BILLBOARD_NAME = "LockedObjectBillboard"
local LABEL_NAME = "StrengthLabel"
local CORNER_NAME = "RoundedCorners"
local PADDING_NAME = "TextPadding"
local REFRESH_DELAY = 0.2

function LockedObjectController:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.PlayerDataChanged = context.remotes:WaitForChild("PlayerDataChanged")
	self.CurrentStrength = 1
	self.RefreshQueued = false
	self.Connections = {}
end

function LockedObjectController:Start()
	self.PlayerDataChanged.OnClientEvent:Connect(function(data)
		local upgrades = if data ~= nil then data.upgrades else nil
		local strength = if upgrades ~= nil and typeof(upgrades.Strength) == "number" then upgrades.Strength else 1
		self.CurrentStrength = strength
		self:QueueRefresh()
	end)

	local feedablesFolder = self:GetFeedablesFolder()
	if feedablesFolder ~= nil then
		table.insert(self.Connections, feedablesFolder.DescendantAdded:Connect(function()
			self:QueueRefresh()
		end))

		table.insert(self.Connections, feedablesFolder.DescendantRemoving:Connect(function()
			self:QueueRefresh()
		end))
	end

	self:QueueRefresh()
end

function LockedObjectController:GetFeedablesFolder(): Folder?
	local world = Workspace:FindFirstChild(self.Constants.WORLD_FOLDER_NAME)
	if world == nil then
		return nil
	end

	return world:FindFirstChild("FeedableObjects") :: Folder?
end

function LockedObjectController:QueueRefresh()
	if self.RefreshQueued then
		return
	end

	self.RefreshQueued = true
	task.delay(REFRESH_DELAY, function()
		self.RefreshQueued = false
		self:RefreshLockedVisuals()
	end)
end

function LockedObjectController:RefreshLockedVisuals()
	local feedablesFolder = self:GetFeedablesFolder()
	if feedablesFolder == nil then
		return
	end

	for _, child in ipairs(feedablesFolder:GetDescendants()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			if child:GetAttribute(self.Constants.ATTRIBUTES.Feedable) == true and self:IsRootFeedable(child, feedablesFolder) then
				self:RefreshFeedable(child)
			end
		end
	end
end

function LockedObjectController:IsRootFeedable(feedable: Instance, feedablesFolder: Folder): boolean
	local current = feedable.Parent

	while current ~= nil and current ~= feedablesFolder do
		if current:GetAttribute(self.Constants.ATTRIBUTES.Feedable) == true then
			return false
		end

		current = current.Parent
	end

	return true
end

function LockedObjectController:RefreshFeedable(feedable: Instance)
	local attributes = self.Constants.ATTRIBUTES
	local consumed = feedable:GetAttribute(attributes.Consumed) == true
	local requiredStrength = feedable:GetAttribute(attributes.RequiredStrength)
	local isLocked = not consumed
		and typeof(requiredStrength) == "number"
		and requiredStrength > self.CurrentStrength

	if isLocked then
		self:EnsureLockedVisuals(feedable, requiredStrength)
	else
		self:ClearLockedVisuals(feedable)
	end
end

function LockedObjectController:EnsureLockedVisuals(feedable: Instance, requiredStrength: number)
	local adornee = self:GetAdornee(feedable)
	if adornee == nil then
		return
	end

	local highlight = feedable:FindFirstChild(HIGHLIGHT_NAME)
	if highlight == nil then
		highlight = Instance.new("Highlight")
		highlight.Name = HIGHLIGHT_NAME
		highlight.Parent = feedable
	end

	if highlight:IsA("Highlight") then
		highlight.Adornee = feedable
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillColor = Color3.fromRGB(28, 28, 32)
		highlight.FillTransparency = 0.45
		highlight.OutlineColor = Color3.fromRGB(150, 150, 160)
		highlight.OutlineTransparency = 0.35
		highlight.Enabled = true
	end

	local billboard = feedable:FindFirstChild(BILLBOARD_NAME)
	if billboard == nil then
		billboard = Instance.new("BillboardGui")
		billboard.Name = BILLBOARD_NAME
		billboard.Parent = feedable
	end

	if billboard:IsA("BillboardGui") then
		billboard.Adornee = adornee
		billboard.AlwaysOnTop = true
		billboard.LightInfluence = 0
		billboard.MaxDistance = 70
		billboard.Size = UDim2.fromOffset(86, 24)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, self:GetBillboardHeight(feedable), 0)
		billboard.Enabled = true

		local label = billboard:FindFirstChild(LABEL_NAME)
		if label == nil then
			label = Instance.new("TextLabel")
			label.Name = LABEL_NAME
			label.BackgroundTransparency = 0.2
			label.BorderSizePixel = 0
			label.Size = UDim2.fromScale(1, 1)
			label.Parent = billboard
		end

		if label:IsA("TextLabel") then
			label.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
			label.Font = Enum.Font.GothamBold
			label.Text = `Strength {requiredStrength}`
			label.TextColor3 = Color3.fromRGB(220, 220, 225)
			label.TextScaled = true
			label.TextWrapped = true

			local corner = label:FindFirstChild(CORNER_NAME)
			if corner == nil then
				corner = Instance.new("UICorner")
				corner.Name = CORNER_NAME
				corner.Parent = label
			end

			if corner:IsA("UICorner") then
				corner.CornerRadius = UDim.new(0, 6)
			end

			local padding = label:FindFirstChild(PADDING_NAME)
			if padding == nil then
				padding = Instance.new("UIPadding")
				padding.Name = PADDING_NAME
				padding.Parent = label
			end

			if padding:IsA("UIPadding") then
				padding.PaddingLeft = UDim.new(0, 8)
				padding.PaddingRight = UDim.new(0, 8)
			end
		end
	end
end

function LockedObjectController:ClearLockedVisuals(feedable: Instance)
	local highlight = feedable:FindFirstChild(HIGHLIGHT_NAME)
	if highlight ~= nil then
		highlight:Destroy()
	end

	local billboard = feedable:FindFirstChild(BILLBOARD_NAME)
	if billboard ~= nil then
		billboard:Destroy()
	end
end

function LockedObjectController:GetAdornee(feedable: Instance): BasePart?
	if feedable:IsA("BasePart") then
		return feedable
	end

	if feedable:IsA("Model") then
		return feedable.PrimaryPart or feedable:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

function LockedObjectController:GetBillboardHeight(feedable: Instance): number
	if feedable:IsA("Model") then
		local _, size = feedable:GetBoundingBox()
		return math.max(3, (size.Y / 2) + 1.75)
	elseif feedable:IsA("BasePart") then
		return math.max(3, (feedable.Size.Y / 2) + 1.75)
	end

	return 4
end

return LockedObjectController
