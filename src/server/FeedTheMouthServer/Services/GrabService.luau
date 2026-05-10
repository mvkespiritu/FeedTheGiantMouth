--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GrabService = {}
GrabService.Name = "GrabService"

local HOLD_DISTANCE = 6
local MAX_GRAB_DISTANCE = 24
local HOLD_HORIZONTAL_SPACING = 3.25
local HOLD_VERTICAL_SPACING = 2.25
local HOLD_DEPTH_SPACING = 1.25
local BASE_THROW_SPEED = 55 --93.75
local ABSURD_GRAB_DISTANCE_MIN_BONUS = 8
local ABSURD_GRAB_DISTANCE_MAX_BONUS = 40
local THROW_CHARACTER_COLLISION_GRACE_SECONDS = 0.45
local THROW_POWER_PER_LEVEL = 12.5
local THROW_UPWARD_SPEED = 50
local DEFAULT_WALK_SPEED = 16
local MIN_WALK_SPEED_MULTIPLIER = 0.45
local WEIGHT_SPEED_PENALTY_PER_UNIT = 0.03
local STRENGTH_WEIGHT_REDUCTION_PER_LEVEL = 6
local THROW_WEIGHT_PENALTY_PER_UNIT = 0.015
local MIN_THROW_SPEED_MULTIPLIER = 0.55
local INTERNAL_WELD_NAME = "FeedTheMouthInternalWeld"
local HOLD_WELD_NAME = "FeedTheMouthHoldWeld"
local PLAYER_GRAB_WEIGHT = 1
local PLAYER_CARRY_BOTTOM_OFFSET = 3
local HELD_PLAYER_WALK_SPEED = 0
local HELD_PLAYER_JUMP_POWER = 0
local HELD_PLAYER_JUMP_HEIGHT = 0
local PLAYER_THROW_OWNERSHIP_RESTORE_DELAY = 0.12
local PLAYER_THROW_SPEED_MULTIPLIER = 1.5 --1
local PLAYER_THROW_WEIGHT_PENALTY_PER_UNIT = 0.01 --0.05
local PLAYER_THROW_STRENGTH_REDUCTION_PER_LEVEL = 0.5 --2
local PLAYER_THROW_MIN_SPEED_MULTIPLIER = 0.55 --0.35
local STRUGGLE_FILL_PER_TAP = 0.08 --0.15
local STRUGGLE_DECAY_PER_SECOND = 0.125
local STRUGGLE_TAP_COOLDOWN = 0.06
local STRUGGLE_ESCAPE_THRESHOLD = 1
local PLAYER_DROP_GRAB_COOLDOWN = 3
local PLAYER_GRAB_COOLDOWN_BILLBOARD_NAME = "GrabCooldownBillboard"

function GrabService:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.RequestGrabRemote = context.remotes:WaitForChild("RequestGrab")
	self.RequestReleaseRemote = context.remotes:WaitForChild("RequestRelease")
	self.RequestThrowRemote = context.remotes:WaitForChild("RequestThrow")
	self.RequestStruggleRemote = context.remotes:WaitForChild("RequestStruggle")
	self.HeldByPlayer = {}
	self.BaseWalkSpeedByPlayer = {}
	self.HeldCharacterStateByPlayer = {}
	self.LastStruggleRequestByPlayer = {}
	self.PlayerGrabCooldownUntil = {}
	self.StruggleHeartbeatConnection = nil
end

function GrabService:Start()
	self.RequestGrabRemote.OnServerEvent:Connect(function(player, feedable)
		self:RequestGrab(player, feedable)
	end)

	self.RequestReleaseRemote.OnServerEvent:Connect(function(player)
		self:RequestRelease(player)
	end)

	self.RequestThrowRemote.OnServerEvent:Connect(function(player, direction)
		self:RequestThrow(player, direction)
	end)

	self.RequestStruggleRemote.OnServerEvent:Connect(function(player)
		self:RequestStruggle(player)
	end)

	if self.StruggleHeartbeatConnection ~= nil then
		self.StruggleHeartbeatConnection:Disconnect()
		self.StruggleHeartbeatConnection = nil
	end

	self.StruggleHeartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self:UpdateHeldCharacterStruggles(deltaTime)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:ClearHeld(player)
		self.BaseWalkSpeedByPlayer[player] = nil
		self.HeldCharacterStateByPlayer[player] = nil
		self.LastStruggleRequestByPlayer[player] = nil
		self.PlayerGrabCooldownUntil[player] = nil
	end)
