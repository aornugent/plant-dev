# Assuring the reverse sweep: two questions, two references, and the rungs between

The objective is correct reverse-mode gradients of a TF24 patch on the birth-date coordinate, with
the light and soil feedbacks live and introductions occurring. This report specifies **what would
make that believable**, in the order the guarantees should be acquired.

It is organised around one distinction, and getting it wrong is how a suite comes to pass while a
gradient is wrong:

> **A reference can establish that a transpose is the transpose of its forward function, or that no
> term is missing. These are different questions, and no single reference answers both.**

Everything else follows. §1 states the distinction and why it is a property of *lifetimes* rather
than of code. §2 restates what any check must carry. §3 is the floor. §4 is the correctness axis and
§5 the completeness axis — the two are not rungs of one ladder, they are independent and one can
pass entirely while the other fails. §6 to §10 are the fixture, the switches, refusal, the scope
limits, and the order.

---

## 1. Two questions, and why one reference cannot answer both

The computation has lifetimes. Report 00's opening section gives them; what matters here is that a
reference covers exactly the lifetimes it **re-runs**, and inherits every declaration made in the
lifetimes it does not.

| lifetime | runs | a tangent re-runs it? | a rebuild re-runs it? |
|---|---|---|---|
| the parameterisation above the carried traits | once | no | yes |
| a strategy's derived quantities | once per species | no | **yes** |
| the shared field | per stage | yes | yes |
| one cohort's rates | per cohort per stage | yes | yes |
| the inflow boundary | per introduction | yes | yes |
| the census | once | yes | yes |

**A forward tangent seeds an already-constructed strategy.** It is exact, tape-free, and traverses
the forward reductions while the transposes under test are not on its path — so it settles whether
the transpose is the transpose of its forward function. It cannot settle whether that forward
function is the model, because it imposes every equation the model imposes. **That is the
correctness axis.**

**A whole-run difference over a rebuilt strategy re-runs everything.** It is inexact and its
validity is per-fixture, and it inherits none of the differentiated paths' declarations. **That is
the completeness axis**, and it is the only instrument on it.

**The corollary is the reason this report was reorganised: agreement with a tangent is not evidence
of completeness and never was.** A channel imposed to zero in construction is exactly zero on the
sweep and on the tangent simultaneously; they agree there for free, and the agreement reads as a
pass. Measured: the sweep and the tangent agree on the two allometric constants to `1.5e-03` while
both disagree with a rebuild by a factor of **two to three**.

**And completeness has a property correctness does not: it needs no enumeration.** The census is a
function of the carried parameters, and a rebuild-difference computes its derivative by definition,
traversing whatever the forward model traverses. So the oracle does not need to know the routes —
enumeration is needed only to *localise* a disagreement, never to detect one. Report 05 §10's six
paths are a localisation aid and its own caveat is right: the count is the routes found rather than
a closed set.

---

## 2. What a check must carry before it counts

A check that passes tells you nothing until five questions about it are answered.

**1. Lifetime coverage — name which lifetimes the reference re-runs, and which of the object's
declarations it therefore inherits.** This replaces a narrower obligation about shared code. The
requirement is not that a reference share no code with the object under test: a transpose is correct
*relative to* a forward function, so the reference must traverse that forward function; what it must
not traverse is the transpose. But **disjointness of code is not disjointness of assumptions.** A
reference that imposes the same equation agrees for free however little code it shares. Report 05
§10.1's seed height is the instance, and the seed's leaf area is a second one found the same way.
Every check below names its axis.

**2. Fault injection — where it is the evidence, not everywhere.** A check's sensitivity is
established by breaking what it watches. **A defect no other check would notice must be injected**,
because the injection is then the only evidence the check works. **A defect that moves a number some
other check already compares needs one injection per class.** Record the margin: a fault detected at
3× is a check about to stop working.

**3. Non-vacuity — the null control.** Zero the channel the check exists for and require the result
to move. §7 raises this from a habit to an obligation.

**4. Fixture adversariality, and that includes duration.** Every distinguishing quantity distinct
and non-commensurate; two species differing by O(1) factors in every per-species reduction
parameter; seeds from a fixed generator, block-normalised. **And a declared run length**, because at
least one defect grows with it (§9) and a fixture chosen for speed under-reports such a defect
silently. A bias quoted without its run length is not a bias, it is a reading.

**5. Tolerance provenance — a measured floor, not a round number.** Every tolerance derived from a
floor measured on the fixture itself, and every check reports its margin.

