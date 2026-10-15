# Held ends at θ′: does a stop end left at θ₀'s zero cost the gradient more than 0.006?

judge.md §5's decisive measurement. The stopped dry run `JT8_ins_3e-4_stop` (libJTstop,
inset schedule, tol 3e-4, JT_STOP=1) has step ends at the first and last f_hi zero of each
switch cluster. At θ′ = TF24_cost_scale × 1.01 the clusters move ≈ 0.28 d (P2's spike), so
held ends no longer sit on θ′'s zeros. Scripts here; runs under
`scratchpad/deep/held-ends/`.

## Protocol (registered before any run)

**Runs** (all libJTstop, adj_run.R at JT8's settings: dry seed 31, tol 3e-4, atol 1e-4,
soil factor 10, rule-A window weights, factor max 100, h ≤ 15 d, share 0.1, split on):
- `D1`: detection-only forward at θ′ (TRAIT_REL=TF24_cost_scale=0.01, JT_STOP=0,
  JT_STOP_LOG=1), its own steps: θ′'s f_hi roots.
- `R0`: JT8's rows pinned at θ₀ plus sweep. Check only: reproduces JT8's stored J and
  elasticities exactly.
- `H1`: JT8's rows pinned at θ′, held, plus sweep.
- `M1`: the same rows with each stop end moved to θ′'s root (below), at θ′, plus sweep.
- `M1b`: as M1 with the soil substep record blanked on every row whose span changed
  (mkstops.R's rule). Bounds the record confound in M1.

**Which rows are stop ends** (`ends.R`). From JT8's log: a recorded row is a stop end if
it lies within 1e-8 yr of a JTCUT's t0 + u·h and the row before it is that JTCUT's t0
(the retake landed as cut). A logged cut whose retake did not land exactly counts as an
end if a recorded row lies within 1e-3 of its attempted step of the cut point; otherwise
it is held and listed. Cuts of u·h ≤ step_size_min (1e-6 yr) were never taken and are
not ends.

**Where each end moves.** Each end's root set R is the JTROOT roots of the attempted step
that produced its cut (node, direction by the sign of the slope). For each (node,
direction) in R, θ′'s root is the D1 root of that node and direction nearest its θ₀ root,
within 3 d; the end moves to the min of those (a first cut) or the max (a last cut).
An end with no matched root is held (counted). Check: the cutting node's own θ′ root
gives the same target for ≥ 90% of ends.

**New rows** (`mkmoved.R`, mkstops.R's approach). Times = the ordinary rows held, plus
the moved ends. A target within 1e-6 yr of another time is held (counted). Sizes are
recomputed as differences on every row whose previous time changed and kept as recorded
elsewhere. M1: every row keeps its own soil record (input slope, substep fractions), the
moved end its held end's. M1b: those records are blanked on rows whose span changed.
Reported: ends moved, ends whose target crosses a held neighbour (the "stays between
its neighbours" check), |move| median and max.

**Checks.** Each pinned pass takes its program exactly: step count equal to its pin's
and max |time − pinned time| ≤ 1e-10. R0 reproduces JT8.

**Score** (nudge.R's: AG/lib.R's `quantities`, `eps_vec`). d = (H1 − M1) / ε over the
scored quantities (ln J and the elasticities, without S_D, a_f3, recruitment_decay,
rooting_depth_max, establishment_window). Reported: rms over the traits (and over all
quantities, nudge.R's form), max and which, TF24_cost_scale's own d, ln J's d; and
M1 − M1b. If M1 − M1b rms > 0.003 the record treatment is a confound and the verdict
carries that caveat.

**Verdict.** rms ≤ 0.006: held ends serve the 1% chord (the floor stands). > 0.006: they
do not (§6's trigger). If 0.004 ≤ rms ≤ 0.009, repeat everything at × 0.99
(TRAIT_REL=TF24_cost_scale=-0.01): `D2`, `H2`, `M2`.

**Registered predictions.** Orchestrator: rms > 0.006 (55%). Judge: ≈ 0.01 summed over
the ~30 clusters that matter.

**Known before the runs** (from JT8 alone, `ends.R`): 477 of 530 logged cuts landed as
cut (249 first, 228 last; 226 first ends followed directly by their last end); 48 were
under step_size_min. The gaps to the held neighbours are short: median 0.08–0.10 d either
side, against a ≈ 0.28 d shift, so most moved ends are expected to cross a neighbour.
Hence the union rule above rather than mkstops.R's window replacement, and why crossing
is counted rather than excluded: excluding it would hold most of the ends being tested.

## Result (D1, R0, H1, M1, M1b; `score.R`, `mk_M1.out`)

**Checks.** D1 (detection at θ′, 4777 steps) logs 14 618 roots, the same as P2's `cs_up1`.
R0 reproduces JT8 exactly: every quantity's difference is 0. Every pinned pass (R0, H1,
M1, M1b and the diagnostics below) takes 5334 steps, with max |time − pinned time| = 0.

**Ends.** 477 of the 482 cuts taken (u·h > 1e-6 yr) landed exactly as cut: 249 first and
228 last. The other 5 had a retake that did not land and were re-cut on the retried
step, so they are not ends of their own. 457 ends moved. 9 were held because no root
matched, and 11 because of a clash (a target within 1e-6 yr of another time).
|move|: median 0.120 d, 90% 0.477 d, max 1.911 d. Signed median +0.105 d. 150 ends moved
more than 0.25 d. Before b = 25: 339 ends moved, median 0.123 d, max 1.911 d.
**127 of the 457 moved ends cross a held neighbour**, as expected from the 0.08–0.10 d
gaps. Placement noise, from the same matching against θ₀'s own detection roots (S1b):
median 0.000 d, 90% within 0.006 d.

**H1 − M1 (held minus moved, at θ′, in ε): rms over the 45 traits 0.0247 (0.0244 with ln J),
max 0.078 on TF24_cost_scale (−0.0782), ln J +4.9e-4.** **> 0.006 by 4×: held ends do not
serve the 1% chord, so §6's trigger is met.** The orchestrator's prediction (> 0.006,
55%) holds. The judge's ≈ 0.01 was low by about 2.5×. Rms 0.025 is outside 0.004–0.009,
so the × 0.99 repeat was not triggered.

Record confound: M1 − M1b is rms 0.0025 (max 0.013, stem_c). That is under the
registered 0.003, so blanking the soil record on the 655 re-spanned rows changes little,
and H1 − M1b is 0.0242. For scale, the chord itself (R0 → H1) moves the elasticities by
rms 1.76ε. The held-end error is about 1.4% of that change.

## Diagnostics (not registered)

- C0: the ends moved to θ₀'s own detection roots and replayed at θ₀, against R0: rms
  0.0015 (max 0.005). This is placement noise, and it sits 16× below the effect.
- M1c: M1 without the 17 ends whose matching is off by more than 0.05 d at θ₀, and
  without ends moved more than 1.5 d (439 moved). H1 − M1c is rms 0.0247 with
  TF24_cost_scale −0.0785. M1c − M1 is rms 0.0001, so suspect matches carry none of it.
- M1s: only ends within 1 d whose cutting node's own θ′ root equals the set target to
  1e-6 yr (432 moved). This test is too strict: it drops the big clusters' ends, whose
  first node changes by 0.001–0.03 d at θ′ (ends at 7.546, 10.686, 13.660, 21.647, which
  moved 0.6–0.8 d). H1 − M1s is rms 0.011 with TF24_cost_scale −0.002. So about 26 ends
  of the big, far-moving clusters carry TF24_cost_scale's −0.076 and over half the rms.
  The remaining ~430 ends still carry rms 0.011 between them, which alone is above 0.006.
