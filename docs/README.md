# Reading order

Four documents rebuild context. Read them in this order and nothing else is needed to start work.

| # | read | what it is for |
|---|---|---|
| 1 | [`HANDOFF.md`](./HANDOFF.md) **Part 1 only** | the rules that must not be relearned: build tax, test invocation, the deduced-return-type hazard, git discipline |
| 2 | [`v3-facts.md`](./v3-facts.md) | **every measured number, with the command that reproduces it.** Read before designing anything |
| 3 | [`v3-dead-ends.md`](./v3-dead-ends.md) | refuted claims and retired approaches. Read before proposing a mechanism |
| 4 | [`v3-engine-design.md`](./v3-engine-design.md) | the current design: commitment, what it deletes, what it makes hard, kill condition |

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
  and a `.R` that runs it. They are the reason a fact can be re-verified instead of trusted.
- `docs/oracle/` — consultations (questions we asked, including the confused ones) and responses
  (answers, carrying the Decisive Experiments). The asymmetry matters.
- `docs/deepenings/` — long-form studies that predate the v3 design.
