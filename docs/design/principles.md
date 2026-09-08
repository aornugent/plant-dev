# How to change this codebase

Two lists. The first is what a change here is judged against, and the second is
what has turned out to catch a defect that reading did not. Both are written to be
argued with: where a rule and the code disagree, one of them is wrong, and which
one is the finding.

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
  pair that duplicates each other.** A census of the names here cleared `segment`
  because it was not another word for the widening event. It was another word for
  `range`, and the tests had been writing the translation between the two out by
  hand for as long as both existed.
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
- **Read a bound against the number the defect would produce.** A tolerance is not a
  check until someone computes what the failure looks like and confirms the bound
  excludes it. One check in the gradient suite asserted `abs(ratio - 1) < 0.5`
  against a defect whose own comment gives the signature as the ratio of cohort
  counts, four thirds — inside the bound. It had passed for as long as it had
  existed, and passing was all it could do.
- **A check inside the branch its own condition selected cannot fail**, and neither can
  one behind a `skip` on the exact complement of its assertion. Three of those here.
- **A skip is a pass with better manners.** Count the tests that never run: an
  unconditional `skip()` and a `skip` whose guard is always true both report green. The
  sharpest form is an environment check or a **compile failure turned into a skip** —
  delete the parameter a probe reads and the test that checks the parameter table stops
  running instead of failing.
- **Ban the metaphor, not the word.** A banlist of nouns bans the domain's vocabulary
  with them: this one forbids `resident` and `mutant` while plant exports `add_mutant`,
  `run_mutant` and `remove_residents`, and forbids `surface` where phylloptim means the
  *soil surface*. Ten of seventeen flagged "decorative nouns" were the physical thing.
  Check the API before adding a word to a rule.
- **A style rule with no mechanical check is a preference.** Seventeen process-history
  comments landed under a written ban, in a tree with no linter, no hook and no CI
  check for it. Twenty lines of scanner over `//` blocks catches every named class.
- **A line number in a document rots silently and reads as precise.** Half the code
  citations here were wrong — five naming a file that no longer exists, seven past the
  end of the file, nineteen pointing at unrelated code, one by 595 lines. Name the
  symbol instead: it is grep-able, and a wrong one fails visibly.
