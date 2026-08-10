# Assuring the reverse sweep: the oracle, the floor, and three rungs

The objective is correct reverse-mode gradients of a TF24 patch on the birth-date coordinate, with
the light and soil feedbacks live and introductions occurring. This report specifies **what would
make that believable**, in the order the guarantees should be acquired.

It is organised around one idea: **use the strongest oracle the size permits, and the size permits an
exhaustive one exactly once — at the bottom.** One cohort's block is small enough to form entirely.
Nothing above it is, so nothing above it is ever checked this well again. Spend the effort here.

Rungs 0 to 2 are preconditions and are not developed here: rung 0 establishes that the forward
reductions integrate over birth dates and that cohort solves are order-independent; rung 1 the leaf's
supplied rows against the individual's own algebra; rung 2 the recorded cohort block against a
tangent with the field held fixed. §3.1 states the one place a rung-1 weakness reaches up into
everything above it.

---

## 1. What a check must carry before it counts

A check that passes tells you nothing until five questions about it are answered. These are the
deliverable of this report as much as the checks are.

**1. Path disjointness — name the code the reference traverses, and what it shares.** The failure this
prevents is a suite that referees the sweep against itself. **The requirement is not that the
reference share no code — it is that it share no code with the object under test.** A transpose is
correct relative to a forward function, so the reference *must* traverse that forward function; what
it must not traverse is the transpose. Every check below names the shared part and the rung that
independently refereed it.

**2. Fault injection — where it is the evidence, not everywhere.** A check's sensitivity is
established by breaking the thing it watches, not by argument. But there are two classes here and
conflating them is what turns a suite ornate. **A defect no other check would notice must be
injected**, because the injection is then the only evidence that check works at all — the lost stage
term of §7 is the case. **A defect that moves a number some other check already compares needs one
injection per class**, to show the comparison is wired and sensitive; the remainder of that class is
a reading guide for when it fails, not a set of runs to perform. **Record the margin** on what you do
inject — a fault detected at 3× is a check about to stop working.

**3. Non-vacuity — the null control.** Zero the channel the check exists for and require the result to
**move**. A check on the slope channel passes with the whole slope channel missing if the fixture's
slope adjoints happen to be zero. §6 raises this from a per-check habit to a systematic obligation.

**4. Fixture adversariality — every distinguishing quantity distinct and non-commensurate.** Two
cohorts of equal height make a mis-targeted scatter invisible. Two species with equal `k_I` make a
species collapse invisible. A seed vector of all ones makes a summation-order defect invisible. No
two quantities the code must keep apart may be equal, related by a small integer ratio, or of the
same magnitude, and seeds come from a fixed generator rather than from units.

**5. Tolerance provenance — a measured floor, not a round number.** Every tolerance is derived from a
floor measured on the fixture itself, and every check reports its margin. A suite of `1e-10` literals
is a suite whose thresholds nobody can defend when one of them starts failing.

---

## 2. The floor: what holds before any harness exists

These need **no reference at all**. They are not a rung — they are properties that should hold from
the first day there is a sweep, and be re-run at every rung after. They are the cheapest assurance in
the document and they are gated behind nothing.

### 2.1 The objective itself

**A gradient of a wrong number is worthless.** A census is a quadrature of a density, so its weights
must be gaps in **the coordinate the state is carried on** — birth date, here. A census whose grid is
built from heights integrates a density in one variable against the spacing of another. Report 05 §9
carries the argument and why sorting by height is the wrong remedy.

**Pass:** the census grid is the integration coordinate, asserted monotone on every call; and the
value matches an independent reduction of the same state to round-off.

It belongs before the ladder rather than in it — it is a forward change and it moves numbers. It is
listed here because §4's fixture mandates a crossed pair, so every run of this ladder sits in the
regime that exposes it, and a reference differentiating the same wrong census would agree with the
sweep.

### 2.2 The sweep computes the same thing however it is decomposed

Tolerance is exactly **zero** for all of these; there is no margin, and their assurance is entirely
§1.3 — prove the two paths computed something.

- **Split sweep.** Split a recording at an interior step, and at an introduction, and at one step
  either side of one. The two-part sweep equals the whole sweep bit for bit. Non-vacuity: assert the
  split point has non-zero adjoint traffic across it.
- **Permutation.** Shuffle cohort solve order; the gradient is bit-identical. Rung 0's purity check
  raised to the sweep.
