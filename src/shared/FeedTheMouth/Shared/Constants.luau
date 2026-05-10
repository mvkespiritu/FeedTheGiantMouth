--!strict

local Constants = {
	ROOT_FOLDER_NAME = "FeedTheMouth",
	SHARED_FOLDER_NAME = "Shared",
	REMOTES_FOLDER_NAME = "Remotes",
	FEEDABLES_FOLDER_NAME = "FeedableObjects",
	WORLD_FOLDER_NAME = "FeedTheMouthWorld",
	MAIN_HUD_NAME = "MainHUD",

	REMOTE_NAMES = table.freeze({
		"RequestGrab",
		"RequestRelease",
		"RequestThrow",
		"RequestStruggle",
		"RequestUpgrade",
		"PlayerDataChanged",
		"PlayFeedback",
	}),

	ATTRIBUTES = table.freeze({
		Feedable = "Feedable",
		Tier = "Tier",
		Value = "Value",
		Weight = "Weight",
		RequiredStrength = "RequiredStrength",
		Consumed = "Consumed",
		LastHolderUserId = "LastHolderUserId",
		ItemId = "ItemId",
		DisplayName = "DisplayName",
		IsGrabbed = "IsGrabbed",
		GrabStruggleProgress = "GrabStruggleProgress",
	}),

	TIERS = table.freeze({
		Small = "Small",
		Medium = "Medium",
		Large = "Large",
		Absurd = "Absurd",
	}),
}

return table.freeze(Constants)
