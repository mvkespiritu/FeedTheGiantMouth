--!strict

local FeedbackService = {}
FeedbackService.Name = "FeedbackService"

function FeedbackService:Init(context)
	self.Context = context
	self.PlayFeedback = context.remotes:WaitForChild("PlayFeedback")
end

function FeedbackService:Play(player, feedbackName: string, payload: {[string]: any}?)
	self.PlayFeedback:FireClient(player, feedbackName, payload or {})
end

function FeedbackService:PlayForAll(feedbackName: string, payload: {[string]: any}?)
	self.PlayFeedback:FireAllClients(feedbackName, payload or {})
end

return FeedbackService
