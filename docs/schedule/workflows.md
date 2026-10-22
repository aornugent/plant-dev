# What the schedule serves: site selection and the eco-evolutionary loop

**Status.** A design, not built. It defines the two workflows the scheduler serves, closely
enough to say what the scheduler must guarantee in each. It sits above `refine.md` (one
recording, certified) and `rows-entries.md` (a table of rows and entries), and changes what a
row is. It was written after `../review/eeo-derivatives.md`, `../review/site-selection.md`,
the Overstorey post on fitness in pulse-driven environments (PR #43, 12 Oct) and Chesson
(2017). Numbers are measured unless marked *estimated*, *derived* or *judgement*.

**The answer, in two decisions.**
1. **Questions come in two kinds, and the kind sets the driver.** A *history* question asks
   what selection the observed community has met under its site's actual weather. The record
   is the forcing, not a sample of it, and there is no weather-sampling error. A *regime*
   question asks what happens under a climate: who persists in the 2060s, where the ESS sits.
   It needs many records, and their sampling error dominates the discretisation error by
   about 10×, because ε was defined as a tenth of the spread between records.
2. **A row is a set of standard patch recordings, each from a disturbance to the horizon, on
   drivers fixed when the row is made, at one seed rain.** A history row slices the site's
   record at several disturbance dates. A regime row draws independent records. Today's row
   is the case of one recording. Every reading, whether an entry, a gradient, a calibration
   step or a step along an evolutionary path, is made on those fixed recordings, so it is a
   difference that shares its weather.

Everything else follows. The refine loop still certifies each recording, unchanged. What is
new is a seed rain shared across recordings, an estimate across them, and an entry that
returns its offspring by date.

## Triage: 3

It sets what `refine_row()` takes and returns, what every entry of the table reports, and
which of `OBJECTIVES.md`'s guarantees hold in each workflow.

## 1. The objects

| object | what it is | made | cost now |
|---|---|---|---|
| driver | a daily rainfall record and a disturbance regime; for a site, its observed record (about 130 years in Australian gridded products, *unchecked*) and projections | once per site or regime | — |
| recording | one patch from disturbance to the horizon under a slice of a driver, with the residents' field recorded | by the refine loop, certified | about 5 F with the balance (`site-selection.md` §4) |
| row | the recordings of one site or regime, at one seed rain b per resident | once; held while outer loops move | M recordings |
| entry | a strategy walked on every recording of a row: ln R′ with its estimate | 30,000 per table per record | 0.36 F per recording (`rows-entries.md`) |
| path | a sequence of rows along θ (the loop) or along c (calibration), on the same drivers | one per root or calibration | steps × M |

F is one TF24 forward run, about 49 s on long drought at an absolute tolerance of 1e-4
(roadtest E7).

## 2. History and regime

| | history | regime |
|---|---|---|
| asks | is the observed community at selection balance? what selection acts on it? which observed strategies could invade it? | who persists under a projected climate? where is the ESS? how does it move with climate? |
| driver | the site's own record | independent records from a weather generator fitted to the climate, or projections |
| disturbance dates | slices of the one record, at dates whose 40-year horizon ends by the present | independent draws, one per recording |
| sampling error | none: the record is the data | dominant: one 41-year record carries an sd in the invader's `lma` gradient of about 2.0, against ε = 0.20 (`eps.csv`: ε is a tenth of the sd over eight seeds) |
| what M buys | quadrature over disturbance dates on one record | the standard error of the climate's answer |
| workflow | the site residual and its calibration | the EEO loop; projections from the table |

**A history row is a quadrature, not a sample** (*derived*). A patch disturbed at t0 meets the
record's calendar weather at every age: a 1982 drought hits a seedling in a patch disturbed in
1980 and a sapling in one disturbed in 1970. Fate is piecewise smooth in t0, as it is in birth
date (`dynamics.md`), so the refine loop's halving estimate carries over to the t0 axis: drop
every other recording, and the difference estimates the error.

**A regime row's error falls as 1/√M** (*derived*). For levels of g in `lma`, getting the
standard error to ε needs about 100 records. Differences between strategies on the same
records cost 5–14× less in the Overstorey toy (*estimated*: a toy, not TF24), which puts M at
about 7–20 for differences. Today's ε then plays its intended role: discretisation stays
under a tenth of the weather's spread, and the weather's error is reported beside it.

**Chesson's asymptotic trajectory is why the history row is legitimate** (*judgement*).
Under a nonstationary record the community converges on a trajectory set by its weather
history, whatever its starting state (Chesson 2017). Each recording starts from bare ground
at its disturbance, so it needs no burn-in. The observed community is read as the stand
that trajectory reaches, and the residual's "disequilibrium" splits in two. Ecological lag
is in the model, since the recordings carry the record's trend. Evolutionary lag is what the
residual reads.

**What fitness is on a row** (*derived*, checked on a toy). Seeds land on patches of every
disturbance date. When drivers are independent (regime), the invader's fitness is the
arithmetic mean of R′ over recordings at a common b, which is exact (`theory.md` D.3). When
recordings share one calendar record (history), cohorts share droughts, and the arithmetic
mean overstates fitness. On the Overstorey toy, a strategy scaled to a mean output of 1 has
a growth rate of −0.13 to −0.39 per year when followed through its seed bank, and persists
only at mean outputs of 4.7–10.8 (`harness/renewal_toy.R`). The right quantity is a renewal growth rate, built
from each cohort's offspring by date. For trees, generations are about as long as the record,
so a history row reads one generation, and the mean over landing dates is the quantity. The
renewal matters where generations are much shorter than the record: annuals, and the
semi-arid perennials of the Overstorey post. **Either way, an entry returns its per-node
offspring by date, not only their sum,** so both can be formed without a second walk.

## 3. Site selection

The applied workflow (`site-selection.md`). Its outputs are within-row readings, and a
calibration that pools rows.

1. **Rows.** For each site, the residents (observed traits, defaults elsewhere) and the
   site's driver. A history row has M recordings at disturbance dates across the record; a
   regime row has M independent records. Balance one b per resident on the mean over the
   recordings, to |F| < 0.02, by secant (one resident) or Broyden (several). Certify each
   resident's g on the row.
2. **Entries.** For each strategy of the pool, walk every recording on the row's entry
   schedule (`rows-entries.md` candidate C). Report Δ_ij = A_ij − A_ii, the difference from
   the resident, with its estimate, plus the per-node offspring by date.
3. **Readings,** all linear algebra on the table: balance (A_ii ≈ 0), the ESS test against
   the pool (A_ij ≤ 0), selection (g_i), its split along and across the observed spectrum,
   home advantage, and who could invade.
4. **Calibration.** The trade-off slopes enter linearly after the sweep, so a fit holds the
   rows. Physiology constants take a Gauss–Newton step on the entries' values, with ∂A/∂c
   from each entry's sweep (first order), not on g (which needs chords). Rows are re-recorded
   only where the check at the fitted constants fails.
5. **Projection.** New rows for the same residents under projected drivers (regime rows); the
   pool walked on them.

**What the readings compare decides the error target.** Steps 3 and 4 read differences
within a row: g, Δ_ij, row maxima, home advantage. They share the row's recordings, so the
weather and much of the field error cancel. Only transfer between sites (A_ij − A_kj), the
rank of A, and pooled calibration read levels across rows. Those carry each row's
discretisation estimate and, for regime rows, its sampling estimate, reported separately.

**Its requirements of the scheduler:**

| | requirement | quantity |
|---|---|---|
| S1 | each resident's g within the invader's ε, and F to 0.02 | `lma` 0.20, `a_dG2` 0.050, at least 0.01 |
| S2 | each Δ_ij within ε, with its own estimate | 0.025 |
| S3 | every number reports discretisation and, on regime rows, sampling error, apart | per number |
| S4 | a row is held across calibration steps while its estimate passes; its answers are smooth in c on the held grid | 1–3 Gauss–Newton steps |
| S5 | throughput, not latency: rows and entries are independent | 100 sites × 300 strategies × M recordings |
| S6 | no throw for any pool strategy, including hydraulics and phenology unlike the residents | 30,000 entries per record |
| S7 | several residents per row | about 3 |
| S8 | a race flags a resident: values only | `rows-entries.md` V6 |

**Scarce resource: invader member-steps, times M.** Entries are 92% of a table at M = 1
(`site-selection.md` §4), and every recording multiplies them. At M = 8 the table is about
99,000 F, 1,350 core-hours (*estimated*), against 170 at M = 1. The levers are, in order: the
entry's nodes (candidate C saves 40.6%), M (differences instead of levels), and the
tolerance (V1).

## 4. The eco-evolutionary loop

The forward programme (`eeo-derivatives.md`). It is a regime workflow: an ESS is defined
under a climate, not under one history.

1. **A path** holds the drivers (M records) and a row's schedule.
2. **A step** at θ: balance b to |F| < 0.02, warm-started from the last step; record; read g
   (an invader sweep on each recording, averaged); optionally F_θ (a resident sweep).
3. **Move** θ along M g (the canonical equation), or by Newton toward g = 0 using J_g.
4. **Classify** a singular point by chords: the invader Hessian, and J_g as a fixed-b
   Jacobian plus a rank-one correction in b (`theory.md` A.3).
5. **Continue** in c: dθ*/dc by the implicit function theorem, checked against roots
   re-solved at ±5% mean rainfall.

**Its requirements of the scheduler:**

| | requirement | quantity |
|---|---|---|
| E1 | along a path the error is a smooth function of θ: a held grid gives a bias, which moves the root slightly, and jitter, which makes false roots | step jitter under ε/3 (0.04ε rms today, `refine.md`) |
| E2 | a chord's two ends share drivers and grid, so the curvature's error is set by the difference of g, not by its level | at r = 1e-2 and \|H\| ≈ 193, 10% in curvature needs δg ≈ 0.27, about ε |
| E3 | a rebuild is an explicit event on the path, with the offset between grids measured at the switch | the rule is open: d\* = 0.5 in ln J is a placeholder |
| E4 | g in absolute terms near g = 0, so the root is located to δθ ≈ ε_g/\|J_g\| | ε_g 0.20 |
| E5 | latency: steps are sequential; the M recordings of a step run in parallel | about 150 F per root per record (*estimated*) |
| E6 | a race or cliff stops gradient-following and reports one-sided values | constant rain (E8) |

**Scarce resource: wall-clock per step.** A root takes tens of sequential steps. The ensemble
does not lengthen a step if its M recordings run on M cores, since they couple only through
the shared b's secant.

## 5. The two side by side

| | site selection | eco-evolutionary loop |
|---|---|---|
| kind | history (residual), regime (projection) | regime |
| what moves | c, the physiology and trade-offs; rows are held | θ; c for continuation |
| what is read | values and within-row differences; g at residents | g near zero; its chords |
| held | the row's grid and drivers across c | the path's grid and drivers across θ |
| error that matters | per number, certified | smooth in θ; differences along chords |
| curvatures | none | needed to classify |
| entries | hundreds per row, far from the residents | the diagonal and its neighbours |
| bound by | throughput | latency |

**The same property under two names.** Both hold a grid and its drivers while an outer
variable moves, and need the answers smooth in that variable: c for calibration, θ for the
loop. `rows-entries.md` deleted R4's radius in θ and kept a hold across c. The loop needs the
radius back, and calibration needs its counterpart in c. Both are measured the same way: an
answer on the held grid against a rebuilt one, as a function of the distance moved.

## Requirements ledger

- **R1 Accurate:** S1, S2; E4. Each number within its ε per quantity (`eps.csv`).
- **R2 Honest:** S3. Discretisation and sampling are each estimated per number, and reported
  apart.
- **R3 Calendar weather:** history rows place the record's droughts at their dates; regime
  rows draw independent records. Quantity: about 130 years of record per site (*unchecked*),
  40-year horizons.
- **R4 Held and smooth:** S4, E1–E3. Answers on a held grid are smooth in the moved variable;
  rebuilds are explicit.
- **R5 Never fails:** S6, E6.
- **R6 Performant:** S5 (throughput) and E5 (latency). About 12,400 M F per table per record;
  about 150 M F per root (*estimated*).

**Challenged upward** (each changes `OBJECTIVES.md`, so each is yours):
1. **ε gains a partner.** Today's ε bounds discretisation. On regime rows a sampling error is
   reported beside it, never folded in. Default: adopt.
2. **The judged quantity is the difference, where the reading is one.** Δ_ij, not A_ij;
   levels only for readings across rows. Default: adopt for entries.
3. **Curvatures return, for the loop only.** `rows-entries.md` deleted them; E2 needs them.
   Default: return them to the loop's judged set.
4. **The radius in θ returns, for the loop only** (E3), with a counterpart in c for
   calibration (S4). Default: adopt.

**Scarce resource:** for the table, invader member-steps × M; for the loop, sequential
wall-clock per step. Both are set by M, so M is the first number to measure.

## The floor

Today's design, `rows-entries.md` candidate C on one 41-year synthetic record per site (M = 1).
It fails R3: it cannot place a site's 1982 drought at 1982, and it reads 40 of a site's ~130
years. It also fails R2 on regime questions: one record's g carries a sampling sd of 2.0
against ε = 0.20, reported as converged.

## Candidates

**A [first thought], a continuous calendar recording** (move 6).
- Commitment: every row is one long patch under calendar weather, with introductions at every
  spell over a window after a burn-in; the patch-age run is its special case.
- Pays for: R3 everywhere, including sites with no stand-replacing disturbance.
- Costs: six new parts (online introductions, retiring old cohorts, a burn-in certificate, a
  batch-means estimate, tape checkpointing, the renewal), and the loss of every constant the
  bank measured on 40-year patch runs (0.5, u_q, ε).
- Wins when: sites have no stand-replacing disturbance (the semi-arid work of the Overstorey
  post), or generations are much shorter than the record.

**B, rows of standard recordings at disturbance dates** (move 7).
- Commitment: a row is M disturbance-to-horizon recordings on fixed drivers at one b.
- Pays for: R3 for disturbed systems, R2 by an estimate across recordings, R4 by fixing the
  drivers with the row.
- Costs: M× runs; three new parts (a b shared across recordings, the estimate across them,
  offspring by date per entry).
- Wins when: a stand-replacing disturbance bounds a patch's life within a horizon the refine
  loop has measured (40 years, the bank).

**C, one record, with the weather's spread as an error bar** (move 1).
- Commitment: rows stay at M = 1. Each climate's spread between records is measured once, as
  ε was, and attached to every reading as its sampling error.
- Pays for: R2 at 1× cost.
- Costs: history questions cannot be asked (fails R3), and nothing averages the sampling
  error down.
- Wins when: readings are signs and rankings within a row that hold across records. The test
  is `eeo-derivatives.md` §5.3, fluctuating selection between records.

**Winner: B.**
- A pays for R3 everywhere, but for disturbed systems B delivers the same readings with no new
  scheduler part, keeping every constant the refine loop rests on.
- C costs 1/M of B and fails R3, which the residual needs: a history question is the site
  residual's question.
- **C is still the first experiment.** Its test (selection's spread between records) measures
  the sampling sd that sets M for B.

## The commitment

**Every reading is made on recordings fixed when its row or path was made.**

Kept true by: the row owns its drivers (a record with its disturbance dates, or a generator
with its seeds). `walk_entry(row, strategy)` and `step(path, θ)` take a row or a path. No
function takes a driver and a strategy together, so a reading on fresh weather cannot be
expressed.

## Kill question

Assumption whose falsity makes this unnecessary: that one record's answer is not what the
workflows want.

Argued false from the ledger. History questions need calendar dates, which one patch-age
record cannot give (R3). Regime questions carry a sampling sd 10× ε on one record (R2).
**Survives.**

## Consistency pass

- B's cost is M× and the loop is latency-bound (E5). The M recordings of a step are
  independent given b, so they run in parallel: a step's latency is one recording's plus the
  secant's coupling. No contradiction.
- B keeps the refine loop's constants, measured at M = 1 on 40-year patch runs. A history
  recording is exactly such a run, on a slice of a real record. The records are new, so the
  constants need the bank's check on them (V1–V3), as any new record would.
- The renewal (§2) is needed where generations are short relative to the record. That is A's
  "wins when", not B's. B only returns offspring by date, so A's quantity can be formed later
  without changing the entry's walk.
- S4 holds rows across c, E3 rebuilds across θ. One mechanism, a held grid with a measured
  distance, serves both.

## What survives deletion

| part | ledger line |
|---|---|
| a row's drivers fixed at creation | R4, R2 (differences share weather) |
| M recordings at disturbance dates | R3 |
| one b per resident over the recordings | R1 (S1's balance) |
| the halving estimate across recordings (history) | R2 |
| the sampling estimate across recordings (regime) | R2 |
| per-node offspring by date in each entry | R1 for fitness under shared weather |
| curvatures and the radius, for the loop | R4 (E2, E3) |

Deleted: burn-in, retiring old cohorts and tape checkpointing (A's parts) until a site
without disturbance is in scope.

## What this settles

- No run starts from anything but bare ground at a disturbance, so no burn-in exists to
  certify.
- No reading mixes weather: every difference shares its recordings.
- The refine loop is unchanged per recording.

## What this makes hard

- **Cost × M.** At M = 8, 1,350 core-hours a table per record (*estimated*). Cope by measuring
  M first (C's test), by reading differences, and by coarser per-recording grids. Averaging M
  recordings shrinks their independent errors by √M but not their shared bias, which Q − e
  removes (*derived*); that is untested.
- **b over a long record is one number.** Under a trending record the regional seed rain
  drifts, and Chesson's trajectory would let b vary in time. A b per era of disturbance dates
  is the cheap correction; it is not designed.
- **History rows end at the present.** Disturbance dates must leave a full horizon inside the
  record, so the most recent decades are read only through older patches. A history row reads
  the selection that shaped today's community, not the selection acting on next year's
  seedlings. That needs projected weather: a regime row.

## Kill condition

Sites with no stand-replacing disturbance, or with intervals far beyond the measured
horizon, hand off to candidate A: the continuous recording of the Overstorey post (plant#519),
with the renewal growth rate as fitness.

## The build, in order

Nothing below is started; each step is small and testable.

1. **Measure M:** C's test. Selection vectors on eight records of one climate; their spread
   per trait, for levels and for differences between two strategies.
2. **A history recording:** one TF24 patch on a slice of a real site record, run by
   `refine_schedule` unchanged. Check the bank's constants hold (V1–V3 of `rows-entries.md`).
3. **A row of M recordings:** b balanced on the mean; the halving estimate across disturbance
   dates; entries returning per-node offspring by date.
4. **The diagonal:** at a resident, the row's mean ln R′ against its mean ln J − ln b.
5. **The loop's hold:** an answer on a held grid against a rebuilt one, as a function of the
   distance moved in θ and in c. That sets E3's rule and S4's.

## References

- Chesson, P. (2017). AEDT: a new concept for ecological dynamics in the ever-changing world.
  *PLoS Biol.* 15: e2002634. doi:10.1371/journal.pbio.2002634
- Overstorey: How to calculate fitness in pulse-driven environments. Unmerged post, PR #43,
  12 October 2026 (shared artifact).
- `../review/theory.md` D.3 (independent records per patch), A.3 (the loop's Jacobians);
  `../review/eeo-derivatives.md`; `../review/site-selection.md`; `refine.md`;
  `rows-entries.md`; `harness/schedule/data/eps.csv`.
