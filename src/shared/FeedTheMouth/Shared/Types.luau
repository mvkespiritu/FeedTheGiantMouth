--!strict

export type UpgradeId = "Strength" | "CarryCapacity" | "ThrowPower" | "ValueMultiplier"
export type ObjectTierId = "Small" | "Medium" | "Large" | "Absurd"

export type PlayerData = {
	schemaVersion: number,
	coins: number,
	upgrades: {
		Strength: number,
		CarryCapacity: number,
		ThrowPower: number,
		ValueMultiplier: number,
	},
	discoveredItems: {[string]: boolean},
}

export type BootstrapContext = {
	remotes: Folder,
	shared: Folder,
	services: {[string]: any}?,
	controllers: {[string]: any}?,
}

return nil
