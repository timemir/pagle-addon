---@meta _
-- The one global the Pagle companion's data addon sets (core/pushed-content.md, PUSH-R1, PUSH-R2): Pagle_Content's
-- data file, which loads after Pagle, sets it before PLAYER_LOGIN. Pagle never defines or writes it, and its zip never
-- holds Pagle_Content; Core reads it once (adapter/PushedContent.lua). Declarations for the types stage only.

--- `v`, `generatedAt`, `keyId`, `seq`, `expires`, `payload` and `sig`, as the companion wrote them; nil with no
--- Pagle_Content loaded. Core checks every field before it trusts one (PUSH-R13).
---@type table?
PagleContentData = nil
