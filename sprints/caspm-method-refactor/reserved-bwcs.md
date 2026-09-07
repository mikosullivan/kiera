~~~vibecode
{"vibecode": {
	"doc": "sprint-notes",
	"sprint": "caspm-method-refactor",
	"role": "Flat list of reserved bareword-commands (bwcs) — words whose meaning is fixed by the language and cannot be overridden by any DSL. Sprint-scoped: the reserved-bwc set matters here because it discriminates which bwc dispatches carry `syn: true` (built-in primitive, skip user override) versus which don't (respect DSL binding). Every other bwc is DSL-resolvable (Tier 3 default-bindings or Tier 4 pure-DSL per the four-tier model in `production/requirements/functions/caller/dsl`). This doc is the single flat reference within the sprint; the four-tier model with rationale lives at that production link.",
	"status": "in progress"
}}
~~~

# Reserved bwcs

The following words are **reserved**: their meaning is fixed by the language, no DSL can rebind them. Every other bwc is DSL-resolvable — see [functions/caller/dsl](tag:dsl) for the full four-tier model and how DSL overriding works for the non-reserved ones.

- `if`
- `elsif`
- `elseif`
- `else`
- `end`
- `begin`
- `ensure`
- `while`
- `do`
- `dofunc`
- `class`
- `instance`
- `function`
- `closure`
- `true`
- `false`
- `null`
- `return`
- `yield`
- `raise`
- `catch`
- `heed`
- `break`
- `next`
- `until`
- `unless`
- `method`
- `amend`
- `and`
- `or`
- `not`
- `as`
