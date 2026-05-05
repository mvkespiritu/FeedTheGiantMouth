--!strict

local GrabController = {}
GrabController.Name = "GrabController"

function GrabController:Init(context)
	self.Context = context
	self.RequestGrabRemote = context.remotes:WaitForChild("RequestGrab")
	self.RequestReleaseRemote = context.remotes:WaitForChild("RequestRelease")
	self.RequestThrowRemote = context.remotes:WaitForChild("RequestThrow")
end

function GrabController:Start() end

function GrabController:RequestGrab(feedable: Instance)
	self.RequestGrabRemote:FireServer(feedable)
end

function GrabController:RequestRelease()
	self.RequestReleaseRemote:FireServer()
end

function GrabController:RequestThrow(direction: Vector3)
	self.RequestThrowRemote:FireServer(direction)
end

return GrabController
