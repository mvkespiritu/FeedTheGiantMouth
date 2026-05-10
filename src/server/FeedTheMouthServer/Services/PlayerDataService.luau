--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local saveInStudio = ServerStorage:FindFirstChild("SaveInStudio")
if saveInStudio == nil then
	saveInStudio = Instance.new("BoolValue")
	saveInStudio.Name = "SaveInStudio"
	saveInStudio.Parent = ServerStorage
end

if saveInStudio:IsA("BoolValue") then
	saveInStudio.Value = true
end

local DataStore2 = require(script.Parent.Parent:WaitForChild("Packages"):WaitForChild("DataStore2"):WaitForChild("MainModule"))

local PlayerDataService = {}
PlayerDataService.Name = "PlayerDataService"

local DATASTORE_MAIN_KEY = "FeedTheMouthPlayerData_v1"
local PROFILE_STORE_KEY = "profile"
local SCHEMA_VERSION = 1
local LOAD_BACKUP_RETRIES = 3
local AUTOSAVE_INTERVAL_SECONDS = 60
local DATA_LOAD_FAILED_MESSAGE = "Your data failed to load. Please rejoin in a moment."

DataStore2.Combine(DATASTORE_MAIN_KEY, PROFILE_STORE_KEY)

local function createDefaultData(upgradeConfig)
	local upgrades = {}

	if upgradeConfig ~= nil then
		for upgradeId, definition in pairs(upgradeConfig.Definitions) do
			upgrades[upgradeId] = definition.defaultLevel or 1
		end
	else
		upgrades.Strength = 1
		upgrades.CarryCapacity = 1
		upgrades.ThrowPower = 1
		upgrades.ValueMultiplier = 1
	end

	return {
		schemaVersion = SCHEMA_VERSION,
		coins = 0,
		upgrades = upgrades,
	}
end

local function getSaveStore(store)
	if store.combinedStore ~= nil then
		return store.combinedStore
	end

	return store
end

local function isStoreBackup(store): boolean
	return getSaveStore(store):IsBackup()
end

function PlayerDataService:Init(context)
	self.Context = context
	self.UpgradeConfig = require(context.shared.UpgradeConfig)
	self.ProjectConfig = require(context.shared.ProjectConfig)
	self.PlayerDataChanged = context.remotes:WaitForChild("PlayerDataChanged")
	self.DataByPlayer = {}
	self.StoreByPlayer = {}
	self.ReadOnlyByPlayer = {}
	self.PlayerConnections = {}
	self.IsShuttingDown = false
end

function PlayerDataService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:LoadPlayer(player)
		self:BindAdminCommands(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:SavePlayerData(player, "player leaving")
		self:CleanupPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:LoadPlayer(player)
		self:BindAdminCommands(player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL_SECONDS)
			self:SaveAllPlayers("autosave")
		end
	end)

	game:BindToClose(function()
		self.IsShuttingDown = true
		self:SaveAllPlayers("server shutdown")
	end)
end

function PlayerDataService:LoadPlayer(player)
	if self.DataByPlayer[player] ~= nil then
		return self.DataByPlayer[player]
	end

	local defaultData = createDefaultData(self.UpgradeConfig)
	local store = DataStore2(PROFILE_STORE_KEY, player)
	store:SetBackup(LOAD_BACKUP_RETRIES)

	self.StoreByPlayer[player] = store

	local success, loadedData = pcall(function()
		return store:GetTable(defaultData)
	end)

	if not success or typeof(loadedData) ~= "table" then
		return self:FailLoad(player, defaultData, `DataStore read failed: {loadedData}`)
	end

	if isStoreBackup(store) then
		return self:FailLoad(player, defaultData, "DataStore2 backup data is active")
	end

	local data, changed = self:NormalizeData(loadedData)
	if changed then
		store:Set(data)
	end

	self.DataByPlayer[player] = data
	self:PushData(player)
	return data
end

