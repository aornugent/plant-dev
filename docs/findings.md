# What the trusting-curie measurements found

**Status.** The measured facts the docs here rest on and do not restate: the regnans roadtest's
E1–E8, which `schedule/refine.md`, `schedule/rows-entries.md` and both review notes cite, and a
few numbers later work will need. Everything else the branch measured stays with its source on
the tag, chiefly: the headline timings and waterfall (`report/deck.tex`), measured with parts since
dropped; the 5-year diagnostics and what the 40-year runs overturned (`measurements/README.md`);
soil stepped alone, replaced by plant#115's substeps (`measurements/soil-alone/`); and schedules
held across θ on an old build (`measurements/perf-across-theta.md`). Every claim is *measured*
unless marked *derived* or *estimated*.

**Sources.** Paths like `measurements/...` are on the tag `archive/trusting-curie`, under `docs/`:
<https://github.com/aornugent/plant-dev/tree/archive/trusting-curie/docs>. Dates are each
source's last commit there. `schedule/...` and `review/...` are in this repository's `docs/`.

**Numbering.** E1–E8 are the roadtest's experiments. `schedule/refine.md`'s "evidence E1, R4, …"
are a different set, `measurements/schedule-search/rootcause/evidence/`, and its tuned schedule
is T0.

**The fixture,** unless stated: TF24, one species at `lma = 0.32`, a 40-year patch, the
long-drought record (seed 31), birth-date coordinate. Costs are in *forwards*, one plain forward
run on the same grid and tolerance.

**ε.** ε_q is a tenth of quantity q's standard deviation across eight long-drought rainfall
seeds, never under 0.01 (`measurements/eps-spread.md`, 2026-10-03; values in
`../harness/schedule/data/eps.csv`). For `ln J` it is 0.0252. For the invader's `lma` elasticity
it is 0.198, the "ε ≈ 0.20" of the roadtest.

## E1–E8: the regnans roadtest's root-cause experiments

In `measurements/regnans-roadtest/rootcause/`: scripts `e1_tol.R` … `e8_cliff.R`, numbers in
`results.txt`, reading in `README.md` (2026-10-21). All ran on long drought at its b* = 4.676, on
uniform introductions, with relative tolerance 1e-4 and absolute 1e-8 unless stated.

| | What was measured | Headline |
|---|---|---|
| **E1** | A forward on 201 introductions: absolute tolerance, step cap | 77 s, 8549 steps. At absolute tolerance 1e-4: 48 s, 5157 steps, and `ln J` moves 0.02ε. The 15-day cap binds on 0.04% of steps, and removing it changes nothing |
| **E2** | Node count 54/108/201/402: `ln J`, the invader's `d ln R′/d ln lma`, and `ln R′` at lma × 0.95 | The invader's gradient converges more slowly than `ln J`. At 108 it is 5.4ε off while `ln J` is 0.3ε off; at 201 they are 0.19ε and 0.01ε. Steps grow only 8223 → 9024 from 108 to 402, so cost is about linear in introductions. Three invaders cost 1.9× one resident (148 s against 77 s) |
| **E3** | The invader's gradient at θ′ = θ, three ways (201) | Sweep and tangent give −23.78595, and two invaders at e^{±0.001} give −23.78594. In forwards: invader plus sweep 0.64 + 2.05, invader plus tangent 0.64 + 1.31, two invaders 1.24 |
| **E4** | Other climates on 201 even introductions | Seasonal takes 8691 steps. Constant takes 3221 steps (median step 3.3 d against 1.1–1.2 d with daily rain), but its J is 2.8e-10: even spacing misses its short establishment window |
| **E5** | The selection gradient g against ln b, at ln b* ± 0.03 and ± 0.1 | dg/d ln b = −5.99 and dF/d ln b = −1.75, with F = ln J − ln b. g's error is 3.4·\|F\|, so \|F\| < 0.06 holds g within ε. At the resident's traits ln R′ = F to every digit printed |
| **E6** | E2's ladder (108/201/402) at absolute tolerance 1e-4 | The same convergence. At 201, g = −23.763 against −23.753 at 402, and the resident run takes 52 s against 77 s |
| **E7** | Cost per pass, 201 introductions, 51 trait columns | Against a plain forward: recorded 0.99, resident sweep 2.14, invader 0.61, invader sweep 1.94, two-invader difference 1.21. At absolute tolerance 1e-4 the plain forward is 49 s and the ratios barely move (2.13, 1.90). F_θ along the trade-off is −5.91 |
| **E8** | Constant rain's jump, b* = 45.06, rebuilt 257-introduction schedule: offspring by introduction for invaders at lma × (1 − 1e-4, 1, 1 + 1e-4) | ln R′ = +2.44, −1.5e-6 and −5.60. The change sits in introduction 1 (birth date 0): its offspring per seed go 1.9e5 / 1.6e4 / 60. One founding cohort wins or loses the canopy |

