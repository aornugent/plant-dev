# A canopy that cannot comb

Candidate D of the node rule (`docs/design-grid-controller.md`) spreads each
panel's leaf area over the heights its members span. The field at the layer's
top then no longer depends on the spacing there. Two spikes ran on plant
7dbd87c3 (`PLANT-98`), at `3e-5` under the tied tolerance. The first isolated the
cause on the invader's `lma` elasticity on long drought, seed 31. The second
asked whether spreading is a general node rule, with the spread built on the
active scalar so that the sweeps carry it.

## Verdict

- **The comb is the cause of the invader's reversal on uniform nodes.** With each
  panel spread, the field part of the 108 → 215 move falls from +0.380 to −0.034
  and the interpolation part is unchanged.
- **Spread uniform nodes report their error on long drought.**
  - For all 49 quantities of both roles on seed 31, the median ratio of
    successive moves is 3.6–3.9.
  - The companions are 0.93–1.09 at u215 and u429, against 0.32–0.42 lumped.
  - For the invader's `lma` on seeds 101 and 103, the ratios are 4.11 and 3.89.
- **The rule is to spread every panel, halve uniform nodes, and report the
  extrapolation from two rungs, with the companion as its error.** Spread single
  rungs are coarse: u108 is 0.7–3ε off, and the invader's `lma` 2.05ε, against
  lumped's 0.17ε. Lumped 108 is accurate only because two opposite errors cancel
  there.
- **On wet and dry, lumping shows the field anomaly and spreading removes it.**
  Neither was run to u429, so their ratios are not measured. Episodic has no
  anomaly to remove.
- **On the constant record spreading fails.** Its node error is the founders'
  front, which still needs front nodes.
- **The price:**
  - the per-member-step cost is the same as lumped in forward and invader runs;
  - the resident's sweep ran 2.0×, 1.7× and 3.4× slower at u108, u215 and u429,
    under varying load, and took 2× the memory at u429. That is unexplained.
    The spike's snapshots show the members' heights and the boundary node in
    order, so neither is the cause.

## How the spread is built

- **Lumped, as plant computes it.** On the birth-date path the light field puts
  each panel's whole leaf area at its node's height, as
  `Σ_j w_j n_j k_I LA_j Q(z, h_j)`. This is a fixed 65-knot Hermite in
  `z/h_max`, and crown-mean light is one QK21 rule over `[0, h]`.
- **Spread.** `PLANT_PROBE_SPREAD=8` puts 8 point crowns in each half panel, at
  the members' heights interpolated between neighbouring nodes. Each carries
  both nodes' hat shares there, and the field is a prefix sum of their moments,
  tallest first. The boundary node's half panel is added at the close.
- **The probes:**
  - `probe.diff` and `probe_double.diff` run at double precision only. Their
    switches are the light field's knots, the spread and the time window it
    applies in, and the self-term.
  - `probe_active.diff` builds the spread on the active scalar. Both sweeps
    replay `J` exactly at u108, u215 and u429, with no refusals, and `J` matches
    the double probe to 3–5e-8.
  - With no switch set, the probe library is bit-identical to `lib_guard`.

## The cause

The invader's `lma` elasticity by central differences, one suspect removed per
row. The moves are split by `elasticity_moves`, in units of the elasticity,
whose ε is 0.20; the top means born before 0.5.

| probe | what it removes | u108 | u215 | u429 | 108 → 215 field (top) | interpolation (top) |
|---|---|---|---|---|---|---|
| lumped | nothing | −27.0764 | −26.9774 | −27.0082 | +0.3803 (+0.3008) | −0.2808 (−0.2869) |
| `KNOTS=257` | the light spline's coarseness | −27.0747 | −26.9762 | | +0.3765 (+0.3010) | −0.2777 (−0.2852) |
| crown rule QK61 | the crown's QK21 rule | −27.0997 | −26.9907 | | +0.3827 (+0.2991) | −0.2732 (−0.2788) |
| `TOL=3.15e-5` | the step choices | −27.0737 | −26.9790 | | +0.3778 (+0.2980) | −0.2827 (−0.2875) |
| **`SPREAD=8`** | **the comb** | −26.6328 | −26.9397 | −27.0207 | **−0.0340 (−0.0146)** | −0.2718 (−0.2816) |
| `SPREAD=16` | the spread's resolution | −26.6317 | | | | |
| `SELF=2` | the twin's panel alone spread | −25.7749 | −26.7127 | | −0.6606 (−0.4136) | −0.2766 (−0.2902) |
| `SELF=1` | the twin's panel removed | −21.5623 | −23.4969 | | | |