function PlayerDataService:FailLoad(player, fallbackData, reason: string)
	self.DataByPlayer[player] = fallbackData
	self.ReadOnlyByPlayer[player] = true
	warn(`[PlayerDataService] Failed to load data for {player.UserId}. {reason}`)

	task.defer(function()
		if player.Parent ~= nil then
			player:Kick(DATA_LOAD_FAILED_MESSAGE)
		end
	end)

	return fallbackData
end

function PlayerDataService:NormalizeData(data)
	local defaultData = createDefaultData(self.UpgradeConfig)
	local changed = false

	if typeof(data) ~= "table" then
		return defaultData, true
	end

	if data.schemaVersion ~= SCHEMA_VERSION then
		data.schemaVersion = SCHEMA_VERSION
		changed = true
	end

	if typeof(data.coins) ~= "number" then
		data.coins = defaultData.coins
		changed = true
	else
		local coins = math.max(0, math.floor(data.coins))
		if data.coins ~= coins then
			data.coins = coins
			changed = true
		end
	end

	if typeof(data.upgrades) ~= "table" then
		data.upgrades = {}
		changed = true
	end

	for upgradeId, defaultLevel in pairs(defaultData.upgrades) do
		local definition = self.UpgradeConfig.Definitions[upgradeId]
		local rawLevel = data.upgrades[upgradeId]
		local level = if typeof(rawLevel) == "number" then math.floor(rawLevel) else defaultLevel

		level = math.max(level, defaultLevel)
		if definition ~= nil and typeof(definition.maxLevel) == "number" then
			level = math.min(level, definition.maxLevel)
		end

		if rawLevel ~= level then
			data.upgrades[upgradeId] = level
			changed = true
		end
	end

	return data, changed
end

function PlayerDataService:GetData(player)
	local data = self.DataByPlayer[player]
	if data == nil then
		data = self:LoadPlayer(player)
	end

	return data
end

function PlayerDataService:GetUpgradeLevel(player, upgradeId: string): number
	local data = self:GetData(player)
	return data.upgrades[upgradeId] or 1
end

function PlayerDataService:AddCoins(player, amount: number)
	if amount <= 0 then
		return
	end

	local data = self:GetData(player)
	data.coins = math.max(0, data.coins + amount)
	self:CommitData(player)
	self:PushData(player)
end

function PlayerDataService:TrySpendCoins(player, amount: number): boolean
	if amount <= 0 then
		return false
	end

	local data = self:GetData(player)
	if data.coins < amount then
		return false
	end

	data.coins -= amount
	self:CommitData(player)
	self:PushData(player)
	return true
end

function PlayerDataService:TryPurchaseUpgrade(player, upgradeId: string, cost: number, newLevel: number): boolean
	if cost < 0 then
		return false
	end

	local data = self:GetData(player)
	if data.coins < cost then
		return false
	end

	data.coins -= cost
	data.upgrades[upgradeId] = newLevel
	self:CommitData(player)
	self:PushData(player)
	return true
end

function PlayerDataService:SetUpgradeLevel(player, upgradeId: string, level: number)
	local data = self:GetData(player)
	data.upgrades[upgradeId] = level
	self:CommitData(player)
	self:PushData(player)
end

function PlayerDataService:CommitData(player): boolean
	if self.ReadOnlyByPlayer[player] then
		return false
	end

	local store = self.StoreByPlayer[player]
	local data = self.DataByPlayer[player]
	if store == nil or data == nil then
		return false
	end

	store:Set(data)
	return true
end

function PlayerDataService:SavePlayerData(player, reason: string): boolean
	if self.ReadOnlyByPlayer[player] then
		return false
	end

	local store = self.StoreByPlayer[player]
	if store == nil then
		return false
	end

	local saveStore = getSaveStore(store)
	if saveStore:IsBackup() then
		warn(`[PlayerDataService] Skipped save for {player.UserId} during {reason}; backup data is active.`)
		return false
	end

	if not saveStore.valueUpdated then
		return false
	end

	local success, result = pcall(function()
		saveStore:Save()
	end)

	if not success then
		warn(`[PlayerDataService] Failed to save data for {player.UserId} during {reason}: {result}`)
		return false
	end

	return true
