~~~vibecode
{"vibecode": {
	"doc": "sprint-notes",
	"sprint": "caspm-method-refactor",
	"role": "Explains how the engine resolves the `{class: true}` atom at runtime — the process of finding the specific class being acted on when a method-definition (or any `class:true`-receivered) step executes. Covers the frame-stack walk, what makes a frame class-owning (dispatched `fn: 'class'` or `fn: 'amend'`), nesting precedence, and the error case at top level.",
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
