-- A Paste string test vector (paste-string.md › Contracts): a small Catch log, cut into parts of 3 entries at an
-- as-of, each part's upload document and its Paste string as Core's logic/PasteString.lua and the vendored LibDeflate
-- 1.0.2 build them, its log at format 2, the format 1.0 ships (LOG-R18). The format-1 vector before it was decoded
-- by pagle-backend's UploadDecoder (commit 4c94092) to the same logId, from, anchor, count, characters and entries;
-- this one, rebuilt by Core at format 2, needs the same check there, since pagle-backend refuses a format below 1.0's
-- as dev_log (its OPS-R135, OPS-R136). It serves both sides as a vector (UPL Contracts › The Paste string).
-- spec/Pagle/logic/PasteString_spec.lua checks Core still builds it byte for byte.
return {
	log = {
		format = 2,
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
			document = "PGL|1|3f9a2c1e7b0d4a65|2|1791735100|9|2|1||3|258|1a924a1a\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zo\195\171||8|7|Alliance|4618||1791732000|1791734000\nB1|1|1791731690|0|70374|1.60.1\nS1|1|1791731690|1|86|150|25\nC1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1\n",
			paste = "!PGL1!DbztQjqqqu499DrPQUQ(NA5mMq2KfcUl76mobco4aUsH3nkhdVy2T4ar39AE93xrvB)4tWq(Xk(bEm9nTxlXa8GtgNKateS2tab(qgCX8AHlUTtLlJNwProVI64E)g5n0TVG(tZZhQam6MM(TCCyeTpb6HtoMxIbYONfDxJ(o(A(6FazKErYdqprlo0A013g3IEJQZkrssbVosRz3UxQzKJGduDJCB(xxstv0bOwfvfR1OzObPb4R3LOaGOeYNz3Td",
		},
		{
			document = "PGL|1|3f9a2c1e7b0d4a65|2|1791735100|9|2|4|Player-4618-0A1B2C3D-1791731747-0|3|275|ef380986\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zo\195\171||8|7|Alliance|4618||1791732000|1791734000\nC1|1|1791731790|0|g|494|1439|1|148|453|86|25|263|||\nC1|2|1791732100|0|c|1100|1429|0|12|87|40|0||||6291x1,2934x2\nP1|1|1791733000|0|1|0\n",
			paste = "!PGL1!TbzVonmqqq4E)SGL2)UF2sNaIgkCnDhooiewyPufKM3iEm4fJ7cXcbIRAoT7mF7UJ3)ayOh9ImXZPNOdwjgGao5CsdmrWRFnmUuEF(uVf5CpnW7K96T9F3fNSupbfskG5JAM8CS7)mGHdfS7066RvQmgwwEP820mAnb6kuoM3KbYPFh0LyS7WJRF(bqgP)eYvJcrBzyvz3(gUTP1PkRNH5gyt9wfldlOihHu3(OcGMNT7G0UdeMa3eSjEBAfKtWAfQVO48z(gXv7S0n(dpLU4Lb191p",
		},
		{
			document = "PGL|1|3f9a2c1e7b0d4a65|2|1791735100|9|2|7|Player-4618-0A1B2C3D-1791733000-0|3|250|95b66f02\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zo\195\171||8|7|Alliance|4618||1791732000|1791734000\nU1|1|1791733100|0|core.crate|300\nA1|2|1791733200|0|Hunts|run|caf\195\169|with bars\nK1|1|1791734000|0|pagle-2026a|7\n",
			paste = "!PGL1!T9ymormmuq0(Ck4cy0)7eBNuMfqGeuSn0q3pEDGveLGCYkesZfcXXyVyydbqReDZxAM3m)TxFhyu23iAphCD0UkXAGgSRHDLgMi0KoDy7G8wiQQSCTIA5n6lkVu9TRsIifHsOnj3MoRTN0f)xa0UtWM400ZPwz0omSxg9bKnbATu2w)J0qn0PG(ct1v4HPJFauNg2PqwdQttAvwLKf3NRBDT5FIGFkgo3hLLas7VOL)9PZHtgU5W4YmIhgHx6p(oED)YtN1jX5IB)dwgEY7lYJdbLM0wbUIp)d",
		},
	},
}
