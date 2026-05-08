--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local MouthService = {}
MouthService.Name = "MouthService"

local FEEDER_FALLBACK_RADIUS = 40
local CHEW_IDLE_TIMEOUT = 4
local CHEW_CLOSE_TIME = 0.12
local CHEW_OPEN_TIME = 0.16
local CHEW_PAUSE_TIME = 0.04
local PLAYER_CHEW_DURATION = 2
local PLAYER_REEAT_COOLDOWN = 1
local PLAYER_SPIT_SPEED = 300
local PLAYER_SPIT_UPWARD_SPEED = 70
local PLAYER_SPIT_NO_COLLISION_GRACE = 0.35
local MOUTH_MODEL_NAME = "MouthModel"
local CHEW_SOUND_NAME = "ChewingSound"
local CHEW_SFX_NAME = "MouthChew"

function MouthService:Init(context)
	self.Context = context
	self.Constants = require(context.shared.Constants)
	self.AudioConfig = require(context.shared.AudioConfig)
	self.LastEatTime = 0
	self.IsChewing = false
	self.PlayersBeingChewed = {}
	self.PlayerEatCooldownUntil = {}
end

function MouthService:Start()
	local eatZone = self:GetEatZone()
	if eatZone == nil then
		warn("[MouthService] EatZone not found")
		return
	end

	eatZone.CanTouch = true
	eatZone.Touched:Connect(function(hit)
		self:TryEat(hit)
	end)
end

function MouthService:GetEatZone(): BasePart?
	local world = Workspace:FindFirstChild(self.Constants.WORLD_FOLDER_NAME)
	local mouth = if world ~= nil then world:FindFirstChild("Mouth") else nil
	local eatZone = if mouth ~= nil then mouth:FindFirstChild("EatZone") else nil

	if eatZone ~= nil and eatZone:IsA("BasePart") then
		return eatZone
	end

	return nil
end

function MouthService:TryEat(hit: BasePart)
	local player = self:GetPlayerFromHit(hit)
	if player ~= nil then
		self:TryEatPlayer(player)
		return
	end

	local feedableService = self.Context.services.FeedableService
	local feedable = feedableService:FindFeedableFromInstance(hit)
	if feedable == nil then
		return
	end

	local attributes = self.Constants.ATTRIBUTES
	if feedable:GetAttribute(attributes.Consumed) == true then
		return
	end

	self:MarkConsumed(feedable)
	self:StartChewing()

	local feeder = self:GetFeeder(feedable, hit.Position)
	local reward = 0
	if feeder ~= nil then
		reward = self.Context.services.EconomyService:AwardFeedReward(feeder, feedable)
		self.Context.services.FeedbackService:Play(feeder, "Reward", {
			amount = reward,
			tier = feedable:GetAttribute(attributes.Tier),
		})
	end

	self.Context.services.FeedbackService:PlayForAll("MouthEat", {
		position = hit.Position,
		reward = reward,
		tier = feedable:GetAttribute(attributes.Tier),
	})

	task.defer(function()
		if feedable.Parent ~= nil then
			feedable:Destroy()
		end
	end)
end

function MouthService:GetPlayerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if character == nil then
		return nil
	end

	local player = Players:GetPlayerFromCharacter(character)
	if player ~= nil then
		return player
	end

	return nil
end

function MouthService:TryEatPlayer(player: Player)
	local now = os.clock()
	local cooldownUntil = self.PlayerEatCooldownUntil[player]
	if typeof(cooldownUntil) == "number" and now < cooldownUntil then
		return
	end

	if self.PlayersBeingChewed[player] == true then
		return
	end

	local character = player.Character
	local humanoidRootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoidRootPart == nil or not humanoidRootPart:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return
	end

	local eatZone = self:GetEatZone()
	local chewCenter = if eatZone ~= nil then eatZone.Position else humanoidRootPart.Position
	local spitDirection = self:GetSpitDirection(humanoidRootPart.Position, chewCenter, eatZone)
	local noCollisionConstraints = self:CreateMouthNoCollisionConstraints(character)

	self.PlayersBeingChewed[player] = true
	self.PlayerEatCooldownUntil[player] = now + PLAYER_CHEW_DURATION + PLAYER_REEAT_COOLDOWN
	self.Context.services.GrabService:RequestRelease(player)
	self:StartChewing()

	humanoidRootPart.CFrame = CFrame.new(chewCenter)
	humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
	humanoidRootPart.Anchored = true

	task.delay(PLAYER_CHEW_DURATION, function()
		self.PlayersBeingChewed[player] = nil

		if humanoidRootPart.Parent ~= nil then
			humanoidRootPart.Anchored = false
		end

		local currentCharacter = player.Character
		if currentCharacter ~= character then
			return
		end

		local currentRootPart = if currentCharacter ~= nil
			then currentCharacter:FindFirstChild("HumanoidRootPart")
			else nil
		local currentHumanoid = if currentCharacter ~= nil
			then currentCharacter:FindFirstChildOfClass("Humanoid")
			else nil
		if
			currentRootPart == nil
			or not currentRootPart:IsA("BasePart")
			or currentHumanoid == nil
			or currentHumanoid.Health <= 0
		then
			return
		end

		currentRootPart.Anchored = false
		currentRootPart.AssemblyLinearVelocity = (spitDirection * PLAYER_SPIT_SPEED)
			+ Vector3.new(0, PLAYER_SPIT_UPWARD_SPEED, 0)
	end)

	task.delay(PLAYER_CHEW_DURATION + PLAYER_REEAT_COOLDOWN + PLAYER_SPIT_NO_COLLISION_GRACE, function()
		self:ClearNoCollisionConstraints(noCollisionConstraints)
	end)
