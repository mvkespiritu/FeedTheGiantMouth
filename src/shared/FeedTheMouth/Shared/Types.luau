--!strict

export type UpgradeId = "Strength" | "CarryCapacity" | "ThrowPower" | "ValueMultiplier"
export type ObjectTierId = "Small" | "Medium" | "Large" | "Absurd"

export type PlayerData = {
	coins: number,
	upgrades: {
		Strength: number,
		CarryCapacity: number,
		ThrowPower: number,
		ValueMultiplier: number,
	},
}

export type BootstrapContext = {
	remotes: Folder,
	shared: Folder,
	services: {[string]: any}?,
	controllers: {[string]: any}?,
}

return nil
