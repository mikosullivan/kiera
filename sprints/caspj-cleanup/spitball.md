~~~vibecode
{"doc": "sprint-scratchpad",
	"sprint": "caspj-cleanup",
	"role": "Running spitball for the new CaspJ shape. Not a spec — a working notepad where shape proposals, alternatives, and open questions accumulate before anything is settled. Ideas here should get promoted to the sprint index (or a dedicated construct doc) once they earn their place; ideas that get rejected stay here as a record of what didn't work and why. The design pass will draw from this and eventually replace most of it with settled decisions.",
	"status": "brainstorm — nothing settled here"}
~~~

# CaspJ shape spitball

Everything on this page is proposal-state. Rejected ideas stay for the paper trail.

## Examples

Working shape proposals on specific Caspian constructs. Each subsection carries the source, one or more proposed CaspJ shapes, and (where relevant) trade-off notes. Nothing here is settled.

### `$x = 1`

~~~json
{
	"cmd": "=",
	"var": "x",
	"val": 1
}
~~~

### `$x = $y = 1`

~~~json
{
	"cmd": "=",
	"var": "x",
	"val": {
		"cmd": "=",
		"var": "y",
		"val": 1
	}
}
~~~

### `function &foo() end`

The smallest named function. `function &foo()` sugars a two-effect operation: define a function value AND bind it to `foo` in the enclosing scope. In CaspJ the sugar desugars — the function-value node is anonymous, the naming lives in an enclosing `assign`. Same shape covers the non-sugar `$foo = function() end` form.

~~~json
[
	{
		"cmd": "=",
		"var": "foo",
		"val": {
			"cmd": "function",
			"params": {},
			"body": []
		}
	}
]
~~~

