-- A Paste string test vector (paste-string.md › Contracts): a small Catch log, cut into parts of 3 entries at an
-- as-of, each part's upload document and its Paste string as Core's logic/PasteString.lua and the vendored LibDeflate
-- 1.0.2 build them, its log at format 3, the format 1.0 ships (LOG-R18). The format-1 vector before it was decoded
-- by pagle-backend's UploadDecoder (commit 4c94092) to the same logId, from, anchor, count, characters and entries;
-- this one, rebuilt by Core at format 3, needs the same check there, since pagle-backend refuses a format below 1.0's
-- as dev_log (its OPS-R135, OPS-R136). It serves both sides as a vector (UPL Contracts › The Paste string).
-- spec/Pagle/logic/PasteString_spec.lua checks Core still builds it byte for byte.
return {
	log = {
		format = 3,
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
			"B1|1|1791731690|0|70374|1.60.1|pagle-2026a",
			"S1|1|1791731690|1|86|150|25",
			"C1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1",
			"C1|1|1791731790|0|g|494|1439|1|148|453|86|25|263|||",
			"C1|2|1791732100|0|c|1100|1429|0|12|87|40|0||||6291x1,2934x2",
			"P1|1|1791733000|0|1|0",
			"U1|1|1791733100|0|core.crate|300",
			"A1|2|1791733200|0|Hunts|def|p_test|1/1|caf\195\169|with bars",
			"K1|1|1791734000|0|pagle-2026a|7",
		},
	},
	asOf = 1791735100,
	partSize = 3,
	parts = {
		{
			document = "PGL|1|3f9a2c1e7b0d4a65|3|1791735100|9|2|1||3|270|1b922062\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zoë||8|7|Alliance|4618||1791732000|1791734000\nB1|1|1791731690|0|70374|1.60.1|pagle-2026a\nS1|1|1791731690|1|86|150|25\nC1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1\n",
			paste = "!PGL1!D1Cmormqmua0(5UKv2E8yptzYcIgkwj6OB2SbeIicARaP)nIJbxmMG2ibBNL9))8H7UhmIpvQYip5hPtA1sic2lShtmrOaPLPTtCc8XIiKjHdZ1pNo3PgN7OEEq2hVb9NQy48YYRTcm6NNFP(24ewdb6IjB5TXevO)d9lJElEC57VaYWVc5srHOndTnggwF3gFHA)YPORG3z0ogVxFEEQtiXQHhUkkJSborqsH9)5MREJzeAPXOXY6fndnfxlijiweawmL)Gd)m",
		},
		{
			document = "PGL|1|3f9a2c1e7b0d4a65|3|1791735100|9|2|4|Player-4618-0A1B2C3D-1791731747-0|3|275|ef380986\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zoë||8|7|Alliance|4618||1791732000|1791734000\nC1|1|1791731790|0|g|494|1439|1|148|453|86|25|263|||\nC1|2|1791732100|0|c|1100|1429|0|12|87|40|0||||6291x1,2934x2\nP1|1|1791733000|0|1|0\n",
			paste = "!PGL1!Tb5Ykrmqqu095BXa1R(rTmZO4gxK1URntgrmyGz1iC)J8ZWFm7ECcII9Qlu19Ck6X7Fam0JErM450t0bRedqbNCoPbMi4qGHXLY7ZN6TiN7PbENSxVT)7T4KL6PAjjfW8rntEo29FfWWHc2DAD91QvgdllVuEBAgTLaDvkhZBXa50VbDbJDhEC9ZpaYi9hixlkeTXWQXU9nDBxRtvxpdZnWM6TjwgwqrocjajQaO1r2W1(himbUfyt821kiNG1guFrX5Z8nIR2zPB8hFkDPldQ7R",
		},
		{
			document = "PGL|1|3f9a2c1e7b0d4a65|3|1791735100|9|2|7|Player-4618-0A1B2C3D-1791733000-0|3|261|40646c50\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zoë||8|7|Alliance|4618||1791732000|1791734000\nU1|1|1791733100|0|core.crate|300\nA1|2|1791733200|0|Hunts|def|p_test|1/1|café|with bars\nK1|1|1791734000|0|pagle-2026a|7\n",
			paste = "!PGL1!T9yVonmmuu4D)uWlqG712XozmfqGem0fwybDRJdurutvIriKoVqiEm6lgoLGqGy7m8D(B9v3cgMUArh4OFd1AfxjmG91S3uYeHAOHhR7L3IJfwhxvqn8k95Mlk(IYqevqztAhdl5SUqjP(pdOPvWQXHHNZTYOPVFRSleXmeOLszx13YsQ(pbDmg7L4(HdFauLh2VdzXOopPfPnlv3nx3YAN)eHWWy80WOKIiVFvdNF5cG(iW1VSlnH2yh2)qkoLaFgJG0D4D8620tNSrgNu38tUZ9KTTxESpwOjTtGx95d",
		},
	},
}
