~~~vibecode
{"vibecode": {
	"doc": "sprint-notes",
	"sprint": "caspm-method-refactor",
	"role": "Enumerates the atom-key vocabulary for the refactored CaspM. An atom is a single-key hash carrying a value directive; the key discriminates what kind of value the atom represents (literal, lookup, marker, closure). Atoms appear in step slots (as receivers) and in arg slots (as closure-like inputs to dispatch). This is the reference list — the shape decisions the sprint has made so far. Open questions are captured at the bottom.",
	"status": "in progress"
}}
~~~

# Atom keys

An **atom** is a single-key hash. The key is the discriminator; its value is the payload the atom carries.

**Every atom resolves to an object pk when invoked.** That's the common return type; individual atoms differ in HOW they resolve — creating a fresh object, looking up a name in scope, reusing the previous rv, pointing to a singleton.

Atoms appear in three positions:

- **As a value step** — the atom is the entire step; the step sets rv to the atom's pk.
- **As a receiver on a dispatch step** — the atom sits alongside `fn:NAME`; the pk it resolves to is the receiver of the dispatch.
- **Inside an arg** — atoms are the building blocks that make up args, but args themselves aren't atoms (see next section).

## Args are always step-lists

A dispatch step's `args:` field is an array of args. **Each arg is a step-list** — an array of steps the dispatched method invokes to get the arg's pk. Args are always closures at CaspM level; single-step args are step-lists of length 1, multi-step args are step-lists of the natural length.

Example dispatch step:

```
{"var": "foo", "fn": "bar", "args": [
    [{"primitive": 42}],
    [{"var": "x"}, {"rv": true, "fn": "+", "args": [[{"primitive": 1}]]}]
]}
```

Two args. First: a one-step closure producing the primitive 42. Second: a two-step closure computing `$x + 1`. The dispatched `bar` method invokes each arg at call time — eagerly for most methods, conditionally for short-circuit operators like `and` / `or`.

**Consequences:**

- **Short-circuit ops don't need `frame.closure` wrapping.** `$a || $b` becomes `[{var:"a"}, {rv:true, fn:"or", syn:true, args:[[{var:"b"}]]}]` — the arg is just `[{var:"b"}]`, a bare step-list. The `.or` method decides whether to invoke it.
- **Eager / lazy lives in the method's contract**, not in the arg shape. Every arg is a callable; the method decides when to call.
- **`blocks:` is a distinct field**, not folded into args, because blocks carry params / `as` / iteration clauses. The `blocks:` array holds full `{frame:true, fn:"closure", params:{...}, body:[...]}` envelopes for that reason.

**Setvar bare-string exception.** Setvar's first arg is the target variable name — a compile-time constant, not a runtime closure — so it appears as a bare string in `args`, not wrapped as a step-list: `{frame:true, fn:"=", args:["name", [<value-atom>]]}`. The value arg wraps normally. This is the only args-bare-string exception; other compile-time names (function / closure / method definition names, when the source uses the `&name` sugar form) live in a dedicated `name:` sibling field, not in args.

## `primitive`
Payload: a JSON scalar literal (string, number, boolean, or nil).

Creates a fresh scalar object in the CVM and returns its pk — read the atom key as "create-and-return-pk": one step, two effects. The Lua type of the payload discriminates the scalar's class: string → String, number → Number, boolean → Boolean, nil → Null.

Example: `{primitive: 1}`, `{primitive: "foo"}`, `{primitive: true}`, `{primitive: null}`.

Hash and array payloads (`{primitive:{a:1}}`, `{primitive:["a","b"]}`) are the subject of a separate sprint: [primitive-collections](../primitive-collections/). Not in scope here.

## `var`
Payload: a variable name (string).

Names a variable in the current scope chain. In a value slot the atom resolves via scope lookup — invoking produces the value bound to that name.

Example: `{var: "foo"}`.

## `rv`
Payload: always `true`.

Refers to the previous step's return value. On a dispatch step's receiver, marks "use the rv as receiver" (the chain-continuation case). In an arg slot, marks "the value in the current rv."

Example: `{rv: true}`.

## `frame`
Payload: always `true`.

Refers to the current frame — the frame that owns the step being dispatched. Used as the receiver of setvar (`{frame:true, fn:"="}`) and any other method whose receiver is the executing frame.

Example: `{frame: true}`.

## `bucket`
Payload: always `true`.

Refers to the current object's shared bucket. Used to desugar source-level `@name` and `%bucket[...]` into an ordinary `[]` / `[]=` dispatch on the bucket object. `@foo` compiles to `{bucket:true, fn:"[]", syn:true, args:[[{primitive:"foo"}]]}`; `@foo = X` to the same shape with `[]=` and a second arg.

