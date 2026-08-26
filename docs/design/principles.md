# How to change this codebase

The rules the reverse-mode work is judged by, and the route that produced the
plan it is working through. Read the second half if you are picking this up
without the context that built it.

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

## Where a change belongs

**A capability of the tool goes in the tool.** The AD library is named in odelia
and nowhere else; how a tape is reset is odelia's business, and a model asked to
help with it is a model carrying odelia's problem. If an increment cannot be
described without teaching the model a new word, the increment is in the wrong
package.

---

# How this plan was arrived at, and how to rejoin it

Five moves, in order. Each produced a document, and each answers a question the
one before it could not. A session that has lost its context can rebuild it by
reading them in this order; a session that wants to continue the work should
start at the cut.

## 1. Read it cold, as an exhausted maintainer

Not "is this correct" — that is what the reports and the ladder are for. The
question is **where does this cost a reader**: which parts are branchy, indirect,
or introduce a name whose purpose only becomes clear three files later. Follow
one product call end to end and write down every word you had to learn.

That walk is at the top of `subtraction-targets.md`, and the hotspots it marks
are what everything after it works on.

## 2. Name what is not earning its keep — `subtraction-targets.md`

A log, not a proposal: each entry names something the work built or left behind,
the evidence it is not earning its keep, and what would break if it went. Found
by asking about **consumers**, not about counts — two counting lenses were tried
and both produced confident nonsense, and that is recorded there so nobody tries
them again.

## 3. Ask where one idea is spelled twice — `unification.md`

The narrower question with the sharper answer. Not "is this dead" but **is this
here twice** — two vocabularies for one idea, two mechanisms answering one
question, a thing built per step whose inputs are constant across the loop, a
parameter that exists for one caller. The tell of the first is a translation layer
between the two spellings.

## 4. Ask what the model forces — `one-reverse-pass.md`

The prior question. Given permission to change dependencies, delete products and
re-open trade-offs: **what shape does the model force**, and what is merely how it
was built? Written as five facts about TF24 that are not design decisions, then
the collapses that follow from them.

This is the move that pays, and it needs the permission to be real. Two things
that had been ruled out became available the moment a whole product could go, and
the hardest item on the previous list turned into a deletion.

## 5. Cut, smallest first, and measure

`one-reverse-pass.md` carries the order. It is subtraction first, then the
mechanisms in the sequence where each makes the next smaller, then the two that
are redesigns. Rank the remaining work **by names removed**, not by lines and not
by seconds: the entries that delete a concept are the ones whose value compounds,
because every later change is read against a smaller vocabulary.

## What holds across all five

- **A comment that blocks your change is evidence, not clutter.** Satisfy its
  claim or disprove it before deleting it.
- **An expectation changed in the same commit as the code it constrains is not a
  check.** If a test says no, the test is the finding.
- **"Free" means unreferenced, and unreferenced means grepped.** A plan's
  cheapest items are the ones its author did not verify.
- **A claim about a library's behaviour is a measurement, not an argument.**
  `odelia/tests/standalone/probe_tape_reset.cpp` is the cheapest place to ask one
  about the tape; twenty lines of it settled what two documents had argued in
  prose.
- **Where a rule spans a model, look for the counter that already knows.** A
  guard reporting a number beats one reporting a boolean, and both beat a
  paragraph telling the reader to be careful.
- **A defect that needs two runs to differ needs a fixture that differs.** "It
  passes on the small case" is not evidence; the small case is where the
  collision lands harmlessly.
- **Every claim about speed needs a control**: the same fixture, both sides,
  interleaved in one session. A figure from a document is a figure from whenever
  it was last true.
