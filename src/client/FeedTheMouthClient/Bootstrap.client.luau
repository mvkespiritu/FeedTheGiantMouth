--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local clientRoot = script.Parent
local controllersFolder = clientRoot:WaitForChild("Controllers")

local feedRoot = ReplicatedStorage:WaitForChild("FeedTheMouth")
local shared = feedRoot:WaitForChild("Shared")
local remotes = feedRoot:WaitForChild("Remotes")

local controllerOrder = {
	"InputController",
	"GrabController",
	"UIController",
	"UpgradeShopController",
	"FeedbackController",
}

local controllers = {}
local context = {
	remotes = remotes,
	shared = shared,
	controllers = controllers,
}

for _, controllerName in ipairs(controllerOrder) do
	controllers[controllerName] = require(controllersFolder:WaitForChild(controllerName))
end

for _, controllerName in ipairs(controllerOrder) do
	local controller = controllers[controllerName]
	if controller.Init ~= nil then
		controller:Init(context)
	end
end

for _, controllerName in ipairs(controllerOrder) do
	local controller = controllers[controllerName]
	if controller.Start ~= nil then
		controller:Start()
	end
end

print("[FeedTheMouthClient] Started")