- **Repeatability.** Two consecutive sweeps of one recording, bit-identical — the check that the
  forward replay of introductions leaves the system where it found it.
- **Rejected steps.** Assert the fixture's rejection count exceeds zero, then require the gradient
  unchanged when rejections are excluded. Otherwise "a rejected step contributes nothing" is vacuous.
- **An empty segment list refuses.** A sweep that never ran must be distinguishable from an
  insensitive stand.

### 2.3 Every zero is attributable to a named cause

**An exact zero is the signature of a missing accumulator and never of true insensitivity**, which
makes it indistinguishable from an ecological finding. So zeros are not tolerated; they are
*classified*.

Every column resolves to exactly one of three declared lists, and the list is part of the suite:

- **structurally zero, with the reason named** — a channel the model genuinely does not have, or one
  imposed to zero by declaration, such as seed height;
- **refused by name** — a parameter the boundary cannot answer for. A refusal, never a number.
- **non-zero**, with a magnitude.

**Two failure modes, not one.** An exact zero in the third class is a missing accumulator. And a
registered parameter that reaches no equation comes back as **round-off at `10⁻¹⁸` to `10⁻²²`**, which
reads as a gradient — so the check is a two-sided band, not a test against zero. An unknown parameter
must refuse by name rather than return anything at all.

---

## 3. The reference, for the rungs that need one

Where a reference is needed, the object under test is a hand-written transpose, so the reference must
be a derivative of the **forward** source obtained by a mechanism that is not the transpose.

**Use a forward-mode tangent.** The model is already templated on its scalar, the toolchain already
provides forward mode, and rung 2 assumes a tangent exists — so this is a seed, not a build. It is
**exact**: no step size, no truncation, and the residual floor is the forward model's own arithmetic.
It is tape-free. One seed gives one exact Jacobian column, which is what makes §5 affordable. And it
traverses the forward reductions while the transposes under test are not on its path, which is
§1.1's obligation.

**It takes branches as the model takes them.** A tangent follows whichever branch the real value
takes, so at a kink it returns the one-sided derivative of the branch actually in force — exactly the
function the transpose ought to be the transpose of. **So the interior pin is a scoping choice, not a
precondition:** the reference does not stop existing outside it, §10's limits are about what the
regime *exercises*, and the same ladder can later be pointed at a pinned state without rebuilding the
oracle.

**The leaf is entered at its solved operating point with rows supplied**, exactly as the sweep enters
it. The graft `ṽ = v + Σ (∂v/∂u_i)(u_i − passive(u_i))` then serves the tangent as report 05 §8 says
it serves forward and reverse — which is why the node exists (report 02 §1). A tangent must not run
through the solve itself: a root-find's iterate count is a comparison outcome, so differentiating the
iteration is not differentiating the solution.

### 3.1 The one seam, and the check that closes it

The reference consumes the **same supplied leaf rows** the sweep does. That is licensed by rung 1
having refereed them independently — and the licence is weaker than it looks in the one place it
matters most.

The water rows are built on report 05 §7.3's rank-two factorisation. The collinearity that makes this
seam awkward is real and has now been measured: the potential-family vectors have a second singular
value `10⁻⁴` to `10⁻⁵` of the first, so a compensating `(a, b)` pair fits every row of **that family**
equally well and an error in `b` is absorbed into `a`. Since the uniform-drying direction is a
near-symmetry whose true response is amplified fifteen- to twenty-six-fold, a one-percent error in
`b` would be a fifteen- to twenty-six-fold error in the quantity the ecology cares about, sitting in
the sweep and in the reference alike, with every rung above passing.

**This section used to say that no check could referee it, and that was too strong. The objection is
to a *fit*, not to a *prediction*.** Solve `(a, b)` from two directions of different families — a
soil potential and a layer resistance, which are not collinear with each other — and predict the
rest. The collinear family is then what is predicted rather than what is fitted, and `b` is pinned
by having to work across both families at once.

**Pass, and it now does:** the out-of-sample residual over all `2L+1` directions, with the condition
number of the solved-from pair reported beside it. Report 05 §7.3 carries the result — worst
`2.4e-05` over four interior states including a near-uniform profile, round-off limited, `(a, b)`
stable to four significant figures across three decades of step. The condition number is the guard
that keeps it honest: 2.6 to 6.7 for a cross-family pair against `10⁴` for two potentials, so a
degenerate pairing is refused rather than absorbed. One state, no gradient run, no stand. **It was
the cheapest high-leverage check in the corpus and it is closed.**