---

## 3. The floor: what holds before any harness exists

These need **no reference at all**, and should hold from the first day there is a sweep.

### 3.1 The forward model must be blessed

**A gradient of an unblessed number is not assurance of anything.** Where the forward model's own
reference comparison does not pass, every rung above it is measuring agreement with a trajectory
nobody has accepted. This is listed first because it gates the rest and because it is the cheapest
thing to check: run the model's golden-value comparison and require it to pass, or record the
re-blessing that makes it pass, before reading any residual below.

### 3.2 The objective itself

**A gradient of a wrong number is worthless.** A census is a quadrature of a density, so its weights
must be gaps in **the coordinate the state is carried on** — birth date, here. A census whose grid
is built from heights integrates a density in one variable against the spacing of another. Report 05
§9 carries the argument and why sorting by height is the wrong remedy.

**Pass:** the census grid is the integration coordinate, asserted monotone on every call; and the
value matches an independent reduction of the same state to round-off.

### 3.3 The sweep computes the same thing however it is decomposed

Tolerance is exactly **zero** for all of these, and their assurance is entirely §2.3 — prove the two
paths computed something.

- **Split sweep.** Split a recording at an interior step, at an introduction, and one step either
  side of one. The two-part sweep equals the whole sweep bit for bit. Assert non-zero adjoint
  traffic across the split point.
- **Cohort-order permutation.** Solve a census of states in different orders and require every
  output bit-identical; then re-run one cohort from stored state plus stored environment reads and
  require the same. **This is the only check a reordering can fail and a re-run cannot** (report 01
  §3), and it is distinct from the metric permutation of §4.5 — a return-to-value check that drives
  the patch elsewhere and back in the *same* cohort order is not a permutation and shuffles nothing.
- **Metric permutation.** Every metric's gradient bit-identical under a permutation of the sweep
  order, and identical to its own single-metric recording (report 05 §9.1).
- **Repeatability.** Two consecutive sweeps of one recording, bit-identical.
- **Rejected steps.** Assert the rejection count exceeds zero, then require the gradient unchanged
  when rejections are excluded.
- **An empty segment list refuses.** A sweep that never ran must be distinguishable from an
  insensitive stand.

### 3.4 Every zero is attributable to a named cause

**An exact zero is the signature of a missing accumulator and never of true insensitivity.** So
zeros are classified, not tolerated. Every column resolves to exactly one of three declared lists,
and the list is part of the suite: **structurally zero with the reason named**; **refused by name**;
or **non-zero with a magnitude**.

**Two failure modes.** An exact zero in the third class is a missing accumulator. And a registered
parameter reaching no equation comes back as round-off at `10⁻¹⁸` to `10⁻²²`, which reads as a
gradient — so the check is a two-sided band, not a test against zero.

**And the classification runs over columns, which is narrower than over rows.** A quantity with
no column of its own can still carry a row, and an exact zero there is invisible to every check
above. The auxiliary slots a state determines are the instance: they are functions of a state
rather than states themselves, nothing is named after them, and a state written past the setter
that re-derives them leaves their rows at exactly zero while every value is unchanged — so no
forward test moves either. **The zero census therefore needs a second half over the derived
slots**, asserted where they are written rather than inferred from a column, and it is cheap:
each slot's row against a difference of the function that defines it. Report 04 §5.1 prices the
one that was missing at a factor of 154 on a boundary row.

---

## 4. The correctness axis

The object under test is a hand-written transpose; the reference is a derivative of the **forward**
source obtained by a mechanism that is not the transpose.

**Use a forward-mode tangent.** The model is templated on its scalar and the toolchain provides
forward mode, so this is a seed rather than a build. It is **exact** — no step size, no truncation,
its residual floor is the forward model's own arithmetic — and it is tape-free. One seed gives one
exact Jacobian column. **It takes branches as the model takes them**, so at a kink it returns the
one-sided derivative of the branch in force, which is exactly the function the transpose ought to be
the transpose of. The interior pin is therefore a scoping choice, not a precondition.

**The leaf is entered at its solved operating point with rows supplied**, exactly as the sweep enters
it. A tangent must not run through the solve: a root-find's iterate count is a comparison outcome,
so differentiating the iteration is not differentiating the solution.

### 4.1 The one seam, and the check that closes it

The reference consumes the **same supplied leaf rows** the sweep does, licensed by those rows having
been refereed independently against the individual's own algebra.