end

function GrabService:RequestGrab(player, feedable)
	if self:IsPlayerCharacterHeld(player) then
		return
	end

	if typeof(feedable) ~= "Instance" then
		return
	end

	local feedableService = self.Context.services.FeedableService
	local upgradeService = self.Context.services.UpgradeService
	local target, isPlayerCharacter = self:ResolveGrabbableTarget(player, feedable)
	if target == nil then
		return
	end

	if isPlayerCharacter then
		local targetPlayer = if target:IsA("Model") then Players:GetPlayerFromCharacter(target) else nil
		if targetPlayer == nil or self:IsPlayerGrabCoolingDown(targetPlayer) then
			return
		end
	end

	if self:GetHeldEntry(player, target) ~= nil then
		self:RequestThrow(player, nil, target)
		return
	end

	if self:IsFeedableHeld(target) then
		return
	end

	if not isPlayerCharacter and not feedableService:IsFeedable(target) then
		return
	end

	if not isPlayerCharacter and target:GetAttribute(self.Constants.ATTRIBUTES.Consumed) == true then
		return
	end

	local requiredStrength = if isPlayerCharacter
		then 1
		else (target:GetAttribute(self.Constants.ATTRIBUTES.RequiredStrength) or 1)
	if not upgradeService:CanHandleTier(player, requiredStrength) then
		self.Context.services.FeedbackService:Play(player, "LockedObject", {
			requiredStrength = requiredStrength,
		})
		return
	end

	local character = player.Character
	local humanoidRootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoidRootPart == nil or not humanoidRootPart:IsA("BasePart") then
		return
	end

	local rootPart = if isPlayerCharacter
		then self:GetCharacterRootPart(target)
		else feedableService:GetRootPart(target)
	if rootPart == nil then
		return
	end

	local heldList = self:GetHeldList(player)
	local carryCapacity = self:GetCarryCapacity(player)
	if #heldList >= carryCapacity then
		self:RequestThrow(player)
		return
	end

	local maxGrabDistance = if isPlayerCharacter then MAX_GRAB_DISTANCE else self:GetMaxGrabDistance(target)
	if (rootPart.Position - humanoidRootPart.Position).Magnitude > maxGrabDistance then
		return
	end

	self:PrepareTargetForHold(target, rootPart, isPlayerCharacter)
	self:AddHeldObject(player, target, rootPart, humanoidRootPart, isPlayerCharacter)
	if not isPlayerCharacter then
		target:SetAttribute(self.Constants.ATTRIBUTES.LastHolderUserId, player.UserId)
	end
	self.Context.services.FeedbackService:Play(player, "GrabObject", {})

	if not isPlayerCharacter then
		local feedableService = self.Context.services.FeedableService
		local itemId = feedableService:GetFeedableItemId(target)
		if self.Context.services.PlayerDataService:TryDiscoverItem(player, itemId) then
			self.Context.services.FeedbackService:Play(player, "NewItemDiscovered", {
				itemName = feedableService:GetFeedableDisplayName(target),
				feedable = target,
				position = rootPart.Position,
			})
		end
	end
end

function GrabService:ResolveGrabbableTarget(player, instance: Instance): (Instance?, boolean)
	local feedableService = self.Context.services.FeedableService
	local feedable = feedableService:FindFeedableFromInstance(instance)
	if feedable ~= nil then
		return feedable, false
	end

	local character = self:FindCharacterFromInstance(instance)
	if character == nil then
		return nil, false
	end

	local targetPlayer = Players:GetPlayerFromCharacter(character)
	if targetPlayer == nil or targetPlayer == player then
		return nil, false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil, false
	end

	return character, true
end

function GrabService:FindCharacterFromInstance(instance: Instance): Model?
	local current: Instance? = instance
	while current ~= nil do
		if current:IsA("Model") and current:FindFirstChild("HumanoidRootPart") ~= nil then
			return current
		end

		current = current.Parent
	end

	return nil
end

function GrabService:GetCharacterRootPart(character: Instance): BasePart?
	if not character:IsA("Model") then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart ~= nil and rootPart:IsA("BasePart") then
		return rootPart
	end

	return nil
end

