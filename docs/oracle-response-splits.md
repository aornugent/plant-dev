# Oracle response: the splits consultation

One reply, captured verbatim. It answers `oracle-consultation-splits.md` as sent
at `b8ec91f`, before the tightened build's two tests (`grid-dynamics.md` §18,
the fourth and fifth extensions in `measurements/sign-changes/prereg.txt`). The
handover records what it changes, which of its premises the record
contradicts, and which of its predictions are under test.

---

## The verdict

The split is finished. None of the three features is the split's: every variant shares them, none of the cut structure's own changes rose above the noise, and the unsplit run carries the first of them too. What your instrument now resolves is the inner solver and the model's own fine structure at the `ε_P` scale, plus one feature of the recording point itself. In order:

## 1. What makes `J(θ)` rough

**The noise per replay is the inner solver's tolerance stop.** A bracketing root-find that stops on a tolerance is a staircase in its inputs with treads of order the tolerance; you measured it, one ulp in moves `p_j` by 1e-9. A perturbation of 1e-12 in `θ` reaches every input of every solve, re-rolls which tread each of the ~5×10⁶ solves lands on, and the sum would still be ~1e-11 in `ln J` if it entered the rates at 1e-9. It enters at 1e-6: the draw is the small difference `p − φ` (finding 9's mechanism), so a 1e-9 jitter in `p` is a ~1e-6 jitter in the draw; in quiescence the chain is a pure integrator of the draw with no damping until the next pulse; `φ ∝ v^{−6.57}` multiplies it; every member reads `φ`. That chain gives 1e-8 in `ln J`, white in `θ`, present unsplit, and it is why a replay at `θ` itself differs from its forward by 3.6e-9: the replay's `h` is reconstructed from times and differs by ulps. Cheapest test: a chain-alone replay (no solves) nudged by 1e-12 must be smooth to 1e-15; and one Newton polish at the end of each solve (below) must drop the response to a 1e-12 nudge by the square of the tread.

**The slower departure is `P⁺`'s smoothing band sampled at stages.** `P⁺` is `C^∞`, but with curvature `1/(2ε_P) = 5×10³` over a band `|P| < 1e-4`. A stage whose `P` sits in the band contributes `b_i·h·f_{P⁺}·ε_P/2 ≈ 1e-8` more than the kink model would, always of one sign in `P⁺`, and the band is `ε_P/|∂P/∂θ| ≈ 3e-6` wide in `ln θ_A` (your graze gives `∂P/∂ln θ_A ≈ 29`). Some 30–40 stages sit in the band at any `θ`; over an interval of 6.25e-5 they all re-roll. That gives a departure from any smooth fit of a few times 1e-8, with runs of one sign, identical in every variant that evaluates smooth `P⁺` on its pieces, which all of yours do. Test: count stages (global and piece) with `|P| < ε_P` per replay and regress the departure on it; or replay with `ε_P` ×10, declared, and watch the departure scale ×10 in height and width.

**The signed residue below `1e-2` has two candidates, and the data cannot yet separate them.** One is the graze: `θ₀` sits 1e-5 below a `θ_g` where a member holding 3.1% of `J` loses a dip. In the kink limit the model's `J` is `C^{1,1/2}` there, `J ⊃ c(θ_g − θ)₊^{3/2}`, and a second difference straddling it reads `≈ c·u^{−1/2}` with the sign of `c`. The member's share and a dip deepening by 29 per unit `ln θ` put `c` in the range that gives tenths at `u = 1e-3`, which is where your residue sits; it is a true property of the model at `θ₀`, not an error, and the chord at `u ≥ 1e-2` is the smoothed curvature. The other candidate is sign-coherent passages: a passage's `O(h⁴)` discrepancy between a member on the stage fields and on the dense output has a sign fixed by the regime, their count grows as `u`, so their sum is `∝ u` and the second difference `∝ 1/u`; 78 passages within `±1e-3` at a mean of 3.5e-9 is exactly your 4.5e-4/u. Variant 1 was meant to kill passages and did not kill the residue, but it also worsened `J` 6.7× and added its own pair jump, so it is not a clean test. Three cheap ones are: `u = 3e-4`, which gives 1.0×, 1.7× or 5.1× the `1e-3` value for `u^{−1/2}`, `1/u` or `1/u²`; re-centring the scan at `θ₀e^{−3e-4}`, away from the graze, which removes the first candidate and leaves the second; and, once the staircase is polished, bisecting a dozen passages to read their signs directly. The unsplit residue, six times larger and of the other sign, is the staircase of uncut kinks you already understand.