---

## 4. The fixture

One fixture serves every rung, widened at each. Its assertions are part of the check, and a violated
assertion **invalidates** the run rather than failing it.

**Regime assertions, evaluated every solve:**

- every operating point classifies **S**, by the branch taken, not by a residual test;
- `|Π_pp| ≥` a declared floor, so the multiplier `m = −s/Π_pp` is not amplified;
- soil moisture strictly interior on every layer, the positivity guard never fires, the infiltration
  bracket strictly positive;
- light at every read point at least 100× the floor, and the interpolant's monotonicity guard silent;
- `P_net > 0` strictly, so no cohort sits in the absorbing reserve region where every derivative out
  of the reserve is exactly zero and a check would pass on a flat region;
- no cohort's rooting depth at the column cap, and no layer at the potential ceiling.

**One assertion is a vacuity guard and is less obvious than the rest.** The reserve gate is centred at
`a_st2 = 0.1` with width `0.1` on `r ∈ [0,1]`, and at full reserves its derivative is three orders of
magnitude smaller than in the band. A stand initialised with comfortable reserves damps every channel
running through growth, and a check then passes because the signal is small rather than because the
code is right. **Initialise `r` inside the transition band and assert `G'` above a floor.**

**Adversariality, by construction:**

- heights mutually non-commensurate — no equal pair, no small-integer ratio;
- **at least one pair crossed**, so birth-date order and height order disagree. This folds the
  crossed-stand condition into every run rather than isolating it, and it is what makes §2.1
  mandatory rather than optional;
- the two species differ by O(1) factors — not percentages — in every parameter carrying a
  per-species reduction row: `k_I`, `η`, `a_l1`, `a_l2`;
- seeds from a fixed generator, **block-normalised**: scale each state component by that state's
  characteristic magnitude and each rate by the reciprocal of its rate's. Soil moisture is `O(0.3)`
  and heartwood mass is in kilograms; an unnormalised inner product is a test of the largest block
  alone. Report residuals **per block** as well as in total.

---

## 5. Rung 3 — one cohort, and the Jacobian formed entirely

**A single cohort already carries endogenous feedback**: it shades itself and it draws on its own
soil layers. Both reduction transposes, the retention factor and the field's slope channel are live
and testable at `N = 1`. Two cohorts buy *accumulation*, not feedback — separating them is what makes
a rung-4 failure localisable.

**Unit:** the adjoint of one right-hand-side evaluation at one stage. No solver, no trajectory.

### 5.1 Form the whole Jacobian and compare entry by entry

**Do not contract.** A dot-product identity `⟨v, Ju⟩ = ⟨Jᵀv, u⟩` yields one number per run: an error
in cell `(i,j)` enters as `v_i · δ · u_j`, so it hides behind a small seed component, it cancels
against other cells, and when it does fail it localises to nothing. At this size the whole object can
be formed, so forming it is strictly better.

The cohort block has **12 outputs** — six strategy rates, the density rate, five per-layer uptakes —
and its inputs are the six own states, the field's `2K` knot values and slopes, the `L` soil
potentials and the traits. At the reference configuration that is on the order of **185 columns**.

- **Forward:** one tangent seed per input column gives one exact Jacobian column. ~185 evaluations
  of one cohort's rates.
- **Reverse:** twelve sweeps, each seeded with a unit output adjoint, give the twelve rows of `Jᵀ`.
- **Compare all ~2 200 entries**, with the residual reported as a matrix rather than a scalar.

**Pass:** every entry within `10·ε₀`, and the largest offending cell named. Localisation to a cell is
the point: a failure says which output row and which input column, not that a sum disagreed.

**Start with the state block if the harness is being built incrementally** — six or seven columns,
seven evaluations — because it is the smallest complete object in the design and it is a full
Jacobian identity on the first day.

### 5.2 The classification falls out for free

The matrix formed in §5.1 **is** report 00 §6's five-way table, measured rather than asserted. Assert
it directly, at no extra cost:

