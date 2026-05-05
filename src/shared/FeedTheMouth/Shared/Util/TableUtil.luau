--!strict

local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, childValue in pairs(value :: any) do
		copy[TableUtil.deepCopy(key)] = TableUtil.deepCopy(childValue)
	end

	return copy :: any
end

function TableUtil.shallowMerge(...: {[any]: any}): {[any]: any}
	local merged = {}

	for _, source in ipairs({...}) do
		for key, value in pairs(source) do
			merged[key] = value
		end
	end

	return merged
end

return TableUtil