**E8's cause is not confirmed.** The roadtest's candidates were a real priority effect, a jump in
the leaf model, and crowns tying in the light field. The tie-density reading
(`review/eeo-derivatives.md` §4) is *derived*, not tested. The constant climate's b* also moved
from 24.5 to 45.1 when its schedule was rebuilt.

## What a sweep costs, and how it could cost half

- **A sweep costs 1.9–2.9 forwards.** Latest: 2.14 for the resident and 1.94 for the invader
  (E7). Earlier builds and tolerances gave 2.5–2.9 (`measurements/perf-adjoint.md`, 2026-09-24;
  `perf-sweep.md`, 2026-10-05). Its cost is flat in the number of introductions.
- **Why.** It makes 0.83 as many member evaluations per row as a forward, and each costs 3.26×
  as much (43.0 µs against 13.2 µs). Of the 43 µs, 32.2 µs is taping the member at its recorded
  point; the implicit-function solves are 37% of the sweep's instructions
  (`measurements/perf-sweep.md`).
- **Three changes would take 47–51%:** insertion rows that do not split the descent (−19%), the
  crown's light quadrature off the tape (−20–24%), and the collar's slope stored (−8.5%). None is
  built (`perf-sweep.md` §4). If the envelope result holds (`review/theory.md` C.4, *derived*),
  an invader sweep could skip the implicit-function solves as well.
- **Recording is free in CPU, not in memory.** A recorded forward costs 0.96–0.99× a plain one.
  Memory is 184–198 bytes per live node per step: a peak of 297 MiB at 108 introductions and
  1423 MiB at 857, against 155 MiB unrecorded (`perf-adjoint.md`). A site table keeps one
  recording per row.
- **Invaders share no work.** Nine walked together cost nine times one (818 s against 92 s), and
  five cost 5.0 walks (roadtest §2; `measurements/equilibrium.md`). Entries are 92% of a site
  table's cost (`schedule/rows-entries.md`), so whether one run can carry many strategies is the
  table's largest lever (`review/site-selection.md` §6).

## Balancing b

Every row of a site table, and every step of the old loop, balances F = ln J − ln b first.
- **A secant in ln b finds b* in 6 runs,** from b = 1 to |F| = 5.4e-8 (b* = 4.659 at 108
  introductions). regnans's nleqslv and dfsane take 12 each; iterating b ← J(b) contracts by
  0.76 a run, about 47 runs to 1e-5 (`measurements/equilibrium.md`, 2026-10-05).
- **The slope.** d ln J/d ln b = −0.75 to −0.76 at b*, so ∂F/∂ ln b = −1.75 (E5). The secant
  through the last two runs matches the sweep's column: −0.7457 against −0.7525 (roadtest §3).
- **The implicit-function warm start lands next to the curve.** Moving lma 1% with ln b moved by
  d ln b*/d ln lma leaves |F| = 0.0025, against 0.10 with b held (`equilibrium.md`). On the
  roadtest's step uphill it predicted b* = 5.56 against a true 5.48, leaving |F| = 0.026, which
  keeps g within 0.4ε by E5 (roadtest §7).
- **A pinned replay costs 0.82 of the adaptive forward** and reproduces J to 12 digits
  (`equilibrium.md`).
- **Two near-identical species make the community's Newton ill-posed.** Undamped, it sent a
  birth rate to 1e74. One equilibrium and one invasion settle it instead
  (`measurements/regnans-smoke/README.md`, 2026-10-20). Rows with several residents
  (`rows-entries.md`, V5) will meet this.

## Where TF24 is not smooth

- **26 non-smooth points:** 3 jumps, 13 kinks, 4 C1 and 6 narrow but smooth
  (`measurements/kinks/inventory.md`, 2026-10-16). Two were handled: net production's sign change,
  by the split, and the rain's knots, by ending steps there. With the splits dropped, only the
  knots are (now by the soil's substeps). The leaf's switch between interior optimum and
  boundary makes 14 728 sign changes in 234 of 4786 steps on dry; it is the tolerance error's D1
  (`schedule/time-axis.md`).
- **Constant rain has no gradient at the resident** (E8). ln R′ is +8.78, +7.40, 0, −39.85 and
  −44.95 at lma × 0.85, 0.95, 1, 1.05 and 1.2; central differences give −40 197 at h = 1e-4 and
  −8 161 at h = 1e-3, and the sweep −6.3 million (roadtest §8).

## Adjoint rows

Keeping the costate at every row costs +1.3–1.4% of a sweep and +35 MB, and is bit-identical when
off. The invader's mortality identity holds to 7.6e-14, and the sum rule reproduces the gradient
to a median 0.26–0.78%. It is a spike, not built (`measurements/adjoint-rows/README.md`,
2026-10-21). It is what attribution of selection by birth date, patch age and state needs
(`review/theory.md` B.5).
