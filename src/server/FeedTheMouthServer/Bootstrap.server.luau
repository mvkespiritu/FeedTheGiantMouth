--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverRoot = script.Parent
local servicesFolder = serverRoot:WaitForChild("Services")

local feedRoot = ReplicatedStorage:WaitForChild("FeedTheMouth")
local shared = feedRoot:WaitForChild("Shared")

local Constants = require(shared:WaitForChild("Constants"))
local InstanceUtil = require(shared:WaitForChild("Util"):WaitForChild("InstanceUtil"))

local remotes = InstanceUtil.getOrCreateFolder(feedRoot, Constants.REMOTES_FOLDER_NAME)
for _, remoteName in ipairs(Constants.REMOTE_NAMES) do
	InstanceUtil.getOrCreateRemoteEvent(remotes, remoteName)
end

local serviceOrder = {
	"PlayerDataService",
	"EconomyService",
	"UpgradeService",
	"FeedableService",
	"GrabService",
	"MouthService",
	"RespawnService",
	"FeedbackService",
}

local services = {}
local context = {
	remotes = remotes,
	shared = shared,
	services = services,
}

for _, serviceName in ipairs(serviceOrder) do
	services[serviceName] = require(servicesFolder:WaitForChild(serviceName))
end

for _, serviceName in ipairs(serviceOrder) do
	local service = services[serviceName]
	if service.Init ~= nil then
		service:Init(context)
	end
end

for _, serviceName in ipairs(serviceOrder) do
	local service = services[serviceName]
	if service.Start ~= nil then
		service:Start()
	end
end

print("[FeedTheMouthServer] Started")
