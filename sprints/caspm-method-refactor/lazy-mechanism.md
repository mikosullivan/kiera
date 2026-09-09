~~~vibecode
{"doc": "sprint-notes",
	"sprint": "caspm-method-refactor",
	"role": "How lazy params work in Caspian at the language-surface and runtime levels. Covers the `&` param-declaration sigil, what the callee body receives (a Lazy — subclass of Closure), the idempotency rule (first invocation evaluates and caches; every subsequent invocation returns the cached value for the lifetime of the Lazy), scope capture from the caller, composition with other per-param metadata (default, optional, splat), the rejected `{lazy: true, bucket: true}` combination, and the workaround pattern for constructs that need per-iteration evaluation (loops explicitly use `$param` + caller-side `closure(...)` rather than lazy). Lives in this sprint because the CaspM `params: {name: {lazy: true}}` metadata shape and the `lazy + bucket` normalizer reject both belong to this sprint's atom-key vocabulary.",
	"status": "draft — idempotency chosen 2026-09-07"}
~~~

# How lazy params work

## The one-sentence version

A parameter declared with `&` receives its arg as a **Lazy** object — a subclass of Closure whose first invocation evaluates the arg expression, caches the result, and returns that cached result on every subsequent invocation for the lifetime of the Lazy.

## Declaring lazy params

Sigils in a function / closure / method signature:

- **`$param`** — eager. The engine evaluates the arg expression before dispatching the body; body sees the value at `$param`.
- **`&param`** — lazy. The engine wraps the arg expression as a Lazy object; body receives that object at `&param` and invokes it — by writing `&param` — to force evaluation.

Mixed signatures compose freely:

~~~caspian
function &foo($idx, &read)
	if $idx
		puts &read
	end
end
~~~

`$idx` is a plain value the engine computed before `foo`'s body ran. `&read` is a Lazy — the caller's arg expression is not yet evaluated when the body begins. `puts &read` fires the Lazy: it evaluates the wrapped expression and hands `puts` the resulting value. If `$idx` is falsy, the branch never runs, the Lazy is never fired, and the arg expression never evaluates.

The caller does nothing special:

~~~caspian
&foo(1, expensive_computation())
~~~

The engine wraps `expensive_computation()` in a Lazy at the call site and hands it to `foo`; `foo` decides whether to fire it.

## Lazy is a subclass of Closure

The Lazy that the body receives supports the full Closure surface — every method Closure carries is there. The body treats it as a plain Closure value; the "lazy" designation is invisible except through the caching behavior.

That means `&read` is a first-class value: it can be stored in a variable, passed to another function, returned from the current one, or introspected via its Closure surface. The Lazy IS a closure that happens to be born from the arg-wrapping mechanism.

## Invoking

Anywhere the source needs the value that a lazy param wraps, write `&param`. That's it:

~~~caspian
puts &read              # print the value
$x = &read              # bind the value to a local
&some_fn(&read)         # pass the value into another call
if &read then ... end   # branch on its truthiness
~~~

`&read` at call position is the amp-call sugar for invocation — same rule as amp-calling any callable value in scope. No explicit `.call` needed; nothing to remember. If a body ever needs the Lazy OBJECT (to introspect, hand to another function without firing it, etc.), that's a separate mechanism the callee reaches through the Closure surface — but the everyday "give me the value" case is just `&read`.

## Idempotency

**The rule**: the first invocation of a Lazy evaluates the wrapped expression and caches the result. Every subsequent invocation on the same Lazy returns the cached value.

~~~caspian
function &double_puts(&x)
	puts &x            # first invocation — evaluates, caches
	puts &x            # subsequent invocation — returns cached
end

$i = 0

function &next_i()
	$i = $i + 1
	return $i
end

&double_puts(&next_i)

# prints:
# 1
# 1
#
# after the call, $i is 1 — not 2
~~~

**Why idempotent**: the mental model for `&param` is "this is the value the caller passed, computed on demand." Once demanded, it's a value. Two references in the body to the same lazy param should show the same value the same way two references to an eager param do — no accidental double-evaluation, no surprise side effects from expressions the caller wrote in what looks like a plain arg slot.

**Scope of the cache**: the cache lives on the Lazy object itself. It persists for the Lazy's lifetime — bounded by however long some frame holds a reference. When the frame that received the Lazy reaps and no other reference remains, the Lazy (and its cache) is collectible.

## Scope capture

The Lazy captures the caller's scope at the call site. When the Lazy fires — whenever that happens, whatever frame it fires in — the arg expression evaluates against the captured scope chain, not the callee's.

~~~caspian
$greeting = 'welcome'

function &wrapper(&msg)
	return &msg
end

$out = &wrapper($greeting + ', crew')
# $out is 'welcome, crew' — $greeting resolved against the caller's scope
~~~

This falls out of "Lazy is a Closure": closures capture their enclosing scope, and the arg-closure is created in the caller's scope. Same rule as every other closure.

