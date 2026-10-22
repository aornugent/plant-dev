# Assembly on 16 cores

**Status.** A survey of parallelism, recursion, greedy steps, warm starts, approximation and
caching across the assembly workflow of `assembly-report.md`. Where the example could test an
idea it was tested (`spikes/assembly-example/assembly.R`, options of `lean()`); the rest are
*estimated* for TF24.

**The wall-time model** (`machine` in the script):
- a resident run of m species, with its sweeps, takes 2m + 2 F and is sequential;
- an invader gradient takes 2.5 F;
- invader work in one batch runs in waves of 16;
- pricing takes the longer of its total work over 16 cores and its deepest single ascent.

The units follow TF24's measured costs, so the example's counts become wall-time estimates.

## 1. Where the time goes

Wall time at 16 cores, for d = 3 (three species, k = 50):

| Configuration | Resident runs | Wall | of which resident runs | pricing | probes |
|---|---|---|---|---|---|
| full curvature every pass | 27 | 1,061 F | 156 | 450 | 455 |
| directional curvature | 44 | 872 F | 284 | 450 | 138 |
| + speculative step lengths | 52 | 734 F | 192 | 450 | 92 |
| **+ warm pricing starts** | 52 | **647 F** | 192 | 362 | 92 |
| + sign-stopped pricing | 70 | 782 F | 270 | 320 | 192 |

d = 2 runs the same way: 489 → 343 F.

**The critical path is pricing,** not the residents. Pricing is about half the wall time,
set by the deepest BFGS ascent, while the resident chain is under a third. That decides which
opportunities pay.

## 2. What was measured

| Opportunity | Kind | Result | Use it? |
|---|---|---|---|
| Directional curvature: one full probe a round, then d + 1 probes along the last step and the best-response shifts | caching, approximate | wall 1,061 → 872 F, CPU −37%, but 27 → 44 resident runs | yes when tracked × k exceeds the cores; full probes win again at 64 cores (466 against 576 F) |
| Speculative step lengths: resident runs at four trust factors side by side, keeping the best; the chosen run becomes the next pass's recording | parallel | resident chain 284 → 192 F; total 872 → 734 F; no gain at d = 2 | yes |
| Warm pricing starts: either side of each resident along its most disruptive direction, plus 5 grid points instead of 13 | warm start, greedy | pricing 450 → 362 F | yes |
| Warm start from a neighbouring problem's community | warm start | K → (1.8, 1.6, 1.2): 36 → 7 runs, 1,399 → 341 F; σ 0.22 → 0.26: 23 → 10 runs | yes, as the default (next row) |
| The same, where the cold start fails | continuation | σ = 0.23: cold start diverged (903 runs, 5 spurious species); warm start took 5 runs | yes: continuation is globalisation, not only speed |
| Newton in pricing (full curvature each ascent step) | — | 3× worse in CPU and wall | no; BFGS seeded by one probe |
| Sign-stopped pricing: stop an ascent once its peak's sign is settled | approximate | pricing −42 F, but entrants arrive loosely placed and the master's sequential chain grows 192 → 270 F | no |
| The final pricing round as the certificate | caching | removes one whole pricing pass per assembly; it was double-counted before | done |

**One rule covers the sign-stop result:** don't approximate parallel work if that moves work
onto the sequential chain.

## 3. What remains, estimated for TF24

**Off the critical path, so wall time falls:**
1. **Overlap pricing with the master's passes.** During a resident run, 15 cores sit idle.
   Pricing in the current field can start once the master is near its root (|F| < 1e-2), so
   the next round's candidates are ready when it converges. It hides up to the resident
   chain's length of pricing: about 190 F of 647 on the example. Candidates found in a
   slightly stale field are tracked and corrected by the master anyway.
2. **Climate records in parallel.** Under independent records per patch (`workflows.md`,
   structure B), fitness is an average over records, each its own resident run. Up to 16
   records cost the wall time of one, so climate structure is nearly free in wall time.
3. **Sites and rows in parallel, warm-started as a wavefront.** Assemble 16 sites at once,
   each starting from the nearest solved neighbour in climate space. The root's adjoint
   (`assembly.md` §5) gives a first-order predictor dx*/dp for the community, which should
   bring a neighbour to 2–3 passes. The example's warm starts, without a predictor, took
   5–10 runs.

**Shortening the sequential chain:**

4. **Vector-mode sweeps.** The kept, mode and cut seeds go in one reverse pass with vector
   adjoints, the cut lane zeroed at the marks. That turns d′ + 2 sweeps into about one, saving
   1–2 F per pass, about 25% of a resident pass at m = 3. XAD has vector adjoint modes; odelia
   would need the cut zeroing per lane.
5. **Multilevel schedules.** Converge on a coarse node schedule, then finish with 1–3 Newton
   passes on the certified one. This is the scheduler's nested density used as a multigrid
   ladder. If a coarse run costs a quarter of F, the resident chain falls about 3×. The
   residual is exact at each level, so the answer is the fine schedule's.
6. **Speculative active sets.** Where the complementarity problem churns (passes 3–5 of the
   d = 3 example), run resident runs for the alternative supports side by side and keep the
   best, alongside the speculative step lengths.

**CPU only, wall unchanged at 16 cores:**

7. **Forward-over-reverse Hessian–vector products.** All d + 1 probe directions in one
   invader pass with vector tangents, instead of d + 1 invader gradients: probe CPU falls by
   about (d + 1)×. At 16 cores the probes are already one wave.
8. **Carried BFGS state.** Each tracked candidate keeps its BFGS matrix across rounds, and
   the master's directional curvature seeds the next round's pricing ascents.

**Recursion and greedy steps:**

9. **Continuation as the default route.** Begin where the answer is easy, for example a
   field so broad that one generalist is the ESS, and step the parameter toward the target,
   pricing at each step. Communities appear as branching points are crossed, each step
   warm-started. Measured above, continuation is what rescued σ = 0.23.
10. **The traits split, recursively.** Assembly works in the d separating directions; the
    k − d traits that follow from niche position are each species' best response in a held
    field, solved in parallel. This is already how the step is built (§5 of the report);
    pricing starts can be placed along the separating directions only.

## 4. A configuration for 16 cores

- **Probes:** directional, with one full probe a round.
- **Resident runs:** speculative step lengths, the chosen run reused as the next recording.
- **Pricing:** BFGS seeded by one probe, from warm starts, overlapped with the master once
  it is near its root.
- **Sweeps:** vector-mode, one reverse pass for every seed.
- **Schedules:** coarse, then the certified schedule for the last passes.
- **Across problems:** continuation by default, with sites in parallel as a wavefront and
  the adjoint predictor.

Measured on the example, the first three bring d = 3 from 1,061 to 647 F of wall time. Items
1, 4 and 5 are estimated to take a further third to half off on TF24. A neighbouring site from
a warm start is 300–400 F on the example (5–7 runs), less with the predictor.
