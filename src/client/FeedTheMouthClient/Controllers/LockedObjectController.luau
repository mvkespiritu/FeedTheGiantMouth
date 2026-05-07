--!strict

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local LockedObjectController = {}
LockedObjectController.Name = "LockedObjectController"

local HIGHLIGHT_NAME = "LockedObjectHighlight"
local BILLBOARD_NAME = "LockedObjectBillboard"
local LABEL_NAME = "StrengthLabel"
local CORNER_NAME = "RoundedCorners"
local PADDING_NAME = "TextPadding"
local REFRESH_DELAY = 0.2
local MARKER_FOLDER_NAME = "NearestAvailableMarker"
local MARKER_START_ATTACHMENT_NAME = "NearestMarkerStart"
local MARKER_END_ATTACHMENT_NAME = "NearestMarkerEnd"
local MARKER_BEAM_NAME = "NearestMarkerBeam"
local HOLD_WELD_NAME = "FeedTheMouthHoldWeld"
local MARKER_COLOR_DEFAULT = Color3.fromRGB(94, 210, 255)
local MARKER_COLOR_HOLDING = Color3.fromRGB(95, 235, 120)

function LockedObjectController:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.PlayerDataChanged = context.remotes:WaitForChild("PlayerDataChanged")
	self.LocalPlayer = Players.LocalPlayer
	self.CurrentStrength = 1
	self.RefreshQueued = false
	self.Connections = {}
	self.MarkerTarget = nil
	self.MarkerStartAttachment = nil
	self.MarkerEndAttachment = nil
	self.MarkerBeam = nil
	self.CharacterConnections = {}
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

	table.insert(self.Connections, self.LocalPlayer.CharacterAdded:Connect(function(character)
		self:AttachCharacterListeners(character)
		self:QueueRefresh()
	end))

	local character = self.LocalPlayer.Character
	if character ~= nil then
		self:AttachCharacterListeners(character)
	end

	self:QueueRefresh()
end

