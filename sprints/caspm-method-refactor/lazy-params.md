~~~vibecode
{"doc": "sprint-notes",
	"sprint": "caspm-method-refactor",
	"role": "Seed / overview for the `&`-sigil lazy parameter mechanism, folded into this sprint alongside the mechanism spec. Eager parameters wear `$` (standard); lazy parameters wear `&`. A lazy parameter receives the arg as a Lazy — a Closure subclass — that the callee invokes with `&param` to force evaluation. First invocation evaluates and caches; every subsequent invocation returns the cached value. Enables user-defined short-circuit operators, control-flow methods, and deferred / macro-like functions without walker special cases. Full mechanism spec, idempotency rule, scope capture, composition with other per-param metadata, and the loop workaround live in the sibling [lazy-mechanism](lazy-mechanism) doc.",
	"status": "settled — folded into caspm-method-refactor 2026-09-07; brainstorm decisions have moved to lazy-mechanism"}
~~~

# Lazy params

Function parameters can be marked lazy. Eager parameters wear the `$` sigil; lazy parameters wear `&`. When a call passes an argument to a lazy position, the caller's expression is NOT evaluated before the call fires — the callee receives the unevaluated expression wrapped as a **Lazy** (a subclass of Closure) and triggers its evaluation on demand.

## Syntax

Declare a lazy parameter with `&` where you'd otherwise write `$`:

~~~caspian
function &foo($eager, &lazy)
	return &lazy
end
~~~

`$eager` is a regular parameter — the engine evaluates the arg expression before dispatching the body, so `$eager` inside the body is a value. `&lazy` is a lazy parameter — the engine wraps the arg expression as a Lazy, so `&lazy` inside the body is a callable value; invoking it fires the wrapped expression.

## Invocation

To trigger a lazy parameter's evaluation, write `&param` at a call position:

~~~caspian
puts &lazy
$x = &lazy
if &lazy then ... end
~~~

Same amp-call sugar you'd use to invoke any other callable value in scope. The caller-supplied expression runs against the caller's captured scope, and the value returns to the callee.

**Full mechanism spec** — evaluation rule, idempotency, scope capture, composition with other per-param metadata, and the loop workaround — is in the sibling [lazy-mechanism](lazy-mechanism) doc.

## What this unlocks

- **User-defined short-circuit operators.** `.or($self, &b)` — return `$self` if truthy, else `&b`. `||` becomes ordinary Caspian.
- **User-defined control flow.** `if($cond, &then, &else)` — dispatch based on `$cond`. `.unless`, `.tap`, guards, and dispatch tables all fall out.
- **General deferred / macro-like functions.** Any function that inspects the SHAPE of an arg-expression (through the Closure surface) before deciding whether to fire it.

## Relationship to the caspm-method-refactor sprint

Originally a standalone brainstorm sprint (`sprints/lazy-params/`), the `&`-sigil lazy-param mechanism was folded into this sprint because the CaspM shape it needs is a per-param metadata slot (`params: {name: {lazy: true}}`) that lives alongside the rest of the sprint's atom-key vocabulary. Two docs cover it now:

- **[lazy-params](lazy-params)** (this doc) — the seed overview and the "what this unlocks" summary.
- **[lazy-mechanism](lazy-mechanism)** — the full spec: idempotency semantics, scope capture, composition rules, invalid combinations, and the CaspM shape.

## Relationship to the expressions sprint

The [expressions sprint](https://puck.uno/sprints/expressions/) needs a mechanism for lazy args so `||` and `&&` can short-circuit without walker special-casing. This sprint's `&` sigil is the language-surface for that mechanism. The two sprints share the underlying runtime — the expressions sprint's walker's `ready` predicate consults the callee's parameter signature to decide which arg slots must be populated before the call can fire.