function GrabService:PrepareTargetForHold(feedable: Instance, rootPart: BasePart, isPlayerCharacter: boolean)
	if isPlayerCharacter then
		rootPart.Anchored = false
		rootPart.CanCollide = false
		return
	end

	local feedableService = self.Context.services.FeedableService
	local parts = feedableService:GetBaseParts(feedable)

	for _, part in ipairs(parts) do
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true

		if part ~= rootPart then
			local alreadyWelded = false
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("WeldConstraint") and child.Name == INTERNAL_WELD_NAME then
					alreadyWelded = true
					break
				end
			end

			if not alreadyWelded then
				local weld = Instance.new("WeldConstraint")
				weld.Name = INTERNAL_WELD_NAME
				weld.Part0 = rootPart
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
end

function GrabService:AddHeldObject(
	player,
	feedable: Instance,
	rootPart: BasePart,
	humanoidRootPart: BasePart,
	isPlayerCharacter: boolean
)
	if isPlayerCharacter and feedable:IsA("Model") then
		local heldPlayer = Players:GetPlayerFromCharacter(feedable)
		if heldPlayer ~= nil then
			self:ClearHeld(heldPlayer)
			self:BeginHeldCharacterState(heldPlayer, player)
		end
	end

	local heldCharacterControlState = self:DisableHeldCharacterControl(feedable, isPlayerCharacter)
	local heldList = self:GetHeldList(player)
	table.insert(heldList, {
		feedable = feedable,
		rootPart = rootPart,
		isPlayerCharacter = isPlayerCharacter,
		heldCharacterControlState = heldCharacterControlState,
		noCollisionConstraints = self:CreateCharacterNoCollisionConstraints(player, feedable),
	})

	self:RepositionHeldObjects(player, humanoidRootPart)
end

function GrabService:RepositionHeldObjects(player, humanoidRootPart: BasePart?)
	humanoidRootPart = humanoidRootPart or self:GetHumanoidRootPart(player)
	if humanoidRootPart == nil then
		return
	end

	local heldList = self:GetHeldList(player)
	for index = #heldList, 1, -1 do
		local held = heldList[index]
		if not self:IsHeldEntryValid(held) then
			self:DetachHeldEntry(held)
			table.remove(heldList, index)
		end
	end

	for index, held in ipairs(heldList) do
		local rootPart = held.rootPart
		local oldWeld = held.holdWeld
		if typeof(oldWeld) == "Instance" and oldWeld.Parent ~= nil then
			oldWeld:Destroy()
		end

		local offset = self:GetHoldOffset(index)
		local carryCFrame = humanoidRootPart.CFrame
			* offset
			* CFrame.new(0, self:GetCarryBottomOffset(held.feedable), 0)
		if held.feedable:IsA("Model") then
			held.feedable:PivotTo(carryCFrame)
		else
			rootPart.CFrame = carryCFrame
		end

		local weld = Instance.new("WeldConstraint")
		weld.Name = HOLD_WELD_NAME
		weld.Part0 = humanoidRootPart
		weld.Part1 = rootPart
		weld.Parent = rootPart
		held.holdWeld = weld

		pcall(function()
			rootPart:SetNetworkOwner(player)
		end)
	end

	self:UpdatePlayerHandling(player)
end

function GrabService:GetHoldOffset(index: number): CFrame
	if index == 1 then
		return CFrame.new(0, 0, -HOLD_DISTANCE)
	end

	local adjustedIndex = index - 2
	local row = math.floor(adjustedIndex / 3)
	local column = adjustedIndex % 3
	local x = ({ -1, 1, 0 })[column + 1] * HOLD_HORIZONTAL_SPACING
	local y = 0.75 + ((row + 1) * HOLD_VERTICAL_SPACING)
	local z = -HOLD_DISTANCE - ((row + 1) * HOLD_DEPTH_SPACING)

	return CFrame.new(x, y, z)
end

function GrabService:GetMaxGrabDistance(feedable: Instance): number
	local maxGrabDistance = MAX_GRAB_DISTANCE
	local tier = feedable:GetAttribute(self.Constants.ATTRIBUTES.Tier)
	if tier ~= self.Constants.TIERS.Absurd then
		return maxGrabDistance
	end

	local boundsSize = self:GetFeedableBoundsSize(feedable)
	local boundsRadius = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z) * 0.5
	local absurdBonus = math.clamp(boundsRadius, ABSURD_GRAB_DISTANCE_MIN_BONUS, ABSURD_GRAB_DISTANCE_MAX_BONUS)
	return maxGrabDistance + absurdBonus