The water rows rest on report 05 §7.3's rank-two factorisation, and the collinearity that makes the
seam awkward is real: the potential-family vectors have a second singular value `10⁻⁴` to `10⁻⁵` of
the first, so a compensating pair fits every row of *that family* equally well. Since the
uniform-drying direction is a near-symmetry amplified fifteen- to twenty-six-fold, a one-percent
error there would be a fifteen- to twenty-six-fold error in the quantity the ecology cares about,
sitting in the sweep and the reference alike.

**The objection is to a fit, not to a prediction.** Solve the pair from two directions of different
families — a soil potential and a layer resistance, which are not collinear with each other — and
predict the rest. **Pass, and it does:** worst `2.4e-05` over all `2L+1` directions at four interior
states including a near-uniform profile, round-off limited, the pair stable to four significant
figures across three decades of step, with the solved-from pair's condition number reported beside
it — 2.6 to 6.7 against `10⁴` for two potentials, so a degenerate pairing is refused rather than
absorbed.

### 4.2 Rung 3 — one cohort, and the Jacobian formed entirely

**A single cohort already carries endogenous feedback**: it shades itself and draws on its own soil
layers, so both reduction transposes, the retention factor and the field's slope channel are live at
`N = 1`. Two cohorts buy *accumulation*, not feedback.

**Unit:** the adjoint of one right-hand-side evaluation at one stage. No solver, no trajectory.

**Do not contract.** A dot-product identity yields one number per run: an error in a cell hides
behind a small seed component, cancels against other cells, and localises to nothing. At this size
the whole object can be formed, so form it. The block has **12 outputs** — six strategy rates, the
density rate, five per-layer uptakes — against order **185 columns**. One tangent seed per column
gives one exact column; twelve unit output adjoints give the twelve rows of the transpose; compare
all ~2 200 entries, reporting the residual as a matrix rather than a scalar.

**Pass:** every entry within `10·ε₀`, largest offending cell named. Localisation to a cell is the
point.

**And form it at trajectory states, not only constructed ones.** A constructed patch's state is
written directly and conditioned into the declared regime; a trajectory's is wherever the run went.
"Correct at one state" and "correct at every state the trajectory visits" are different claims.
Measured at both: worst cell `1.8e-16` to `3.4e-16` at constructed and at trajectory states alike,
one cohort and two, both species — so the per-stage linearisation holds everywhere, and this closes
the last place a per-stage error could hide.

### 4.3 The classification falls out for free

The matrix formed above **is** report 00 §6's table, measured rather than asserted:

| structural claim | assertion on the formed Jacobian |
|---|---|
| the *blocked* rows | those cells are **exactly** zero, not small |
| `∂c_i/∂ψ_j` diagonal | off-diagonal cells exactly zero |
| the argmax channel is rank one | the uptake sub-block minus its explicit part has numerical rank 1 |
| the field block is rank one | the `12 × 2K` block has numerical rank 1 on the birth-date coordinate |
| quadrature weights carry no derivative | the abscissa columns are exactly zero |

**Every later cost argument in the corpus assumes this structure.** This is the one place it is
checked rather than read, and it costs a rank computation on a matrix that already exists.

### 4.4 What a wrong cell means

The light transpose is posed on the field's values and slopes as independent inputs. **The pair is
not a convenience**: the height transpose of the slope channel carries a second-derivative term
appearing nowhere in the value transpose, so an identity posed on values alone passes with the entire
slope channel absent.

**Every defect below is a wrong entry in §4.2's matrix**, so the entry-by-entry comparison catches
all of them and names the cell. Inject two to establish the comparison is live; read the rest when
something fails.

| injected defect | must fail because |
|---|---|
| drop the second-derivative term from the height row | the slope channel's own contribution to height |
| drop the crown-shape partial | that row arises inside the reduction |
| keep one half of the leaf-area/height product, drop the other | the two halves are separately wrong and jointly plausible |
| sign flip on the slope term | a sign error survives any magnitude-only check |
| build trapezium widths from heights | the documented silent defect; caught only because the reference traverses the forward reduction |
| route the transpose through a structure with size and density slots only | the four reduction parameter rows read exactly zero |
| omit the retention derivative; apply it twice; apply the clamped zero unclamped | the row survives as the potential's adjoint, dimensionally wrong and finite |
| omit the soil accumulator rows | both leave a plausible bidiagonal transpose |