end

function PlayerDataService:SaveAllPlayers(reason: string)
	for _, player in ipairs(Players:GetPlayers()) do
		self:SavePlayerData(player, reason)
	end
end

function PlayerDataService:ResetPlayerData(targetPlayer, adminPlayer): boolean
	local store = self.StoreByPlayer[targetPlayer]
	if store == nil then
		return false
	end

	local data = createDefaultData(self.UpgradeConfig)
	self.DataByPlayer[targetPlayer] = data
	self.ReadOnlyByPlayer[targetPlayer] = nil
	store:Set(data)
	self:SavePlayerData(targetPlayer, `admin reset by {adminPlayer.UserId}`)
	self:PushData(targetPlayer)
	return true
end

function PlayerDataService:BindAdminCommands(player)
	if self.PlayerConnections[player] ~= nil then
		return
	end

	self.PlayerConnections[player] = player.Chatted:Connect(function(message)
		self:HandleAdminCommand(player, message)
	end)
end

function PlayerDataService:HandleAdminCommand(player, message: string)
	local parts = string.split(message, " ")
	local command = string.lower(parts[1] or "")
	local resetCommand = string.lower(self.ProjectConfig.AdminResetCommand or "!resetdata")
	if command ~= resetCommand then
		return
	end

	if not self:IsAdmin(player) then
		warn(`[PlayerDataService] {player.UserId} attempted to use {resetCommand} without admin access.`)
		return
	end

	local targetArg = parts[2]
	local targetToken = if targetArg ~= nil then string.lower(targetArg) else "me"
	if targetToken == "all" then
		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			self:ResetPlayerData(targetPlayer, player)
		end

		self:SendStatus(player, "Reset data for all online players")
		return
	end

	local targetPlayer = if targetToken == "me" then player else self:FindOnlinePlayer(targetArg)
	if targetPlayer == nil then
		self:SendStatus(player, "Player not found")
		return
	end

	if self:ResetPlayerData(targetPlayer, player) then
		self:SendStatus(player, `Reset data for {targetPlayer.Name}`)
	else
		self:SendStatus(player, "Data reset failed")
	end
end

function PlayerDataService:IsAdmin(player): boolean
	if RunService:IsStudio() then
		return true
	end

	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end

	for _, adminUserId in ipairs(self.ProjectConfig.AdminUserIds or {}) do
		if player.UserId == adminUserId then
			return true
		end
	end

	return false
end

function PlayerDataService:FindOnlinePlayer(token: string?)
	if token == nil then
		return nil
	end

	local userId = tonumber(token)
	if userId ~= nil then
		for _, player in ipairs(Players:GetPlayers()) do
			if player.UserId == userId then
				return player
			end
		end
	end

	local loweredToken = string.lower(token)
	local match = nil
	for _, player in ipairs(Players:GetPlayers()) do
		local loweredName = string.lower(player.Name)
		local loweredDisplayName = string.lower(player.DisplayName)
		if loweredName == loweredToken or loweredDisplayName == loweredToken then
			return player
		end

		if string.sub(loweredName, 1, #loweredToken) == loweredToken then
			if match ~= nil then
				return nil
			end

			match = player
		end
	end

	return match
end

function PlayerDataService:SendStatus(player, message: string)
	local feedbackService = self.Context.services.FeedbackService
	if feedbackService ~= nil then
		feedbackService:Play(player, "StatusMessage", {
			message = message,
		})
	end
end

function PlayerDataService:CleanupPlayer(player)
	local connection = self.PlayerConnections[player]
	if connection ~= nil then
		connection:Disconnect()
	end

	self.PlayerConnections[player] = nil
	self.DataByPlayer[player] = nil
	self.StoreByPlayer[player] = nil
	self.ReadOnlyByPlayer[player] = nil
end

function PlayerDataService:PushData(player)
	self.PlayerDataChanged:FireClient(player, self:GetData(player))
end

return PlayerDataService
