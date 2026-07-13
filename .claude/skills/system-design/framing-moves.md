# Framing moves

The strongest designs come from re-representing the problem, not from
enumerating solutions to the problem as stated. These seven moves are the
re-representations that recur. In Step 3, assign a different move to each
candidate; the assignment exists to force genuine diversity, not as a
taxonomy — moves overlap, and a candidate may end up using two.

**1. Weaken exactness, or change the quantifier.**
"Always correct" becomes "almost always, plus detect and repair", or
"exact" becomes "within tolerance". Trade accepted: a repair path that
must itself be boring. Bites when the last 1% of the guarantee causes 90%
of the machinery. (Optimistic concurrency instead of locks; eventual
consistency; a checksum-and-refetch instead of a distributed
transaction.)

**2. Move a decision offline.**
Trade an online choice for recorded data or a precomputed table: run the
deciding pass once in a cheap regime, then replay its decisions in the
expensive regime. Trade accepted: the decisions are now data — stale by
one pass, and their own sensitivities are gone. Bites when the decision
logic poisons the expensive regime (branches on active AD values;
planning inside a hot loop). This is the record→replay shape.

**3. Move the system boundary.**
Solve it in the caller, the build step, the schema, or a library — or
delete the requirement and report who screams. Buying beats building when
the problem is not your domain. Trade accepted: a dependency, or a
conversation with the requirement's owner. Bites when the problem is only
hard because of where it's standing.

**4. Trade compute for storage, or storage for compute.**
Recompute what you were caching; cache what you were recomputing;
checkpoint and replay the middle. Trade accepted: the resource you now
spend more of — say which, with a number. Bites when one resource is
scarce and the other is embarrassingly cheap, which the ledger already
told you.

**5. Optimize the typical case, detect the rest.**
A fast path for the shape the ledger says dominates, a guard that routes
everything else to a slow, obviously-correct path. Trade accepted: two
paths, and the guard must be structurally honest (the fast path must be
unable to receive what it can't handle). Bites when the workload is
lopsided and the general case is expensive precisely because it is
general.

**6. Pólya, with witnesses.**
Replace N existing special cases with one mechanism that is smaller than
their sum, and whose stronger guarantee genuinely holds for all N. Trade
accepted: the stronger spec is now load-bearing. Bites when you hold
three-or-more cases in hand and their disagreement is a live bug class.
Never fires on rumored cases — that is the YAGNI trap wearing this
move's clothes.

**7. Batch or amortize across the population.**
Per-item costs (boundary crossings, setup, allocation, taping) become
per-batch costs. Trade accepted: latency granularity and a batching
seam. Bites when the ledger shows count × per-item-overhead dominating —
ten thousand 5 ms solves are not a solver problem, they are a crossing
problem.