| structural claim | assertion on the formed Jacobian |
|---|---|
| the *blocked* rows | those cells are **exactly** zero, not small |
| `∂c_i/∂ψ_j` diagonal | off-diagonal cells exactly zero |
| the argmax channel is rank one | the uptake sub-block minus its explicit part has numerical rank 1 |
| the field block is rank one | the `12 × 2K` block has numerical rank 1 on the birth-date coordinate |
| quadrature weights carry no derivative | the abscissa columns are exactly zero |

**Every later cost argument in the corpus assumes this structure.** This is the one place it is
checked rather than read, and it costs a rank computation on a matrix that already exists.

### 5.3 What a wrong cell means

The light transpose is posed on `(Λ, Λ')` as `2K` independent inputs. **The pair is not a
convenience**: the `h̄` transpose of the slope channel carries a `Q̃''` term appearing nowhere in the
value transpose, so an identity posed on values alone passes with the entire slope channel absent.

**Every defect below is a wrong entry in §5.1's matrix**, so the entry-by-entry comparison catches
all of them and names the cell. This table is therefore a **reading guide** — what it means when a
given cell is wrong — and not a set of runs. Inject two of them to establish the comparison is live,
per §1.2, and read the rest when something fails.

| injected defect | must fail because |
|---|---|
| drop the `Q̃''` term from `h̄` | the slope channel's own contribution to height |
| drop `∂Q̃/∂η` | the crown-shape row arises inside the reduction |
| keep `A'_k Q̃`, drop `A_k Q̃' z_q/h_k²` | the two halves of `∂E/∂h` are separately wrong and jointly plausible |
| sign flip on the `Q̃'` term | a sign error survives any magnitude-only check |
| build trapezium widths from heights | the documented silent defect; caught **only** because the reference traverses the forward reduction and the unit traverses the transpose |
| route the transpose through a structure with size and density slots only | `k̄_I`, `η̄`, `ā_l1`, `ā_l2` read exactly zero |
| omit `∂ψ/∂θ`; apply it twice; apply the clamped zero unclamped | the row survives as the potential's adjoint, dimensionally wrong and finite |
| omit the two soil accumulator rows, or the `C_4` row | both leave a plausible bidiagonal transpose |

**What this rung cannot catch, so a pass is not over-read:** a `k_I` accumulated per cohort rather
than per species, and the species collapse of the reduction sums. Both need a second species.

---

## 6. Every path switchable, and every switch watched

The systematic answer to the corpus's central hazard — **every defect produces a finite, plausible
number** — is that each route by which a parameter reaches a census gets a switch, and something
fails when it is off. **If a switch can be thrown and nothing notices, that route is not known to be
right**, whatever the aggregate residual says.

Report 05 §10 enumerates six routes. Most already have their switch somewhere above, and saying
where is the point of this section:

- **The cohort block, the light reduction and the water reduction** are columns of §5.1's matrix, so
  their switch is a column of zeros and the entry-by-entry comparison is what notices. **The light
  reduction needs two switches, not one**, because the value and slope channels fail independently.
- **The three boundary channels and the initial condition** are §8.1's single-channel probes, which
  is the cleanest form: each is a parameter reaching the census through one route only, so a dropped
  route gives an exact zero rather than a small error.
- **The census direct term has no other home.** `∂𝔪/∂φ` at fixed state is not a sensitivity of the
  state, so no sweep produces it and no transpose check touches it — and it is easy to omit precisely
  because it is a one-line calculation at the final state. Switch it off; the metrics whose integrand
  reads traits must move.

**The count is the routes found, not a closed set.** Two of the six were missed by an enumeration
that declared itself complete, so a seventh discovered later is a seventh switch — not a reason to
distrust the six.

---

## 7. Rung 4 — two species, two cohorts each

**The minimum fixture is `2 × 2 = 4` nodes.** Two species with one cohort each catches the species
collapse and not per-species accumulation; two cohorts of one species catches accumulation and not
the collapse. Four nodes catches both and is still small enough to reason about by hand.

**Unit:** the trajectory sweep. New over rung 3: the stage recursion, step-size handling, accumulation
across cohorts and species, record-once-sweep-many.

**Reference:** a tangent run of the whole solve, **replaying the recorded step sizes**. Without that
replay the tangent run's controller chooses its own steps and the comparison differentiates the
controller, which report 05 §4 excludes from the model deliberately.

**Here the Jacobian can no longer be formed, so the contraction returns** — with its blind spot
stated. A contraction against a random direction masks a column whose true value is near zero, so it
is paired with §2.3's zero census and with coordinate directions on a declared shortlist: `k_I`, `η`,
`a_l1`, `a_l2` and the boundary-borne parameters, each chosen because it has a documented structural
route to reading exactly zero.

