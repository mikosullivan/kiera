--[[
{
	"spec":  "parse-negative-spec",
	"role":  "Sprint copy of parse-negative-spec. Runs the negative test cases from the sprint's parse-negative.casp. Each case is a source snippet that must cause transpile to raise with an error message containing the declared substring. Points at the sprint's own caspian-caspj so parser changes made under the sprint (including the retired singleton `method $obj.name()` and sigil-less `method name()` forms) are exercised here.",
	"input": "sprints/caspm-method-refactor/tests/parse-negative.casp",
	"run":   "busted sprints/caspm-method-refactor/tests/parse-negative-spec.lua (from repo root)"
}
]]

--[[
# `parse-negative-spec`

Runs every fixture in `parse-negative.casp`, all of which are
declared as `raises` cases. For each case, calls
`transpile(source)` under `pcall` and asserts that (a) the call
returns unsuccessfully and (b) the error message contains the
substring declared in the fixture. Fixtures without a `raises`
kind trigger a hard `assert` at load time — the file's whole
purpose is negative coverage, so a non-raises fixture there is a
fixture-format bug that must be surfaced loudly.
]]

package.path = "./sprints/caspm-method-refactor/src/?.lua;"
	.. "./sprints/caspm-method-refactor/tests/?.lua;"
	.. package.path

local transpiler = require("caspian-caspj")
local extractor  = require("parse-extract")

describe("transpile parse-negative.casp", function()
	local cases = extractor.extract("sprints/caspm-method-refactor/tests/parse-negative.casp")

	for _, case in ipairs(cases) do
		assert(case.kind == "raises",
			"parse-negative.casp:" .. case.line
				.. ": expected a raises case (%raises heredoc), got kind=" .. tostring(case.kind))

		it(case.name .. " [raises] (parse-negative.casp:" .. case.line .. ")", function()
			local ok, err = pcall(transpiler.transpile, case.source)

			assert.is_false(ok,
				"expected transpile to raise, but it returned successfully")
			assert.truthy(
				tostring(err):find(case.expected, 1, true),
				"expected error containing: " .. case.expected
					.. "\ngot: " .. tostring(err))
		end)
	end
end)
