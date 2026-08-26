# How to change this codebase

The rules the reverse-mode work is judged by. The first half is general and
inherited; the second half was earned on this branch, and each of those entries
names the change that taught it. Where the two halves conflict the second wins,
because it was paid for.

## The prime directive

If a maintainer would find it exhausting, it is a bad solution. Aim for the most
result with the least code and the fewest concepts. Writing code is cheap here,
which is what makes over-engineering easy; the counterweight is to borrow a
human's fatigue.

## Subtraction

**Remove before you build.** Adding to a complex system compounds it; removing
first cuts the surface, reveals the structure, and usually makes the next design
obvious. Sequence removal before construction, and subtraction before scaffolding.

**When asked to improve, look for removals first.** A reference with no novel
content is deleted, not stubbed.

**Design for observed usage.** No speculative validators, parsers or guards
beyond what the model demands. Out-of-spec features drag guards behind them.

## Structure

**Data structures first.** Get the shape right before the logic; the right shape
makes the downstream obvious. A structure change late is a rewrite and early is a
one-line diff.

**Model the domain in a structure, not in conditionals.** A state machine rather
than scattered booleans; a table, registry or discriminated union rather than
branching spread across files; a module organised around one body of knowledge
rather than a sequence of phases. Execution order is not ownership.

**A boolean that records how a value was computed means the domain wants a
structure.** So does one that decides which half of a type is live: that is two
types.

**Do not force it.** Prefer boring code where the current shape is clear, local
and unlikely to grow. Three similar statements beat a premature abstraction. DRY
the structure, not every line.

## Layers

**Collapse what does not earn its keep.** A wrapper with one caller is not a
boundary. An adapter with no second implementation is not an adapter. A layer
that repeats its arguments and hands them on is reader load without compression.

**Demand interface compression.** A broad interface hiding little makes a reader
learn both the surface and the implementation. Prefer boundaries that hide
decisions.

**Keep the call hierarchy flat.** If answering a question means tracing more than
three files, flatten it. A rich interface hiding substantial work is not a deep
chain; a chain of forwarders is.

**Question the threading.** A signal passed through four frames to reach one
reader has a shorter path.

**Consolidate decisions.** Do not make the same choice in several places. One
source of truth, and pass the result.

**Name the invariant at the boundary**, not in every consumer, so a reader learns
it once.

**Shrink state scope**: returns over mutations, locals over fields, fields over
module state. Derive instead of syncing.

**Before adding a layer or a piece of state, ask whether it reduces reader load
somewhere else by at least as much.**

## Consumers

**A thing earns its keep by having a consumer that is not itself.** Tests are a
consumer, but a surface reachable only from tests is held up by the thing it is
meant to check.

**One fact, one representation.** A fact spelled three ways costs a reader three
times, and the spellings drift.

**Tests-only reachability does not distinguish dead from unfinished.** The check
that separates them is whether a plan item still carries open work.

---

# What this branch taught

## 1. A subtraction that adds a protocol is not a subtraction

Carrying one lifted System across a width's recordings, instead of rebuilding it
per recording, needed every class of the model to declare its active values and
every caller to release them. That is eleven files, a new concept in the shared
header, and a standing obligation on the model — for three to four per cent,
measured.

⚠️ **Count the concepts a change adds, on the same page as the time it saves.**
A change that removes a name is worth more than one that removes a millisecond,
and a change that adds a name has to earn it against both. The question is never
"is this faster" but "is the whole smaller".

The tell was available before the work: the increment could not be described
without introducing a word.

## 2. Measure the mechanism before arguing about it

The same change was first written on the reasoning that a recording rewrites
every value it reads, so carrying a System is safe. The reasoning was wrong for a
reason no amount of reading the calling code would surface: in this AD library,
**assigning to a value keeps the tape slot it already had**. Rewriting does not
refresh it.

Twenty lines of standalone probe settled in one run what two documents had argued
about in prose. `odelia/tests/standalone/probe_tape_reset.cpp` is that probe, and
it is now the cheapest place to ask this class of question.

⚠️ **A claim about a library's behaviour is a measurement, not an argument.**
Write the probe. It is smaller than the paragraph.

## 3. The reason lives in the comment, so deleting the comment deletes the reason

The paragraph that said *assigning from an expression keeps the slot the target
already had* was deleted by the change it would have refuted, as part of tidying
away an explanation that had become inconvenient. The failure it warned about
followed within the hour.

⚠️ **A comment that blocks the change you are making is evidence, not clutter.**
Before removing one, satisfy its claim or disprove it.

## 4. Never edit the assertion that says no

`test-state-and-parameter-adjoints.R` asserted one lift per recording — three
calls, three lifts. To make the change compile, that expectation was edited to
one, with a confident comment explaining why the new invariant was better. Then
the numbers were run, and they were wrong by twelve orders of magnitude.

⚠️ **An expectation changed in the same commit as the code it constrains is not a
check.** Change the code or change the claim, and never both at once without
saying which came first.

## 5. "Free" means unreferenced, and unreferenced means checked

Two items were planned as costless deletions. Neither was: the single-potential
supply path is selected by the finite-difference product through a name lookup,
and `extra_splits` is what the identity rung's bit-for-bit split passes. Both
took ten seconds to check and would have taken a session to unpick.

⚠️ **Grep before you promise.** A plan's cheapest items are the ones its author
did not verify.

## 6. Turn an audit into a number

The requirement "every active value must be released before the tape is cleared"
was, at first, a list of ten classes to read carefully. It became the tape's own
count of registered values, which has to return to zero. It failed four times
during development, each time naming how many values had been missed.

⚠️ **Where a rule spans a model, look for the counter that already knows.** A
guard that reports a number beats a guard that reports a boolean, and both beat a
paragraph telling the reader to be careful.

This is the one part of the change worth keeping whatever happens to the rest.

## 7. A silent failure needs a shape to show up in

The carried System is *accidentally correct* while every recording registers the
same number of inputs. It only breaks once the shapes differ — which the sweep
does at every widening. A narrower test passes.

⚠️ **When a defect depends on two runs differing, the fixture has to differ.**
"It passes on the small case" is not evidence; the small case is where the
collision lands harmlessly.

## 8. Prefer the increment that removes a word

Of the work landed on this branch, the parts that read best afterwards are the
ones that deleted vocabulary: the calibration path (one tape discipline where
there were two), and the complete recording (*piece* and *with_insertions* left
with nothing to name). The part that reads worst is the one that added a word for
a percentage.

⚠️ **Rank the backlog by names removed, not by lines or by seconds.** The
entries that delete a concept are the ones whose value compounds, because every
later change is read against a smaller vocabulary.
