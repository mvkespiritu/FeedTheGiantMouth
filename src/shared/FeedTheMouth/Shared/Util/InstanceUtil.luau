--!strict

local InstanceUtil = {}

function InstanceUtil.getOrCreate(parent: Instance, name: string, className: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing ~= nil then
		if not existing:IsA(className) then
			error(`Expected {parent:GetFullName()}.{name} to be a {className}, got {existing.ClassName}`)
		end

		return existing
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

function InstanceUtil.getOrCreateFolder(parent: Instance, name: string): Folder
	return InstanceUtil.getOrCreate(parent, name, "Folder") :: Folder
end

function InstanceUtil.getOrCreateRemoteEvent(parent: Instance, name: string): RemoteEvent
	return InstanceUtil.getOrCreate(parent, name, "RemoteEvent") :: RemoteEvent
end

function InstanceUtil.setMissingAttributes(instance: Instance, attributes: {[string]: any})
	for attributeName, attributeValue in pairs(attributes) do
		if instance:GetAttribute(attributeName) == nil then
			instance:SetAttribute(attributeName, attributeValue)
		end
	end
end

return InstanceUtil