**What this rung cannot catch:** a per-species parameter accumulated per cohort, and the species
collapse of the reduction sums. Both need a second species.

### 4.5 Rung 4 — two species, two cohorts each

**The minimum fixture is `2 × 2 = 4` nodes.** Two species with one cohort each catches the species
collapse and not per-species accumulation; two cohorts of one species catches accumulation and not
the collapse.

**New over rung 3:** the stage recursion, step-size handling, accumulation across cohorts and
species, record-once-sweep-many.

**Reference:** a tangent run of the whole solve, **replaying the recorded step sizes**. Without that
replay the comparison differentiates the controller, which report 05 §4 excludes from the model
deliberately.

Here the Jacobian can no longer be formed, so the contraction returns — with its blind spot stated.
A contraction against a random direction masks a column whose true value is near zero, so it is
paired with §3.4's zero census and with coordinate directions on a declared shortlist.

| injected defect | | signature |
|---|---|---|
| replace the stage sum with its immediate predecessor alone | **injected** | a lost stage term was thought to have no signature of its own; against a one-cohort control it has an enormous one — residual `2.2e-07` to `7.0e-03`, a margin of thirty-one thousand, longer fixtures saturating at 1.0. Diagnostic as well as sensitive: a lost term lifts a **one**-cohort stand as much as a two-cohort one |
| clear the tape between metric sweeps with an active value held outside the loop | **inject** | first metric correct, later metrics **exactly zero in whole column families** |
| seed the two zero-weight stage accumulators from abscissae rather than weights | | those weights vanish while no abscissa does; wrong in a way a smooth problem hides |
| recompute the step size on the reverse pass | | differentiates the controller; record the magnitude |
| treat one trait as one input per cohort | | a fixed fraction of the right answer, correct sign, no error raised |
| sum a per-species parameter over every species' cohorts | | collapses the species to one scalar; undetectable at rung 3 |
| narrow by truncating the tail | | correct for the last species only; undetectable with one species |
| swap two cohorts' scatter targets | | invisible unless the fixture's heights are non-commensurate |

**The last four are caught because the fixture is adversarial, not because the check is clever.**

### 4.6 Rung 5 — introductions

**Minimum fixture:** two species and three introductions in the order species 1, species 2,
species 1 — four segments, node stride exercised in both directions.

§3.3's split-at-the-boundary and repeatability checks carry most of the structural load and need no
reference. Beyond them:

**The introduction map can be formed entirely, and should be.** It maps the pre-introduction state
and the parameters to the widened state. Measured: forward against reverse to `7.5e-16` over every
one of its 3729 cells, at a widening into an empty patch and into a populated one.

**A verified map does not cover its application.** Which output adjoints seed the boundary's
vector–Jacobian product, and how the incoming adjoint narrows across the widening, are separate
decisions the map's Jacobian says nothing about. **An accumulator written and never consumed is
indistinguishable by inspection from a channel that was forgotten**, so each unconsumed one is
switched into the seed and required either to move the residual or to be provably redundant.

**Single-channel probes.** Each boundary channel is probed by a parameter reaching the census through
that channel and no other, so a dropped channel gives an exact zero rather than a small error. This
is the cleanest test shape available anywhere in the report.

| channel | probe | dropped-channel signature |
|---|---|---|
| the initial reserve | its own constant, with introductions after `t = 0` | exactly zero |
| the initial condition | that constant reaching only founding cohorts | exactly zero if the final narrowed adjoint is discarded |
| the newcomer's dependence on pre-introduction state | perturb soil moisture at the introduction time | exactly zero if potentials come from a cache |
| the newcomer's leaf area through a field built without it | a field-borne parameter seeded only at the introduction | a shortfall rather than a zero; needs the contraction |
| the seed height | **not a numerical probe** — §5 prices it | must appear on §3.4's declared-zero list |

**The marginal recruit.** As establishment tends to zero the census gradient exists, is finite, and
tends to zero from both sides. Its fixture assertion is derived rather than chosen: the
establishment probability's derivative peaks at a known point, so **assert the recruit's production
lies in the stiff band** and report where in it. **Fault:** seed the boundary node's adjoint in the
log density rather than the density — the product is `0·∞` and the injected version must diverge.

---

### 4.7 One introduction is the sharpest fixture, and three scaling traps

Adversariality (§6) widens a fixture until it can fail in every way at once. That is right for
catching a defect and wrong for *localising* one, and the two want opposite fixtures.

