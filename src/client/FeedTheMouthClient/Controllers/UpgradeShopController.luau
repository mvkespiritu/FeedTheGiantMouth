--!strict

local UpgradeShopController = {}
UpgradeShopController.Name = "UpgradeShopController"

local BUTTON_TO_UPGRADE: {[string]: string} = {
	StrengthButton = "Strength",
	CarryCapacityButton = "CarryCapacity",
	ThrowPowerButton = "ThrowPower",
	ValueMultiplierButton = "ValueMultiplier",
}

function UpgradeShopController:Init(context)
	self.Context = context
	self.UpgradeConfig = require(context.shared.UpgradeConfig)
	self.RequestUpgradeRemote = context.remotes:WaitForChild("RequestUpgrade")
	self.PlayerDataChanged = context.remotes:WaitForChild("PlayerDataChanged")
	self.ButtonsByUpgrade = {}
	self.CurrentPlayerData = nil
end

function UpgradeShopController:Start()
	local uiController = self.Context.controllers.UIController
	self.UIController = uiController
	self.ShopFrame = uiController.UpgradeShopFrame
	self.UpgradeButton = uiController.HUDFrame:WaitForChild("UpgradeButton")
	self.ShopFrame.Visible = false

	if self.UpgradeButton:IsA("TextButton") then
		self.UpgradeButton.Activated:Connect(function()
			self:ToggleShop()
		end)
	end

	for buttonName, upgradeId in pairs(BUTTON_TO_UPGRADE) do
		local button = self.ShopFrame:FindFirstChild(buttonName)
		if button ~= nil and button:IsA("TextButton") then
			self.ButtonsByUpgrade[upgradeId] = button

			button.Activated:Connect(function()
				self:RequestUpgrade(upgradeId)
			end)
		end
	end

	self.PlayerDataChanged.OnClientEvent:Connect(function(data)
		self.CurrentPlayerData = data
		self:Render(data)
	end)

	self:Render(uiController.CurrentPlayerData)
end

function UpgradeShopController:ToggleShop()
	self.ShopFrame.Visible = not self.ShopFrame.Visible
end

function UpgradeShopController:RequestUpgrade(upgradeId: string)
	self.RequestUpgradeRemote:FireServer(upgradeId)
end

function UpgradeShopController:RenderButton(button: TextButton, displayName: string, priceText: string)
	local nameLabel = button:FindFirstChild("NameLabel")
	local priceLabel = button:FindFirstChild("PriceLabel")

	if nameLabel ~= nil and nameLabel:IsA("TextLabel") and priceLabel ~= nil and priceLabel:IsA("TextLabel") then
		button.Text = ""
		nameLabel.Text = displayName
		priceLabel.Text = priceText
		return
	end

	button.Text = displayName .. string.char(10) .. priceText
end

function UpgradeShopController:Render(data)
	local upgrades = if data ~= nil and data.upgrades ~= nil then data.upgrades else {}
	local coins = if data ~= nil and typeof(data.coins) == "number" then data.coins else 0

	for upgradeId, button in pairs(self.ButtonsByUpgrade) do
		local definition = self.UpgradeConfig.Definitions[upgradeId]
		if definition == nil then
			continue
		end

		local currentLevel = upgrades[upgradeId] or definition.defaultLevel
		local cost = self.UpgradeConfig.getCost(upgradeId, currentLevel)

		if cost == nil then
			self:RenderButton(button, definition.displayName, "MAX")
			button.AutoButtonColor = false
		else
			self:RenderButton(button, definition.displayName, tostring(cost) .. " COINS")
			button.AutoButtonColor = coins >= cost
		end
	end
end

return UpgradeShopController
