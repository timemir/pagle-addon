-- scripts/link-addons.sh: the macOS counterpart of link-addons.ps1, run as bash would run it over a scratch install
-- (a World of Warcraft folder with _retail_/Interface/AddOns and a .build.info beside it, in a path with a space) and
-- a scratch source of two addons. Whole links for a Forever install; with --retail, real folders of links and a
-- generated TOC, the repo's own TOCs left as they are (CORE-R2).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
local io = io
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
local os = os

local BUILD_INFO = "Branch!STRING:0|Active!DEC:1|Version!STRING:0|Product!STRING:0\n"
	.. "us|1|11.2.7.65299|wowt\nus|1|12.1.5.70575|wow\n"

--- Runs a shell command and returns its output (stderr too) and its exit code.
---@param command string
---@return string out, integer code
local function sh(command)
	local pipe = assert(io.popen(command .. ' 2>&1; echo "rc=$?"'))
	local out = pipe:read("*a")
	pipe:close()
	local body, code = out:match("^(.*)rc=(%d+)\n$")
	return body, tonumber(code)
end

--- A shell-quoted string.
---@param text string
---@return string
local function q(text)
	return "'" .. text:gsub("'", "'\\''") .. "'"
end

---@param path string
---@return string?
local function read(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local text = file:read("*a")
	file:close()
	return text
end

---@param path string
---@param text string
local function write(path, text)
	local file = assert(io.open(path, "wb"))
	file:write(text)
	file:close()
end

--- The link's target, or nil when it isn't a symlink.
---@param path string
---@return string?
local function target(path)
	local out, code = sh("readlink " .. q(path))
	return code == 0 and out:gsub("\n$", "") or nil
end

describe("scripts/link-addons.sh", function()
	local base, install, addOns, source

	--- Runs the script over the scratch install and source, with `args` after the AddOns folder.
	---@param args string
	---@return string out, integer code
	local function link(args)
		return sh("bash scripts/link-addons.sh " .. q(addOns) .. " --source " .. q(source) .. " " .. args)
	end

	before_each(function()
		local tmp = os.tmpname()
		os.remove(tmp)
		base = tmp .. " scratch"
		assert.are.equal(0, select(2, sh("mkdir -p " .. q(base))))
		-- The script resolves its folders (macOS's tmp is a link), so the spec compares against the real paths.
		base = (sh("cd " .. q(base) .. " && pwd -P"):gsub("\n$", ""))
		install = base .. "/World of Warcraft"
		addOns = install .. "/_retail_/Interface/AddOns"
		source = base .. "/checkout/addons"
		local made = select(
			2,
			sh(
				"mkdir -p "
					.. q(addOns)
					.. " "
					.. q(source .. "/Alpha/logic")
					.. " "
					.. q(source .. "/Beta/data")
					.. " "
					.. q(source .. "/Pagle/logic")
			)
		)
		assert.are.equal(0, made)
		write(install .. "/.build.info", BUILD_INFO)
		write(
			source .. "/Alpha/Alpha.toc",
			"## Interface: 16001\n## AllowLoadGameType: camelot\n## Title: Alpha\n## Version: @project-version@\n\nlogic\\One.lua\n"
		)
		write(source .. "/Alpha/logic/One.lua", "-- one\n")
		write(source .. "/Alpha/Bindings.xml", "<Bindings/>\n")
		write(
			source .. "/Beta/Beta.toc",
			"## Interface: 16001\n## AllowLoadGameType: camelot\n## Dependencies: Alpha\n\ndata\\Two.lua\n"
		)
		write(source .. "/Beta/data/Two.lua", "-- two\n")
		write(
			source .. "/Pagle/Pagle.toc",
			"## Interface: 16001\n## AllowLoadGameType: camelot\n## Title: Pagle\n## SavedVariables: PagleDB\n\n"
				.. "# the files\nlogic\\Core.lua\n"
		)
		write(source .. "/Pagle/logic/Core.lua", "-- core\n")
	end)

	after_each(function()
		sh("rm -rf " .. q(base))
	end)

	describe("without --retail", function()
		it("symlinks each addon folder whole, and says ok when run again", function()
			local out, code = link("")
			assert.are.equal(0, code)
			assert.is_truthy(out:find("linked   Alpha ->", 1, true))
			assert.is_truthy(out:find("linked   Beta ->", 1, true))
			assert.are.equal(source .. "/Alpha", target(addOns .. "/Alpha"))
			assert.are.equal("-- one\n", read(addOns .. "/Alpha/logic/One.lua"))

			out, code = link("")
			assert.are.equal(0, code)
			assert.is_truthy(out:find("ok       Alpha ->", 1, true))
			assert.is_truthy(out:find("ok       Beta ->", 1, true))
		end)

		it("re-points a link that leads to another checkout", function()
			sh("ln -s " .. q(base .. "/elsewhere") .. " " .. q(addOns .. "/Alpha"))
			local out, code = link("")
			assert.are.equal(0, code)
			assert.is_truthy(out:find("relinked Alpha ->", 1, true))
			assert.are.equal(source .. "/Alpha", target(addOns .. "/Alpha"))
		end)

		it("stops at a real folder with an addon's name and leaves it", function()
			sh("mkdir " .. q(addOns .. "/Alpha"))
			write(addOns .. "/Alpha/mine.txt", "mine\n")
			local out, code = link("")
			assert.are.equal(1, code)
			assert.is_truthy(out:find(addOns .. "/Alpha exists and is not a symlink", 1, true))
			assert.are.equal("mine\n", read(addOns .. "/Alpha/mine.txt"))
		end)
	end)

	describe("with --retail", function()
		it("makes a real folder of links to everything but the TOC, and a generated TOC", function()
			local out, code = link("--retail")
			assert.are.equal(0, code)
			assert.is_truthy(out:find("interface 120105 (", 1, true))
			assert.is_truthy(out:find("retail build 12.1.5.70575", 1, true))
			assert.is_truthy(out:find("linked   Alpha ->", 1, true))
			assert.is_nil(target(addOns .. "/Alpha"))
			assert.are.equal(source .. "/Alpha/logic", target(addOns .. "/Alpha/logic"))
			assert.are.equal(source .. "/Alpha/Bindings.xml", target(addOns .. "/Alpha/Bindings.xml"))
			assert.is_nil(target(addOns .. "/Alpha/Alpha.toc"))
			assert.are.equal("-- one\n", read(addOns .. "/Alpha/logic/One.lua"))
			assert.is_truthy(read(addOns .. "/Alpha/.pagle-dev-link"))
			assert.are.equal(
				"# Generated by scripts/link-addons.sh --retail from the repo TOC. Do not edit; run the script again.\n"
					.. "## Interface: 120105\n## AllowLoadGameType: standard\n## Title: Alpha\n## Version: dev\n\nlogic\\One.lua\n",
				read(addOns .. "/Alpha/Alpha.toc")
			)
		end)

		it("never touches the repo's TOCs", function()
			local before = read(source .. "/Alpha/Alpha.toc")
			link("--retail")
			assert.are.equal(before, read(source .. "/Alpha/Alpha.toc"))
			assert.is_nil(read(source .. "/Alpha/.pagle-dev-link"))
		end)

		it("takes the interface number from the retail row of .build.info, not another product's", function()
			local out = link("--retail")
			assert.is_truthy(out:find("interface 120105", 1, true))
			write(install .. "/.build.info", BUILD_INFO:gsub("12%.1%.5%.70575", "12.2.0.71000"))
			out = link("--retail")
			assert.is_truthy(out:find("interface 120200", 1, true))
			assert.is_truthy(read(addOns .. "/Alpha/Alpha.toc"):find("## Interface: 120200\n", 1, true))
		end)

		it("falls back to the default without a .build.info, and --interface sets it", function()
			os.remove(install .. "/.build.info")
			local out = link("--retail")
			assert.is_truthy(out:find("interface 120105 (the default", 1, true))
			out = link("--retail --interface 120107")
			assert.is_truthy(out:find("interface 120107 (--interface)", 1, true))
			assert.is_truthy(read(addOns .. "/Beta/Beta.toc"):find("## Interface: 120107\n", 1, true))
		end)

		it("says ok when run again, and links a new top-level file and drops a removed one", function()
			link("--retail")
			local out = link("--retail")
			assert.is_truthy(out:find("ok       Alpha ->", 1, true))
			write(source .. "/Alpha/New.lua", "-- new\n")
			sh("rm " .. q(source .. "/Alpha/Bindings.xml"))
			out = link("--retail")
			assert.is_truthy(out:find("updated  Alpha ->", 1, true))
			assert.is_truthy(out:find("ok       Beta ->", 1, true))
			assert.are.equal(source .. "/Alpha/New.lua", target(addOns .. "/Alpha/New.lua"))
			assert.is_nil(read(addOns .. "/Alpha/Bindings.xml"))
			assert.is_nil(target(addOns .. "/Alpha/Bindings.xml"))
		end)

		it("writes a changed TOC again and re-points links that lead to another checkout", function()
			link("--retail")
			write(addOns .. "/Alpha/Alpha.toc", "tampered\n")
			sh("ln -sfn " .. q(base .. "/elsewhere") .. " " .. q(addOns .. "/Beta/data"))
			local out = link("--retail")
			assert.is_truthy(out:find("updated  Alpha ->", 1, true))
			assert.is_truthy(out:find("relinked Beta ->", 1, true))
			assert.are.equal(source .. "/Beta/data", target(addOns .. "/Beta/data"))
			assert.is_truthy(read(addOns .. "/Alpha/Alpha.toc"):find("## Version: dev\n", 1, true))
		end)

		it("replaces a whole-folder link, and a whole link replaces the generated folder", function()
			link("")
			local out = link("--retail")
			assert.is_truthy(out:find("relinked Alpha ->", 1, true))
			assert.is_nil(target(addOns .. "/Alpha"))
			assert.is_truthy(read(addOns .. "/Alpha/Alpha.toc"))
			out = link("")
			assert.is_truthy(out:find("relinked Alpha ->", 1, true))
			assert.are.equal(source .. "/Alpha", target(addOns .. "/Alpha"))
		end)

		it("stops at a folder it didn't create, names it and leaves it", function()
			sh("mkdir " .. q(addOns .. "/Beta"))
			write(addOns .. "/Beta/mine.txt", "mine\n")
			local out, code = link("--retail")
			assert.are.equal(1, code)
			assert.is_truthy(out:find(addOns .. "/Beta exists and this script did not create it", 1, true))
			assert.are.equal("mine\n", read(addOns .. "/Beta/mine.txt"))
			assert.is_nil(read(addOns .. "/Beta/Beta.toc"))
		end)

		it("stops at a TOC that lacks CORE-R2's lines", function()
			write(source .. "/Beta/Beta.toc", "## Title: Beta\n")
			local out, code = link("--retail")
			assert.are.equal(1, code)
			assert.is_truthy(out:find("lacks a ## Interface or ## AllowLoadGameType line", 1, true))
		end)
	end)

	describe("the dev shim", function()
		local SHIM = "PagleRetailDev.lua"

		it("is generated into Pagle's retail folder and listed first in its TOC, and in no other addon's", function()
			local out, code = link("--retail")
			assert.are.equal(0, code)
			assert.is_truthy(out:find("generated Pagle.toc and " .. SHIM .. ")", 1, true))
			local shim = assert(read(addOns .. "/Pagle/" .. SHIM))
			assert.is_nil(target(addOns .. "/Pagle/" .. SHIM))
			assert.is_truthy(
				shim:find(
					"-- Generated by scripts/link-addons.sh --retail for UI checks on the retail client only. Never shipped.\n",
					1,
					true
				) == 1
			)
			assert.is_truthy(shim:find("WOW_PROJECT_CAMELOT = WOW_PROJECT_ID\n", 1, true))
			assert.is_truthy(shim:find("Pagle: retail UI-check build (dev link)", 1, true))
			assert.are.equal(
				"# Generated by scripts/link-addons.sh --retail from the repo TOC. Do not edit; run the script again.\n"
					.. "## Interface: 120105\n## AllowLoadGameType: standard\n## Title: Pagle\n## SavedVariables: PagleDB\n\n"
					.. "# the files\n"
					.. SHIM
					.. "\nlogic\\Core.lua\n",
				read(addOns .. "/Pagle/Pagle.toc")
			)
			assert.is_nil(read(addOns .. "/Alpha/" .. SHIM))
			assert.is_nil(read(addOns .. "/Alpha/Alpha.toc"):find(SHIM, 1, true))
			assert.is_nil(read(source .. "/Pagle/" .. SHIM))
		end)

		it("is written again when changed, and says ok when not", function()
			link("--retail")
			assert.is_truthy(link("--retail"):find("ok       Pagle ->", 1, true))
			local shim = read(addOns .. "/Pagle/" .. SHIM)
			write(addOns .. "/Pagle/" .. SHIM, "tampered\n")
			local out = link("--retail")
			assert.is_truthy(out:find("updated  Pagle ->", 1, true))
			assert.are.equal(shim, read(addOns .. "/Pagle/" .. SHIM))
		end)

		it("is removed by --unlink with the folder", function()
			link("--retail")
			local out = link("--unlink")
			assert.is_truthy(out:find("removed  Pagle", 1, true))
			assert.is_nil(read(addOns .. "/Pagle/" .. SHIM))
			assert.are.equal("", (sh("ls -A " .. q(addOns))))
		end)

		it("is removed when a whole link replaces the generated folder", function()
			link("--retail")
			link("")
			assert.are.equal(source .. "/Pagle", target(addOns .. "/Pagle"))
			assert.is_nil(read(addOns .. "/Pagle/" .. SHIM))
		end)

		it("is not created without --retail", function()
			link("")
			assert.is_nil(read(addOns .. "/Pagle/" .. SHIM))
			assert.is_nil(read(source .. "/Pagle/" .. SHIM))
			assert.is_nil(read(addOns .. "/Pagle/Pagle.toc"):find(SHIM, 1, true))
		end)

		it("stops when the repo's Pagle already has a file of that name", function()
			write(source .. "/Pagle/" .. SHIM, "-- mine\n")
			local out, code = link("--retail")
			assert.are.equal(1, code)
			assert.is_truthy(out:find("exists; the script writes a file of that name", 1, true))
			assert.are.equal("-- mine\n", read(source .. "/Pagle/" .. SHIM))
		end)
	end)

	describe("--unlink", function()
		it("removes what a run made and nothing else", function()
			link("--retail")
			sh(
				"rm "
					.. q(addOns .. "/Beta/Beta.toc")
					.. " "
					.. q(addOns .. "/Beta/data")
					.. " "
					.. q(addOns .. "/Beta/.pagle-dev-link")
			)
			sh("rmdir " .. q(addOns .. "/Beta"))
			sh("ln -s " .. q(source .. "/Beta") .. " " .. q(addOns .. "/Beta"))
			write(source .. "/Gamma.txt", "not an addon\n")
			local out, code = link("--unlink")
			assert.are.equal(0, code)
			assert.is_truthy(out:find("removed  Alpha", 1, true))
			assert.is_truthy(out:find("removed  Beta", 1, true))
			assert.is_nil(read(addOns .. "/Alpha/Alpha.toc"))
			local listing = sh("ls -A " .. q(addOns))
			assert.are.equal("", listing)
			assert.is_truthy(read(source .. "/Alpha/Alpha.toc"))
		end)

		it("keeps a generated folder that holds other files, a real folder and a link to another checkout", function()
			link("--retail")
			write(addOns .. "/Alpha/mine.txt", "mine\n")
			sh(
				"rm "
					.. q(addOns .. "/Beta/Beta.toc")
					.. " "
					.. q(addOns .. "/Beta/data")
					.. " "
					.. q(addOns .. "/Beta/.pagle-dev-link")
			)
			sh("rmdir " .. q(addOns .. "/Beta"))
			sh("ln -s " .. q(base .. "/elsewhere") .. " " .. q(addOns .. "/Beta"))
			local out, code = link("--unlink")
			assert.are.equal(0, code)
			assert.is_truthy(out:find("kept     Alpha (a generated folder with other files in it)", 1, true))
			assert.is_truthy(out:find("kept     Beta (a link to " .. base .. "/elsewhere", 1, true))
			assert.are.equal("mine\n", read(addOns .. "/Alpha/mine.txt"))
			assert.are.equal(base .. "/elsewhere", target(addOns .. "/Beta"))
		end)
	end)

	describe("usage", function()
		it("exits 2 for an unknown option, a missing folder argument and --interface without --retail", function()
			assert.are.equal(2, select(2, link("--nope")))
			assert.are.equal(2, select(2, sh("bash scripts/link-addons.sh")))
			assert.are.equal(2, select(2, link("--interface 120105")))
			assert.are.equal(2, select(2, link("--retail --interface x")))
		end)

		it("exits 1 for an AddOns folder that isn't there", function()
			local out, code = sh("bash scripts/link-addons.sh " .. q(base .. "/nope") .. " --source " .. q(source))
			assert.are.equal(1, code)
			assert.is_truthy(out:find("AddOns folder not found", 1, true))
		end)
	end)

	describe("over the repo's own addons", function()
		it(
			"generates a retail TOC for each, with CORE-R2's two lines replaced and no @project-version@ left",
			function()
				local out, code = sh("bash scripts/link-addons.sh " .. q(addOns) .. " --retail")
				assert.are.equal(0, code)
				local names = sh("ls addons")
				local count = 0
				for name in names:gmatch("[^\n]+") do
					count = count + 1
					local toc = assert(read(addOns .. "/" .. name .. "/" .. name .. ".toc"), name)
					assert.is_truthy(toc:find("## Interface: 120105\n", 1, true), name)
					assert.is_truthy(toc:find("## AllowLoadGameType: standard\n", 1, true), name)
					assert.is_nil(toc:find("camelot", 1, true), name)
					assert.is_nil(toc:find("@project-version@", 1, true), name)
					assert.is_nil(target(addOns .. "/" .. name .. "/" .. name .. ".toc"), name)
				end
				assert.are.equal(6, count)
				assert.is_truthy(out:find("retail: ", 1, true))
				assert.is_truthy(
					read(addOns .. "/Pagle/Pagle.toc"):find("\n\nPagleRetailDev.lua\nlibs\\LibStub", 1, true)
				)
				assert.is_truthy(read(addOns .. "/Pagle/PagleRetailDev.lua"))
				assert.is_nil(read(addOns .. "/Pagle_Ledger/PagleRetailDev.lua"))
			end
		)
	end)
end)
