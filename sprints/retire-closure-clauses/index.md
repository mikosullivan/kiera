~~~vibecode
{"vibecode": {
	"doc": "sprint-index",
	"sprint": "retire-closure-clauses",
	"role": "Sprint for removing the retired `closure(...) ... before ... between ... after ... noloop ... end` syntax from the Caspian → CaspJ transpiler. Under the current design, iteration-lifecycle clauses (`before` / `between` / `after` / `noloop`) belong on the LOOP construct that owns the iteration (`while`, `until`, `.each`, `.times`, ...), NOT on the closure the loop invokes. Closures are pure functions: just `params` + `body`. The parser still accepts the old syntax; this sprint strips that acceptance so users writing the deprecated form get a clear error instead of a working-but-obsolete CaspJ tree.",
	"status": "not started"
}}
~~~

# retire-closure-clauses

Retire the `closure(...) ... before / between / after / noloop ... end` syntax from the Caspian → CaspJ transpiler.

## Background

Historically, closures could carry iteration-lifecycle clauses (`before`, `between`, `after`, `noloop`) as sibling structures to `body`. The idea was: a closure passed to an iterator like `.each` could declare what runs before the first iteration, between iterations, after the last, or when there are no iterations at all.

Under the current design, those clauses live on the **loop construct that owns the iteration** — `frame.while`, `frame.until`, `.each` dispatches, `.times` dispatches — not on the closure the loop invokes. Closures become pure functions again: just `params` + `body`.

## What this sprint does

Removes parser support for iteration-lifecycle clauses inside `closure(...) ... end`, `function(...) ... end`, and `method ...(...) ... end` frames. The parser continues to accept these clause keywords in the constructs that legitimately own them (loops, `.each`); it just stops accepting them inside callable-frame openers.

## What this sprint doesn't do

- Doesn't touch loop constructs' handling of these clauses. Loops keep their clause-openers.
- Doesn't touch `ensure` — that already belongs on bare `begin ... end` and is unaffected.
- Doesn't touch the CaspM engine — this is a parser-level change only. cjcm never receives the old shape after this sprint lands.

## Deliverables

- **transpiler.lua** — remove the `before` / `between` / `after` / `noloop` clause-openers from the closure / function / method frame types in the tokenizer's clause-word set (or wherever the clause-set is scoped per frame type).
- **A parse-negative fixture** — `closure body carrying iteration-lifecycle clause raises`, showing that the old syntax now errors with a clear message pointing at the loop construct as the correct home.
- **Update prose** — the "design decisions for Section 11 (functions, closures, methods)" note in parse.casp (if it discusses the retired clauses) gets updated.

## Downstream

Nothing in the caspm-method-refactor sprint blocks on this. That sprint's fixture `closure with all four iteration-lifecycle clauses` was removed when this sprint was created — the shape it documented is no longer part of Caspian.
