-- A Paste string test vector (paste-string.md › Contracts): a small Catch log, cut into parts of 3 entries at an
-- as-of, each part's upload document and its Paste string as Core's logic/PasteString.lua and the vendored LibDeflate
-- 1.0.2 build them. Every Paste string here was decoded by pagle-backend's UploadDecoder (commit 4c94092, accepted
-- format 1) to the same logId, from, anchor, count, characters and entries, so it serves both sides as a vector
-- (UPL Contracts › The Paste string). spec/Pagle/logic/PasteString_spec.lua checks Core still builds it byte for byte.
return {
	log = {
		format = 1,
		logId = "3f9a2c1e7b0d4a65",
		characters = {
			{
				guid = "Player-4618-0A1B2C3D",
				name = "Ada",
				surname = "Brook",
				classID = 1,
				raceID = 1,
				faction = "Alliance",
				realmID = 4618,
				hardcore = false,
				firstSeen = 1791731680,
				lastSeen = 1791735090,
			},
			{
				guid = "Player-4618-0B2C3D4E",
				name = "Zo\195\171",
				classID = 8,
				raceID = 7,
				faction = "Alliance",
				realmID = 4618,
				firstSeen = 1791732000,
				lastSeen = 1791734000,
			},
		},
		entries = {
			"B1|1|1791731690|0|70374|1.60.1",
			"S1|1|1791731690|1|86|150|25",
			"C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1",
			"C1|1|1791731790|0|g|494|1439|1|148|453|86|25|263|||",
			"C1|2|1791732100|0|c|1100|1429|0|12|87|40|0||||6291x1,2934x2",
			"P1|1|1791733000|0|1|0",
			"U1|1|1791733100|0|core.crate|300",
			"A1|2|1791733200|0|Hunts|run|caf\195\169|with bars",
			"K1|1|1791734000|0|pagle-2026a|7",
		},
	},
	asOf = 1791735100,
	partSize = 3,
	parts = {
		{
			document = "PGL|1|3f9a2c1e7b0d4a65|1|1791735100|9|2|1||3|258|1a924a1a\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zo\195\171||8|7|Alliance|4618||1791732000|1791734000\nB1|1|1791731690|0|70374|1.60.1\nS1|1|1791731690|1|86|150|25\nC1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1\n",
			paste = "!PGL1!D9yVonmqqq4(7Djr7C7E)vAhq0qrKOlDhogjewyjxfKM3iEm4fJZiheKUr7CFF3UhF4rcQVuQ(bmMEwoB1yOncPcsAaIWc9TbuPpKjQfVvr1DCQ(X4YolI8oPd9(d6DS7CL9lZZVTAGDttVwFFyKRpIYMteZxJbPi)x0pAS75P5V(KmZ0ns2a9IC1H1IUE87kJyrA)vs0KrSpk7H7PBQbZrIG0Ui3H)0LSudDGwPHAAzTXY0c6kGpqFujzud5lW99d",
		},
		{
			document = "PGL|1|3f9a2c1e7b0d4a65|1|1791735100|9|2|4|Player-4618-0A1B2C3D-1791731747-0|3|275|ef380986\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zo\195\171||8|7|Alliance|4618||1791732000|1791734000\nC1|1|1791731790|0|g|494|1439|1|148|453|86|25|263|||\nC1|2|1791732100|0|c|1100|1429|0|12|87|40|0||||6291x1,2934x2\nP1|1|1791733000|0|1|0\n",
			paste = "!PGL1!Tbzponqmuq4(9SWk9(Z)8k3eq0qXwtNjzdcXkwPufKMBehdUyXoKfeiCH1ipV5BS949pag6bVi74P0t0ERed1J4KZjnWebhcmmoxEF6yVf5CpnWBKT6T9FnfNSupbfskGPdAM8CS7)cGH9fS54YYRTkWW88lL32nH2qGUwkhZRYa50VbDbJDhEC5ZpaYi9hixdkeTYWQYUT83VP6ov76zyUb2uV5yzybf5iKaKOcGwgzfx7FGWoWnbBI3UTcYjynJ6kkoFIVrC1ojDJ)0NsxYYG6od",
		},
		{
			document = "PGL|1|3f9a2c1e7b0d4a65|1|1791735100|9|2|7|Player-4618-0A1B2C3D-1791733000-0|3|250|95b66f02\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zo\195\171||8|7|Alliance|4618||1791732000|1791734000\nU1|1|1791733100|0|core.crate|300\nA1|2|1791733200|0|Hunts|run|caf\195\169|with bars\nK1|1|1791734000|0|pagle-2026a|7\n",
			paste = "!PGL1!T9yqonmmqu09(uWfiOzSJTtwMciqcw0nSHDtCDGkIsQCtfcP)fcXXOxmCkbqvIDFz98B()13(ayy6QfDGJ(wAtP4S5NyFn7nwMiudn8yDV8Emvu64QcQHxPVYCDX3ugIOccgOTzABRZ1rA1)9b0SrWQ044RZNan99BLHqeZqGwok7Q(jAPA6CrN0uEdEA84Nav5IDUKLpQZvAjwMJQh5F3KzEtecJP4LHKmfrU)QgoVYfa9jG7ommThPddiiDh)aVTD6LlAL0E19)jBwEMDN8CFSqtANaV6R",
		},
	},
}
