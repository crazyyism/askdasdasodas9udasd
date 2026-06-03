-- Compatibility shim: DialogueConfig now lives inside QuestConfig.
-- This module re-exports QuestConfig.Dialogue as a flat table so that any
-- existing code that does `require(...DialogueConfig)` continues to work
-- without modification.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestConfig = require(ReplicatedStorage.Shared.QuestConfig)

-- Build a flat table that matches the old DialogueConfig shape:
--   DialogueConfig.QuestGiverName
--   DialogueConfig.WelcomeDialogue
--   DialogueConfig.FreshwaterCleaning_Complete
--   ... etc.
local DialogueConfig = {}
DialogueConfig.QuestGiverName = QuestConfig.QuestGiverName

for key, value in pairs(QuestConfig.Dialogue) do
	DialogueConfig[key] = value
end

return DialogueConfig
