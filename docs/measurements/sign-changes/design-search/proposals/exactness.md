# Proposal: weaken exactness — correct the kink's leading error from what the step already rated

## Triage: 3 — it spans odelia's step, sweep and recording and plant's System; the incumbent (odelia +1117, plant +605) failed review on its orchestration.

## Requirements ledger
R1–R13 as in the ledger, unchanged. No requirement is weakened under the default answers. What the move weakens is a mechanism: the order restored at a crossing goes from full to the leading term.
- *Challenge to R7, upward:* this design also corrects invader walks, which gives J′ = J to the last bit; the incumbent's unsplit walk misses it by about 1e-5 in ln J. Is treating invaders' own crossings wanted? Default: yes.

Scarce resource: ratings on crossing steps. 9247 crossing node-steps fall in 726 of 14 840 steps (ledger; 714 steps in my replay). One extra whole-patch rating on each of those steps costs 0.9% of a forward (726 of about 80k evaluations), and every sweep and walk pays it again. So the treatment must work from what the step has already rated.

## The floor
Plain Cash–Karp at 1e-4. It fails R1: the nudge moves are d_I 1.261 and a_dG1 1.048, against a bar of 1 (in ε/3). It fails R2: 0.56ε at r = 1e-2, against ε/3.

## Candidates (all under "weaken exactness")
In the toy, the leading-order model h·B·K explains plain's local error at crossings to within 5.3% (storage) and 1.6% (height). Here K is the positive part's quadrature error along the true path and B is the rates' slope in the positive part. So full order buys at most about 5%, and only K has to be estimated.

| variant | K error vs truth | e1 range, 7 nudges (plain 6.2e-3) | extra ratings per corrected step |
|---|---|---|---|
| A [first thought] quartic through the stages and the end | 21% (43% on steps > 4 d, bias +18%) | 8.0e-4; J +1.4e-3 at 1e-3 | 1 |
| B the archive's KINK_FIX (slope from the bracketing stages) | 18% | 7.4e-4, but ln J jumps (third differences 7.3e-6 against R3's 1e-8) | 1 |
| C cubic through two dense-output ratings | 1.2% | 1.9e-4 | 3 |
| **D derivative of the dense output** | **3.4%; TF24 11%** | **1.7e-4** (split-like reference 2.3e-4) | **1** |

Winner: D. Eliminations:
- A biases J worse than plain at loose tol (R5), because explicit stages undershoot a draining soil.
- B fails R3. Its jumps also explain why M2 halved one trait's spread and left the other.
- C costs three times D's ratings for no measured gain (R8).

D beats the floor on R1 and R2: the toy's nudge range is 37× narrower than plain's. It costs +0.9% of a forward and +0.8% of a sweep (counted), against the incumbent's +6.0% and +7.3%.

Does this lead back to the incumbent's per-node cut? No. Nothing is located, cut or re-integrated, because the leading term is closed-form in data the step already holds.

## The commitment
A sign change is treated from what the step has already rated: each node's net production at its six stages and at its end.
Kept true by: `positive_part_errors` takes those seven values and the width, and nothing else, so it cannot rate, locate or read a field. The forward and the sweep call the same templated code inside `Step`.

## Kill question
Assumption whose falsity makes this unnecessary: that the spread at 1e-4 is the kinks', and so removable at crossings.
Verdict: survives. The kink is 70–85% of the spread, and the incumbent's cut reduces the standard deviation 3.4–6.4× (§11).
On sufficiency: at crossings hL ≈ 0.08 for a draining pool and up to 0.19 for a filling one (τ_s = 7 days, rate up to 2.3/τ_s; the median crossing step is 0.57 days). On TF24, D's K is off by 11% rms inside J's window (t < 29.3), 11.4% weighted by J's remaining share, with a median of 0.12%.

## What survives deletion
- `positive_part_errors` (odelia) → R1, R2, R3, R4.
- `ReadsPositivePart` (odelia concept): `sign_values`, `positive_part_width`, `add_positive_part_errors` → R12, R10.
- `solved_row::end_before_correction` (optional): the sweep tapes the end's P there, and walks rate there in the resident's field → R4, R7.
- `corrected_steps` (odelia), shown in plant as `SCM$ode_corrected_steps` → R11.
- `TF24_Strategy::positive_part_slopes` → R1. Storage's slope is not readable from its rate.
- `Patch::add_positive_part_errors`, `Patch::positive_part_width` → R12.
- `ode_correct_positive_part` (plant control) → R10.

Deleted: `RatesParts`, `SplitsSignChanges`, `part_split`, `part_width`, `part_reads`, `part_rates`, `dense_state`, `reads_at`, `integrate_pieces`, `taped_split`, `field_recorded`, `ode_splits`, `ode_split_record`.