end

function GrabService:GetFeedableBoundsSize(feedable: Instance): Vector3
	if feedable:IsA("BasePart") then
		return feedable.Size
	end

	if feedable:IsA("Model") then
		local _boundsCFrame, boundsSize = feedable:GetBoundingBox()
		return boundsSize
	end

	return Vector3.new(4, 4, 4)
end

function GrabService:GetCarryBottomOffset(feedable: Instance): number
	local targetPlayer = if feedable:IsA("Model") then Players:GetPlayerFromCharacter(feedable) else nil
	if targetPlayer ~= nil then
		return PLAYER_CARRY_BOTTOM_OFFSET
	end

	if feedable:IsA("BasePart") then
		return feedable.Size.Y * 0.5
	end

	if feedable:IsA("Model") then
		local boundsCFrame, boundsSize = feedable:GetBoundingBox()
		local bottomY = boundsCFrame.Position.Y - (boundsSize.Y * 0.5)
		return math.max(0, feedable:GetPivot().Position.Y - bottomY)
	end

	return 0
end

function GrabService:GetCharacterBaseParts(player): { BasePart }
	local character = player.Character
	if character == nil then
		return {}
	end

	local parts = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

function GrabService:CreateCharacterNoCollisionConstraints(player, feedable: Instance): { NoCollisionConstraint }
	local feedableService = self.Context.services.FeedableService
	local feedableParts = feedableService:GetBaseParts(feedable)
	local characterParts = self:GetCharacterBaseParts(player)
	local constraints = {}

	if #feedableParts == 0 or #characterParts == 0 then
		return constraints
	end

	for _, feedablePart in ipairs(feedableParts) do
		for _, characterPart in ipairs(characterParts) do
			local noCollision = Instance.new("NoCollisionConstraint")
			noCollision.Part0 = feedablePart
			noCollision.Part1 = characterPart
			noCollision.Parent = feedablePart
			table.insert(constraints, noCollision)
		end
	end

	return constraints
end

function GrabService:ClearNoCollisionConstraints(constraints: { NoCollisionConstraint }?)
	if constraints == nil then
		return
	end

	for _, constraint in ipairs(constraints) do
		if constraint.Parent ~= nil then
			constraint:Destroy()
		end
	end
end

function GrabService:DisableHeldCharacterControl(feedable: Instance, isPlayerCharacter: boolean): any?
	if not isPlayerCharacter or not feedable:IsA("Model") then
		return nil
	end

	local humanoid = feedable:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end

	local state = {
		humanoid = humanoid,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
		autoRotate = humanoid.AutoRotate,
	}

	humanoid.WalkSpeed = HELD_PLAYER_WALK_SPEED
	humanoid.JumpPower = HELD_PLAYER_JUMP_POWER
	humanoid.JumpHeight = HELD_PLAYER_JUMP_HEIGHT
	humanoid.AutoRotate = false

	return state
end

function GrabService:RestoreHeldCharacterControl(state)
	if typeof(state) ~= "table" then
		return
	end

	local humanoid = state.humanoid
	if typeof(humanoid) ~= "Instance" or not humanoid:IsA("Humanoid") or humanoid.Parent == nil then
		return
	end

	if typeof(state.walkSpeed) == "number" then
		humanoid.WalkSpeed = state.walkSpeed
	end

	if typeof(state.jumpPower) == "number" then
		humanoid.JumpPower = state.jumpPower
	end

	if typeof(state.jumpHeight) == "number" then
		humanoid.JumpHeight = state.jumpHeight
	end

	if typeof(state.autoRotate) == "boolean" then
		humanoid.AutoRotate = state.autoRotate
	end
end

function GrabService:BeginHeldCharacterState(heldPlayer, holder)
	local character = heldPlayer.Character
	if character == nil then
		return
	end

	local heldState = self.HeldCharacterStateByPlayer[heldPlayer]
	if heldState == nil then
		heldState = {}
		self.HeldCharacterStateByPlayer[heldPlayer] = heldState
	end

	heldState.character = character
	heldState.holder = holder
	heldState.progress = 0
	character:SetAttribute(self.Constants.ATTRIBUTES.IsGrabbed, true)
	character:SetAttribute(self.Constants.ATTRIBUTES.GrabStruggleProgress, 0)
