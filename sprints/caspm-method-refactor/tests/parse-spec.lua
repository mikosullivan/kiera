--[[
{
	"spec":  "parse-spec",
	"role":  "Sprint copy of the transpiler test loop. Iterates every `*.casp` fixture file under `tests/examples/` (parse.casp, loops.casp, if.casp, and anything else that lands there). For 'expects' cases, asserts (a) `caspian_caspj.transpile(source, {lines: true})` produces the expected CaspJ, and (b) `caspj_caspm.transpile(CaspJ)` equals the CaspM section if the fixture provides one, or equals the CaspJ section when the CaspM section is omitted. Convention: fixtures omit `#--- CaspM ---` when the CaspM form is identical to the CaspJ form — saves duplicating identical JSON. `#--- CaspM refactor ---` is an alias for `#--- CaspM ---` used to mark fixtures that have been rewritten to the new CaspM shape. For 'raises' cases, asserts the snippet causes transpile to raise with an error message containing the expected substring. Uses the sprint's own copies of caspian-caspj.lua and caspj-caspm.lua (production's copies stay untouched until the sprint lands).",
	"input": "sprints/caspm-method-refactor/tests/examples/*.casp",
	"run":   "busted sprints/caspm-method-refactor/tests/parse-spec.lua (from repo root)"
}
]]

--[[
# `parse-spec` (sprint copy)

Positive-coverage spec for the sprint's CaspM refactor. Iterates
every fixture file under
`sprints/caspm-method-refactor/tests/examples/` and dispatches on
each case's kind — `expects` cases compare the CaspJ tree against
the fixture's declared JSON, and `raises` cases confirm the snippet
fails with an error message containing the expected substring.

The CaspM section is optional on `expects` cases; when missing, the
fixture is declaring that the CaspM form is identical to the CaspJ
form, and the assertion compares `caspj_caspm.transpile(CaspJ)`
against `CaspJ` itself.

**Split source vs sprint code:**

- **Caspian → CaspJ transpiler:** sprint's copy at
  `sprints/caspm-method-refactor/src/caspian-caspj.lua`. Copied in
  from `production/src/engine/transpiler.lua` and renamed for the
  new naming convention (each layer named `<input>-<output>.lua`).
  Extended for numeric-receiver dot-method calls like
  `10.times do end` that the loops.casp fixtures exercise.
  Production's copy stays untouched until the sprint lands.
- **CaspJ → CaspM transpiler:** sprint's copy at
  `sprints/caspm-method-refactor/src/caspj-caspm.lua`. Iterate here.
]]

-- Wire up requires. Bare-name requires resolve first against the
-- sprint's src/ (for caspian-caspj + caspj-caspm), then against
-- production's src/ (fallback for anything the sprint hasn't
-- overridden), then against the sprint's tests/ (for parse-extract),
-- then against luarocks paths (dkjson, etc.).
package.path = "./sprints/caspm-method-refactor/src/?.lua;"
	.. "./production/src/engine/?.lua;"
	.. "./sprints/caspm-method-refactor/tests/?.lua;"
	.. package.path

local caspian_caspj = require("caspian-caspj")
local caspj_caspm   = require("caspj-caspm")
local extractor     = require("parse-extract")

--[[ {
	"in":  "path (string) — directory to scan",
	"out": "sorted array of file names ending in .casp (basenames only, no path prefix)",
	"note": "shells out to `ls` — read-only, no external deps beyond coreutils"
} ]]
local function list_casp_files(dir)
	local h = assert(io.popen('ls "' .. dir .. '" 2>/dev/null'))
	local names = {}
	for name in h:lines() do
		if name:match("%.casp$") then
			table.insert(names, name)
		end
	end
	h:close()
	table.sort(names)
	return names
end

local EXAMPLES_DIR = "sprints/caspm-method-refactor/tests/examples"

for _, fname in ipairs(list_casp_files(EXAMPLES_DIR)) do
	local full_path = EXAMPLES_DIR .. "/" .. fname

	describe("transpile " .. fname, function()
		local cases = extractor.extract(full_path)

		for _, case in ipairs(cases) do
			if case.kind == "expects" then
				it(case.name .. " (" .. fname .. ":" .. case.line .. ")", function()
					local caspj = caspian_caspj.transpile(case.source, {lines = true})
					assert.same(case.expected, caspj)

					-- Fixture convention: omitting `#--- CaspM ---` means
					-- CaspM == CaspJ. If CaspM is present, use it;
					-- otherwise fall back to CaspJ.
					local expected_caspm = case.caspm or case.expected
					assert.same(expected_caspm, caspj_caspm.transpile(caspj))
				end)

			else
				it(case.name .. " [raises] (" .. fname .. ":" .. case.line .. ")", function()
					local ok, err = pcall(caspian_caspj.transpile, case.source)

					assert.is_false(ok,
						"expected transpile to raise, but it returned successfully")
					assert.truthy(
						tostring(err):find(case.expected, 1, true),
						"expected error containing: " .. case.expected
							.. "\ngot: " .. tostring(err))
				end)
			end
		end
	end)
end
