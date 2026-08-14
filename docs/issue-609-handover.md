# #609, at handover: what is measured, what is not, and the one experiment left

The charge/drain form and its bounds are done and validated. **The cost is now
understood and is answered in `storage-lower-bound-design.md`**; what is kept here
is the measurement record and the four corrections, because the mechanism was
misdiagnosed three times from a proxy rather than a measurement and the corrections
should not be inherited a fourth time.

## Established, and reproducible

Fixture unless stated: one species, `lma = 0.0825`, `birth_rate = 1.10`,
`max_patch_lifetime = 10`, `node_density_in_birth_date = TRUE`, schedule refined
once. Built at `-O2` against odelia `f6638de` and phylloptim `a17dd69` (see
*Pinned dependencies*).

**The rate.** `dS/dt = charge·(1−r) − drain·r/(r + drain_ref)` with
`charge = Ppos(1−G)`, `drain = Ppos − P`, `drain_ref = 1e-3`. The split is exact:
`charge − drain = P − Ppos·G`, the old net flux.

**The upper bound is fixed.** At 105.32 yr the fraction of cohorts at `r > 0.99`
falls **0.527 → 0.000**, median `r` **1.000 → 0.858**, and the state's worst
excursion above capacity **1.035 → 0.862**. Nothing reaches capacity at any
lifetime from 2 to 105.32. The mechanism is `(1−r)` going negative past capacity,
i.e. a restoring term — which is why capping `r` *destroys* this bound.

**The kink is removed, and was real.** On the old rate `d(dS/dt)/dP` stepped by
`(r + drain_ref)/r` across the sign change of the net flux: measured **1.972**
against a predicted 2.000 at `r = 1e-3`, unbounded as the pool empties.

**Negative storage is unreachable.** With `odelia::util::stop_domain` in the rate
and `Patch::ode_state_valid`, crossings go **3.02% → 0.000** of records and the
worst value **−7.13e-2 → +4.2e-14** of capacity. Committed states rest *on* the
boundary from above.

**Gradients are unaffected.** Full trajectory ladder 8/8 files, 278 assertions,
0 failures; fast tier 142 assertions, 0 failures; block Jacobian forward against
reverse **2.40e-16**; all 17 injected corruptions still detected.

**The cost.** Accepted ODE steps **941 → 12,866** (13.7×), wall **8 s → 116 s**,
time per accepted step unchanged (8.5 ms → 9.0 ms). So there is no per-step
overhead: the system became stiffer.

## Corrections to earlier readings, so they are not inherited

1. **`min(r,1)` is not load-bearing for the height coordinate.** It appeared to be
   because removing `max(S,0)` exposed a **pole at `r = −drain_ref`** in the drain
   limiter, and RK *stages* evaluate at states the solver has not accepted. With
   the refusal in place both coordinates run clean with no clamp at all.
2. **The cost is not rejection chatter.** Damping `step_size_last` after a domain
   rejection (odelia `975ce4b`) buys **12–14%**: 127 → 109 s. Committed states
   never violate, so rejections are rare.
3. **The cost is not `min(r,1)`'s removal.** The build with `min(r,1)` restored
   still ran **128 s** against a 9 s baseline. The lever is `max(S,0)`.
4. **A tolerance on the refusal does not help.** `storage_domain_tol = 1e-8` of
   capacity on the throw: 116 s. The stage refusals are not the cost either.

Two instrument errors caused most of this. `length(unique(out$species$time))`
is the *collection* grid (the node schedule, constant at 94) and was mistaken for
a step count; and `max r` was read off a build whose rate contained the pole, so
an apparent broken upper bound was self-inflicted.

## The cost — answered, in `storage-lower-bound-design.md`

The hypothesis below was right about the layer and wrong about whose dynamics it
is. **Measured:** the rate's eigenvalue is `drain/(S_max · drain_ref)`, so the
knee at `r ≈ drain_ref` is an *attracting fixed point* with a relaxation time of
`S_max · drain_ref / drain` — **0.64 hours** at the stiffest record, against 18.9
hours for the shipped form's worst. Both forms have that knee; the shipped one
falls through it into the region where `max(S,0)` makes the rate identically
zero, so it never resolves it.

