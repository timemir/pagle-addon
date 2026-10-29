---@meta _

-- The backend-generated load-on-demand data addon sets this envelope; Core verifies it before opening the log.
---@type table?
PagleRecoveryData = nil

-- Original branches, staged record indexes and stable completed-application markers, saved with PagleLog.
---@type table?
PagleRecovery = nil