## Working with loops

Idempotency and per-iteration re-evaluation don't mix: `while &cond ... end` with a lazy `&cond` runs the body 0 or 1 times because the cached value never changes after the first iteration.

For a callable that needs a condition or body evaluated once per iteration, use an **eager param whose value is an explicit closure** — plain closures aren't idempotent, so each invocation inside the loop evaluates fresh:

~~~caspian
function &while_true($cond, $body)
	while &cond
		&body
	end
end

$i = 0
&while_true(
	closure()
		return $i < 3
	end,
	closure()
		puts $i
		$i = $i + 1
	end)

# prints:
# 0
# 1
# 2
~~~

The sigils spell the intent: `$cond` and `$body` are eager params receiving closure VALUES; the caller wraps its expressions in `closure(...) ... end` explicitly to signal that they should be re-callable. Inside the body, `&cond` and `&body` are amp-call sugar for invoking the callables held at `$cond` and `$body`. Because plain closures don't cache, each invocation runs the closure body fresh.

Marking the params `&cond` and `&body` (lazy) would signal "wrap for me, and cache the first result" — the wrong contract for a loop condition.

**Rule of thumb**: reach for `&param` when the callee will invoke it at most once (short-circuits, conditional dispatch, deferred work); reach for `$param` + caller-side `closure(...)` when the callee will invoke it more than once (loops, retries, per-element handlers).

## Composition with other per-param metadata

Lazy composes with every other param property in the flat metadata hash. All valid:

- **`&name: {default: expr}`** — lazy param with a default. The default is itself lazy; its expression evaluates and caches on first invocation if the caller didn't supply an arg.
- **`&*rest`** — lazy positional splat.
- **`&**opts`** — lazy kwsplat.
- **`&name: {optional: true, default: expr}`** — lazy, optional, with a default.

At the CaspM level each of these lands as flat entries in the param spec:

~~~json
"params": {
	"read": {"lazy": true},
	"rest": {"lazy": true, "splat": true},
	"opts": {"lazy": true, "splat": "kw"}
}
~~~

## The invalid combination: `lazy + bucket`

`{lazy: true, bucket: true}` **raises at CaspJ→CaspM normalize time**. There's no legal source syntax that produces it — the parser doesn't accept `&@name` or `@&name` as a param sigil — but the check is a safety net for future work (metaprogramming, direct CaspM construction) that might build param specs programmatically.

Why it's rejected: `@`-auto-assign writes the param's value into the receiver's bucket at param-binding time. A lazy param IS a closure carrying the caller's scope chain. Writing that closure into the bucket would smuggle a caller-scope reference into the object's persistent state, blurring the boundary between "the object's data about itself" and "an outstanding computation borrowed from a caller." No coherent semantic; the language rejects it rather than pick one.

## What lazy params unlock

- **Short-circuit operators.** `$a || $b` desugars to `$a.obj.or(&b)` — `.or` has one lazy param, invokes it only when `%self` (which is `$a`) is falsy. `.and` is the mirror image.
- **Control-flow methods.** `if($cond, &then, &else)` — three lazy params, exactly one branch's Lazy fires per invocation.
- **Deferred side effects.** `.tap(&block)`, `.unless(&guard, &action)`, `.retry(&body)` — anywhere the callee decides whether and when to actually run something.
- **DSL macros.** Any method that inspects the SHAPE of an arg-expression before deciding whether to fire it — for example, dispatching on the callee's `.params` metadata rather than the value the arg would produce.

Every one of these lives as an ordinary user-definable method on some class. No walker special cases, no new syntax; the runtime uniformity is what buys it — see [expressions/eval-algorithm](https://puck.uno/requirements/expressions/eval-algorithm).

## CaspM shape

**Callee-side.** The param spec carries `lazy: true`:

~~~json
{
	"frame": true,
	"fn": "function",
	"name": "foo",
	"params": {
		"idx": {},
		"read": {"lazy": true}
	},
	"body": [...]
}
~~~

**Caller-side.** Nothing changes. The `args:` field is uniformly a list of step-lists per the atom-keys "[args are always step-lists](tag:args-are-step-lists)" rule. At dispatch, the engine consults the callee's signature; positions marked `lazy: true` get their step-list wrapped in a Lazy and passed through, while eager positions get their step-list invoked eagerly and the resulting value dropped into the arg slot. No divergence at the call site — one CaspM shape covers both cases.

## Related

- [caspm-method-refactor sprint index](index) — this sprint's overall scope.
- [lazy-params](lazy-params) — the seed / overview doc for the `&`-sigil mechanism; sibling to this deeper spec.
- [atom-keys](atom-keys) — the atom-key vocabulary this doc's CaspM shapes fit into; the "args are always step-lists" rule that makes call-site uniformity possible.
- [expressions/eval-algorithm](https://puck.uno/requirements/expressions/eval-algorithm) — the unified dispatch model that lazy fits into.