end

function MouthService:GetSpitDirection(entryPosition: Vector3, chewCenter: Vector3, eatZone: BasePart?): Vector3
	local offset = entryPosition - chewCenter
	if offset.Magnitude > 0.05 then
		return offset.Unit
	end

	if eatZone ~= nil then
		local fallbackDirection = -eatZone.CFrame.LookVector
		if fallbackDirection.Magnitude > 0.05 then
			return fallbackDirection.Unit
		end
	end

	return Vector3.new(0, 0, -1)
end

function MouthService:GetCharacterBaseParts(character: Model): { BasePart }
	local parts = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

function MouthService:GetMouthCollisionParts(): { BasePart }
	local parts = {}

	local mouthModel = self:GetMouthModel()
	if mouthModel ~= nil then
		for _, descendant in ipairs(mouthModel:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end

	local eatZone = self:GetEatZone()
	if eatZone ~= nil then
		table.insert(parts, eatZone)
	end

	return parts
end

function MouthService:CreateMouthNoCollisionConstraints(character: Model): { NoCollisionConstraint }
	local characterParts = self:GetCharacterBaseParts(character)
	local mouthParts = self:GetMouthCollisionParts()
	local constraints = {}

	if #characterParts == 0 or #mouthParts == 0 then
		return constraints
	end

	for _, characterPart in ipairs(characterParts) do
		for _, mouthPart in ipairs(mouthParts) do
			if characterPart ~= mouthPart then
				local noCollision = Instance.new("NoCollisionConstraint")
				noCollision.Part0 = characterPart
				noCollision.Part1 = mouthPart
				noCollision.Parent = characterPart
				table.insert(constraints, noCollision)
			end
		end
	end

	return constraints
end

function MouthService:ClearNoCollisionConstraints(constraints: { NoCollisionConstraint })
	for _, constraint in ipairs(constraints) do
		if constraint.Parent ~= nil then
			constraint:Destroy()
		end
	end
end

function MouthService:StartChewing()
	self.LastEatTime = os.clock()
	if self.IsChewing then
		return
	end

	self.IsChewing = true
	task.spawn(function()
		self:RunChewLoop()
	end)
end

function MouthService:RunChewLoop()
	local mouthModel = self:GetMouthModel()
	if mouthModel == nil then
		warn("[MouthService] MouthModel not found")
		self.IsChewing = false
		return
	end

	local restCFrames = self:CaptureMouthCFrames(mouthModel)
	local chewSound = self:GetChewSound(mouthModel)
	self:PlayChewSound(chewSound)

	while true do
		while os.clock() - self.LastEatTime <= CHEW_IDLE_TIMEOUT do
			self:TweenMouth(restCFrames, true, CHEW_CLOSE_TIME)
			task.wait(CHEW_CLOSE_TIME + CHEW_PAUSE_TIME)
			self:TweenMouth(restCFrames, false, CHEW_OPEN_TIME)
			task.wait(CHEW_OPEN_TIME + CHEW_PAUSE_TIME)
		end

		self:TweenMouth(restCFrames, false, CHEW_OPEN_TIME)
		task.wait(CHEW_OPEN_TIME)
		if os.clock() - self.LastEatTime > CHEW_IDLE_TIMEOUT then
			break
		end
	end

	self:StopChewSound(chewSound)
	self.IsChewing = false
end

function MouthService:GetMouthModel(): Model?
	local world = Workspace:FindFirstChild(self.Constants.WORLD_FOLDER_NAME)
	local mouth = if world ~= nil then world:FindFirstChild("Mouth") else nil
	local mouthModel = if mouth ~= nil then mouth:FindFirstChild(MOUTH_MODEL_NAME) else nil

	if mouthModel ~= nil and mouthModel:IsA("Model") then
		return mouthModel
	end

	return nil
end

function MouthService:CaptureMouthCFrames(mouthModel: Model): { [BasePart]: CFrame }
	local restCFrames = {}
	for _, descendant in ipairs(mouthModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			restCFrames[descendant] = descendant.CFrame
		end
	end

	return restCFrames
end

function MouthService:GetChewSound(mouthModel: Model): Sound
	local existingSound = mouthModel:FindFirstChild(CHEW_SOUND_NAME, true)
	if existingSound ~= nil and existingSound:IsA("Sound") then
		return existingSound
	end

	local chewSound = Instance.new("Sound")
	local chewConfig = self.AudioConfig.SFX[CHEW_SFX_NAME]
	chewSound.Name = CHEW_SOUND_NAME
	chewSound.SoundId = chewConfig.soundId
	chewSound.Volume = chewConfig.volume or 1
	chewSound.Looped = if chewConfig.looped ~= nil then chewConfig.looped else true
	chewSound.RollOffMaxDistance = chewConfig.rollOffMaxDistance or 120
	chewSound.Parent = self:GetChewSoundParent(mouthModel)

	return chewSound
end

function MouthService:GetChewSoundParent(mouthModel: Model): Instance
	local mouthBack = mouthModel:FindFirstChild("MouthBack")
	if mouthBack ~= nil and mouthBack:IsA("BasePart") then
		return mouthBack
	end

	local firstPart = mouthModel:FindFirstChildWhichIsA("BasePart", true)
	if firstPart ~= nil then
		return firstPart
	end

	return mouthModel
end

function MouthService:PlayChewSound(chewSound: Sound)
	if not chewSound.IsPlaying then
		chewSound:Play()
	end
end

function MouthService:StopChewSound(chewSound: Sound)
	if chewSound.IsPlaying then
		chewSound:Stop()
	end
end

function MouthService:GetChewOffset(partName: string): Vector3
	if partName == "UpperLip" or partName:sub(1, 8) == "TopTooth" then
		return Vector3.new(0, -7, 0)
	elseif partName == "LowerLip" or partName:sub(1, 11) == "BottomTooth" then
		return Vector3.new(0, 7, 0)
	elseif partName == "LeftLip" then
		return Vector3.new(4, 0, 0)
	elseif partName == "RightLip" then
		return Vector3.new(-4, 0, 0)
	elseif partName == "Tongue" then
		return Vector3.new(0, 2, -3)
	end

	return Vector3.zero
end

function MouthService:TweenMouth(restCFrames: { [BasePart]: CFrame }, closed: boolean, duration: number)
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for part, restCFrame in pairs(restCFrames) do
		if part.Parent == nil then
			continue
		end

		local offset = if closed then self:GetChewOffset(part.Name) else Vector3.zero
		local targetCFrame = restCFrame * CFrame.new(offset)
		TweenService:Create(part, tweenInfo, {
			CFrame = targetCFrame,
		}):Play()
	end
end

function MouthService:MarkConsumed(feedable: Instance)
	local attributes = self.Constants.ATTRIBUTES
	feedable:SetAttribute(attributes.Consumed, true)

	local feedableService = self.Context.services.FeedableService
	for _, part in ipairs(feedableService:GetBaseParts(feedable)) do
		part.CanTouch = false
		part.CanCollide = false
		part:SetAttribute(attributes.Consumed, true)
	end
end

function MouthService:GetFeeder(feedable: Instance, position: Vector3): Player?
	local userId = feedable:GetAttribute(self.Constants.ATTRIBUTES.LastHolderUserId)
	if typeof(userId) == "number" then
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			return player
		end
	end

	return self:GetNearestPlayer(position, FEEDER_FALLBACK_RADIUS)
end

function MouthService:GetNearestPlayer(position: Vector3, maxDistance: number): Player?
	local nearestPlayer = nil
	local nearestDistance = maxDistance

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if rootPart ~= nil and rootPart:IsA("BasePart") then
			local distance = (rootPart.Position - position).Magnitude
			if distance <= nearestDistance then
				nearestPlayer = player
				nearestDistance = distance
			end
		end
	end

	return nearestPlayer
end

return MouthService