**A stand carrying one introduction makes a parameter a single-channel probe.** With one
introduction the seed mass reaches a size-moment census through the seed's height and through
nothing else, so its whole column is one channel and a discrepancy cannot be apportioned away.
The same stand at four introductions dilutes that channel to a fifth of its size, and at twelve
it is invisible. **The widest fixture is the worst place to measure a channel**, and a rung that
only ever runs the adversarial one will see a defect and never localise it.

**Its discriminator is free and it is a two-sided test.** Every parameter whose seed-height slope
is zero must come back at *exactly* 1.000 against a rebuilding reference; every parameter with a
non-zero slope carries the channel in proportion. Measured on such a stand: the reserve constant,
the establishment constant and the extinction coefficient all read 1.0000 to four decimals while
the seed mass read 0.84 — which locates the channel before any mechanism is proposed. A defect
that moved all of them would be a different defect.

**Trap one: a matrix residual normalised by the matrix.** §4.2 asks for the Jacobian entry by
entry, and the entry that matters may be small. Scaled by the largest entry anywhere in the
matrix, a diagonal wrong by a tenth of a percent reads as `10⁻⁵` when the largest entry is four
orders above it. **Scale each cell by itself**, and report the offending cell's own value beside
the residual.

**Trap two: a difference whose step has an absolute floor.** A step sized `max(|state|, 1)·rel`
is relative for a state of order one and absolute below it. At early trajectory states the
reserve and heartwood accumulators are `10⁻¹¹` and smaller, so such a step moves them by many
orders and the row it returns is not a derivative of anything. Those rows read as enormous
Jacobian errors and are the instrument. **A difference over state needs a relative floor**, and
a rung forming this matrix along a trajectory must report which rows its step was valid for.

**Trap three: refereeing a partial against a total.** A row read where a quantity is
formed is a partial derivative at fixed state. A whole-run difference of the same
quantity is a total, because a changed parameter moves the state the quantity is
evaluated in. The two differ by however much the trajectory responds, which for a
parameter setting birth size is two orders — enough to make a correct row read as
wrong by a hundred and an incorrect one read as right. **A row check must hold the
state and re-derive only what construction derives**, and the free check that it did
is that both sides agree on the *value*. Report them side by side; a value mismatch
invalidates the derivative comparison above it.

**Trap four: reading the quantity off the wrong plant.** A per-node reader returns a
vector, and which end the boundary node sits at is a convention. A threshold that
divides by the carbon a *seedling* makes, refereed against the carbon a grown cohort
makes, is off by three orders in the denominator — which was enough here to hide a
cancellation of 0.65 percent behind an apparent residue of 75. **Assert the value
you differenced is the value the expression used**, by comparing it against the same
read on the path side, before believing any ratio built from it.

**Trap five: a reference that is stable and still wrong.** §5.1's step-stability guard varies
the *perturbation*, so it cannot see an error that is flat in it. A whole-run difference that
holds four figures across two orders of perturbation can still be dominated by round-off two
orders further down, and the plateau reads as convergence. Take the difference at four steps
spanning three orders, not three spanning two, and say which end the plateau is at.

### 4.8 Two paths can agree because they share a multiplier

§1's corollary is that agreement with a tangent is not evidence of completeness, and its
mechanism there is a shared *declaration* — a channel imposed to zero in construction is zero on
both paths. There is a second mechanism and it is not covered by that argument.

**A term both paths multiply by the same wrong factor agrees between them and is wrong in both.**
The value can be independently confirmed correct — a rebuilding reference agreeing with the
recorded path on the quantity itself — while what the paths do with it downstream is over-weighted.
Then the tangent and the sweep agree to round-off, every rung of §4 passes, the quantity's own
check passes, and only a reference that never forms the product disagrees.

Two consequences for this report. **Confirming a derivative is not confirming its use**, so a
check on a supplied or derived quantity needs a companion check on what multiplies it. And where
a channel acts once per step rather than once per plant, the count is part of the row: a rung
should assert the number of times a boundary term enters, not only its value.

**The instance, because this section was written without one.** The introduction map's whole
Jacobian is formed both ways at §4.6 and agreed to `7.5e-16` over all 3729 cells — while the map's
seed-mass column was wrong, because the seed's dependent auxiliaries were not re-derived where its
grafted height is written and the leaf area every rate at birth size is scaled by therefore carried
no derivative. **Both sides of that check reach the newcomer's state through the same code**, so
each inherited the same missing row and the check could not see it: it is §1's "disjointness of
code is not disjointness of assumptions" applied to a reference that shares the *object's* forward
function, which is exactly the reference a transpose check is supposed to have.

