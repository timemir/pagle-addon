local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
local ns = loaded.ns

---@diagnostic disable-next-line: undefined-global -- stock Lua fixtures use dkjson, already pinned with busted
local json = require("dkjson")
local vectors = assert(json.decode(readFile("spec/fixtures/integrity-vectors.json")))

describe("the canonical core record and checkpoint contract (#302)", function()
	-- bytesHex carries records JSON text can't: lone or ill-formed UTF-8 bytes.
	local function recordBytes(vector)
		if vector.bytesHex == nil then
			return vector.entry
		end
		return (vector.bytesHex:gsub("%x%x", function(pair)
			return string.char(tonumber(pair, 16))
		end))
	end

	for _, vector in ipairs(vectors.records) do
		it("classifies " .. vector.name, function()
			assert.are.equal(vector.valid, ns.CanonicalRecordProblem(recordBytes(vector)) == nil)
		end)
	end

	it("executes the shared independently derived SHA-256 byte frames", function()
		local digest = ns.CheckpointInitial(vectors.logId, vectors.format)
		assert.are.equal(vectors.initial, digest)
		for _, variant in ipairs(vectors.initialVariants) do
			assert.are.equal(variant.digest, ns.CheckpointInitial(variant.logId, variant.format))
		end
		for _, variant in ipairs(vectors.entryVariants) do
			assert.are.equal(
				variant.digest,
				ns.CheckpointNext(variant.previous, variant.sequence, variant.guid, variant.entry)
			)
		end
		for _, step in ipairs(vectors.steps) do
			digest = ns.CheckpointNext(digest, step.sequence, step.guid, step.entry)
			assert.are.equal(step.digest, digest)
		end
	end)
end)