**Rule that falls out**: callable-defining constructs (`function`, `closure`, `method`) produce anonymous values at CaspJ level. Naming is a separate concern handled by the surrounding context (an `assign`, a class-body installation, whatever the surface syntax's binding mechanism translates to).

### `'foo'`

A bare scalar as a top-level statement. Statement-list entries are structurally self-labeled — each carries an identifier (a `cmd:` for compound statements, an atom-key for atom statements). Scalars use the `{"scalar": ...}` wrapper at statement position:

~~~json
[
	{
		"scalar": "foo"
	}
]
~~~

**Rules that fall out:**

- **Scalars at statement-list position wear `{"scalar": ...}`** — top-level programs, function bodies, class bodies, and other statement-list slots see every entry as a self-labeled node. Bare JSON at statement position would break that self-labeling.
- **Scalars in value slots can stay bare** (per the `val:` polymorphism rule) — `"val": 1` is still fine because the containing field name (`val:`) carries the type context.
- **Line info attaches naturally.** `{"scalar": "foo", "line": 5}` — the wrapper gives a home for source-fidelity decoration. Bare scalars in value slots that need line info can also promote to the wrapper form.

### `$foo.bar.gup`

Method chain. Every link is a `.` dispatch step. First link carries an explicit `obj:`; subsequent links elide it — the reader implicitly treats absence as "receiver is the prior step's return value."

~~~json
[
	{
		"cmd": ".",
		"obj": {"var": "foo"},
		"m": "bar"
	},
	{
		"cmd": ".",
		"m": "gup"
	}
]
~~~

**Rules that fall out:**

- **`obj:` is polymorphic** — bare atom for the common case (`{"var": "foo"}`), array-wrapped when there's a multi-step expression (`[{"cmd": "+", ...}, {"rv": true}]`). Same rule as `val:` and array items.
- **First link always carries `obj:`** — there's no prior step to chain from.
- **Subsequent links elide `obj:`** (the emitter default). Absence means "chain from prior rv." Saves the ~14-char repeat that spelling `"obj": {"rv": true}` on every link would otherwise cost.
- **Compact form is also accepted.** A writer who wants to spell it out can emit `"obj": {"rv": true}` on a subsequent link and mean the same thing. Parsers and formatters treat both as equivalent; the elided form is what the transpiler emits by default.
- **Args on any link**: add `"args": [...]` alongside `m:`. Parenless `.bar`, parens-empty `.bar()`, and parens-with-args `.bar($x)` are all the same node with different `args:` values.
- **`m:` has three forms discriminated by JSON type:**
	- **Bare string** — `"m": "bar"` — method named literally in the source (bareword dispatch, `.bar`).
	- **`{"scalar": ...}` atom** — `"m": {"scalar": "bar"}` — method name written as a quoted string in source (`.'bar'`). Rare source form; carried in CaspJ so the formatter can round-trip it. Semantically identical to bareword at runtime.
	- **Array-wrapped expression** — `"m": [{"var": "fn"}]` — dynamic dispatch (`.$fn`; see the next example).
- **Compound receivers** on the first link: `obj:` can be any value expression — `"obj": {"cmd": "+", "lhs": [{"var": "a"}], "rhs": [{"scalar": 2}]}` for `($a + 2).method()`.

### `$foo.$fn`

Dynamic dispatch — the method-designator is a variable rather than a bareword. Caspian source `$foo.$fn` covers two engine-time cases at once: the downloaded-method mechanism (if `$fn` holds a callable, apply it as a method on `$foo` with `%self = $foo`) and dispatch-by-name-in-variable (if `$fn` holds a method-name string, look up the method by that name). Same source syntax, same CaspJ, engine picks at runtime based on what `$fn` contains.

Same `.` cmd as the bareword chain; the only difference is `m:` holds a value expression rather than a bare string:

~~~json
[
	{
		"cmd": ".",
		"obj": {"var": "foo"},
		"m": [
			{"var": "fn"}
		]
	}
]
~~~

**Rules that fall out:**

- **`m:` has three forms discriminated by JSON type** (see the rules-block on `$foo.bar.gup` above for the full spec — bareword string, `{"scalar": ...}` quoted-string atom, array-wrapped expression). Dynamic dispatch is the array-wrapped form.
- **Chain composition works uniformly.** Any link in a chain can be dynamic:

~~~json
[
	{
		"cmd": ".",
		"obj": {"var": "foo"},
		"m": [
			{"var": "fn"}
		]
	},
	{
		"cmd": ".",
		"m": "then_something"
	}
]
~~~

`$foo.$fn.then_something` — dynamic on link 1, bareword on link 2. Same rules per link; `m:`'s JSON-type distinction handles the difference. Elision on link 2's `obj:` still applies.

- **The engine resolves at dispatch time** whether the resolved `m:` value is a callable-to-download or a method-name-to-look-up. CaspJ doesn't try to disambiguate at compile time — same shape captures both semantics.

### `$x = []`

Array literal — empty case.

~~~json
[
	{
		"cmd": "=",
		"var": "x",
		"val": {"array": []}
	}
]
~~~

### `$x = [$foo, $bar, $buzz]`

Array literal with items.

~~~json
[
	{
		"cmd": "=",
		"var": "x",
		"val": {
			"array": [
				{"var": "foo"},
				{"var": "bar"},
				{"var": "buzz"}
			]
		}
	}
]
~~~

**Rules that fall out:**

- **Array literals use the `{"array": [items]}` atom** — same atom-key vocabulary as `{"var": ...}`, `{"scalar": ...}`, `{"rv": true}`. Single atom; the array payload holds the items.
- **`scalar:` is for scalars only.** Numbers, strings, booleans, null. Arrays and hashes never wear `{"scalar": ...}` — they get their own dedicated atoms.
- **Item slots are polymorphic** — bare atom for the common case (`{"var": "foo"}`), array-wrapped step-list when an item needs multi-step evaluation. Same rule as `val:`.
- **Items can be any value expression.** Static primitives (bare or wrapped), var refs, method calls, compound expressions — anything that resolves to a value at runtime.
- **Empty and non-empty use the same shape.** No special-case atom for `[]`; it's `{"array": []}`, uniform with the with-items case.
- **Hash literals presumably follow the same pattern** — `{"hash": {...}}` atom, empty case is `{"hash": {}}`. Not spelled out yet; deferred until we get to the hash-literal example.

### Heredoc / interpolated string

Any source construct with "literal-plus-embedded-expressions" semantics — heredocs, template strings, and any similar interpolation form — compiles to a `concatenate` command.

Source (heredoc form):

~~~caspian
<<EOF
Hello, $name.
EOF
~~~

CaspJ:

~~~json
[
	{
		"cmd": "concatenate",
		"heredoc": "EOF",
		"elements": [
			"Hello, ",
			{"var": "name"},
			"."
		]
	}
]
~~~

With a MIME-type annotation (`<<('text/markdown')EOF ... EOF`):

~~~json
[
	{
		"cmd": "concatenate",
		"heredoc": "EOF",
		"mime": "text/markdown",
		"elements": [
			"# Hello\n\nThis is **markdown**."
		]
	}
]
~~~

With a single-quoted terminator (`<<'EOF' ... EOF`):

~~~json
[
	{
		"cmd": "concatenate",
		"heredoc": "EOF",
		"quote": true,
		"elements": [
			"Hello, world."
		]
	}
]
~~~

**Rules that fall out:**

- **`cmd: "concatenate"`** — combines multiple pieces into a single value. Applies to all source constructs with literal + interpolation semantics. NOT applied to plain `+`-chained string concatenation (parser is type-blind, doesn't infer "these `+`s are between strings"); those stay as nested binops.
- **`elements:`** — flat list of pieces in source order. Same polymorphism rule as `val:` and array items: bare scalar (`"Hello, "`), bare atom (`{"var": "name"}`), or array-wrapped step-list for multi-step expressions.
- **`heredoc:` (optional)** — value is the delimiter (`"EOF"`, `"END"`, whatever the source used); presence signals "this was a heredoc." Absence means the source used a different interpolation syntax (template string, etc.). Preserved so the formatter can round-trip the source form.
- **`mime:` (optional)** — MIME-type annotation from the heredoc opener (`<<('text/markdown')EOF`). Verbatim from source; no validation. At runtime the engine writes this to the resulting string's `@content_type` bucket entry (per [heredocs § Type annotation](https://puck.uno/requirements/built-in-classes/primitives/string/heredocs#type-annotation)). Applies to any interpolation construct that carries a type — not heredoc-specific.
- **`quote: true` (optional)** — the source wrote the terminator in single quotes (`<<'EOF'`). Semantically identical to bare `<<EOF` (both are literal, no interpolation); preserved purely so the formatter can round-trip the author's stylistic choice. Engine doesn't care. Absence means bare terminator.
- **Heredoc with no interpolation** stays as `concatenate` with a single element — uniform rule: any heredoc becomes `concatenate`. AI never has to decide whether to wrap or not.
- **Double-quoted terminator** (`<<"EOF"`) enables interpolation and is inferred from `elements:` content — if interpolated expressions are present, the source used double-quoted. No dedicated flag needed for the interpolation-vs-literal distinction; it's carried by the elements themselves.

## What we're leaning toward

- **`cmd:` as the universal tag.** Every node carries it; value names the construct or operator.
- **Source-op as `cmd` value where it's the identity.** `"="`, `"+"`, `"||"`, etc. Punchy and source-visible.
- **Short field names.** `var`, `val`, `cond`. Token savings across a whole program.
- **Bare JSON scalars in value slots.** `"val": 1`, `"val": "hello"`, `"val": true` — no wrapper when the containing field's name carries the type context. Wrap with `{"scalar": ...}` at statement-list positions (top-level program, function body, chain, etc.) or wherever the self-labeling gain is worth the tokens.
- **Value-position slots are polymorphic — one universal rule.** Every value slot (`val:`, `obj:`, array items, and any future slot that holds evaluatable code) accepts either a bare atom (single-step common case) OR an array-wrapped step-list (multi-step evaluation). Emitter picks whichever is cheaper for the common case; parsers treat both as equivalent. Bare JSON primitives are also accepted where JSON's own type carries the meaning.
- **`m:` is the one field with special-case shape rules** — three forms discriminated by JSON type:
	- **Bare string** — bareword method dispatch (`.bar` in source).
	- **`{"scalar": ...}` atom** — method name written as a quoted string in source (`.'bar'` in source). Semantically identical to bareword at runtime; carried in CaspJ so the formatter can round-trip the source form.
	- **Array-wrapped expression** — dynamic dispatch (`.$fn` in source).
- **Elision for defaults.** Fields with a canonical default value can be omitted; readers reconstruct from the schema. Chain-link `obj:` (defaults to `{"rv": true}`, "chain from prior rv") is the current example.
- **Line info opt-in via `line:` field on any node.** Only source-fidelity decoration CaspJ carries.
- **Three reserved pass-through fields.** `misc`, `corporate`, `vibecode` on any hash. Free-form.
- **Callables are anonymous.** `function`, `closure`, `method` produce anonymous values at CaspJ level. Naming is handled by the surrounding context (an enclosing `assign`, a class-body installation, etc.).

## What we haven't decided

### `val:` for both expressions and statement bodies?

An assign's RHS is a single-expression-that-yields-a-value. A function body is a statement-list-that-happens-to-return-the-last-value. Same shape (step-list) but different semantic flavor.

**Uniform `val:` for both**: minimizes vocab; one field name across cases.

**Separate names — `value:` for expressions, `body:` for statement lists**: more discoverable per role; the reader knows immediately whether they're looking at an expression or a body.

### How do var references fit?

`$y` in the RHS of `$x = $y`:

**Uniform `cmd:` variant** (one-shape-fits-all):

~~~json
{
	"cmd": "var",
	"name": "y"
}
~~~

**Separate atom-shape variant** (leaves are different from constructs):

~~~json
{
	"var": "y"
}
~~~

The uniform-cmd version adds ≈3 tokens per var ref (`"cmd"`, `"var"`, and the `"name"` label vs the `"var"` label). Var refs are HIGH-frequency — every use of a variable is one — so the choice is a real token cost across a program.

**Middle ground**: leaves are `{"var": "y"}`, statements / compound expressions are `{"cmd": OP, ...}`. Two shape families, but each family has one rule. The reader can tell them apart by the presence of a `cmd:` field.

### Binary operators

`$y + 2` — several plausible shapes:

**Named args (left/right)**:

~~~json
{
	"cmd": "+",
	"left": {
		"var": "y"
	},
	"right": 2
}
~~~

Reads naturally. Not uniform with `val:`.

**Block as ordered pair**:

~~~json
{
	"cmd": "+",
	"val": [
		{
			"var": "y"
		},
		2
	]
}
~~~

Uniform with the `val:` pattern but loses the left/right labeling. Two-operand order-matters case; if operators are always binary, positional inside `val:` is fine. If they can be unary or n-ary, positional is fragile.

**Method-call analog**:

~~~json
{
	"cmd": "+",
	"self": {
		"var": "y"
	},
	"args": [
		2
	]
}
~~~

Reflects that `+` is really `self.plus(other)`. Nice conceptual alignment with CaspM's dispatch model — an operator is a method call on the LHS with the RHS as an arg. Slightly verbose for two-operand cases; scales cleanly to compound calls.

### `var:` value: full `$x` string or just `"x"`?

Currently in the proposal, `var: "x"` (name only, no sigil).

**Case for `"x"` (no sigil)**: CaspJ is post-parse; the sigil served its parsing role and is gone.

**Case for `"$x"`**: source-mirror — you can read the JSON and see the sigil the user wrote. AI-friendly if the AI thinks in source-syntax terms.

Aligns with the earlier "sigils translate to metadata" rule (Option 4 rejected earlier); leaning toward `"x"` — sigils are surface syntax that CaspJ doesn't need to carry.

## Constructs to draft next

Working list — sketch each in the leading proposal, note alternatives:

- scalar literal (bare vs wrapped, decoration attachment)
- var reference (atom-shape vs uniform-cmd)
- `@field` read and write
- `%context` reference
- method call (`$obj.method(args)`)
- amp-call (`&fn(args)`)
- binop
- unary op
- if / unless
- ternary
- while / until
- function / closure / method def
- params spec (with all sigils' metadata)
- return
- class / amend
- array / hash literals
- subscript
- ranges / splats
- pipes
- comments (structural or format?)

## Rejected

- **`{value: true}` scalar wrappers everywhere** — the current CaspJ pattern. Rejected: verbose, no reader-value benefit, tokens wasted. Bare JSON scalars win unless a specific decoration (line, base) needs a home.
- **Association-list metadata** (`{"meta": [["optional", {"value": true}]]}`) — current CaspJ shape for param specs. Rejected: two-level nesting for a flat concept, hostile to schema, verbose.
- **Positional arrays** (`["scope", "setvar", "x", 1]`) — current CaspJ statement shape. Rejected: positional-memorization tax; the whole point of the sprint is to lose these.
- **CaspM-shape + decoration** (my earlier proposal — CaspJ literally uses CaspM's atom-key + fn + args). Rejected: CaspJ is Caspian's semantic AST, not the engine's dispatch tree. Multi-syntax purpose (goal 2) argues against CaspJ being engine-flavored.
