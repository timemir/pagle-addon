-- Current producer input and independent document-v2 golden parts from spec/fixtures/document-v2.json (format4). The
-- log's entries are an array here; the specs pack them into format 4's blocks (setLogEntries).
return {
	log = {
		format = 4,
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
			"S1|2|1791733200|0|86|150|0",
			"K1|1|1791734000|0|pagle-2026a|7",
		},
	},
	asOf = 1791735100,
	partSize = 3,
	parts = {
		{
			document = "PGL|2|3f9a2c1e7b0d4a65|4|1791735100|9|2|1|080ae791ce5a68d738650c428d71e02d49c400c1adc9a624ec077a29cf56d400|3|270|1b922062\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zoë||8|7|Alliance|4618||1791732000|1791734000\nB1|1|1791731690|0|70374|1.60.1|pagle-2026a\nS1|1|1791731690|1|86|150|25\nC1|1|1791731747|0|c|494|1439|1|148|453|86|25|263|||6358x1\n",
			paste = "!PGL2!DbzSontmqq4(7D5I2D96DTlVeq0qrKOJohFo)cXjckvG08g9)yWlg(qjsq6w5zMVzK3)WJqq4yUivU5hOzTyrOG9m7HiteYDhmOevA9hRTyXsZEizrQQs)KBKmR5QsuLlZ1CXeTvj3lsUEmAZDfeG4e4dzritg2Vu(SDEunonst8wzx4omnxW2ZNo9AVqgtllVuER2WQjqx2eBPRNrkt)f0py07XZN(6)aj43a5sqHORm6tJg2Uw3v8zQ3LtbV)lSXOnmEV8VL2OqIvgE6gRmsg4ibjoS7xAU6DmvO5ognKxv0e0yynGeHybayHy6dE47d",
		},
		{
			document = "PGL|2|3f9a2c1e7b0d4a65|4|1791735100|9|2|4|c0e6e662df20d4a75627d4f5bd8cc062c7cf4eb35d6d522a607187cb791e2635|3|275|ef380986\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zoë||8|7|Alliance|4618||1791732000|1791734000\nC1|1|1791731790|0|g|494|1439|1|148|453|86|25|263|||\nC1|2|1791732100|0|c|1100|1429|0|12|87|40|0||||6291x1,2934x2\nP1|1|1791733000|0|1|0\n",
			paste = "!PGL2!DbzSontmqq4(7zHiT761RTltciA(lsnD(S9Hq)rePufKM3iEm4fd7O7ecURzK2z(M17PN)he4wszPWTWmv1S5HcoK4GZZeHu3HIc1SMzsDrgMcEtcvDXpxJLczsjuw02SZxTQxKSrbogkZDonXCE4Ge8OT4IukAtNoN)ODDNACChTNpihDpI91moC9YL)dU)V)853YVxAyyc06oXwCt6Pe9Bq3XOpHxU81Nare(dK1GcrBm0UC64OUv8He176vOP(vqDPXenc17q0G4r)1aGrgzd34mrOaEiyvsJTvqmaDmO)zsIVXpijNEtMo9tFo6Ewg003d",
		},
		{
			document = "PGL|2|3f9a2c1e7b0d4a65|4|1791735100|9|2|7|5043c526647ce3d5949412e7e4f9027a447b482f9d2598750e92322e16a5c6e2|3|233|c68be854\nPlayer-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\nPlayer-4618-0B2C3D4E|Zoë||8|7|Alliance|4618||1791732000|1791734000\nU1|1|1791733100|0|core.crate|300\nS1|2|1791733200|0|86|150|0\nK1|1|1791734000|0|pagle-2026a|7\n",
			paste = "!PGL2!vbzSormmmy49(UCiBh7K4XEaIby4KqSWwAQlcrffvXcs(nIhdEXi94oHoLL)i)5p7Kd39GtEyslufT0amYLO4SJjftbbbW1grYfGdvHIrovTWOOSYizjJNuGsfMtdCMM0rs0CsatPargglsnATH4ui41yEWYc3DyU8LTUJJyEh0J7PRd349JfF)6YYBo2o9ZZVwEVA(gKdN2jmMphfqHlfDudFR)8YpF7EUT3xk5uJeaNDWTy3tBJ7V7HTNm41Lv7Q6A5tZdnGhX2NWja6iqo6O0cD3)FVBUAL(O8YSTJakw8u3V",
		},
	},
}