## 2. Does it reach the gradient and the sweep

No. The sweep differentiates the discretised model through the implicit-function theorem at the recorded roots, which is the derivative of the exact implicit map evaluated at a point 1e-9 off it; the error is 1e-9 times a curvature. Its gradient is a smooth function of `θ` except for the band's own gradient-level term, `b_i h f_{P⁺}(dP⁺/dP − branch)P_θ λ ≈ 1e-3 λ` per band stage, a few 1e-4 absolute in an elasticity as `θ` moves by one band width, which branches remove. The roughness is a property of finite-difference instruments at small `u`, not of the gradient. So the gate for the sweep through splits is central differences on the frozen grid at `u = 1e-3`: noise `2.6e-8/(2u) ≈ 1.3e-5` relative, truncation `u²g‴/6g ≈ 3e-6`, against an `ε/3` that is never below 3e-4 relative. That gate is already meetable; it also tests the implicit-function routing of `t_c`, since with smooth-`P⁺` pieces a sweep that freezes `t_c` misses by `O(h)` coherently, which at `1e-3` is visible. The `1e-10` gate I gave for the multirate step assumed a smooth solver; it applies only after the polish, at `u = 1e-5`. The multirate step itself adds no noise once its inner steps are frozen, because the chain alone has no solves.

## 3. What the split should be

Four changes, two of them to the solver rather than the split:

- **One Newton polish per root, at every level of the nest.** After the bracket stops at 1e-9, one step `p ← p − F/F′` with the derivative the sweep already forms turns a tread of height `s` into one of height `~s²F″/2F′`: the output becomes a smooth function of its inputs to roundoff, whatever path the bracket took. Cost about one outer iteration plus the implicit-function pieces, 10–15% of a solve; tightening the brackets to 1e-14 instead costs two superlinear iterations per root and leaves a 1e-14 staircase, which is also fine. This is also what the warm start needs: a warm-started bracket is still a staircase; a polished one is not. Afterwards a replay at `θ` repeats its forward to ulps if `h` is stored rather than recomputed.
- **A branch per piece.** It is not a change to the rates; it is a choice of which of two `C^∞` functions a piece evaluates, with `P⁺` replaced by its asymptote on that piece's side, an error below `ε_P/2` confined to `|P| ≲ 10ε_P`, about 2e-7 time units per crossing, of order 1e-10 in `ln J` in all. It buys three things, each visible: the band departure vanishes for cut members (the departure's standard deviation falls to the polished noise); the cut time's influence falls from `O(h)` to `O(h^p)`, so the sweep may freeze `t_c` and a routed sweep changes by nothing measurable; and near a graze the cut terms stay bounded, `O(h^p)/Ṗ`, instead of `O(h)/Ṗ`. If the rule forbids even this, keep smooth `P⁺` on pieces and route `t_c`; the band then stays and the routing is mandatory.
- **Detection by interior extrema.** The quartic's derivative is a cubic with closed-form roots; test the sign of `P` at each interior root. That catches the six or seven pairs a run that the stage-sign rule misses in the first fifth of onset steps, makes a pair's birth continuous by construction (two cuts of zero separation at `P(t*) = 0`), and costs nothing per step.
- **Pieces should rebuild only what they read.** A piece reads `φ` from the chain's dense output and `Φ` from interpolated `x_j`; it never needs `a_ℓ`, and the member created now contributes to `Φ` through `w_new A(z; x_new)` with `x_new` fixed and `w_new = N_M/Δ_M` interpolable, so its inner solve (39% of the split's cost) and the draw's rebuild are wasted. The split should cost about 3%, not 7%.

