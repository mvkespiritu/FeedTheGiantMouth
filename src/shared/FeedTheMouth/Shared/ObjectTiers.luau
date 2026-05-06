--!strict

local ObjectTiers = {
	Small = {
		displayName = "Small",
		folderName = "Small",
		requiredStrength = 1,
		baseReward = 10,
		weight = 1,
		spawnLimit = 16,
	},

	Medium = {
		displayName = "Medium",
		folderName = "Medium",
		requiredStrength = 2,
		baseReward = 35,
		weight = 4,
		spawnLimit = 12,
	},

	Large = {
		displayName = "Large",
		folderName = "Large",
		requiredStrength = 3,
		baseReward = 100,
		weight = 10,
		spawnLimit = 8,
	},

	Absurd = {
		displayName = "Absurd",
		folderName = "Absurd",
		requiredStrength = 4,
		baseReward = 250,
		weight = 25,
		spawnLimit = 5,
	},
}

return table.freeze(ObjectTiers)
