--!strict

local FeedbackController = {}
FeedbackController.Name = "FeedbackController"

function FeedbackController:Init(context)
	self.Context = context
	self.PlayFeedback = context.remotes:WaitForChild("PlayFeedback")
end

function FeedbackController:Start()
	self.PlayFeedback.OnClientEvent:Connect(function(feedbackName, payload)
		self:HandleFeedback(feedbackName, payload)
	end)
end

function FeedbackController:HandleFeedback(feedbackName: string, payload)
	payload = payload or {}

	if feedbackName == "Reward" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowReward(payload.amount or 0)
		end
	elseif feedbackName == "LockedObject" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowLockMessage(payload.requiredStrength or 1)
		end
	elseif feedbackName == "NotEnoughCoins" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowStatusMessage(`Need {payload.cost or 0} coins`)
		end
	elseif feedbackName == "UpgradeMaxed" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowStatusMessage(`{payload.displayName or "Upgrade"} maxed`)
		end
	elseif feedbackName == "UpgradePurchased" then
		local uiController = self.Context.controllers.UIController
		if uiController ~= nil then
			uiController:ShowStatusMessage(`{payload.displayName or "Upgrade"} level {payload.level or "?"}`)
		end
	end
end

return FeedbackController
