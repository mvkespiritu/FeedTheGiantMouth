--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraController = {}
CameraController.Name = "CameraController"

local CHEW_FRONT_DISTANCE = 8
local CHEW_HEIGHT = 3
local ORBIT_RADIUS = 9
local ORBIT_HEIGHT = 4

function CameraController:Init(context)
	self.Context = context
	self.LocalPlayer = Players.LocalPlayer
	self.PlayFeedback = context.remotes:WaitForChild("PlayFeedback")
	self.SequenceToken = 0
end

function CameraController:Start()
	self.PlayFeedback.OnClientEvent:Connect(function(feedbackName, payload)
		if feedbackName ~= "MouthPlayerSequence" then
			return
		end

		self:PlayMouthSequence(payload or {})
	end)
end

function CameraController:PlayMouthSequence(payload)
	self.SequenceToken += 1
	local token = self.SequenceToken

	local character = self.LocalPlayer.Character
	local rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return
	end

	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end

	local chewDuration = if typeof(payload.chewDuration) == "number" then math.max(0, payload.chewDuration) else 2
	local spitDuration = if typeof(payload.spitDuration) == "number" then math.max(0.05, payload.spitDuration) else 1.8
	local mouthPosition = if typeof(payload.mouthPosition) == "Vector3" then payload.mouthPosition else rootPart.Position
	local spitDirection = if typeof(payload.spitDirection) == "Vector3" then payload.spitDirection else rootPart.CFrame.LookVector

	if spitDirection.Magnitude < 0.05 then
		spitDirection = Vector3.new(0, 0, -1)
	end

	local savedCameraType = camera.CameraType
	local savedCameraSubject = camera.CameraSubject
	camera.CameraType = Enum.CameraType.Scriptable

	-- Phase 1: chew camera in front of character, facing them.
	local chewStart = os.clock()
	while os.clock() - chewStart < chewDuration do
		if token ~= self.SequenceToken then
			return
		end

		character = self.LocalPlayer.Character
		rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if rootPart == nil or not rootPart:IsA("BasePart") then
			break
		end

		local focus = rootPart.Position + Vector3.new(0, 2.25, 0)
		local position = focus + (rootPart.CFrame.LookVector * CHEW_FRONT_DISTANCE) + Vector3.new(0, CHEW_HEIGHT, 0)
		camera.CFrame = CFrame.lookAt(position, focus)
		RunService.RenderStepped:Wait()
	end

	-- Phase 2: orbit (inverted) from the opposite side and end on the opposite side.
	local startYaw = math.atan2(spitDirection.Z, spitDirection.X) + math.pi
	local orbitStart = os.clock()
	while os.clock() - orbitStart < spitDuration do
		if token ~= self.SequenceToken then
			return
		end

		character = self.LocalPlayer.Character
		rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if rootPart == nil or not rootPart:IsA("BasePart") then
			break
		end

		local alpha = math.clamp((os.clock() - orbitStart) / spitDuration, 0, 1)
		local orbitYaw = startYaw - (math.pi * alpha)
		local orbitDirection = Vector3.new(math.cos(orbitYaw), 0, math.sin(orbitYaw))

		local focus = rootPart.Position + Vector3.new(0, 2.25, 0)
		local offset = (orbitDirection * ORBIT_RADIUS) + Vector3.new(0, ORBIT_HEIGHT, 0)
		camera.CFrame = CFrame.lookAt(focus + offset, focus)
		RunService.RenderStepped:Wait()
	end

	-- End pose: inverted end side.
	character = self.LocalPlayer.Character
	rootPart = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if rootPart ~= nil and rootPart:IsA("BasePart") then
		local focus = rootPart.Position + Vector3.new(0, 2.25, 0)
		local mouthDirection = mouthPosition - rootPart.Position
		if mouthDirection.Magnitude > 0.05 then
			local direction = Vector3.new(mouthDirection.X, 0, mouthDirection.Z).Unit
			local offset = (-direction * ORBIT_RADIUS) + Vector3.new(0, ORBIT_HEIGHT, 0)
			camera.CFrame = CFrame.lookAt(focus + offset, focus)
		end
	end

	if token == self.SequenceToken then
		camera.CameraType = savedCameraType
		camera.CameraSubject = savedCameraSubject
	end
end

return CameraController
