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

# The documents, and which of them is live

One is the work; the rest are the rules and the record. **Read this file, then
`two-paths.md`**, which carries every open item this objective reaches and names the
ones it does not.

| | |
|---|---|
| **[`two-paths.md`](two-paths.md)** | **The objective, delivered bar one item.** Seven of its eight are closed; item 7 is open and is what a new session picks up. Read its first two sections; the rest is the record of how each closed |
| [`principles.md`](principles.md) | the rules, and this map |
| [`subtraction-targets.md`](subtraction-targets.md) | what was not earning its keep, by consumer. **Eight of its 24 entries still open**; the ones this objective reaches are carried into `two-paths.md` |
| [`unification.md`](unification.md) | where one idea was spelled twice. **Four of its 10 entries still open**, same treatment |
| [`one-reverse-pass.md`](one-reverse-pass.md) | what the model forces, and the cut, sequenced 0–9. **Closed** |
| [`one-order.md`](one-order.md) | the leaf's derivative boundary. Landed, bar a memo of three unbuilt items |
| [`one-program.md`](one-program.md) | a trajectory as a composition of maps. **Steps 4 and 6 outstanding** — they are lens 1 of `two-paths.md` |
| [`measurements.md`](measurements.md) | the running record: root causes, figures, two scares. History |

⚠️ **Several documents describe past states in the present tense**, which is how a
name that no longer exists gets read as current. `solve_adjoint_over_insertions`,
`advance_over_insertions` and `insertion_steps` appear in four of them and in **no**
code file. Where a passage narrates what was found, read it as of its own date; the
code is the authority on what a symbol is called today.

# How the plan was arrived at

Five questions, each of which the one before it could not answer. A session
rebuilding context reads them in this order; a session doing work does not need
them.

1. **Read it cold, as an exhausted maintainer.** Not "is this correct" -- that is
   what the ladder is for. **Where does this cost a reader?** Follow one product
   call end to end and write down every word you had to learn. That walk is at the
   top of `subtraction-targets.md`, and counting those words is what
   `two-paths.md` now does.
2. **What is not earning its keep?** -- `subtraction-targets.md`. Asked about
   consumers, never about counts: two counting lenses were tried and both produced
   confident nonsense, which is recorded there so nobody tries them again.
3. **Where is one idea spelled twice?** -- `unification.md`. The narrower question
   with the sharper answer. The tell is a translation layer between two spellings.
4. **What shape does the model force**, as against how it was built? --
   `one-reverse-pass.md`, written as five facts about TF24 that are not design
   decisions. This is the move that paid, and it needed the permission to delete a
   whole product to be real.
5. **Cut, smallest first, and measure.** Rank by names removed, not lines and not
   seconds: an entry that deletes a concept compounds, because every later change is
   read against a smaller vocabulary.

**Two of those cuts turned out to be redesigns and got their own documents**:
`one-order.md` for the leaf's seven kinds of derivative, and `one-program.md` for the
trajectory. Both are leaves of this cascade, not branches.

# Where the cut ended

All ten steps are closed. Three findings are worth more than the diffs:

* **Step 1** deleted the calibration path -- 8,005 lines -- and the trait table
  turned out to be sixteen wide for a fourteen-trait model.
* **Step 8** found the leaf's two supply paths were the same arithmetic: one is the
  other at a single layer with no horizontal term. Sixteen `switch` statements
  carried one line of genuine difference, and **the defaults made that line
  invisible** -- a first probe built on them reported agreement, because
  `psi_crit == root_psi_crit` there. A fixture built on the defaults cannot referee
  a difference the defaults collapse.
* **Step 9 is refused**, and the defect proposed for it is closed separately. The
  redesign was forty files for a hazard that needed a property: a rate evaluation is
  a function of the state it is given, so revisiting a state after a different one
  makes a carried value observable. Three calls and two comparisons.
  **Separate a defect from the redesign proposed for it.**

# What held across all of them

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
- **Trace callers; do not read names.** Two production functions were nearly
  deleted for sitting beside a dead family and being named like it.
- **A guard that cannot fail is not a guard.** Verify one by breaking the thing it
  watches. Two of three fault injections here failed to fail, and each was
  informative: the fault was not where it looked.
- **A fixture built on the defaults cannot referee a difference the defaults
  collapse.** `psi_crit == root_psi_crit` at this package's defaults, and that was
  the one line two supply paths differed in.
- **Ask what an open plan item is FOR.** Tests-only reachability does not
  distinguish dead from unfinished, and the usual check is whether a plan item
  still carries open work -- but an open question about a thing whose only consumer
  is being deleted is not open work. The same test kept one file and released
  another.
- **Ask whether the thing this replaced is still here.** Cheap at the end of an
  increment, and a year later it is a 137-name census.
- **Count the names at the end of an increment.** One increment here deleted four
  and added five while its commit message described subtraction, and nobody would
  have noticed: the deletions were visible and the additions were an enum, a nested
  type and two enumerators. Four deletions felt like progress and the total went up.
- **Two states are a bool.** A discriminated union earns its keep by replacing
  branching spread across files. One branch in one place is a bool, and reaching for
  the union costs three names to save none.
- **A rename is not done when the package compiles.** A field renamed in the headers
  and the tests left two scripts reading the old key, where R yields NULL rather than
  erroring — and one of them wrapped it in a `tryCatch` that turned the miss into a
  printed NA. Grep the whole tree, `scripts/` included, and prefer a spelling the
  compiler can refuse.
- **Asking whether a name duplicates the thing you are looking at will not find the
  pair that duplicates each other.** This file's own census cleared `segment` because
  it was not another word for the widening event. It was another word for `range`, and
  the tests had been writing the translation out by hand for as long as both existed.
- **A comment that justifies a design is a claim, not a given.** Two here were wrong
  and both had shaped the code around them: one said a returned pair used
  out-parameters to avoid a taped copy, and it had none; one said an accessor returned
  a stale snapshot, and it was live for four of the five things read through it. A
  blocking comment gets checked because it is in the way. A justifying comment gets
  believed.
- **Measure a dispatch rather than reasoning about it.** Twenty lines of probe said a
  named struct replacing a `std::pair` reached zero of its two scalars, silently. No
  amount of reading the `if constexpr` chain would have produced that number, and the
  failure it describes has no error to look for.
- **Do not increment a count whose base you have not checked.** A record here read
  "26 entries landed" against 24 entries; three sessions added one each and none
  counted. State a number a reader can verify by counting, or do not state one.