What did see it was a rebuilding difference — the one instrument that never forms the product. On
the seed-mass column of a leaf-area census the sweep read 0.99 of that reference at a lifetime of
one and **0.38 at a lifetime of three**, while sweep and tangent agreed with each other to
`5e-07`. So the two differentiated paths were three to eight parts in a thousand apart, both about
one per cent to sixty per cent below the reference, and every rung of §4 passed.

Two readings worth keeping. **A tolerance widened around a disagreement hides the class it was
widened for**: the two columns held to a looser bound were the only two of their eight-parameter
class the ladder compared at all, so the other six were unrefereed and the two that were had room
to be wrong. And **the sharpest probe was the smallest fixture**, per §4.7: the seed mass reaches a
size-moment census through birth size and almost nothing else, so it localised in one column what
two amplified columns had carried for months.

## 5. The completeness axis

This axis asks a different question and needs the other reference. It is not a rung above §4: it can
fail while every rung of §4 passes, and it did.

### 5.1 The reference

**A whole-run central difference of the census, rebuilding the strategy from its parameters and
running the model twice.** A rebuild re-runs construction, so the derived quantities move — where
both differentiated paths hold them still.

**It is not exact and its validity is established per fixture, not assumed.** A re-run difference is
unusable at production: a relative step of `2e-07` in leaf mass per area moves a mature stand between
alive and identically zero. So the check on the check is **step-stability** — take the difference at
steps spanning two orders and require the answer to hold its figures. Where it does not, the fixture
is out of this reference's domain and the run is **invalid rather than failing**. Measured on a
one-species two-cohort stand it holds four figures across `1e-05`, `1e-04` and `1e-03` at two- and
four-year lifetimes.

### 5.2 The precondition: one parameter moved

**A perturbation refereeing a column must move exactly one carried parameter**, and must refuse
otherwise. Where a parameterisation derives some carried parameters from others, perturbing the
*input* moves several at once, and the difference then prices a directional derivative while the
column is a basis vector — both finite, plausible, the same sign, and differing by a factor of
**3.2** on the trait that most invites the mistake.

The check is one comparison of the carried set before against after. It costs nothing, it fails
loudly where the alternative fails silently, and it generalises past any particular derivation.

### 5.3 The sweep

For each carried parameter: perturb it alone, assert one-parameter movement, rebuild, difference the
census, compare against the sweep's column, with step-stability as the guard. **A disagreement means
a missing or short term for that parameter. An exact zero means absent or genuinely dead, against
§3.4's declared list.**

Two runs per column against one seeded run for a tangent column, so this is affordable only on a
small fixture — which is the same constraint that bounds what it establishes (§5.4).

**What it found, stated because it is what earns the axis.** With the sweep and the tangent agreeing
with each other throughout, on the leaf-area census at four tenths of a year: the parameters reaching
birth size through the seed's **height** alone cluster at 0.885, 0.901 and 0.895 of the difference —
agreeing to two per cent of each other — while the **two allometric constants**, which also carry the
seed's leaf area, sit at 2.18 and 2.73. The first converges to 1.003 by four years; **the second does
not converge**, remaining between 1.6 and 2.1.

**Two rulings this leaves behind**, worth more than either number. A gradient that is right about the
wrong function passes every rung of §4, because every rung of §4 compares it against something wrong
the same way. And a channel can be real, correctly derived, and still not be the explanation for the
thing it was recovered to explain — recovering the seed's leaf area moves those two columns by 0.3
per cent against a discrepancy over a hundred times that.

### 5.4 What this axis cannot establish

**Its fixture must be small, so a term that only appears at production scale is invisible.** The
guarantee is "complete on this fixture", and that is weaker than it sounds given §9.

**And a one-species fixture is blind to a whole class of defect, which "small" does not imply.**
Where a row is built on coefficients read at one operating point, a stand with no competition keeps
every cohort near that point, so a row that is wrong only *far* from it reads as correct. Measured:
the root-carbon rows agreed with a single-species reference to `1e-06` for both trait sets while the
suppressed species' root allometry was six per cent out on a stand where the two compete. **So this
axis needs a fixture with competition as well as a small one**, and they are different fixtures.