- *The spread ladder converges on the square law.* Its ratio is 3.79, against
  −3.2 lumped, and its interpolation part falls 4.01×, as lumped. Against the
  graded reference, −27.0432 in central differences, its companion reports 0.99×
  and 1.20× of the error, against lumped's 0.50× and 0.29×.
- *The self-term is part of the comb but not separable.* Removing the twin's
  panel is a first-order change, 27ε at u108. Spreading it alone overshoots,
  since the leaf area at a crown's height belongs to its twin's hat and its
  neighbours' together.
- *The light spline, the crown rule and the steps are ruled out.* Each moves the
  parts by at most 1%. The crown rule is a separate bias of −0.013 to −0.023,
  nearly grid-independent.

**When the error is made.** At u108 with the spread on in one window only, the
windows' shares of the spread's +0.443 are 1% before t = 2, 24% over 2–5, 67%
over 5–10 and 8% after 10. At the top crown, born at 0, u108 against u215:
- *at t = 2.96* the canopy has closed to `A = 0.14`, and neighbouring crowns are
  1.99 and 1.00 top layers apart. The light gradient at u108 is 12.5% too steep,
  1.4% when spread;
- *at t = 5.19,* with `A = 0.81` and 1.35 and 0.65 top layers apart, its light is
  off by 1.2e-2, and by 1.9e-3 when spread;
- *the crown's own panel* supplies 98, 80, 59, 60 and 40% of its light gradient at
  t = 1.5, 3, 5, 8 and 12. After t ≈ 14 the two agree, and the top cohort earns
  its offspring at t = 14–18.

**Why `J` converges anyway.** For `J` the comb is about half the top's field
part, +1.63% falling to +0.73% when spread; the rest is ordinary second-order
error.

## Every quantity, long drought, seed 31

`stand_gradient` on the uniform ladders against the graded G2 and G3
extrapolation, the small four excluded (`runs/q1_ladder_compare.txt`):

| ladder | group | median ratio | below 0 / in 2.5–6, of resolved | median error at 108 / 215 / 429 (ε) | companion at 215 / 429 |
|---|---|---|---|---|---|
| lumped | invader, main | −1.36 | 3 / 1 of 5 | 0.08 / 0.13 / 0.05 | 0.42 / 0.32 |
| lumped | invader, other | −1.44 | 28 / 3 of 35 | 0.09 / 0.21 / 0.10 | 0.38 / 0.33 |
| spread | invader, main | 3.73 | 0 / 6 of 6 | 0.86 / 0.22 / 0.050 | 0.99 / 1.09 |
| spread | invader, other | 3.83 | 1 / 36 of 39 | 1.18 / 0.30 / 0.067 | 0.98 / 1.08 |
| spread | resident, main | 3.88 | 0 / 3 of 3 | 0.70 / 0.18 / 0.044 | 0.94 / 1.03 |
| spread | resident, other | 3.59 | 0 / 13 of 14 | 0.65 / 0.19 / 0.043 | 0.93 / 1.06 |

- *The invader's ratios on the spread ladder:* `lma` 3.86, `a_dG2` 2.64, `hmat`
  4.14, `stem_P50` 3.60, `rho` 4.02, `recruitment_decay` 6.52, `a_y` 4.02, `a_bio`
  4.02, `a_f1` 4.11, `a_l2` 4.06, `theta` 4.15 and `jmax_25` 3.91. `J`'s is 3.34,
  and the resident's `lma` 3.53.
- *Their companions* are 0.67–1.62 at u215 and 0.95–1.21 at u429.
- *One resolved quantity reverses:* the invader's `rooting_depth_max`, at −5.3.
- *The extrapolations:*
  - spread u215 + u429: the invader's median error is 0.009ε (at most 0.020), and
    the estimate covers the error on 29 of 29 quantities. The resident's is
    0.003ε (at most 0.026);
  - spread u108 + u215: the invader's is 0.015ε (at most 0.049), the resident's
    0.021ε (at most 0.13, in `a_dG1`, `root_c` and `root_P50`);
  - lumped u215 + u429: 0.052ε (at most 0.14), covering the error on 0 of 32.

