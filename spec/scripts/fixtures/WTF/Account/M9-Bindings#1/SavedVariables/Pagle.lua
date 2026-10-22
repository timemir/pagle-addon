PagleLog = {
["characters"] = {
{
["guid"] = "Player-4618-0A1B2C3D",
["name"] = "Ada",
["surname"] = "Brook",
["firstSeen"] = 1791800000,
["lastSeen"] = 1791800700,
},
},
["format"] = 1,
["logId"] = "9b3e5c7a1d2f4086",
["entries"] = {
"B1|1|1791800000|0|70338|1.60.1", -- [1]
"S1|1|1791800000|1|150|150|25", -- [2]
"C1|1|1791800060|0|c|494|1439|1|12|0|150|25||||6303x1", -- [3]
"U1|1|1791800100|0|hunts.notebookcover.leather|0", -- [4]
"U1|1|1791800200|0|ledger.binding.birch|150", -- [5]
"C1|1|1791800260|0|c|495|1439|1|40|0|150|25||||19803x1", -- [6]
"U1|1|1791800300|0|hunts.notebookcover.oilcloth|150", -- [7]
"U1|1|1791800400|0|core.toaststyle.ripple|150", -- [8]
"U1|1|1791800400|1|hunts.notebookcover.tooled|400", -- [9]
"U1|1|1791800500|0|core.binding.tooled|400", -- [10]
"C1|1|1791800560|0|g|497|1439|1|12|0|150|25||||", -- [11]
"A1|1|1791800600|0|Hunts|note|U1|1|2|0|ledger.binding.birch|150", -- [12]
},
}
PagleDB = {
["global"] = {
["schemaVersion"] = 2,
["coins"] = {
["earned"] = {
["Ledger"] = 2000,
},
},
["catchCounts"] = {
["logId"] = "9b3e5c7a1d2f4086",
["rulesVersion"] = 1,
["seq"] = 12,
["entry"] = "A1|1|1791800600|0|Hunts|note|U1|1|2|0|ledger.binding.birch|150",
["counts"] = {
[6303] = 1,
[19803] = 1,
},
},
["projections"] = {
["fieldReport"] = {
["lastSeq"] = 3,
["logId"] = "9b3e5c7a1d2f4086",
["fingerprint"] = "0123456789abcdef",
["rulesVersion"] = 1,
["projection"] = {
["rows"] = {
},
},
},
["varieties"] = {
["lastSeq"] = 12,
["logId"] = "9b3e5c7a1d2f4086",
["fingerprint"] = "0123456789abcdef",
["rulesVersion"] = 1,
["projection"] = {
["bySpecies"] = {
},
},
},
["wallet"] = {
["lastSeq"] = 12,
["logId"] = "9b3e5c7a1d2f4086",
["fingerprint"] = "0123456789abcdef",
["rulesVersion"] = 1,
["projection"] = {
["spent"] = 1250,
["purchased"] = {
["hunts.notebookcover.leather"] = true,
["ledger.binding.birch"] = true,
["hunts.notebookcover.oilcloth"] = true,
["core.toaststyle.ripple"] = true,
["hunts.notebookcover.tooled"] = true,
["core.binding.tooled"] = true,
},
},
},
},
["goods"] = {
["core.toaststyle.ripple"] = {
["name"] = "Ripple",
["slot"] = "core.toaststyle",
["slotLabel"] = "Toast style",
["category"] = "Announcements",
["module"] = "Core",
["tier"] = 1,
},
["ledger.binding.field"] = {
["name"] = "Field Binding",
["slot"] = "ledger.binding",
["slotLabel"] = "Binding",
["category"] = "Fish Journal",
["module"] = "Ledger",
["default"] = true,
},
["ledger.binding.birch"] = {
["name"] = "Birch Bark",
["slot"] = "ledger.binding",
["slotLabel"] = "Binding",
["category"] = "Fish Journal",
["module"] = "Ledger",
["tier"] = 1,
},
["ledger.binding.level10"] = {
["name"] = "Tanned Hide",
["slot"] = "ledger.binding",
["slotLabel"] = "Binding",
["category"] = "Fish Journal",
["module"] = "Ledger",
["earned"] = true,
},
["hunts.notebookcover.leather"] = {
["name"] = "Saddle Leather",
["slot"] = "hunts.notebookcover",
["slotLabel"] = "Notebook cover",
["category"] = "Hunts",
["module"] = "Hunts",
["default"] = true,
},
["hunts.notebookcover.oilcloth"] = {
["name"] = "Oilcloth",
["slot"] = "hunts.notebookcover",
["slotLabel"] = "Notebook cover",
["category"] = "Hunts",
["module"] = "Hunts",
["tier"] = 1,
},
["hunts.notebookcover.pathfinder"] = {
["name"] = "Pathfinder's Calf",
["slot"] = "hunts.notebookcover",
["slotLabel"] = "Notebook cover",
["category"] = "Hunts",
["module"] = "Hunts",
["earned"] = true,
},
["hunts.trackerframe.inkwash"] = {
["name"] = "Ink Wash",
["slot"] = "hunts.trackerframe",
["slotLabel"] = "Hunts tracker frame",
["category"] = "Trackers",
["module"] = "Hunts",
["tier"] = 1,
},
},
},
["profileKeys"] = {
["Ada - Brook"] = "Default",
["Bram - Reed"] = "Alt",
["Cora - Fen"] = "Hunter",
["Dell - Moor"] = "Keeps",
},
["profiles"] = {
["Default"] = {
["appearance"] = {
["core.toaststyle"] = "core.toaststyle.ripple",
["ledger.binding"] = "ledger.binding.level10",
["hunts.notebookcover"] = "hunts.notebookcover.oilcloth",
},
["lengthUnit"] = "in",
},
["Alt"] = {
["appearance"] = {
["hunts.notebookcover"] = "hunts.notebookcover.leather",
},
},
["Hunter"] = {
["appearance"] = {
["hunts.notebookcover"] = "hunts.notebookcover.pathfinder",
["hunts.trackerframe"] = "hunts.trackerframe.inkwash",
},
},
["Keeps"] = {
["appearance"] = {
["core.binding"] = "core.binding.birch",
["ledger.binding"] = "ledger.binding.field",
},
},
},
}