**Two of these must be injected because nothing else would notice; the rest are caught by the
contraction and the structural checks, and are listed so a failure is interpretable.**

| injected defect | | documented signature |
|---|---|---|
| replace `Σ_{l>i} a_{li} Ȳ_l` with the `l = i+1` term alone | **inject** | a lost stage term **has no signature of its own** — the injection is the only evidence this check works |
| clear the tape between metric sweeps with an active value held outside the loop | **inject** | first metric correct, later metrics **exactly zero in whole column families**; only the permutation of §7's record-once-sweep-many sees it |
| seed the two zero-weight stage accumulators from abscissae rather than weights | | `β₂ = β₅ = 0` while no abscissa is zero; wrong in a way a smooth problem hides |
| recompute `Δt` on the reverse pass | | differentiates the controller; **record the magnitude** — it prices what holding the step buys |
| treat one trait as one input per cohort | | a fixed fraction of the right answer, correct sign, no error raised |
| sum `k_I` over every species' cohorts | | collapses the species to one scalar; undetectable at rung 3, which is what earns the second species |
| narrow by truncating the tail | | correct for the last species only; also undetectable with one species |
| swap two cohorts' scatter targets | | invisible unless the fixture's heights are non-commensurate |

**The last four are caught because the fixture is adversarial, not because the check is clever** —
two species, non-commensurate heights, block-normalised seeds. §4 is doing that work, and the table
is what makes it legible.

**Record once, sweep many.** Every metric's gradient must be bit-identical under a permutation of the
sweep order, and identical to its own single-metric recording. This is the check for the failure
report 05 §9.1 calls the worst available — **a correct first row lending credibility to the rest** —
and permuting is what converts it from unobservable to certain, because the defect is positional.

---

## 8. Rung 5 — introductions

**Minimum fixture:** two species and three introductions in the order species 1, species 2,
species 1 — four segments, node stride exercised in both directions. Introducing into species 1 while
species 2 exists is the arrangement a tail truncation fails on.

§2.2's split-at-the-boundary and repeatability checks carry most of the structural load here and need
no reference.

### 8.1 Single-channel probes

Each boundary channel is probed by a parameter reaching the census **through that channel and no
other**, so a dropped channel gives an exact zero rather than a small error. This is the cleanest
test shape in the ladder, and the boundary is where it is available.

| channel | probe | dropped-channel signature |
|---|---|---|
| initial reserve `r₀ = a_st3 · S_max` | `a_st3`, with introductions after `t = 0` | `ā_st3` exactly zero |
| the initial condition `ȳ(0)` | `a_st3` reaching only founding cohorts | exactly zero if the final narrowed adjoint is discarded |
| the newcomer's dependence on pre-introduction state | perturb soil moisture at the introduction time | exactly zero if potentials come from a cache — where the retention factor is most easily omitted |
| the newcomer's leaf area through a field built without it | a field-borne parameter seeded only at the introduction | a shortfall rather than a zero; needs the contraction |
| seed height `h₀` | not a numerical probe | must appear on §2.3's declared-zero list; a silent zero here is the failure |

### 8.2 The marginal recruit

**Pass:** as `pr_estab → 0⁺` the census gradient exists, is finite, and tends to zero from both sides.

**Its fixture assertion is derived rather than chosen.** The establishment probability's derivative
peaks at `0.65/k` at `P = k/√3`; a recruit anywhere else is in a flat region and the check proves
nothing. **Assert the recruit's `P_net` lies in the stiff band**, and report where in it.

**Fault:** seed the boundary node's adjoint in `ℓ` rather than in `n`. The seed `n·∂ℓ/∂φ` is `0·∞`,
so the injected version must diverge or land orders above the reference.

---

## 9. Refusal, plumbed to metric level

The leaf reports an honest per-point kind, by the branch taken. **The stand must aggregate it, and the
aggregation rule is not obvious enough to leave implicit.**

**A refusal has no localisation within a metric.** A sum has no defined value with an undefined term,
so one refused operating point anywhere in one metric's sweep makes **that metric's entire gradient
undefined**. Not the cohort's column, not the parameter's entry — the metric.

