---@class PagleNS
local ns = select(2, ...)

--- Whether the client is World of Warcraft: Forever (CORE-R4): its project ID is the Camelot one.
--- Either ID may be nil; a nil Camelot ID means some other client, never Forever.
---@param projectID integer? `WOW_PROJECT_ID`
---@param camelotID integer? `WOW_PROJECT_CAMELOT`
---@return boolean
function ns.IsForever(projectID, camelotID)
	return camelotID ~= nil and projectID == camelotID
end