end

function GrabService:EndHeldCharacterState(heldPlayer)
	local heldState = self.HeldCharacterStateByPlayer[heldPlayer]
	self.HeldCharacterStateByPlayer[heldPlayer] = nil
	self.LastStruggleRequestByPlayer[heldPlayer] = nil
	self.PlayerGrabCooldownUntil[heldPlayer] = os.clock() + PLAYER_DROP_GRAB_COOLDOWN
	self:ShowPlayerGrabCooldownBillboard(heldPlayer)

	local character = heldPlayer.Character
	if
		character == nil
		and heldState ~= nil
		and typeof(heldState.character) == "Instance"
		and heldState.character:IsA("Model")
	then
		character = heldState.character
	end

	if character ~= nil then
		character:SetAttribute(self.Constants.ATTRIBUTES.IsGrabbed, false)
		character:SetAttribute(self.Constants.ATTRIBUTES.GrabStruggleProgress, 0)
	end
end

function GrabService:IsPlayerGrabCoolingDown(player): boolean
	local cooldownUntil = self.PlayerGrabCooldownUntil[player]
	if typeof(cooldownUntil) ~= "number" then
		return false
	end

	if os.clock() >= cooldownUntil then
		self.PlayerGrabCooldownUntil[player] = nil
		return false
	end

	return true
end

