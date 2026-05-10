local DataStoreService = game:GetService("DataStoreService")

local Standard = {}
Standard.__index = Standard

function Standard:Get()
	local success, value = pcall(function()
		return self.dataStore:GetAsync(tostring(self.dataStore2.UserId))
	end)

	if not success then
		return false, value
	end

	return true, value
end

function Standard:Set(value)
	local success, problem = pcall(function()
		self.dataStore:SetAsync(tostring(self.dataStore2.UserId), value)
	end)

	if not success then
		return false, problem
	end

	return true
end

function Standard.new(dataStore2)
	local info = {
		dataStore2 = dataStore2,
		dataStore = DataStoreService:GetDataStore(dataStore2.Name),
	}

	return setmetatable(info, Standard)
end

return Standard
