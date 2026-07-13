# Examples

Copy the derivations, never the conclusions. Three examples end three
different ways — floor, batching, challenge — on purpose: if your winner
matches any conclusion here, re-run Step 1.3 and Step 5.2 before
trusting it.

---

## 1. A full search (ends in batching)

Task: calibration runs the model over ~10,000 independent small datasets;
each solve takes < 5 ms with 3 parameters; gradients already work via
record→replay. Users ask for a full calibration to finish over lunch,
not hours.

> **Triage:** 2 — internal pipeline, but a batching seam is a visible
> boundary.
> **Ledger:**
> R1: full calibration ≤ ~1 h — currently ~4 h.
> R2: per-dataset results identical to today's, bitwise — regression
> suite exists.
> R3: 10,000 datasets × < 5 ms solve, 3 parameters each.
> Scarce resource: derived from R3 — 5 ms of solve cannot explain 4 h;
> 10,000 × (R↔C++ crossing + tape setup + allocation) can. The scarce
> resource is per-call overhead, not solver speed and not tape memory.
> **Floor:** parallelize the existing R loop (mclapply). Pays R1 only if
> overhead is in the solver — but the overhead is per-call and is paid
> once per dataset regardless of cores; 8 cores of crossings is still
> 10,000 crossings. Fails R1 by arithmetic.
> **Candidates:**
> A [first thought] (move 4, compute↔storage): cache tapes per dataset —
> pays part of setup — costs a cache keyed by dataset, and crossings
> remain — wins when tape setup alone dominates.
> B (move 7, batch): one R→C++ call takes all datasets; C++ loop reuses
> one tape, parallel-for across datasets; one crossing total — pays R1
> at the mechanism level — costs a batching entry point (1 new name) —
> wins when count × overhead dominates, which is R3.
> C (move 2, offline): precompute solves overnight — pays R1 by removing
> it — costs staleness — wins when inputs are known ahead of time; they
> are not (calibration proposes new parameters each iteration).
> Winner: B. Eliminations: A pays setup but not crossings (fails R1's
> arithmetic); C fails the calibration loop's structure (inputs are
> online by definition).
> **Commitment:** the R boundary is crossed once per calibration
> iteration, not once per dataset.
> Kept true by: the only exported entry point takes the full dataset
> list; a per-dataset call does not exist to be misused.
> **Kill question:** assumption — overhead, not solve time, dominates.
> Falsify from the ledger: if solves were the cost, 10,000 × 5 ms = 50 s,
> not 4 h. The assumption survives; the design stands.
> **Makes hard:** progress reporting and partial failure now live inside
> one long call — cope with a callback and per-dataset status in the
> return.
> **Kill condition:** datasets grow until one batch exceeds memory —
> hands off to a chunked variant of B; A's tape cache is never the
> answer.

The deep move was in Step 1.3: refusing the inherited scarcity. Gradients
plus tape *sounds like* the memory problem from the AD literature; the
ledger's own numbers said otherwise.

---

## 2. The floor wins (ends in ~15 lines of code)

Task: when an integration fails to converge, a developer needs enough to
reproduce it — parameters, initial state, accepted-step history. Happens
a few times a week in development; production users must see the
existing error unchanged.

> **Triage:** 1 — internal, reversible. Steps 1–2 only.
> **Ledger:** R1: reproduction data on failure — a few/week, dev only.
> R2: production behavior unchanged — exactly.
> Scarce resource: developer time re-deriving failing inputs; nothing
> here is hot.
> **Floor:** on the failure path, serialize the three items to one file
> and put the path in the existing error message. ~15 lines, zero new
> names, R2 untouched. It suffices. Stop.

What did NOT happen: a logging framework, severity levels, sinks, a
DiagnosticsCollector. Stopping is a result.

---

## 3. Annotated failure (the tells of a decorated search)

A design doc for gradients of an equilibrium model chose reverse-mode AD
with adjoint-at-equilibrium. The answer was even correct. The search was
theater. The tells, and the step that catches each:

**Tell 1 — the candidates were decoration.** A restated the floor; C was
a strawman with no defensible "wins when". The answer predated the
section; A/B/C were arranged around it. *Caught by:* Step 3's wins-when
gate, honestly applied — and at Tier 3, by deep-search.md, because
independence can't be faked from inside one context.

**Tell 2 — the document refuted itself and never noticed.** Its design
section held parameters to observed quantities, keeping the calibrated
set small — while its centerpiece was justified by reverse-mode's
advantage at large parameter counts. Two fields, one contradiction, zero
cross-checks. *Caught by:* Step 5.2, reading your own fields against
each other as quantities. n ≤ 8 beside "scales with parameter count" is
a kill, not a nuance.

**Tell 3 — inherited scarcity.** It declared tape memory the binding
constraint because the exemplar's problem had that constraint — but its
own candidate B ran to equilibrium on doubles, which kills the tape
regardless. The actual scarce resource (wall-clock per forward run) was
never derived. *Caught by:* Step 1.3 — scarcity is derived from this
ledger's quantities before any design exists, or it is not claimed.

The general lesson: presence checks (a section exists) are satisfiable
by decoration. The gates that bite are the ones that can fail the whole
design — the kill question, the consistency pass, arithmetic. When in
doubt, ask of any section: could this paragraph kill the design it
appears in? If nothing in the doc could have, the search never happened.

---

## 4. Challenge upward (two lines)

"Make the output format flexible for downstream tools" — today's only
consumer is the R package; a Python consumer is rumored. Ledger entry:
`R?: flexible format — challenged upward: "is the Python consumer
committed? A rumor is not a witness; today one format suffices, and the
retrofit when a second consumer lands is a serializer seam we can add
then."` Kill condition: second consumer confirmed. Nothing is built now.
