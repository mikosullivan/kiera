~~~vibecode
{"doc": "sprint-index",
	"sprint": "caspj-cleanup",
	"role": "Redesign CaspJ as a clean semantic AST for Caspian — named constructs, labeled fields, flat metadata, one shape rule readers can learn once and apply everywhere. The current CaspJ is a museum of ad-hoc structures accumulated in isolation (positional arrays for `[\"scope\", \"setvar\", ...]`, key-discriminated objects for `{function: {...}}`, association-list metadata for `[[\"optional\", {value: true}]]`, scalar wrappers like `{value: true}`, `{var: name}` / `{value: v}` / `{at: name}` sitting alongside newer `{primitive: v}` and `{context: 'stdout'}`) that no reader can hold in one mental model. This sprint gives CaspJ four explicit purposes — formatting-round-trip target, multi-syntax hub (any Caspian frontend targets CaspJ), debug-info carrier (line numbers propagate to CaspM), AI code-generation target (structural, self-labeling, token-efficient) — and picks shape choices that serve those purposes. Formatting details (indent, blank lines, operator forms, quote styles) live in the user's format-config, not in CaspJ. Line numbers are the only source-fidelity decoration CaspJ carries. CaspM interaction is out of scope for this sprint; that comes later.",
	"status": "brainstorm — design pass in progress; no code changes yet"}
~~~

# caspj-cleanup

Redesign CaspJ so that a reader can pick up a block and picture the code, and an AI can generate a block without knowing Caspian's source syntax.

## What CaspJ is for

Four purposes, all load-bearing:

**1. Formatting round-trip.** A formatter (VS Code extension or CLI) reads user-configured format preferences (indent style, blank-line placement, operator forms, quote styles), reads a CaspJ tree, and emits Caspian source per the config. CaspJ carries the STRUCTURE of the code; formatting choices live in the user's config, not in CaspJ.

**2. Multi-syntax hub.** Caspian's canonical AST. Any frontend syntax (Caspian's own, a Python-like syntax, a Ruby-like syntax, anything) transpiles to CaspJ. From CaspJ downward everything is uniform. This means CaspJ names SEMANTIC constructs (`assign`, `function`, `return`) rather than source-syntax tokens (`=`, `end`, `&`). A Python-like frontend spelling `def foo():` produces the same CaspJ as Caspian spelling `function &foo()`.

**3. Debug-info carrier.** Line numbers propagate from source through CaspJ into CaspM so runtime errors can name a source location. `line:` fields on nodes are the one exception to "CaspJ doesn't store formatting details."

**4. AI code-generation target.** Structured JSON is dramatically easier for LLMs to generate correctly than free-form source syntax — no operator-precedence confusion, no `end`-matching, no ambiguous grammar. CaspJ is a clean target for AI-generated Caspian. This purpose adds a specific design objective:

- **Minimize the tokens an AI needs to emit a program in CaspJ.** Fewer tokens = faster generation, lower cost, more headroom in the context window. Every structural-noise choice (long field names, redundant wrappers, deep nesting) costs the AI. Every clear-labeling choice helps reliability. When the two trade off, we pick per the specific case; when we can get both (short but self-labeling names, optional fields omissible, bare scalars where the type is JSON-obvious), we do.

## Design objectives

- **Structural clarity.** A reader can look at a CaspJ block and picture the source. Named constructs, labeled fields, no positional-array shapes to memorize.
- **Multi-syntax neutral.** Shape names semantic constructs, not source syntax. Sigils translate to metadata (`@name` → `{"bucket": true}` on a param) rather than becoming JSON key characters.
- **Debug-info friendly.** `line:` is a first-class optional field on any node. Propagates through the pipeline.
- **AI-generation friendly.**
  - Self-labeling. Every construct's identity is in the shape, not in a positional slot.
  - Token-efficient. Short common field names, optional fields omitted when not needed, bare scalars where safe.
  - Schema-shaped. A JSON Schema (or equivalent validator) should be authorable so AI output can be validated cheaply.
