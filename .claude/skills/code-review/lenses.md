# The four lenses

Each lens is a separate pass over the diff under one question. The point
of separation: one reading produces one gestalt, and every comment gets
drawn from it; re-reading under orthogonal questions is how a single
context buys independent looks. Run them in order — Lens 1 is ruined by
reading bodies first. Each lens either reports or declares its empty
state; each can fail the diff outright.

## Lens 1 — Cold Reader (comprehensibility as experiment)

You are the new developer the code will be read by. Use that.

1. List the diff's public surface: new or changed signatures, types,
   names, return shapes. Skip bodies entirely.
2. For each element, write a one-line prediction of its behavior and
   contract — what it does, what it returns on failure, what it mutates.
3. Now read the bodies. Verify each prediction.
4. Every miss is a finding, stated as fact: "<signature> predicts <X>;
   body does <Y> — makes every future call-site author guess wrong the
   same way." The fix is usually a rename, a signature change, or moving
   a side effect — chosen because it ends the miss, not because of
   taste.

Empty state: "no misses — checked N." Honesty rule: predictions come
before bodies; if you've already read the bodies (long session), say so
— the experiment is weakened and its misses are a lower bound.

## Lens 2 — Alternative Implementer (reopening decisions)

1. Extract the decisions the diff made — forks, not lines. Worth
   reopening: what is stored vs derived; where state lives; which
   component owns which responsibility; error strategy (propagate,
   retry, swallow); representation choices (map vs vector, string vs
   type); boundary shapes (parameters, return types); dependencies
   taken. Not worth reopening: names, formatting, micro-idioms (Lens 1
   owns those, via evidence).
2. Keep the ≤5 with the largest blast radius. Write each as
   "chose X over Y", where Y is the *simplest live alternative*. If you
   cannot name a Y a competent implementer might have picked, it wasn't
   a decision — drop it. "Nothing" is frequently the strongest Y.
3. Judge each with the null on Y: a ledger line pays for X, or the
   decision is UNSETTLED and becomes a question with default Y.

This lens is where pushback lives. Its failure mode is deference —
treating the diff's choice as evidence for itself. The diff chose X *is
not* a reason for X.

## Lens 3 — Time Traveler (durability as experiment)

1. Pick 1–2 plausible next changes, in priority order: explicitly
   planned work (tickets, roadmap, "next we'll…" in the PR); the
   ledger's trajectory (a fourth System this quarter → simulate adding
   it); failing that, the classic axes — a new variant of whatever the
   diff just special-cased, one dimension of scale ×10, a second
   consumer of a new interface.
2. Walk each change through the post-diff code. List every file and
   function that must be edited, and every place that must be *known
   about* even if unedited.
3. Classify: one-place (edit where the concept lives), leaky (edit plus
   remember distant facts), shotgun (parallel edits that must agree).
4. Shotgun or leaky on a *planned or trajectory* change is a structural
   finding with the cost sentence pre-filled: "makes <that change>
   harder because <these N sites must agree>." On a speculative axis
   it is at most a question — do not demand generality for changes
   nobody has witnessed; that is the YAGNI trap running in reverse.

Empty state: "simulated <change>: one-place."

## Lens 4 — Keeper (what must always be true)

One sentence: the property that must hold for this code to be correct.
Classify its protection: **structure** (breaking it cannot be
expressed), **convention** (developers must remember), **nothing**.
Convention or nothing, where a structural form exists, is a structural
finding — a bug class outranks any local issue. Trivial diffs: "none —
<reason>"; inventing a property teaches readers to skip the section.
If a design doc exists, this lens also verifies its "kept true by"
claim against the code as merged reality, not as intended.