Example: `{bucket: true}`.

## `class`
Payload: always `true`.

Refers to the current class being worked on — either the class-under-construction inside a `class ... end` body, or the class of the object being extended inside an `amend $target ... end` body. Both bodies register methods against a class; `class:true` is that class.

Used as the receiver when a method definition inside the body registers: `method &hello() ... end` inside a class or amend body compiles to `{class:true, fn:"method", name:"hello", params:{}, body:[...]}`. The `name:` sibling field carries the method name; its presence is what triggers the registration into the class's methods collection. A plain `$foo = method() ... end` (no `&name` sugar in the source) would omit `name:` — just create the method-value without registering.

Distinct from `frame`: `{frame:true}` refers to the executing scope's frame; `{class:true}` refers specifically to the class-being-worked-on, which only makes sense inside a class or amend body.

Note on name overload: `class` also appears as the method name on the outer frame dispatch (`{frame:true, fn:"class"}`). Same word in two positions — the atom-key form and the fn-value form. Position disambiguates (atom-key vs value of `fn`).

Example: `{class: true}`.

## `context`
Payload: a name (string).

Names a runtime-provided ambient service — the objects Caspian source reaches via the `%` sigil (`%stdout`, `%net`, `%engine`, `%call`, and every other `%name`). "Context" because each such name resolves against the current execution context: `%call` is THIS call, `%stdout` is THIS process's stdout, `%engine` is the engine hosting THIS run. cjcm doesn't decide what any specific name resolves to; the runtime does that lookup at dispatch time, same way user-scope names resolve.

Distinct from `var` (which names a definite variable in scope) and `bwc` (which invokes a bareword whose resolution is dynamic). `context` names a well-known runtime object accessible without declaration.

Example: `{context: "call"}`, `{context: "stdout"}`, `{context: "engine"}`.

## `bwc`
Payload: a bareword name (string).

**A dispatch atom, not a lookup.** Where `primitive` / `var` / `rv` / `frame` / `bucket` all *produce* values, `bwc` *invokes*. A bareword like `foo` encodes both a receiver and a method name; which receiver and which method are the runtime's decision, dictated by the DSL context, scope chain, class hierarchy, or built-in defaults. cjcm captures only "invoke the bareword `foo` with these args" and lets the runtime resolve the rest.

Concretely: `puts 'X'` compiles to `{bwc: "puts", args: [[{primitive: "X"}]]}`. In a plain scope the runtime routes `puts` to `Object.puts` (which prints to stdout); in a DSL the same shape might route to a template method, a route handler, a shell command — the CaspM is agnostic.

**Never combines with `fn:` on the same step.** Because the "method" is baked into the bareword itself, there's no room for `fn:` to name a separate method. To dispatch further methods on the invocation's return value, decompose into two steps: the bwc-call, then an `{rv: true, fn: X, ...}` chaining step. Source `foo.bar` compiles to:

```
[
    {"bwc": "foo"},
    {"rv": true, "fn": "bar"}
]
```

**No `syn: true` marker.** The source form (`foo` at call position) and the CaspM form (`{bwc: "foo"}`) are the same shape — no rephrasing happened. `syn` marks CaspM shapes that differ from source; `bwc` isn't one of them.

**No value-slot use.** Unlike other atoms, `bwc` never appears as a pure value producer. `{bwc: "foo"}` as a step is always an invocation with side effects. If the runtime ever needs to introspect a bareword without invoking it, that's a different mechanism.

Distinct from `var`: `{var: "foo"}` names a definite variable and produces its bound value with no side effect; combining with `fn:` on the same step is fine (`{var: "foo", fn: "bar"}` reads foo and dispatches `.bar` on the value). `bwc` is dynamic AND active — resolution and invocation happen in one shot.

Example: `{bwc: "puts"}`.

## Requirement

- There must be exactly one of these atom-key per atom hash. Lacking one of these keys or having multiple of them raises an exception.

## Command-hash key order (custom)

By convention, a command hash's keys are emitted in this order:

1. The atom-key (`primitive`, `var`, `rv`, `frame`, `bucket`, `class`, `context`, `bwc`) — the receiver spec, first
2. `fn`
3. `syn`
4. `args` and/or `opts`
5. Trailing fields (e.g. `line`)

**This is a formatting custom, not a semantic requirement.** Lua tables are unordered hashes; the engine reads command fields by name and doesn't care about key order. The transpiler / normalizer output CaspM in this order so hand-authored fixtures, CaspM dumps, and pretty-printed outputs all follow the same visual layout — easier to compare and diff. Skipping the order (or reordering) doesn't change what the engine does.