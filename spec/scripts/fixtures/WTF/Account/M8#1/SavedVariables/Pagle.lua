
PagleDB = {
["global"] = {
["schemaVersion"] = 1,
["dev"] = true,
["probe"] = {
["time"] = 1793790000,
["locale"] = "enUS",
["build"] = {
["version"] = "1.61.0",
["build"] = "71002",
["date"] = "Nov  3 2026",
["interface"] = 16100,
},
["checks"] = {
[3] = {
["exists"] = true,
["zone"] = "Darkshore",
["map"] = 1439,
["keys"] = {
"GetCurrentWeather", -- [1]
},
["call"] = "0, 0",
["values"] = {
0, -- [1]
0, -- [2]
},
},
[8] = {
["call"] = "C_QuestLog.GetTitleForQuestID",
["later"] = "Nat Pagle, Angler Extreme",
["laterRead"] = true,
},
[11] = {
["checked"] = 173,
["missing"] = {
"C_GameRules.IsHardcoreActive", -- [1]
"GetCurrentRegion", -- [2]
},
},
[12] = {
["projectId"] = 18,
["camelot"] = 18,
["forever"] = true,
},
[16] = {
["max"] = 10,
["sets"] = {
"Pagle Fishing", -- [1]
"Pagle Previous", -- [2]
},
},
[18] = {
["dailyExists"] = true,
["weeklyExists"] = false,
["daily"] = 3600,
["serverTime"] = 1793790000,
["gameTime"] = "11:00",
["fallbackDayStart"] = 1793750400,
},
[19] = {
["exists"] = false,
},
[20] = {
["bit"] = false,
["vectors"] = {
{
["h"] = 2657620567,
["band"] = 2,
}, -- [1]
{
["h"] = 4227872046,
["band"] = 4,
}, -- [2]
{
["h"] = 1190098033,
["band"] = 2,
}, -- [3]
{
["h"] = 3063819173,
["band"] = 3,
}, -- [4]
},
},
[21] = {
["reference"] = {
["name"] = "Fishing",
["icon"] = 136245,
},
["knownCall"] = "C_SpellBook.IsSpellKnown",
["spells"] = {
{
["id"] = 7620,
["name"] = "Fishing",
["icon"] = 136245,
["known"] = true,
}, -- [1]
{
["id"] = 1240948,
["name"] = "Fishing Rank 5",
["icon"] = 136245,
["known"] = false,
}, -- [2]
},
["channels"] = {
{
["id"] = 7620,
["count"] = 3,
["listed"] = true,
}, -- [1]
},
},
[22] = {
["exists"] = true,
["keys"] = {
{
["name"] = "IsHardcoreActive",
["type"] = "function",
}, -- [1]
{
["name"] = "IsSelfFoundAllowed",
["type"] = "function",
}, -- [2]
},
["calls"] = {
{
["name"] = "IsSelfFoundAllowed",
["ok"] = true,
["result"] = "true",
}, -- [1]
},
},
},
},
},
["profileKeys"] = {
["Ada - Brook"] = "Default",
},
}
PagleLog = {
["format"] = 1,
["logId"] = "8c1d5e2f9a3b7c40",
["characters"] = {
{
["guid"] = "Player-4618-0A1B2C3D",
["name"] = "Ada",
["surname"] = "Brook",
["firstSeen"] = 1793789000,
["lastSeen"] = 1793790000,
}, -- [1]
},
["entries"] = {
"B1|1|1793789000|0|71002|1.61.0", -- [1]
},
}
