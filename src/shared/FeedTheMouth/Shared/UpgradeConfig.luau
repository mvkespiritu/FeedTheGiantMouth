--!strict

local UpgradeConfig = {}

UpgradeConfig.Definitions = table.freeze({
	Strength = {
		displayName = "Strength",
		defaultLevel = 1,
		maxLevel = 4,
		baseCost = 10, --300,
		costMultiplier = 1.75,
	},

	CarryCapacity = {
		displayName = "Carry Capacity",
		defaultLevel = 1,
		maxLevel = 10,
		baseCost = 240,
		costMultiplier = 1.55,
	},

	ThrowPower = {
		displayName = "Throw Power",
		defaultLevel = 1,
		maxLevel = 10,
		baseCost = 210,
		costMultiplier = 1.5,
	},

	ValueMultiplier = {
		displayName = "Value Multiplier",
		defaultLevel = 1,
		maxLevel = 10,
		baseCost = 450,
		costMultiplier = 1.8,
	},
})

UpgradeConfig.Order = table.freeze({
	"Strength",
	"CarryCapacity",
	"ThrowPower",
	"ValueMultiplier",
})

function UpgradeConfig.getCost(upgradeId: string, currentLevel: number): number?
	local definition = UpgradeConfig.Definitions[upgradeId]
	if definition == nil or currentLevel >= definition.maxLevel then
		return nil
	end

	local levelsBought = math.max(currentLevel - definition.defaultLevel, 0)
	return math.floor(definition.baseCost * (definition.costMultiplier ^ levelsBought))
end

return UpgradeConfig
