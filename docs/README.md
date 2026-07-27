# Reading order

**Writing or editing a doc? [`DOC-DISCIPLINE.md`](./DOC-DISCIPLINE.md) first — it is mandatory**, and
it supersedes the "where new writing goes" table at the bottom of this file (which it restates in
full). It also carries the compaction protocol. `./docs/check-docs.sh` enforces the mechanical rules.

Four documents rebuild context. Read them in this order and nothing else is needed to start work.

| # | read | what it is for |
|---|---|---|
| 1 | [`HANDOFF.md`](./HANDOFF.md) **Part 1 only** | the **rebuild runbook** (execute it), **"ALREADY SETTLED — DO NOT REDISCOVER THESE"**, and the rules that must not be relearned: build tax, test invocation, the deduced-return-type hazard, git discipline |
| 2 | [`v3-facts.md`](./v3-facts.md) | **every measured number, with the command that reproduces it.** Read before designing anything |
| 3 | [`v3-dead-ends.md`](./v3-dead-ends.md) | refuted claims and retired approaches. Read before proposing a mechanism |
| 4 | [`v3-engine-design.md`](./v3-engine-design.md) | the current design: commitment, what it deletes, what it makes hard, kill condition |
| 5 | [`v3-requirements.md`](./v3-requirements.md) | **the constraint inventory: ~110 individual constraints, PER COMPONENT (AD substrate, solver/schedule, patch restore, introductions, light field, spline, structure, K93, FF16, TF24 leaf, TF24 soil, density transport, census, multi-species, disturbance, Strategy ownership, verification, DX). §20 is what is still untested per component; §21 keeps the CURRENT CANDIDATE's properties separate, because they are answers and not requirements** |

Then, only if the task touches them:

- [`v3-control-flow.md`](./v3-control-flow.md) — the adaptive → fixed → reverse flow for FF16 and
  TF24, and the memory profile of the proposed TF24 solution.
- [`v3-replayable-redesign.md`](./v3-replayable-redesign.md) — the `Replayable` concept decision.
- [`v3-evidence-triage.md`](./v3-evidence-triage.md) — how to read the older corpus. **For every
  number, ask what would change it.** Three worked examples of that rule catching a wrong claim.
- [`v3-north-star.md`](./v3-north-star.md) — the objective and the durable principles.
- [`oracle/oracle-consultation-index.md`](./oracle/) — **mandatory** if the task touches the TF24
  leaf `p*` adjoint or FD-verifying a TF24 gradient. Trust a *response*'s Decisive Experiment;
  distrust a *consultation*'s framing.
- [`deepenings/`](./deepenings/) — earlier deep studies. `deepening-6-light-coupling.md` is the one
  that was re-derived the hard way; read it before touching the light path.

### Discovery narratives — findable, not required

These record *how* something was worked out. Their numbers are already in `v3-facts.md` and their
wrong turns in `v3-dead-ends.md`, so read them only when you need the derivation rather than the
conclusion.

- [`v3-l2-audit.md`](./v3-l2-audit.md) — the light-field audit: three coexisting paths reduced to
  two sources and one transform, the secant deletion, and the spline-versus-field question closed.
- [`v3-step-local-adjoint.md`](./v3-step-local-adjoint.md) — the sweep's derivation. **§3b is dead
  text**, kept for its argument only.
- [`v3-reverse-memory-design.md`](./v3-reverse-memory-design.md) — the memory profile and design
  search. **§6d's estimates are refuted** (see dead ends); §1's measurements stand.
- [`v3-phase1-plan.md`](./v3-phase1-plan.md), [`p2c-leaf-adjoint-design.md`](./p2c-leaf-adjoint-design.md),
  [`design.md`](./design.md), [`phase0-results.md`](./phase0-results.md) — earlier plans and rationale.

---

## Where new writing goes

**A session appends to the three ledgers. It creates a new document only for a new decision.**

| you have | it goes |
|---|---|
| a measured number | a row in `v3-facts.md`, with its command. Re-measured differently? **Edit the row**, don't add one |
| a refuted claim | a row in `v3-dead-ends.md`, plus a one-line pointer where it was asserted |
| a new commitment | a new design doc, with a ledger, a kill condition, and what it deletes |
| a narrative of how you found out | `archive/`, **after** its numbers are in `v3-facts.md` |

This rule exists because session 22 produced four design documents for one design at four stages of
discovery, and retracted claims inline in documents it had just written — so a linear reader met each
claim before its correction.

## What lives where

- `docs/*.md` — live. Anything superseded moves to `archive/`.
- `docs/archive/` — superseded, kept because a dead end unrecorded is a dead end re-walked.
- `docs/reference/` — **runnable probes.** These are the citations in `v3-facts.md`; each has a `.cpp`
  and a `.R` that runs it. They are the reason a fact can be re-verified instead of trusted:
  - `segment-rerecord-probe` — does a unit replay reproduce the forward pass? (`rebuilt_worst`
    describes `rebuilt_abs`, **not** `from_copy_abs` — see the driver header)
  - `leaf-staleness-probe` — **the discriminating test for the `Leaf` blocker**: inline vs deferred
    replay, with FF16/K93 as no-leaf controls
  - `soil-clamp-probe` — where a trajectory sits relative to the soil clamps; takes a `rainfall`
    argument (drier is much slower — run points one at a time)
  - `restore-stamp-probe` — what `r_set_state` drops (the birth stamps), and the reference magnitude
    that makes the raw drift columns readable
  - `chained-adjoint-probe` — A1/A2: the chained state adjoint in plant, and whether a
    newborn is stand-dependent. Read `lambda scale` before believing a match
  - `unit-adjoint-probe` — the first plant witness of a unit under AD: adjoint accumulation,
    the shared-Strategy pointer identity that decides it, and the per-unit tape
  - `two-species-probe` — the shared-`eta` constraint the separable field carries, plus
    two-species replay and the empty-first-species UB
  - `unit-cost-probe` — what one unit costs in wall clock, split copy / restore / advance
  - `spline-tangent-probe` — the spline-cannot-carry-the-tangent measurement
  - `crown-preaccum-probe` — the crown boundaries, and the XAD byte model
- `docs/oracle/` — consultations (questions we asked, including the confused ones) and responses
  (answers, carrying the Decisive Experiments). The asymmetry matters.
- `docs/deepenings/` — long-form studies that predate the v3 design.
