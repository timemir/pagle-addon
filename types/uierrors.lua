---@meta _
-- FrameXML's error text frame, as far as Stats uses it (STA-R61: the red UI error for a 4th watched Dry spell), which
-- Ketho's vscode-wow-api annotations (WOW_API_COMMIT, scripts/tools.env) lack. Declarations for the types stage only:
-- never loaded by the game, and excluded from luacheck. The pinned forever dump lists the frame (Frames.lua,
-- BIR_COMMIT).

--- The game's error text at the top of the screen (UIErrorsFrame.xml), a ScrollingMessageFrame.
---@class UIErrorsFrame : Frame
UIErrorsFrame = {}

--- Adds a line of text in the colour given (ScrollingMessageFrame:AddMessage).
---@param text string
---@param r number?
---@param g number?
---@param b number?
function UIErrorsFrame:AddMessage(text, r, g, b) end