**The step-stability guard of §5.1 is not optional on that fixture, and skipping it once reversed a
decision here.** A suppressed species contributes less, so its columns sit nearer the difference's own
floor: the same column read at four steps from `1e-6` to `1e-3` gave 0.275, 0.131, 0.122 and 0.126 —
a factor of two — converging only at the coarse end. A single reading at `1e-5` was taken as evidence
and was wrong by that factor. §4.7's fifth trap is this exact failure, and the guard now lives inside
the fixture rather than beside it.

**It gives per-column totals, not per-route localisation.** A disagreement says a term is missing for
a parameter, not where. Report 05 §10's enumeration is the localisation aid, and its own caveat
applies.

**It cannot referee a column whose channel is legitimately zero at the fixture's state** — the two
critical potentials under complementary slackness at an interior optimum. Those are correct zeros and
still need their declared reason.

**And state adjoints need none of it.** State derivatives do not run through the construction
lifetimes, so the tangent contraction is sufficient for them. **Traits need the rebuild; states need
only the tangent.**

---

## 6. The fixture

One fixture serves every rung, widened at each. Its assertions are part of the check, and a violated
assertion **invalidates** the run rather than failing it.

**Regime assertions, and they must be evaluated at every solve.** A report taken at the terminal
state of a run says nothing about the states the trajectory passed through, and it is exactly those
states the trajectory rungs measure on:

- every operating point classifies as an interior stationary optimum, **by the branch taken**, not by
  a residual test — which requires the classification to be readable from outside the solver;
- the profit's curvature magnitude above a declared floor, so the argmax multiplier is not amplified;
- soil moisture strictly interior on every layer, the positivity guard never firing, the infiltration
  bracket strictly positive;
- light at every read point at least 100× the floor, and the interpolant's monotonicity guard silent;
- production strictly positive at every cohort, so none sits in the absorbing reserve region;
- no cohort's rooting depth at the column cap, and no layer at the potential ceiling.

**One assertion is a vacuity guard and is the least obvious.** The reserve gate is centred near the
bottom of its range with a width of a tenth, and at full reserves its slope is orders below its slope
in the band — so every derivative running through growth is damped there, and a check passes because
the signal is small rather than because the code is right. **Initialise inside the transition band
and assert the gate's slope above a floor.**

**This assertion is the one a run fixture cannot satisfy by construction**, and that is a finding
rather than a licence to drop it. Measured: constructed patches sit at a gate slope of 0.99, run
stands at 0.04 to 0.12 against a declared floor of 0.4 — an order of magnitude of damping in exactly
the fixtures the trajectory rungs use. **Report it at both levels.** Where it cannot be enforced,
the run is not thereby valid; it is a run whose growth-mediated channels are tested at a tenth of
their sensitivity, and any margin taken there carries that qualification.

**Adversariality, by construction:** heights mutually non-commensurate; **at least one pair crossed**,
so birth-date order and height order disagree; the two species differing by O(1) factors in every
per-species reduction parameter; seeds from a fixed generator, block-normalised by each state's
characteristic magnitude, with residuals reported **per block** as well as in total.

**And a declared run length.** §9's growth in duration means a short fixture under-reports; a fixture
is fast *and* under-reporting, and the trade must be recorded rather than inherited.

---

## 7. Every path switchable, and every switch watched

The systematic answer to the corpus's central hazard — every defect produces a finite, plausible
number — is that each route by which a parameter reaches a census gets a switch, and something fails
when it is off. **If a switch can be thrown and nothing notices, that route is not known to be
right.**

- **The cohort block and both reductions** are columns of §4.2's matrix, so their switch is a column
  of zeros. **The light reduction needs two switches**, because value and slope fail independently.
- **The boundary channels and the initial condition** are §4.6's probes, the cleanest form: one route
  each, so a dropped route gives an exact zero.
- **The census direct term has no other home.** It is not a sensitivity of the state, so no sweep
  produces it and no transpose check touches it. Switch it off; the metrics whose integrand reads
  traits must move.
- **The construction lifetimes are switched by §5, not here.** A switch inside the sweep cannot reach
  them.

**A switch's evidence is its injection.** A suite that defines the machinery for naming an injected
fault and never invokes it has switches on paper. **Count the injections; a rung whose faults have
not been injected has not been climbed.**

---

## 8. Refusal, plumbed to metric level

The leaf reports an honest per-point kind by the branch taken. **The stand must aggregate it, and the
rule is not obvious enough to leave implicit.**

