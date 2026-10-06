# The sign-change design search

The working files of the search that `docs/design-sign-changes.md` reports.
Scripts take paths under the session's scratchpad (`DEV`), as the other
measurements here do. The runs' `.rds` outputs are not committed.

- `ledger.md` — the problem as mathematics, the requirements R1–R13, what
  exists. Two corrections were added during the search: R1's ε floor, and the
  pairs count.
- `sealed_scarcity.md` — the orchestrator's derived scarce resource. The
  judge read it only after writing its own.
- `proposals/` — the six candidates as written. A is the orchestrator's first
  thought; the others each came from one proposer on one framing move:
  - `boundary` (move the system boundary);
  - `exactness` (weaken exactness);
  - `offline` (move a decision offline);
  - `typical` (optimise the typical case);
  - `batch` (batch across the population).
- `judge/` —
  - `candidates/` holds the same six with authorship stripped: A as above,
    B exactness, C batch, D boundary, E offline, F typical;
  - `scarcity.md` holds the judge's own derivation;
  - `verdict.md` holds the ranking, the flags, the pre-registered
    measurements M1 and M2, and the challenges;
  - `m3/` holds its count of crossing steps on episodic and long drought.
- `judge_prompt.md` — the judge's instructions.
- `spikes/<label>/` — each proposer's scripts and logs.
- `orchestrator/psi_check.R` — the check that a Cash–Karp step's error across a
  kink averages to zero over the crossing's place, and that its derivative
  jumps at the weighted stages.