The stiffest record is a **0.41 m seedling**, not a large plant in drought, and
its production is `−1.66e-5` kg/yr while `Ppos` is `+4.24e-5` — so the fixed point
is held up partly by carbon `storage_prod_eps` invented.

Two things this settles beyond the cost. **#610's rung 2 cannot help**: an
eigenvalue at a fixed point is a property of the vector field and not of the
chart, so `S = w²` and `log S` leave it where it is. And the way out is to stop
treating the drain limiter as a mollifier: `drain · r` mirrors the fill limiter,
deletes `drain_ref`, and measures **2.55× less stiff than the shipped form's own
worst**. The design document carries the ledger, the candidates and the pricing.

*(Kept for the record: the original hypothesis said the 13.7× would be "the honest
cost of the model's own dynamics". It is not — it is the cost of resolving a
mollifier's width, and the mollifier had no scale anyone had chosen against a
plant.)*

## State of the work

Nothing is pushed. Nothing is submitted.

| branch | base | contents |
|---|---|---|
| `PLANT-609` | `ad/v3-forward` | `95e3ab64` split, `90ea565b` limiters on; rung 3 uncommitted in the worktree |
| `PLANT-609-develop` | `develop` | `67f9d306` rung 1 ported, `TF24@v9`, NEWS; rung 3 uncommitted |
| `PLANT-609-base` | `90ea565b` | timing baseline only, no changes |
| `ODELIA-55-damp` | odelia `master` | `975ce4b` the damping |
| `ODELIA-55-damp-ad` | odelia `f6638de` | `bfa9f15` same patch on the AD line |

Worktrees under `plant/.claude/worktrees/` and `$CLAUDE_JOB_DIR/tmp`.

## Pinned dependencies, and two blockers that are not #609

The installed `phylloptim` and `odelia` were changed mid-session by another
session, so builds used private libraries under `$CLAUDE_JOB_DIR/tmp/rlib-phyl`:
odelia from the AD line, phylloptim at `a17dd69`.

- **The phylloptim submodule pointer is ahead of plant.** `50840b0` merged
  upstream master, bringing `26574f4` which gave `Leaf::set_traits` a 14th
  argument (`R_d_25`); `tf24_strategy.h` still passes 13. `ad/v3-forward` does not
  compile against the phylloptim it points at. `a17dd69` is the last commit with
  the wired derivatives *and* 13 arguments. Own issue, not #609, and it does not
  touch the develop-targeted PR — phylloptim is a package dependency there, not a
  submodule, and the port builds against the installed 0.2.1.
- **~~`develop` cannot take rung 3.~~ Withdrawn: it can, and does.** The 68
  errors were the wrong odelia. **Upstream `v0.3.1` keeps
  `typedef std::vector<double>::iterator iterator` in `namespace ode` and has
  `util::stop_domain`**; the *AD-line* odelia that also calls itself 0.3.1 — and
  which is what is installed in the default library here — removed the typedef.
  Built against upstream `v0.3.1` in a private library, `PLANT-609-develop`
  compiles clean with the refusal in place: **0 errors**. The DESCRIPTION's
  `odelia (>= 0.3.1)` / `traitecoevo/odelia@v0.3.1` is right as written.
- **And there is no odelia PR to pair with.** odelia#55 is already merged
  upstream as `880a1c2`, "Reject steps that leave a system's state domain (#56)",
  released in 0.3.0. Only the step-damping patch on `ODELIA-55-damp` is unlanded,
  and it was worth 12–14 per cent when rejections were frequent; with the
  proportional drain limiter they are not, so it has no consumer.

## Not addressed, measured

`storage_prod_eps` is absolute (1e-4 kg/yr) against a **seed capacity of 4.80e-7
kg** — 208× a seedling's whole pool per year, and 0.32 of its actual net
production; every plant under 1.20 m has a capacity below `eps · 1 yr`. #609
predicted this and asked for it to be checked against a real germination state
before acting. It has been. Changing it moves establishment and wants its own
re-blessing.

Also unaddressed: carbon is not conserved across the block. The pool is capped by
withholding the surplus rather than spending it, so at capacity `Ppos(1−G)`, about
1.2e-4 of production, leaves the budget. Routing it into growth would conserve and
is a larger modelling change than #609 proposes.
