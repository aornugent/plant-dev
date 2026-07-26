# Reading the corpus: how to tell wheat from chaff

24 design docs, deepenings and Oracle consults exist across `docs/` and `docs/archive/`.
Some are load-bearing, some were superseded by refutations, and some were always estimate
dressed as measurement. This document is the **triage rule**, earned the hard way in
session 21, plus a marked reading list for the L2 question that is next.

It exists because "verify before building" (Part 1) tells you *to* check and not *what
counts as a check*. Session 21 produced three wrong claims that all passed a casual
version of that rule.

---

## The rule: for every number, ask what would change it

| answer | verdict | what to do |
|---|---|---|
| Nothing stated / can't tell | **estimate** — chaff | re-measure before building on it |
| A config, policy or schedule we expect to change | **conditional** — real but not load-bearing | never put a contract on it |
| Only a change to the mechanism itself | **wheat** | build on it, cite it |

A number in a table with a `×` after it looks identical in all three cases. The distinction
is not the number's precision, it is **what the number is a measurement of.**

### Three worked examples, all from one session

1. **Estimate wearing measurement's clothes.** `v3-reverse-memory-design.md` §6d gave crown
   preaccumulation as **2.7×** (boundary A) and **12×** (boundary B), in a table, as the
   basis for the next task. Measured: **1.49×** and **3.7×** (§6e). The estimate assumed the
   light-field read was 29% of the crown tape; it is **66%**. Nothing in §6d said it was an
   estimate — and §0 of `v3-step-local-adjoint.md` had already built a ceiling table on top
   of it.
2. **A real measurement of the wrong thing.** §3b measured **1.10–1.34 ODE steps per event
   segment** and chose the segment as the step-local unit on that basis. The measurement was
   correct and the conclusion was wrong: the ratio is a property of **one schedule policy**,
   and that policy is known to be poor (the multirate work found a coarser uniform grid
   refined at introductions beats the default for TF24's rainfall transient). A contract
   built on it would inherit whatever `refine_schedule` happens to do. **Conditional, not
   wheat** — and the tell was available: L0/L1 are *replay*, resolved by a policy, not
   mechanism.
3. **A measurement of my own method.** Sessions 20 and 21 reported odelia as having 10, then
   **30, "loader errors"** — session 21 calling them *proven* pre-existing after rebuilding a
   stashed baseline. `cd odelia && make test` gives **0 fail / 467 pass**. `test_dir()` does
   not attach the package; `test_local()` silently skips the whole AD workflow. **A baseline
   controls for the change, not for the method** — reproducing a number says nothing about
   how it was obtained. `AGENTS.md` documented the right command the whole time.

### Two corollaries

- **A refutation ages every doc upstream of it.** §6d's estimates propagated into §0's
  ceiling table and into a handoff signpost before being measured. When you refute
  something, grep for what cited it.
- **Prefer the doc that names its own kill condition.** A design doc that says what would
  invalidate it has been thought about adversarially; one that only argues has not.

---

## Reading list for the L2 question, marked

The live question (owner, session 21): *the light field has accreted a lot of bandaid, and
there may be no optimal replayable L2 construct.* **L3 is deferred.** Read in this order.

**Read the code first, not the docs.** The bandaid is visible and current, and it is the one
source that cannot be stale. Session 21 saw four coexisting mechanisms without looking for
them: `FF16_Environment`'s `freeze_query_derivative` and `freeze_field_derivative` debug
statics on a production class; `field_supersedes_spline`; a fitted spline kept alive only for
"not-yet-assembled reads" while `competition_field` serves the rate path; and
`get_value_at_height_frozen_query` indexing at the stripped double height with the tangent
supplied separately by a secant. **That is three light paths and two derivative-stripping
switches in one class** — the audit's subject, and none of it needs a doc to confirm.

| doc | what to take | what to distrust |
|---|---|---|
| `odelia/AUTODIFF.md` | the **contract** for L1/L2/L3 and the one-way-to-get-it-wrong. Mechanism, currently true, and the authority | nothing known — but it describes L2 as node *positions*, which predates the separable field entirely |
| `archive/ad-record-replay.md` | the original L2/L3 record→replay derivation — why positions are per-step and values per-stage | any status claim; it predates the field |
| `oracle/oracle-response-transport-compression.md` | an Oracle **response** (not a consultation) — responses carry Decisive Experiments, which are the wheat-shaped part | — |
| `archive/tape-memory-design.md`, `archive/odelia-6-boundary-tape-checkpoint.md` | earlier framings of the memory problem, useful for *what was already rejected and why* | its numbers: superseded by §1 of `v3-reverse-memory-design.md`, which measured them |
| `archive/reverse-mode-dx-design.md` | the DX=concept-count framing in its original form | — |
| `v3-reverse-memory-design.md` §6c | the **frozen-L2 principle** — a frozen position set makes the reconstruction a fixed linear operator, so its Jacobian is shared and its transpose exact. This is mechanism, and it is why `separable_field`'s hand transpose is sanctioned | its conclusion that L2 "cannot be the lever" — that was about *memory*, and the live question is *complexity*, which it did not weigh |

**The trap specific to this question:** §6c set frozen-L2 aside on a scaling argument (the
reconstruction is per-stage, the tape is per-cohort-step, so it is a fraction of a percent of
the bytes). That argument is sound **and answers a different question than the owner asked.**
Bandaid count is not bytes. Do not read §6c as "L2 is settled".

**Consult the Oracle index (`oracle/oracle-consultation-index.md`) before designing**, per
Part 1 §3b — and note the asymmetry in that directory: `oracle-consultation-*.md` are
*questions we asked* (they encode our confusions, including the wrong ones);
`oracle-response-*.md` are *answers*, and only the responses carry the Decisive Experiments.
Distrust a consultation's framing; trust a response's experiment.