## Other records and seeds

The invader's `lma` by per-node central differences:

| record | top field part 108 → 215, lumped → spread | top interpolation part, lumped / spread | the elasticity's move, lumped / spread |
|---|---|---|---|
| long drought | +0.301 → −0.015 | −0.287 / −0.282 | +0.099 / −0.307 |
| wet | +0.381 → −0.044 | −0.328 / −0.329 | +0.178 / −0.344 |
| dry | +0.115 → +0.037 | −0.226 / −0.231 | −0.075 / −0.182 |
| episodic | +0.027 → +0.017 | −0.034 / −0.036 | +0.011 / −0.009 |

- *The interpolation part does not change on any record.*
- *Spread `J` on wet* extrapolates to 18.486, against the wet graded ladder's
  18.495.
- *On the constant record,* `J` is 1.20 and 200.7 lumped and 1411 and 822 spread
  at u108 and u215, against the converged 289.3.

Two more seeds of long drought, against each seed's spread u215 + u429
extrapolation:

| seed | lumped ratio | lumped companion at 215, 429 | spread ratio | spread companion at 215 | extrapolation, lumped / spread |
|---|---|---|---|---|---|
| 101 | 1.82 | 0.44, 0.85 | 4.11 | 1.03 | −29.904 / −29.908 |
| 103 | its errors change sign (−0.19ε, +0.12ε) | 0.88 at 215 | 3.89 | 0.97 | – / −25.811 |

On both, lumping shows the top's field anomaly (+0.286 and +0.148) and spreading
removes it (−0.010 and +0.018). Seed 103's lumped u429 was not run.

## The trade-off

The invader's `lma` against the reference −27.0432:

| scheme | single rungs: error (member-steps) | two rungs extrapolated: error / companion (member-steps) |
|---|---|---|
| lumped, graded | G1 −0.18ε (1.25e6); G2 −0.044ε (2.56e6) | G1 + G2: 0.002ε / 1.04 (3.81e6) |
| spread, uniform | u108 +2.05ε (0.96e6); u215 +0.52ε (1.97e6) | u108 + u215: 0.006ε / 0.99 (2.93e6) |
| spread, graded | G1 −0.058ε (1.25e6); G2 −0.028ε (2.56e6); G3 −0.011ε (5.26e6) | not measurable |

- *Spread and graded together is the most accurate at low counts.* But its moves,
  0.006 and 0.003, are the size of a tolerance nudge's (0.0016–0.0027). So its
  companion reads 0.36 and 0.53 and its ratio 1.74, set by noise: at G1 it is
  already at the time axis's floor.
- *At about 0.05ε:*
  - spread graded G1 alone costs 1.25e6 member-steps, with no usable error
    estimate;
  - lumped graded G2 costs 2.56e6, with a companion that reports its error;
  - spread uniform u108 + u215 costs 2.93e6 for 0.006ε, also reporting its
    error;
  - lumped uniform gets there by no count up to 429.
- *The three references* (lumped graded, spread uniform, spread graded) agree
  within 0.0045, or 0.02ε.

## What would falsify it

- A record with a first-mover layer whose spread ladder is not near 4 at u429:
  wet, dry and other climates are not run that far.
- More quantities reversing on the spread ladder; `rooting_depth_max` already
  does.
- An extrapolation that fails on a new record. The rule leans on it, since single
  spread rungs are coarse.
- The resident sweep's cost holding in a version built for plant.

## Files

All in `canopy-spread/`, from the spikes' scratch directories as they ran:
- `probe.diff`, `probe_double.diff` and `probe_active.diff`, against 7dbd87c3;
- `scripts/harness/`: the run scripts, `inv_probe.R`, `inv_probe2.R`,
  `run_record_probe.R` and `field_snap2.R`, with the harness copies they source;
- `scripts/`: the analysis (`moves.R`, `node_diff.R`, `j_parts.R`, `companion.R`,
  `top_crown.R`, `field_analysis.R`, `ladder_compare.R`, `pair_scores.R`,
  `seed_companions.R`, `gen_table.R` and `q4_table.R`), the queue runners and
  their job lists, each line a run's settings;
- `runs/` and `logs/`: every run and its log.