**How smooth that makes `J(θ)` on a frozen grid.** Polished and branched: roundoff times the chain's amplification, ~1e-13, plus `O(h⁴)` passage jumps of ~5e-9 at a density of ~6.5×10⁴ per unit `u`, plus `C^{1,1/2}` points at grazes. That is as smooth as the kink model allows and smoother than the `ε_P` model, whose fine structure at 3e-6 is the smoothing's artefact, not the biology's. The passages could be removed only by re-integrating every member on the dense output (2×) or by variant 1's correction, which costs accuracy; at `u = 1e-2` their coherent sum is at most 0.05 in a second difference, so leave them.

## 4. What a frozen grid should freeze

| frozen? | what it buys | what it costs |
|---|---|---|
| step times, multirate selection, inner chain steps: yes | the controller's discontinuities gone; the tape's row structure fixed | nothing |
| cut structure: no, re-detect | `J` continuous across passages to `O(h⁴)`; freezing it brings back a kink error that grows linearly as a crossing walks into its old step | re-detection is already in the replay |
| cut times: record their values; route them by the IFT, or make them `O(h^p)` by branches | the gradient of the model actually run | one scalar sink per cut |
| inner iterations: no | a frozen bracket is unconverged off `θ₀`; a polished solve is smooth everywhere | the polish |

The sweep needs nothing beyond the recording. For continuity over the box the grid is already adequate once polished; for second derivatives the instrument, not the grid, was the problem.

## 5. Second derivatives: windowed, and the adjoint warning

A second derivative on the `ε_P` model must be a window average, and the window must be stated. Pointwise, every stage in the band contributes `b_i h f_{P⁺}·(1/2ε_P)·P_θ² λ ≈ 180λ` to `d²J/dθ²`, there are tens of them at any `θ`, so a second-order adjoint evaluated pointwise at `θ₀` returns tens to hundreds of meaningless units against an ε of 1.17; a graze within 1e-5 adds a rounded `(θ_g−θ)^{−1/2}` spike of order ε. A window of `u ∈ [1e-2, 2e-2]` averages the band to `~1e-4`, a graze inside it to `c/√u ≈ 0.01–0.1`, and sits well below the length scale 0.245; that is the second derivative ε was defined on, and `u = 1e-2` is a modelling choice, not a numerical compromise. If a second-order adjoint is built, it must differentiate `P⁺` as its branch (`d²P⁺/dP² = 0`, `dP⁺/dP ∈ {0,1}`) and be checked against the windowed difference; a pointwise curvature of the smoothed model is not a quantity you want. Per run, report members with `|P_min|` inside a step below a threshold together with their share of `J`: those are the grazes, and they bound how far a window can be trusted.

## 6. The decided setting

Nothing qualitative changes. Longer late steps raise passage jumps as `h⁴` and band bumps as `h`, both weighted by late `λ` that is small by construction; the multirate step's frozen inner chain adds no solves and so no staircase; the spread rule's sort changes summation order at swaps, roundoff only. The one thing to check there is the band count on long steps after the window, which is free.

## 7. Remove, bound, or leave

Remove the staircase: it is cheap, it will masquerade as physics in every future measurement, and the warm start needs it gone. Remove the band from pieces if the rule allows the branch. Fix detection and the pieces' cost. Leave passages, bounded at `5e-9 × count`. Report grazes and windows; they are the model's. Then build the sweep through splits and gate it at `u = 1e-3`, and separately gate a frozen-`t_c` sweep against a routed one: with branches they agree, without them the frozen one is `O(h)` off, and that single compari son tells you whether the construction is right.