- **Pass-through fields.** Any hash in CaspJ may carry `misc`, `corporate`, and `vibecode` fields. These are reserved for user / org / AI free-form annotation. Engine ignores them; transpilers pass them through.
- **Format-neutral.** Whitespace, indent, blank-line counts, semantically-equivalent syntax choices (`&&` vs `and`, `0xFF` vs `255`, `"..."` vs `'...'`) do NOT appear in CaspJ. Those are the formatter's job, driven by user config.

## What we've settled so far

- **Named-construct shape.** Statements and compound expressions are single-key objects: `{"assign": {...}}`, `{"function": {...}}`, `{"return": {...}}`. The key names the semantic construct. Inside, all fields are labeled.
- **`assign`, not `setvar`.** The old CaspM verb-noun name; the new name reads as what the source actually does. Applies at the CaspJ construct-name level; CaspM still uses `fn: "="` for the underlying method call.
- **Line numbers as the ONLY source-fidelity decoration.** Comments TBD (are they structural author-content or format decoration?). Semantic-equivalent form choices explicitly NOT preserved in CaspJ — config picks at re-emit.
- **Reserved pass-through fields**: `misc`, `corporate`, `vibecode` on any hash. Free-form; engine ignores; transpilers pass through when possible.

## What we haven't decided yet

- **Scalar wrapping** — bare JSON primitive (`"value": 1`) vs atom-key wrapper (`"value": {"primitive": 1}`). Token-cost tips toward bare; decoration attachment (like `line:` on a specific primitive) tips toward wrapped.
- **Comments** — structural (preserved through CaspJ) or format-only (regenerated at re-emit from source text). Author-content leans structural, but the round-trip via config-driven formatter argues for stripping them here.
- **The full shape catalog** — every construct (var ref, method call, binop, if, while, function-def, class-def, ...) needs its shape spelled out. That's the design pass.

## Constructs to spell out

Rough source-frequency order for the design pass:

- assign, primitive literals, var references, `@field` reads / writes
- method call (`$obj.method(args)`), amp-call (`&fn(args)`)
- binop, unary op, ternary
- if / unless, while / until, other loops
- function / closure / method definition, params (with all sigils' metadata)
- return
- class / amend
- array / hash literals, subscript, ranges, splats at call sites
- pipes
- `%context` / `%self` references
- comments (as first-class if we decide structural)

## Phased approach

1. **Design pass.** Each construct's shape settled and documented, with a sample JSON block. This sprint's real deliverable.
2. **Transpiler emit.** Rewrite `caspian-caspj.lua` to emit the new shape. Sprint copy only; production stays untouched.
3. **Fixture sweep.** Rewrite every CaspJ block in the sprint's `tests/examples/*.casp` to the new shape.
4. **Formatter (later).** A separate track — reads CaspJ + user config, emits Caspian source. Out of scope for this sprint's design pass.
5. **Integration overlay.** Fold into whatever plan lands the sprints' cumulative changes into production.

CaspM interaction (whether CaspJ maps to CaspM by translation or by decoration-stripping) is deliberately out of scope. That question waits until CaspJ's shape is settled on its own terms.

## Related

- [caspm-method-refactor sprint](https://puck.uno/sprints/caspm-method-refactor/) — where CaspM's uniform shape was designed. Some concepts (atom-key vocabulary, args-as-step-lists, param-metadata as flat hash) may transfer to CaspJ, but CaspJ is not required to look like CaspM.
- [caspianj](https://puck.uno/requirements/caspianj) — the production spec for the current CaspJ/CaspM formats. Will need integration-time revision once this sprint lands.
- [misc-and-corporate](https://puck.uno/requirements/built-in-classes/misc-and-corporate) — where the `misc` / `corporate` pass-through fields are established as a language convention.
- [object/structure § vibecode (per-stack)](https://puck.uno/requirements/built-in-classes/object/structure/#vibecode-per-stack) — where `vibecode` is established as a free-form AI-readable field on stack entries. The same convention generalizes to CaspJ hashes.
