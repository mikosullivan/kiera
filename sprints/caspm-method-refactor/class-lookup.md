~~~vibecode
{"vibecode": {
	"doc": "sprint-notes",
	"sprint": "caspm-method-refactor",
	"role": "Explains how the engine resolves the `{class: true}` atom at runtime — the process of finding the specific class being acted on when a method-definition (or any `class:true`-receivered) step executes. Covers the frame-stack walk, what makes a frame class-owning (dispatched `fn: 'class'` or `fn: 'amend'`), nesting precedence, the closure-escape corner case, and the error case at top level.",
	"status": "current"
}}
~~~

# Determining the class being acted on

The `{class: true}` atom is a receiver-placeholder for "the class currently being worked on." Inside a class body it's the class being defined; inside an amend body it's the class of the object being extended. The CaspM doesn't hard-code which; the engine resolves it at dispatch time.

## The mechanism

When a step with `{class: true}` as receiver executes:

1. Start at the frame the step lives in.
2. Walk up the frame stack toward the top.
3. Look for the first frame whose active dispatch is `frame.class` or `frame.amend`.
4. That frame's class-being-worked-on is the receiver of the step's dispatch.

The engine already tracks frame stacks for scope resolution. Adding "walk up to find the class-frame" reuses that mechanism — no new machinery.

## Cases

### Class body

```
class
    method &hello() return 'hi' end
end
```

The `class ... end` opens a class-body frame. When the `method` step executes, its enclosing frame IS the class-body frame. The walk finds it on the first step. Method registers on the class being defined.

### Amend body

```
amend $target
    method &added() return 'x' end
end
```

`amend $target ... end` opens an amend-body frame. The walk finds it. Method registers on the class of `$target`.

### Nested class-in-class

```
class
    class
        method &inner() ... end
    end
end
```

Both frames are class-frames. The walk hits the inner one first — nearest wins. Method registers on the inner class.

### Nested amend-in-class (or class-in-amend)

Same rule: nearest wins. Whichever frame is closest on the walk owns the method. In practice that means intent expressed nearest to the definition is honored — a method inside an amend body registers on the amend target, even if that amend body sits inside another class.

## Corner case: closure carrying a method-definition step, invoked inside a class body

Under the dynamic-scoping semantic, if a closure containing a `{class:true, fn:"method"}` step gets INVOKED inside a class body, the walk finds the class-frame and registers the method on the class-being-worked-on — regardless of where the closure was defined.

In practice this corner case is hard to construct in valid Caspian. Scope rules prevent the obvious paths:

- Top-level variables aren't visible inside `class ... end`, so a top-level `$foo = closure() ... end` followed by `$foo.call` inside a class body doesn't parse — `$foo` isn't in scope there.
- Class bodies have their own scope; a closure would have to arrive via an unusual path — passed in as an arg to `.new()` or similar constructor, stashed on the class's own bucket beforehand, retrieved through `%engine` or another ambient service, etc.

Even in those unusual paths, the semantic is what the stack walk says: dynamic; the class is determined by where the code RUNS, not where it was WRITTEN. If a use-case ever surfaces where lexical binding is wanted ("this method registers on the class this step was WRITTEN inside, not the caller's class"), that's a cjcm-time addition — bake the target-class reference into the step at compile time. Not needed for V1; not needed until a concrete case demands it.

## Error case: no class on the stack

```
method &orphan() return 'x' end
```

At the top level (or inside any frame that isn't a class-body / amend-body descendant), the walk hits the top of the stack empty-handed. The engine raises a specific error:

> `class:true` used outside a class or amend body

Same error family as `bwc:break` executed outside any loop. The step's dispatch has no receiver; nothing to fall back to; a targeted error message beats a null-pointer crash.

## What this means for cjcm

cjcm doesn't need to know anything about which class a method-definition targets. It emits `{class: true, fn: "method", args: [name], params: ..., body: ...}` and lets the engine's runtime walk do the resolution. Compile-time stays simple; runtime handles the context-sensitivity.

Same principle as bwc-resolution: cjcm captures the bareword's name, the runtime figures out what to invoke based on context.
