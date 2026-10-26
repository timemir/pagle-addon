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

	it("refuses damaged record bytes instead of exporting a repaired history", function()
		local log = savedLog({ "S1|1|1791735001|0|86|150|0\n" })
		assert.is_nil(ns.PasteExport(log, 1, source.asOf))
	end)
end)