function LockedObjectController:AttachCharacterListeners(character: Model)
	for _, connection in ipairs(self.CharacterConnections) do
		connection:Disconnect()
	end
	self.CharacterConnections = {}

	table.insert(self.CharacterConnections, character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("WeldConstraint") and descendant.Name == HOLD_WELD_NAME then
			self:QueueRefresh()
		end
	end))

	table.insert(self.CharacterConnections, character.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("WeldConstraint") and descendant.Name == HOLD_WELD_NAME then
			self:QueueRefresh()
		end
	end))
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
		self:ClearNearestMarker()
		return
	end

	local characterRootPart = self:GetCharacterRootPart()
	local mouthTargetPart = self:GetMouthTargetPart()
	local heldRootPart = self:GetHeldObjectRootPart()
	if heldRootPart ~= nil and mouthTargetPart ~= nil then
		self:RefreshNearestMarker(heldRootPart, mouthTargetPart, MARKER_COLOR_HOLDING)
		return
	end

	local nearestAvailableFeedable = nil
	local nearestAvailableDistance = math.huge

	for _, child in ipairs(feedablesFolder:GetDescendants()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			if child:GetAttribute(self.Constants.ATTRIBUTES.Feedable) == true and self:IsRootFeedable(child, feedablesFolder) then
				self:RefreshFeedable(child)

				if characterRootPart ~= nil and self:IsAvailableFeedable(child) then
					local targetPosition = self:GetFeedablePosition(child)
					if targetPosition ~= nil then
						local distance = (characterRootPart.Position - targetPosition).Magnitude
						if distance < nearestAvailableDistance then
							nearestAvailableDistance = distance
							nearestAvailableFeedable = child
						end
					end
				end
			end
		end
	end

	self:RefreshNearestMarker(characterRootPart, nearestAvailableFeedable, MARKER_COLOR_DEFAULT)
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

function LockedObjectController:GetCharacterRootPart(): BasePart?
	local character = self.LocalPlayer.Character
	if character == nil then
		return nil
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart ~= nil and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart
	end

	return nil
end

function LockedObjectController:IsAvailableFeedable(feedable: Instance): boolean
	local attributes = self.Constants.ATTRIBUTES
	if feedable:GetAttribute(attributes.Consumed) == true then
		return false
	end

	local requiredStrength = feedable:GetAttribute(attributes.RequiredStrength)
	if typeof(requiredStrength) ~= "number" then
		requiredStrength = 1
	end

	return requiredStrength <= self.CurrentStrength
end

function LockedObjectController:GetFeedablePosition(feedable: Instance): Vector3?
	local adornee = self:GetAdornee(feedable)
	if adornee ~= nil then
		return adornee.Position
	end

	return nil
end

function LockedObjectController:GetMouthTargetPart(): BasePart?
	local world = Workspace:FindFirstChild(self.Constants.WORLD_FOLDER_NAME)
	if world == nil then
		return nil
	end

	local mouth = world:FindFirstChild("Mouth")
	if mouth ~= nil then
		local eatZone = mouth:FindFirstChild("EatZone")
		if eatZone ~= nil and eatZone:IsA("BasePart") then
			return eatZone
		end

		local model = mouth:FindFirstChild("MouthModel")
		if model ~= nil and model:IsA("Model") then
			return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		end

		local mouthPart = mouth:FindFirstChildWhichIsA("BasePart", true)
		if mouthPart ~= nil then
			return mouthPart
		end
	end

	local worldEatZone = world:FindFirstChild("EatZone", true)
	if worldEatZone ~= nil and worldEatZone:IsA("BasePart") then
		return worldEatZone
	end

	local worldMouthModel = world:FindFirstChild("MouthModel", true)
	if worldMouthModel ~= nil and worldMouthModel:IsA("Model") then
		return worldMouthModel.PrimaryPart or worldMouthModel:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

function LockedObjectController:GetHeldObjectRootPart(): BasePart?
	local humanoidRootPart = self:GetCharacterRootPart()
	if humanoidRootPart == nil then
		return nil
	end

	local feedablesFolder = self:GetFeedablesFolder()
	if feedablesFolder ~= nil then
		for _, descendant in ipairs(feedablesFolder:GetDescendants()) do
			if descendant:IsA("WeldConstraint") and descendant.Name == HOLD_WELD_NAME then
				local part0 = descendant.Part0
				local part1 = descendant.Part1
				if part0 == humanoidRootPart and part1 ~= nil and part1:IsA("BasePart") then
					return part1
				end

				if part1 == humanoidRootPart and part0 ~= nil and part0:IsA("BasePart") then
					return part0
				end
			end
		end
	end

	return nil
end

function LockedObjectController:RefreshNearestMarker(
	characterRootPart: BasePart?,
	targetInstance: Instance?,
	markerColor: Color3
)
	if characterRootPart == nil or targetInstance == nil then
		self:ClearNearestMarker()
		return
	end

	local targetPart = if targetInstance:IsA("BasePart") then targetInstance else self:GetAdornee(targetInstance)
	if targetPart == nil then
		self:ClearNearestMarker()
		return
	end

	local character = characterRootPart.Parent
	if character == nil then
		self:ClearNearestMarker()
		return
	end

	local markerFolder = character:FindFirstChild(MARKER_FOLDER_NAME)
	if markerFolder == nil then
		markerFolder = Instance.new("Folder")
		markerFolder.Name = MARKER_FOLDER_NAME
		markerFolder.Parent = character
	end

	local startAttachment = characterRootPart:FindFirstChild(MARKER_START_ATTACHMENT_NAME)
	if startAttachment == nil then
		startAttachment = Instance.new("Attachment")
		startAttachment.Name = MARKER_START_ATTACHMENT_NAME
		startAttachment.Parent = characterRootPart
	end

	if self.MarkerEndAttachment ~= nil and self.MarkerEndAttachment.Parent ~= targetPart then
		self.MarkerEndAttachment:Destroy()
		self.MarkerEndAttachment = nil
	end

	local endAttachment = targetPart:FindFirstChild(MARKER_END_ATTACHMENT_NAME)
	if endAttachment == nil then
		endAttachment = Instance.new("Attachment")
		endAttachment.Name = MARKER_END_ATTACHMENT_NAME
		endAttachment.Parent = targetPart
	end

	if startAttachment:IsA("Attachment") then
		startAttachment.Parent = characterRootPart
		startAttachment.Position = Vector3.new(0, 0.5, 0)
	end

	if endAttachment:IsA("Attachment") then
		endAttachment.Parent = targetPart
		endAttachment.Position = Vector3.new(0, 0, 0)
	end

	local beam = markerFolder:FindFirstChild(MARKER_BEAM_NAME)
	if beam == nil then
		beam = Instance.new("Beam")
		beam.Name = MARKER_BEAM_NAME
		beam.Parent = markerFolder
	end

	if beam:IsA("Beam") and startAttachment:IsA("Attachment") and endAttachment:IsA("Attachment") then
		beam.Attachment0 = startAttachment
		beam.Attachment1 = endAttachment
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Width0 = 0.17
		beam.Width1 = 0.17
		beam.Segments = 20
		beam.Color = ColorSequence.new(markerColor)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.08, 0),
			NumberSequenceKeypoint.new(0.12, 1),
			NumberSequenceKeypoint.new(0.22, 1),
			NumberSequenceKeypoint.new(0.26, 0),
			NumberSequenceKeypoint.new(0.34, 0),
			NumberSequenceKeypoint.new(0.38, 1),
			NumberSequenceKeypoint.new(0.48, 1),
			NumberSequenceKeypoint.new(0.52, 0),
			NumberSequenceKeypoint.new(0.6, 0),
			NumberSequenceKeypoint.new(0.64, 1),
			NumberSequenceKeypoint.new(0.74, 1),
			NumberSequenceKeypoint.new(0.78, 0),
			NumberSequenceKeypoint.new(0.86, 0),
			NumberSequenceKeypoint.new(0.9, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Enabled = true
	end

	self.MarkerTarget = targetInstance
	self.MarkerStartAttachment = if startAttachment:IsA("Attachment") then startAttachment else nil
	self.MarkerEndAttachment = if endAttachment:IsA("Attachment") then endAttachment else nil
	self.MarkerBeam = if beam:IsA("Beam") then beam else nil
end

function LockedObjectController:ClearNearestMarker()
	local character = self.LocalPlayer.Character
	if self.MarkerBeam ~= nil then
		self.MarkerBeam:Destroy()
		self.MarkerBeam = nil
	end

	if self.MarkerStartAttachment ~= nil then
		self.MarkerStartAttachment:Destroy()
		self.MarkerStartAttachment = nil
	end

	if self.MarkerEndAttachment ~= nil then
		self.MarkerEndAttachment:Destroy()
		self.MarkerEndAttachment = nil
	end

	if character ~= nil then
		local markerFolder = character:FindFirstChild(MARKER_FOLDER_NAME)
		if markerFolder ~= nil then
			markerFolder:Destroy()
		end
	end

	self.MarkerTarget = nil
end

return LockedObjectController
