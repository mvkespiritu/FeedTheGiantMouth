--!strict

local GrabController = {}
GrabController.Name = "GrabController"

function GrabController:Init(context)
	self.Context = context
	self.RequestGrab = context.remotes:WaitForChild("RequestGrab")
	self.RequestRelease = context.remotes:WaitForChild("RequestRelease")
	self.RequestThrow = context.remotes:WaitForChild("RequestThrow")
end

function GrabController:Start() end

function GrabController:RequestGrab(feedable: Instance)
	self.RequestGrab:FireServer(feedable)
end

function GrabController:RequestRelease()
	self.RequestRelease:FireServer()
end

function GrabController:RequestThrow(direction: Vector3)
	self.RequestThrow:FireServer(direction)
end

return GrabController
