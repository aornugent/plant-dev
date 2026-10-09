# Design: building a run's schedule on the birth-date coordinate

Plant moved TF24 to the birth-date coordinate for stability once the storage
pools were introduced. On the height coordinate, invaders at a zero relaxation
offset overshot; on the birth date they run (`assessment.md`;
`archive/scope-imex-stepper.md`). Exact counts followed, then the crown spread.
The schedule is still built as it was for the height coordinate:

- `refine_schedule()` refuses the birth date.
- The pilot, the tolerance over time (`control_window`) and the error estimate
  (`diagnose_scm`) are separate calls a person strings together.

This turn designs how plant builds a run's schedule on the birth date from first
principles. That covers:

- the introductions;
- the tolerance over time;
- the representation between nodes, today's "exact counts" and "crown spread".

The object both of those integrate over is unnamed, and naming it is part of the
design. The map of today's pieces is `map-schedule-building.md`.

## Triage: 3

- It is public R API: `run_scm(refine_schedule = )`, `control_window`,
  `diagnose_scm`, and the Parameters that carry a schedule.
- It is the core numerical representation of the birth-date coordinate.
- The requirements arrived partly as mechanisms ("pilot", "window",
  "refine").

## Requirements ledger

Sources: `OBJECTIVES.md`, `design-grid-controller.md` (items 6–8 and the user's
decisions), `grid-dynamics.md` (§8, §14, §16) and `geometry.md` (§1–3, §5).

- **R0: heuristics choose the introductions and the tolerance over time,
  together** (OBJECTIVES.md, first line).
  - Today a person chooses the node count and strings together pilot, run and
    diagnosis. `refine_schedule()` refuses the birth-date coordinate.
- **R1: accurate.** `ln J`, every elasticity and every curvature is within ε of
  the converged answer.
  - ε is 0.025 in `ln J`. Each elasticity's ε is a tenth of its spread, never
    under 0.01. Curvatures' ε is 1.2 and 4.0 for `lma`.
  - On the birth-date coordinate the node error is about 100× the time error at
    the tolerances used (item 8).
  - Spread uniform nodes at 108 introductions alone err by up to 3.31ε (long-wet)
    and 2.72ε (long drought).
- **R2: reproducible.**
  - A ±5% nudge in `tol`, or the introductions moved by a quarter of their
    spacing, moves each quantity by less than ε/3.
  - The quarter-spacing move passes on long-wet and dry for both roles
    (`measurements/node-rule/`).
- **R3: continuous in the traits.** On one frozen grid the answer moves smoothly
  as the resident's θ moves within ±10%, or an invader's θ′ within ×0.5–×2.
  - The grid's introductions and steps are frozen per analysis. Invaders walk the
    resident's recording.
- **R4: predictable.** Each knob's error falls at its order, so a coarser run
  estimates the error.
  - Spread uniform nodes are on the square law over 108, 215 and 429 on long-wet
    and long drought. The ratio is 3.78 and 3.92, the companion reports 0.95 and
    0.98 of the error, and the estimate covers 93–95% of quantities.
  - Graded nodes (a fixed rule: 0.03 growing ×1.11 to 0.37) are not on the square
    law under bounded Cash–Karp: their companion reports 0.71 and 0.80.
  - Episodic is not yet asymptotic over u108–u429. Its error falls 4.8× from u429
    to u857, once the spacing is under its dry spells (median 31 days).
  - Under constant rain `J` falls on the square law but its gradients do not:
    the fate front moves them up to 3ε, and no uniform rung refines it. A pilot
    with nodes every 1/16 day around the front was used.
- **R5: never fails** over the trait range, for residents and invaders. This is
  held today by the 15-day cap and the substepped soil.
- **R6: shared.** One grid per local analysis serves the resident and every
  invader in the box. It is rebuilt on big moves in θ.
  - An analysis is 60–84 forwards at `b*`. Each `b*` takes a secant of 4–6
    runs.
  - The grid an analysis shares is the record of its resident's last
    equilibrium run.
- **R7: performant.** The least runtime at matched error.
  - A forward on long drought at `3e-5` and 108 nodes is 962 505 rows. A
    gradient run is about 7 forwards in rows (1 + 2.6 + 0.8 + 2.6). In an
    invader loop an evaluation is about 3.4.
  - Spread 108+215 extrapolated reaches 0.090ε at 2.41M rows (long-wet) and
    0.174ε at 1.95M rows (long drought), forward rows over both rungs.
  - **Measured levers:**
    - the tolerance over time from a pilot saves 21–23% of rows on pulsed
      records and 1.9% under constant rain;
    - the pilot (54 nodes at `1e-3`) costs 0.25–0.32 of a forward's
      member-steps;
    - an invader's shared thinned schedule saves 24–25% of a walk's rows, at
      most 0.43ε (on `recruitment_decay`);
    - thinning the stand's nodes after b = 10 fails (0.70ε), because the soil
      field changes for the cohort that produces `J`.
  - **Where J comes from:** 78–100% of `J` from members born before 3.6.
    59–61% of member-steps come after t = 25, where at most 6.1% of `J` is still
    to come. A node costs its lifetime in steps, so early nodes cost most.
  - **The root law:** at fixed weighted error the fewest cells take spacing ∝
    weight^(−1/3) in birth date (second order) and weight^(−1/6) in time. So
    nodes answer to weight, and steps hardly do.
- **R8: diagnosed.** Every run reports:
  - its error estimate;
  - its θ's distance from the grid's θ₀ against the radius (the radius is
    unmeasured);
  - its failures.

  `diagnose_scm` does this today, at about 0.75 of a run extra.
- **R9: scope.** The birth-date coordinate, which the user decided D applies to
  for every strategy: TF24 first, FF16 and K93 on the same code. The bank is
  constant, wet, episodic, dry and long drought. The height coordinate keeps
  `refine_schedule` and must not break.
- **R10: names a reader can reason with.** The object the counts and the canopy
  integrate over (the birth-date interval between two introductions) has no
  type or name. "Crown spread", `mom` and "pilot" were each hard to read
  (the user). Every new noun must earn its place; none may be a metaphor.

*Challenged upward:* none yet. The proposals may raise some.

Scarce resource: sealed until the judge has derived it.
