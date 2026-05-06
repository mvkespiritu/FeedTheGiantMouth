--!strict

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioController = {}
AudioController.Name = "AudioController"

local DEFAULT_SOUND_LIFETIME = 8
local POSITIONAL_PART_NAME = "FeedTheMouthPositionalSound"

function AudioController:Init(context)
	self.Context = context
	self.AudioConfig = require(context.shared.AudioConfig)
	self.PlayFeedback = context.remotes:WaitForChild("PlayFeedback")
	self.SoundGroups = {}
	self.MusicTracks = {}
	self.SoundTemplates = {}
end

function AudioController:Start()
	self:CreateSoundGroups()
	self:CreateMusicTracks()
	self:CreateSoundTemplates()
	self:PreloadSounds()
	self:PlayMusic("MainTheme")

	self.PlayFeedback.OnClientEvent:Connect(function(feedbackName, payload)
		self:HandleFeedback(feedbackName, payload)
	end)
end

function AudioController:CreateSoundGroups()
	for groupName, groupConfig in pairs(self.AudioConfig.SoundGroups) do
		local soundGroup = SoundService:FindFirstChild(`FeedTheMouth{groupName}`)
		if soundGroup == nil or not soundGroup:IsA("SoundGroup") then
			soundGroup = Instance.new("SoundGroup")
			soundGroup.Name = `FeedTheMouth{groupName}`
			soundGroup.Parent = SoundService
		end

		soundGroup.Volume = groupConfig.volume or 1
		self.SoundGroups[groupName] = soundGroup
	end
end

function AudioController:CreateMusicTracks()
	local musicGroup = self.SoundGroups.Music
	for trackName, trackConfig in pairs(self.AudioConfig.Music) do
		local sound = Instance.new("Sound")
		sound.Name = trackName
		sound.SoundId = trackConfig.soundId
		sound.Volume = trackConfig.volume or 1
		sound.Looped = trackConfig.looped == true
		sound.SoundGroup = musicGroup
		sound.Parent = SoundService
		self.MusicTracks[trackName] = sound
	end
end

function AudioController:CreateSoundTemplates()
	local sfxGroup = self.SoundGroups.SFX
	for sfxName, sfxConfig in pairs(self.AudioConfig.SFX) do
		local sound = Instance.new("Sound")
		sound.Name = sfxName
		sound.SoundId = sfxConfig.soundId
		sound.Volume = sfxConfig.volume or 1
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMaxDistance = sfxConfig.rollOffMaxDistance or 80
		sound.SoundGroup = sfxGroup
		sound.Parent = SoundService
		self.SoundTemplates[sfxName] = sound
	end
end

function AudioController:PreloadSounds()
	local sounds = {}
	for _, sound in pairs(self.MusicTracks) do
		table.insert(sounds, sound)
	end

	for _, sound in pairs(self.SoundTemplates) do
		table.insert(sounds, sound)
	end

	if #sounds == 0 then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)

		if not ok then
			warn(`[AudioController] Failed to preload audio: {err}`)
		end
	end)
end

function AudioController:PlayMusic(trackName: string)
	local track = self.MusicTracks[trackName]
	if track == nil then
		return
	end

	if track.IsPlaying then
		return
	end

	track:Play()
end

function AudioController:HandleFeedback(feedbackName: string, payload)
	local sfxName = self.AudioConfig.FeedbackSFX[feedbackName]
	if sfxName == nil then
		return
	end

	payload = payload or {}
	self:PlaySFX(sfxName, payload.position)
end

function AudioController:PlaySFX(sfxName: string, position: Vector3?)
	local template = self.SoundTemplates[sfxName]
	local sfxConfig = self.AudioConfig.SFX[sfxName]
	if template == nil or sfxConfig == nil then
		return
	end

	local sound = template:Clone()
	sound.PlaybackSpeed = self:GetPlaybackSpeed(sfxConfig)

	local parent: Instance = SoundService
	local cleanupTarget: Instance = sound
	if sfxConfig.spatial == true and typeof(position) == "Vector3" then
		parent = self:CreateSoundPart(position)
		cleanupTarget = parent
	end

	sound.Parent = parent
	sound:Play()

	sound.Ended:Connect(function()
		if cleanupTarget.Parent ~= nil then
			cleanupTarget:Destroy()
		end
	end)

	Debris:AddItem(cleanupTarget, DEFAULT_SOUND_LIFETIME)
end

function AudioController:GetPlaybackSpeed(sfxConfig): number
	local pitchMin = sfxConfig.pitchMin
	local pitchMax = sfxConfig.pitchMax
	if typeof(pitchMin) ~= "number" or typeof(pitchMax) ~= "number" then
		return 1
	end

	if pitchMax <= pitchMin then
		return pitchMin
	end

	return pitchMin + (math.random() * (pitchMax - pitchMin))
end

function AudioController:CreateSoundPart(position: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = POSITIONAL_PART_NAME
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.25, 0.25, 0.25)
	part.Position = position
	part.Parent = Workspace
	return part
end

return AudioController