function GrabService:ShowPlayerGrabCooldownBillboard(player)
	local character = player.Character
	if character == nil then
		return
	end

	local adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if adornee == nil or not adornee:IsA("BasePart") then
		return
	end

	local existing = character:FindFirstChild(PLAYER_GRAB_COOLDOWN_BILLBOARD_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = PLAYER_GRAB_COOLDOWN_BILLBOARD_NAME
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 80
	billboard.Size = UDim2.fromOffset(74, 6)
	billboard.StudsOffset = Vector3.new(0, 3.1, 0)
	billboard.Parent = character

	local frame = Instance.new("Frame")
	frame.Name = "Background"
	frame.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
	frame.BackgroundTransparency = 0.48
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(245, 248, 252)
	fill.BackgroundTransparency = 0.08
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = frame

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	task.spawn(function()
		while billboard.Parent ~= nil do
			local cooldownUntil = self.PlayerGrabCooldownUntil[player]
			if typeof(cooldownUntil) ~= "number" then
				break
			end

			local remaining = cooldownUntil - os.clock()
			if remaining <= 0 then
				if self.PlayerGrabCooldownUntil[player] == cooldownUntil then
					self.PlayerGrabCooldownUntil[player] = nil
				end
				break
			end

			fill.Size = UDim2.fromScale(math.clamp(remaining / PLAYER_DROP_GRAB_COOLDOWN, 0, 1), 1)
			task.wait(0.1)
		end

		if billboard.Parent ~= nil then
			billboard:Destroy()
		end
	end)
end

function GrabService:RestoreFeedablePhysics(feedable: Instance)
	local targetPlayer = if feedable:IsA("Model") then Players:GetPlayerFromCharacter(feedable) else nil
	if targetPlayer ~= nil then
		local rootPart = self:GetCharacterRootPart(feedable)
		if rootPart ~= nil then
			rootPart.CanCollide = false
		end
		return
	end

	local feedableService = self.Context.services.FeedableService
	local parts = feedableService:GetBaseParts(feedable)

	for _, part in ipairs(parts) do
		part.CanCollide = true
		part.Massless = false
	end
end

function GrabService:GetHeldList(player): { any }
	local heldList = self.HeldByPlayer[player]
	if heldList == nil then
		heldList = {}
		self.HeldByPlayer[player] = heldList
	end

	return heldList
end

function GrabService:GetCarryCapacity(player): number
	local level = self.Context.services.PlayerDataService:GetUpgradeLevel(player, "CarryCapacity")
	return math.max(1, math.floor(level))
end

function GrabService:GetHumanoidRootPart(player): BasePart?
	local character = player.Character
	local humanoidRootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoidRootPart ~= nil and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart
	end

	return nil
end

function GrabService:GetHumanoid(player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		return humanoid
	end

	return nil
end

function GrabService:GetWeightFromFeedable(feedable: Instance): number
	local targetPlayer = if feedable:IsA("Model") then Players:GetPlayerFromCharacter(feedable) else nil
	if targetPlayer ~= nil then
		return PLAYER_GRAB_WEIGHT
	end

	local weight = feedable:GetAttribute(self.Constants.ATTRIBUTES.Weight)
	if typeof(weight) == "number" then
		return math.max(0, weight)
	end

	return 1
end

function GrabService:GetTotalHeldWeight(player): number
	local totalWeight = 0
	for _, held in ipairs(self:GetHeldList(player)) do
		if self:IsHeldEntryValid(held) then
			totalWeight += self:GetWeightFromFeedable(held.feedable)
		end
	end

	return totalWeight
end

function GrabService:GetEffectiveCarryWeight(player): number
	local totalWeight = self:GetTotalHeldWeight(player)
	if totalWeight <= 0 then
		return 0
	end

	local strengthLevel = self.Context.services.PlayerDataService:GetUpgradeLevel(player, "Strength")
	local strengthReduction = math.max(0, strengthLevel - 1) * STRENGTH_WEIGHT_REDUCTION_PER_LEVEL
	return math.max(0, totalWeight - strengthReduction)
end

function GrabService:UpdatePlayerHandling(player)
	local humanoid = self:GetHumanoid(player)
	if humanoid == nil then
		return
	end

	local baseWalkSpeed = self.BaseWalkSpeedByPlayer[player]
	if typeof(baseWalkSpeed) ~= "number" or baseWalkSpeed <= 0 then
		baseWalkSpeed = if humanoid.WalkSpeed > 0 then humanoid.WalkSpeed else DEFAULT_WALK_SPEED
		self.BaseWalkSpeedByPlayer[player] = baseWalkSpeed
	end

	local effectiveWeight = self:GetEffectiveCarryWeight(player)
	if effectiveWeight <= 0 then
		humanoid.WalkSpeed = baseWalkSpeed
		return
	end

	local speedMultiplier =
		math.clamp(1 - (effectiveWeight * WEIGHT_SPEED_PENALTY_PER_UNIT), MIN_WALK_SPEED_MULTIPLIER, 1)
	humanoid.WalkSpeed = baseWalkSpeed * speedMultiplier
end

function GrabService:IsHeldEntryValid(held): boolean
	return typeof(held) == "table"
		and typeof(held.feedable) == "Instance"
		and typeof(held.rootPart) == "Instance"
		and held.feedable.Parent ~= nil
		and held.rootPart:IsA("BasePart")
		and held.rootPart.Parent ~= nil
end

function GrabService:GetHeldEntry(player, feedable: Instance): any?
	local heldList = self:GetHeldList(player)
	for _, held in ipairs(heldList) do
		if held.feedable == feedable then
			return held
		end
	end

	return nil
end

function GrabService:IsFeedableHeld(feedable: Instance): boolean
	for _player, heldList in pairs(self.HeldByPlayer) do
		for _, held in ipairs(heldList) do
			if held.feedable == feedable then
				return true
			end
		end
	end

	return false
end

function GrabService:RemoveHeldEntry(player, targetFeedable: Instance?, restoreCollisionNow: boolean?): any?
	local heldList = self:GetHeldList(player)
	if #heldList == 0 then
		return nil
	end

	local removeIndex = #heldList
	if targetFeedable ~= nil then
		for index, held in ipairs(heldList) do
			if held.feedable == targetFeedable then
				removeIndex = index
				break
			end
		end
	end

	local held = table.remove(heldList, removeIndex)
	if held == nil then
		return nil
	end

	self:DetachHeldEntry(held, restoreCollisionNow)
	self:RepositionHeldObjects(player)
	self:UpdatePlayerHandling(player)
	return held
end

function GrabService:DetachHeldEntry(held, restoreCollisionNow: boolean?)
	restoreCollisionNow = if restoreCollisionNow == nil then true else restoreCollisionNow

	local holdWeld = held.holdWeld
	if typeof(holdWeld) == "Instance" and holdWeld.Parent ~= nil then
		holdWeld:Destroy()
	end

	self:RestoreHeldCharacterControl(held.heldCharacterControlState)
	held.heldCharacterControlState = nil

	if held.isPlayerCharacter == true and typeof(held.feedable) == "Instance" and held.feedable:IsA("Model") then
		local heldPlayer = Players:GetPlayerFromCharacter(held.feedable)
		if heldPlayer ~= nil then
			self:EndHeldCharacterState(heldPlayer)
		end
	end

	if restoreCollisionNow and typeof(held.feedable) == "Instance" and held.feedable.Parent ~= nil then
		self:RestoreFeedablePhysics(held.feedable)
	end

	if restoreCollisionNow then
		self:ClearNoCollisionConstraints(held.noCollisionConstraints)
		held.noCollisionConstraints = nil
	end
end

function GrabService:ClearHeld(player): { any }
	local heldList = self:GetHeldList(player)
	local released = {}

	for index = #heldList, 1, -1 do
		local held = table.remove(heldList, index)
		if held ~= nil then
			self:DetachHeldEntry(held)
			table.insert(released, held)
		end
	end

	self.HeldByPlayer[player] = nil
	self:UpdatePlayerHandling(player)
	return released
end

function GrabService:RequestRelease(player)
	self:ClearHeld(player)
end

function GrabService:GetThrowDirection(player, direction): Vector3
	local humanoidRootPart = self:GetHumanoidRootPart(player)
	if typeof(direction) == "Vector3" and direction.Magnitude > 0.05 then
		return direction.Unit
	end

	if humanoidRootPart ~= nil then
		return humanoidRootPart.CFrame.LookVector
	end

	return Vector3.new(0, 0, -1)
end

function GrabService:ApplyThrowVelocity(player, held, direction)
	local rootPart = held.rootPart
	if typeof(rootPart) ~= "Instance" or not rootPart:IsA("BasePart") or rootPart.Parent == nil then
		return
	end

	local throwDirection = self:GetThrowDirection(player, direction)
	local throwPowerLevel = self.Context.services.PlayerDataService:GetUpgradeLevel(player, "ThrowPower")
	local speed = BASE_THROW_SPEED + ((throwPowerLevel - 1) * THROW_POWER_PER_LEVEL)
	local heldWeight = self:GetWeightFromFeedable(held.feedable)
	local strengthLevel = self.Context.services.PlayerDataService:GetUpgradeLevel(player, "Strength")
	local isPlayerCharacter = held.isPlayerCharacter == true
	local strengthReductionPerLevel = if isPlayerCharacter
		then PLAYER_THROW_STRENGTH_REDUCTION_PER_LEVEL
		else STRENGTH_WEIGHT_REDUCTION_PER_LEVEL
	local weightPenaltyPerUnit = if isPlayerCharacter
		then PLAYER_THROW_WEIGHT_PENALTY_PER_UNIT
		else THROW_WEIGHT_PENALTY_PER_UNIT
	local minThrowSpeedMultiplier = if isPlayerCharacter
		then PLAYER_THROW_MIN_SPEED_MULTIPLIER
		else MIN_THROW_SPEED_MULTIPLIER
	local strengthReduction = math.max(0, strengthLevel - 1) * strengthReductionPerLevel
	local effectiveWeight = math.max(0, heldWeight - strengthReduction)
	local throwMultiplier = math.clamp(1 - (effectiveWeight * weightPenaltyPerUnit), minThrowSpeedMultiplier, 1)
	speed *= throwMultiplier
	if isPlayerCharacter then
		speed *= PLAYER_THROW_SPEED_MULTIPLIER
	end

	local thrownPlayer = if isPlayerCharacter
			and typeof(held.feedable) == "Instance"
			and held.feedable:IsA("Model")
		then Players:GetPlayerFromCharacter(held.feedable)
		else nil

	if thrownPlayer ~= nil then
		pcall(function()
			rootPart:SetNetworkOwner(nil)
		end)
	end

	rootPart.AssemblyLinearVelocity = (throwDirection * speed) + Vector3.new(0, THROW_UPWARD_SPEED, 0)

	local thrownFeedable = held.feedable
	if thrownPlayer ~= nil then
		task.delay(PLAYER_THROW_OWNERSHIP_RESTORE_DELAY, function()
			if
				typeof(thrownFeedable) == "Instance"
				and thrownFeedable.Parent ~= nil
				and not self:IsFeedableHeld(thrownFeedable)
				and Players:GetPlayerFromCharacter(thrownFeedable) == thrownPlayer
			then
				pcall(function()
					rootPart:SetNetworkOwner(thrownPlayer)
				end)
			end
		end)
		return
	end

	pcall(function()
		rootPart:SetNetworkOwner(nil)
	end)
end

function GrabService:RequestThrow(player, direction, targetFeedable: Instance?)
	if self:IsPlayerCharacterHeld(player) then
		return
	end

	local held = self:RemoveHeldEntry(player, targetFeedable, false)
	if held == nil then
		return
	end

	self:ApplyThrowVelocity(player, held, direction)
	task.delay(THROW_CHARACTER_COLLISION_GRACE_SECONDS, function()
		if
			typeof(held.feedable) == "Instance"
			and held.feedable.Parent ~= nil
			and not self:IsFeedableHeld(held.feedable)
		then
			self:RestoreFeedablePhysics(held.feedable)
		end

		self:ClearNoCollisionConstraints(held.noCollisionConstraints)
		held.noCollisionConstraints = nil
	end)
	self.Context.services.FeedbackService:Play(player, "ThrowObject", {})
end

function GrabService:FindHolderHoldingCharacter(character: Model): (Player?, any?)
	for holder, heldList in pairs(self.HeldByPlayer) do
		for _, held in ipairs(heldList) do
			if held.isPlayerCharacter == true and held.feedable == character then
				return holder, held
			end
		end
	end

	return nil, nil
end

function GrabService:UpdateHeldCharacterStruggles(deltaTime: number)
	if deltaTime <= 0 then
		return
	end

	for heldPlayer, heldState in pairs(self.HeldCharacterStateByPlayer) do
		local character = heldPlayer.Character
		if character == nil then
			self:EndHeldCharacterState(heldPlayer)
			continue
		end

		local holder = heldState.holder
		local holderEntry = nil
		if typeof(holder) == "Instance" and holder:IsA("Player") then
			holderEntry = self:GetHeldEntry(holder, character)
		end

		if holderEntry == nil then
			local foundHolder, foundEntry = self:FindHolderHoldingCharacter(character)
			holder = foundHolder
			holderEntry = foundEntry
			heldState.holder = foundHolder
		end

		if holderEntry == nil then
			self:EndHeldCharacterState(heldPlayer)
			continue
		end

		local previousProgress = if typeof(heldState.progress) == "number" then heldState.progress else 0
		local nextProgress = math.max(0, previousProgress - (deltaTime * STRUGGLE_DECAY_PER_SECOND))
		if math.abs(nextProgress - previousProgress) >= 0.001 then
			heldState.progress = nextProgress
			character:SetAttribute(self.Constants.ATTRIBUTES.GrabStruggleProgress, nextProgress)
		end
	end
end

function GrabService:RequestStruggle(player)
	if not self:IsPlayerCharacterHeld(player) then
		return
	end

	local now = os.clock()
	local lastRequest = self.LastStruggleRequestByPlayer[player]
	if typeof(lastRequest) == "number" and (now - lastRequest) < STRUGGLE_TAP_COOLDOWN then
		return
	end
	self.LastStruggleRequestByPlayer[player] = now

	local character = player.Character
	if character == nil then
		return
	end

	local heldState = self.HeldCharacterStateByPlayer[player]
	if heldState == nil then
		local holder = self:FindHolderHoldingCharacter(character)
		if holder == nil then
			return
		end
		self:BeginHeldCharacterState(player, holder)
		heldState = self.HeldCharacterStateByPlayer[player]
	end
	if heldState == nil then
		return
	end

	local previousProgress = if typeof(heldState.progress) == "number" then heldState.progress else 0
	local nextProgress = math.clamp(previousProgress + STRUGGLE_FILL_PER_TAP, 0, STRUGGLE_ESCAPE_THRESHOLD)
	heldState.progress = nextProgress
	character:SetAttribute(self.Constants.ATTRIBUTES.GrabStruggleProgress, nextProgress)

	if nextProgress >= STRUGGLE_ESCAPE_THRESHOLD then
		local holder = heldState.holder
		if typeof(holder) ~= "Instance" or not holder:IsA("Player") then
			local foundHolder = self:FindHolderHoldingCharacter(character)
			holder = foundHolder
		end

		if typeof(holder) == "Instance" and holder:IsA("Player") then
			self:RemoveHeldEntry(holder, character, true)
		else
			self:EndHeldCharacterState(player)
		end
	end
end

function GrabService:IsPlayerCharacterHeld(player): boolean
	local character = player.Character
	if character == nil then
		return false
	end

	return self:IsFeedableHeld(character)
end

return GrabService