## What this settles
- No cut moves with θ. That removes the regula falsi, the golden search, the cuts' implicit nodes, and the held stage times (1.17e-5 of d J/d lma).
- No node is rated apart from the patch. That removes the five-fraction reads and the quartic field.
- No choice can jump on a frozen mesh. The map is C∞ in the stage values, and K → 0 continuously at passages and as a pair merges. In the toy, ln J's residual is 1.2e-8 and the chord equals the second difference (−7.8761 both).
- The sweep has no split-specific tape, and its derivative is the run's own.
- Walks need no field at unrecorded times, so invaders are corrected too.

## What this makes hard
- **Saturating pulse onsets.** Where P swings by 100 kg/yr or more and flattens within a step, the cubic misses about half of K. One such onset (t = 35.4, 50 nodes) carries 70% of TF24's squared K error, and 80% of the worst 200 node-steps fall after J's window. If forced: two dense-output ratings per corrected step (C: K to 1.2%, +1.8% of a forward).
- **Pairs inside a step** (13 node-steps a run): K is off 165%, but the error is smooth and not a jump.
- **Coverage.** Rates must read P through σ. The height coordinate's density reads σ′, which jumps at a crossing, so only the birth-date coordinate is covered.
- **Slope maintenance.** `positive_part_slopes` must track the rates. A missing component is silently uncorrected; the guard is a unit test against a fine step.
- **Near-empty pools.** A correction can push one below zero. A forward retries; a pinned walk fails (R6), as plain does.

## Kill condition
- P read other than through the smooth positive part.
- A σ-reading component that is fast (hL ≈ 1 at crossings).
- Steps at crossings too long for a cubic (rule A's late 15-day steps).

In those cases, go to C, then to the incumbent's per-node pieces.

## The design
**odelia.**
- The step keeps each stage's sign values. After an accepted or pinned step, it forms for each node P̂(u) = Σᵢ wᵢ′(u)·Pᵢ over the six stages and the end, where w is Cash–Karp's C¹ fourth-order dense output. This is the cubic through both ends whose integral is the step's own sum.
- K = ∫₀¹ σ(P̂) − Σ bᵢ σ(Pᵢ), taken as zero where P̂ keeps one sign. The integral is split at P̂'s roots (passive) and taken by Gauss–Legendre.
- If any K ≠ 0: `add_positive_part_errors(h·K, y)`, keep the end's solved values in `end_before_correction`, and rate y again.
- The sweep tapes, on such rows, the end rating, K and the addition.
- Walks run the same hook: the first end rating in the resident's field from before its correction, the second in its field after.

**plant.**
- TF24 gives the slopes at P = 0 for height, fecundity and storage; the node adds offspring.
- The Patch adds h·K × slopes from its internals at the uncorrected end (toy residual 3.1%, against 2.2% at the start).
- Off, nothing is reported, and runs repeat bit for bit.

**Size.** odelia about +150 lines (+100 tests), plant about +100 (+50 tests). It deletes about 1.4k of the incumbent's 1.7k lines.

**First build gate:** TF24's seven-nudge test at 1e-4 (R1), the curvature at r = 1e-2 (R2), and J′ = J on the diagonal. The inferred d_I is 0.25–0.39 ε/3.

## Spike files (`spikes/exactness/`)
- `toy.R`: soil plus 8 nodes, TF24's σ, pool and gate; κ median about 4000; methods plain, smooth, endpoint, bracket, dense2, slope, split.
- `model_check.R/.log`: −h·B·K_true explains plain's local error to within 5.3% (storage) and 1.6% (height). Stage-quartic K is off 43% on long steps.
- `local*.R/.log`: gradient residual of single crossing steps relative to plain: slope 2–6%, split 5%, bracket 7–8%, endpoint 10–11%. Slopes read at the start 2.2%, end 3.1%, mean 2.3%.
- `kvariants2.R`, `kslope.R`: K error 3.4% (slope), 1.2% (dense2), 20% (one dense rating), 21% (stage quartic).
- `exp1*.R`, `summary.log`: e1 range under seven nudges: plain 6.2e-3, bracket 7.4e-4, endpoint 8.0e-4, dense2 1.9e-4, slope 1.7e-4, split 2.3e-4.
- `exp3*.log`: J error at 1e-4: plain −1.3e-4, slope −1.9e-6, split +3.3e-5. All arms meet a shared 1e-5 at 1e-5.
- `exp2.R`, `scan_stats.log`: on a frozen mesh, ln J's residual is 1.2e-8 (slope) against 4.5e-7 (plain) and 1.1e-6 with jumps (bracket).
- `tf24_K.R`, `tf24_*.log`: TF24 replay of the plain program (lib_rr). 714 crossing steps. K error 11% in J's window, median 0.12%. Stage values deviate from the dense output by under 0.2% of P's swing. Caveat: this replay ran on the height coordinate, with pools clamped on 8512 stage evaluations.
- `slope_plus.R/.log`: fitting extra shapes to the stage values worsens K, to 37%.
