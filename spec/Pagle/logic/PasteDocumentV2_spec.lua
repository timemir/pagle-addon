local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
local ns = loaded.ns
local codec = loaded.env.LibStub("LibDeflate")

---@diagnostic disable-next-line: undefined-global -- stock Lua fixtures use dkjson, already pinned with busted
local json = require("dkjson")
local vectors = assert(json.decode(readFile("spec/fixtures/document-v2.json")))
---@diagnostic disable-next-line: undefined-global -- stock Lua fixture data is not shipped in the addon
local source = dofile("spec/Pagle/fixtures/PasteString.lua")

describe("document-v2 Paste exports (#302, #316)", function()
	it("emits the independently framed current-format documents and decodes every golden Paste string", function()
		local log = source.log
		log.entries[8] = "S1|2|1791733200|0|86|150|0"
		local export = assert(ns.PasteExport(log, 1, source.asOf, source.partSize))
		for n, part in ipairs(vectors.format3) do
			local document = ns.PasteDocument(export, n)
			assert.are.equal(part.document, document)
			local paste = ns.PasteString(document, codec)
			assert.are.equal("!PGL2!", paste:sub(1, 6))
			assert.are.equal(part.document, codec:DecompressDeflate(assert(codec:DecodeForPrint(paste:sub(7)))))
			assert.are.equal(part.document, codec:DecompressDeflate(assert(codec:DecodeForPrint(part.paste:sub(7)))))
		end
	end)

	it("uses format-specific prefix digests for generic historical framing", function()
		for format = 1, 2 do
			local log = source.log
			log.format = format
			local export = assert(ns.PasteExport(log, 4, source.asOf, source.partSize))
			for n = 1, 2 do
				assert.are.equal(vectors["format" .. format][n + 1].document, ns.PasteDocument(export, n))
			end
		end
		source.log.format = 3
	end)

	it("keeps checkpoints so a later export hashes no more than one part before its first anchor", function()
		local log = { logId = source.log.logId, format = 3, characters = source.log.characters, entries = {} }
		for seq, entry in ipairs(source.log.entries) do
			log.entries[seq] = entry
		end
		log.entries[8] = log.entries[8] or "S1|2|1791733200|0|86|150|0"
		local function anchors(export)
			local out = {}
			for n, part in ipairs(export.parts) do
				out[n] = { part.from, part.count, part.anchor }
			end
			return out
		end
		local stride, next = ns.PASTE_PART_ENTRIES, ns.CheckpointNext
		ns.PASTE_PART_ENTRIES = 2
		local hashed = 0
		ns.CheckpointNext = function(...)
			hashed = hashed + 1
			return next(...)
		end
		local cache = {}
		local ok, problem = pcall(function()
			local everything = anchors(assert(ns.PasteExport(log, 1, source.asOf, 2, nil, cache)))
			assert.are.same(everything, anchors(assert(ns.PasteExport(log, 1, source.asOf, 2))))
			-- Every second seq hashed: up to the last part's anchor.
			local kept, expected = {}, {}
			for seq in pairs(cache.at) do
				kept[#kept + 1] = seq
			end
			table.sort(kept)
			for seq = 2, everything[#everything][1] - 1, 2 do
				expected[#expected + 1] = seq
			end
			assert.are.same(expected, kept)
			-- From 6, the first anchor is at 5: hashing starts past the checkpoint kept at 4, not at 1.
			hashed = 0
			local new = anchors(assert(ns.PasteExport(log, 6, source.asOf, 2, nil, cache)))
			assert.are.equal(new[#new][1] - 1 - 4, hashed)
			assert.are.same(anchors(assert(ns.PasteExport(log, 6, source.asOf, 2))), new)
			-- A kept entry that isn't the log's any more drops every checkpoint, and the anchors stay right.
			cache.at[4].entry = "S1|1|1|0|1|1|0"
			hashed = 0
			assert.are.same(new, anchors(assert(ns.PasteExport(log, 6, source.asOf, 2, nil, cache))))
			assert.are.equal(new[#new][1] - 1, hashed)
			-- Another log starts them over.
			local other = { logId = "fedcba9876543210", format = 3, characters = log.characters, entries = log.entries }
			assert.is_truthy(ns.PasteExport(other, 1, source.asOf, 2, nil, cache))
			assert.are.equal("fedcba9876543210", cache.logId)
		end)
		ns.PASTE_PART_ENTRIES, ns.CheckpointNext = stride, next
		assert(ok, problem)
	end)

	it("refuses damaged record bytes instead of exporting a repaired history", function()
		local log = savedLog({ "S1|1|1791735001|0|86|150|0\n" })
		assert.is_nil(ns.PasteExport(log, 1, source.asOf))
	end)
end)