**A refusal has no localisation within a metric.** A sum has no defined value with an undefined term,
so one refused operating point anywhere in one metric's sweep makes **that metric's entire gradient
undefined** — not the cohort's column, not the parameter's entry.

**And metrics are independent**, so refusal is metric-level and no wider. That is the whole design: it
is the difference between losing one column and losing the answer.

**The two output kinds refuse independently.** The profit row survives every degeneracy except a jump
of the argmax and an undefined objective; **the uptake row is the one that ceases to exist.** A metric
seeded only on size states survives a fold that kills a water-coupled one, so refusing them as a pair
throws away the surviving metric for nothing.

**Checks:** inject a refusal at one cohort at one stage and require exactly the water-coupled metrics
to come back undefined; require an undefined metric distinguishable from a zero one at the boundary;
assert the aggregation is not per-parameter, since a partly-populated gradient vector is the shape
that reads as an answer.

---

## 9. What a pinned interior pass does not establish

The pin is a scoping choice, so its price is coverage rather than the reference.

**Unrefereed by anything here:** the constrained-optimum row at either bound, and the wet bound in
particular, where more than half of all pins sit; the substituted-feasible and shutdown branches; the
amplification ceiling on the argmax multiplier; the retention derivative's clamped zero and the
one-way feedback at the potential ceiling; a positivity-guard-zeroed layer with a live uptake adjoint;
the absorbing reserve region; the light floor and the monotonicity guard; the rooting-depth cap.

**The selector is not on that list, and the distinction matters.** The leaf classifies its operating
point by the branch taken and the stand refuses everything that is not interior, so the *decision*
exists and is exercised whenever a fixture leaves the regime. What is unrefereed is the **rows** each
non-interior branch would return, because no run reaches them. A selector that refuses correctly and
one that classifies correctly are different claims, and only the first is established.

**Two consequences worth stating rather than implying.** The stand reaches 1.4 to 2.4 MPa at the
reference configuration under its own dynamics, so the interior pin is a *test condition* and not the
model's normal condition. And the shutdown case is governed by **light**, not water, so no rainfall
sweep reaches it; opening that branch needs a shaded driver, and no plant in this corpus has been run
in shade.

**One defect grows with duration and the fixtures are short.** Between the two differentiated paths,
the allometric pair's residual is essentially fully present one step after the first introduction —
`1.3e-04` against a same-point control seven orders smaller — and then grows and **saturates**, as
roughly the `0.4` power of run length. The growth is not specific to those columns: the control's own
residual grows by a factor of forty over the same range, from round-off to round-off. **So the onset
is a defect and the growth is not**, and a fixture measuring only the growth would mis-rank both.

---

## 10. Order, and what it costs

**Before anything — the floor (§3), and it is nearly free.** The forward model blessed, the objective's
coordinate check, the bit-identity family. No reference, zero tolerance. If any of these fails,
nothing below is worth building.

**Then the one check that gates the meaning of the correctness axis (§4.1).** The factorisation
residual over all state directions, predicted out of sample from a cross-family pair. One state, no
stand, no gradient run — and until it passes, every rung above shares a possible common-mode error on
the water channel.

**Then the two axes, and they are independent.**

On the correctness axis: §4.2's full Jacobian, state block first, then the whole object, at
constructed **and** trajectory states; then §4.3's structural assertions, free once the matrix exists;
then §4.4's reduction faults, each a deliberately broken build with a recorded margin; then rung 4,
structural checks before the contraction; then rung 5, structural checks, then the probes, then the
marginal recruit.

On the completeness axis: §5.2's invariant first, because it is an assertion and everything else on
this axis is invalid without it; then §5.1's step-stability on the fixture; then §5.3's sweep, which
needs no enumeration and localises nothing. **Do it early.** It is two model runs and no machinery, it
is the only instrument that prices a declared zero, and the declaration it prices turned out to be two
orders above its recorded figure.

**Then §7's switches and §8's refusal plumbing**, cheap and systematic, and the direct answer to the
finite-plausible-number hazard.

**The fault-injection runs are the deliverable, not a by-product.** Each table row is one deliberately
broken build, one recorded margin, and one line of evidence that a check does what its name says.

**What is deliberately absent.** No acceptance number is a standing test. A shortfall figure becomes
zero the moment the missing term lands, so it belongs in the change that closes it, as evidence the
change did what it claimed — not in a suite that would then have to be edited to keep passing.