**And metrics are independent of one another**, so refusal is metric-level and no wider. That is the
whole design: it is the difference between losing one column and losing the answer.

**The two output kinds refuse independently, and this asymmetry must be built in rather than
discovered.** The profit row survives every degeneracy except a jump of the argmax and an undefined
objective; **the uptake row is the one that ceases to exist.** So a metric seeded only on size states
survives a fold that kills a water-coupled one. Refusing them as a pair throws away the surviving
metric for nothing.

**Checks:**

- inject a refusal at one cohort at one stage; require exactly the water-coupled metrics to come back
  undefined and the others to return values;
- require an undefined metric to be **distinguishable from a zero one** at the boundary — a refusal
  is not a number;
- assert the aggregation is not per-parameter: a refusal must not surface as a partly-populated
  gradient vector, which is the shape that reads as an answer.

This is scaffolding built at rung 3 and exercised at rungs 4 and 5. It cannot be validated in the
pinned regime — §10 — but the **plumbing** can be, by injection, and it is far cheaper to build now
than to retrofit around a working sweep.

---

## 10. What a pinned interior pass does not establish

The pin is a scoping choice (§3), so its price is coverage rather than the reference: it exercises
none of the branch machinery. The list is stated in full so a pass is not mistaken for more than it
is.

**Unrefereed by anything here:** the constrained-optimum row at either bound, and the wet bound in
particular, where more than half of all pins sit; the substituted-feasible and shutdown branches; the
refusal *cases* and the selector choosing between all five — §9 builds the plumbing, not the
branches; the amplification ceiling on `|m| = |s|/|Π_pp|`; the retention derivative's clamped zero and
the one-way feedback at the potential ceiling; a positivity-guard-zeroed layer with a live uptake
adjoint; the absorbing reserve region; the light floor and the monotonicity guard; the rooting-depth
cap.

**Two consequences worth stating rather than implying.** The stand reaches 1.4 to 2.4 MPa at the
reference configuration under its own dynamics, so the interior pin is a *test condition*, not the
model's normal condition — and incidence measured here says nothing about a dry driver. And the
shutdown case is governed by **light**, not water, so no rainfall sweep reaches it; opening that
branch needs a shaded driver, and no plant in this corpus has been run in shade.

**One item is a precondition for opening any of it.** Bounding the root vulnerability integral must
land before the selector, because the wet bound's position is set by the same cancellation an
unbounded extrapolation inflates, and a correct constrained row at a corrupted bound is a correct
derivative of the wrong thing that passes every invariant the row has.

---

## 11. Order, and what it costs

**Before the harness — the floor (§2), and it is nearly free.** The bit-identity family, the zero
census, and the objective's own coordinate check. No reference, zero tolerance. If any of these fails, nothing below is worth building yet.

**Then the one check that gates the meaning of the rest (§3.1).** The factorisation residual over
`2L+1` directions and `b` at fixed `a`. One state, no stand, no gradient run — and until it passes,
every rung above shares a possible common-mode error on the water channel.

**Then the harness** — tangent seeding over input columns, `passive`, step-size replay. Smaller than
it looks, because the scalar templating and the tangent already exist; what is new is the seeding
loop and the replay.

1. **Rung 3's full Jacobian (§5.1), state block first**, then the whole 12 × ~185 object, then §5.2's
   structural assertions, which are free once the matrix exists.
2. **Rung 3's reduction faults (§5.3)**, each one a deliberately broken build with a recorded margin.
3. **The six switches (§6).** Cheap, systematic, and the direct answer to the finite-plausible-number
   hazard.
4. **Rung 4**, structural checks before the contraction — they need no reference, so they fail earlier
   and cheaper, and a split-sweep failure invalidates the contraction anyway.
5. **Rung 5**, structural checks, then the probes, then the marginal recruit.
6. **Refusal plumbing (§9)**, built at rung 3 and exercised above.

**The fault-injection runs are the deliverable, not a by-product.** Each table row is one deliberately
broken build, one recorded margin, and one line of evidence that a check does what its name says. **A
rung whose faults have not been injected is a rung that has not been climbed.**

**What is deliberately absent.** No acceptance number is a standing test. The feedback-suppression
figures and the extinction coefficient's shortfall are **one-shot targets** — the shortfall becomes
zero the moment the missing summation lands — so they belong in the commit that closes each, as
evidence that the change did what it claimed, and not in a suite that would then have to be edited to
keep passing.
