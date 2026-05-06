--!strict

local AudioConfig = {}

AudioConfig.SoundGroups = table.freeze({
	Music = {
		volume = 0.45,
	},
	SFX = {
		volume = 0.8,
	},
})

AudioConfig.Music = table.freeze({
	MainTheme = {
		soundId = "rbxassetid://1841647742",
		volume = 0.25,
		looped = true,
	},
})

AudioConfig.SFX = table.freeze({
	UiClick = {
		soundId = "rbxassetid://122835655736085",
		volume = 0.45,
	},
	GrabObject = {
		soundId = "rbxassetid://138519713272464",
		volume = 1.35,
		pitchMin = 0.95,
		pitchMax = 1.05,
	},
	ThrowObject = {
		soundId = "rbxassetid://130418119356313",
		volume = 0.7,
		pitchMin = 0.95,
		pitchMax = 1.05,
	},
	MouthEat = {
		soundId = "rbxassetid://137282216533276",
		volume = 0.9,
		rollOffMaxDistance = 120,
		spatial = true,
	},
	Reward = {
		soundId = "rbxassetid://134612482016650",
		volume = 0.75,
	},
	LockedObject = {
		soundId = "rbxassetid://136810595658522",
		volume = 0.6,
	},
	NotEnoughCoins = {
		soundId = "rbxassetid://136810595658522",
		volume = 0.6,
	},
	UpgradePurchased = {
		soundId = "rbxassetid://85494326384043",
		volume = 0.75,
	},
	UpgradeMaxed = {
		soundId = "rbxassetid://85494326384043",
		volume = 0.65,
	},
	InvalidUpgrade = {
		soundId = "rbxassetid://136810595658522",
		volume = 0.6,
	},
})

AudioConfig.FeedbackSFX = table.freeze({
	GrabObject = "GrabObject",
	InvalidUpgrade = "InvalidUpgrade",
	LockedObject = "LockedObject",
	MouthEat = "MouthEat",
	NotEnoughCoins = "NotEnoughCoins",
	Reward = "Reward",
	ThrowObject = "ThrowObject",
	UpgradeMaxed = "UpgradeMaxed",
	UpgradePurchased = "UpgradePurchased",
})

return table.freeze(AudioConfig)
