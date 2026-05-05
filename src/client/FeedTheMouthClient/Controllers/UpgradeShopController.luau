--!strict

local UpgradeShopController = {}
UpgradeShopController.Name = "UpgradeShopController"

local BUTTON_TO_UPGRADE = {
	StrengthButton = "Strength",
	CarryCapacityButton = "CarryCapacity",
	ThrowPowerButton = "ThrowPower",
	ValueMultiplierButton = "ValueMultiplier",
}

function UpgradeShopController:Init(context)
	self.Context = context
	self.RequestUpgrade = context.remotes:WaitForChild("RequestUpgrade")
end

function UpgradeShopController:Start()
	local uiController = self.Context.controllers.UIController
	local shopFrame = uiController.UpgradeShopFrame

	for buttonName, upgradeId in pairs(BUTTON_TO_UPGRADE) do
		local button = shopFrame:FindFirstChild(buttonName)
		if button ~= nil and button:IsA("TextButton") then
			button.Activated:Connect(function()
				self.RequestUpgrade:FireServer(upgradeId)
			end)
		end
	end
end

return UpgradeShopController
