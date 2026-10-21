We profiled the FF16 reverse pass on top of #679 and odelia#78. The fixture is one species at lifetime 60, birth-date coordinate, lma 0.0825, default `hmat` (the issue used 3), all 32 columns. On it, the spike branch takes `stand_gradient()` from 15 to 5 times the forward run for one metric, and from 27 to 7 times for all five metrics. Those are medians of interleaved runs on Linux x86-64: 0.56 s to 0.19 s, and 1.04 s to 0.27 s, against a 0.038 s run.

Values are unchanged. The gradient differs from #679's by at most 2.3e-12 relative at lifetime 8 and 2.7e-13 at lifetime 30. The plant and odelia test files fail the same tests before and after.

The spikes, the measurement tools, a catalogue of every patch and a review of them are in [aornugent/plant-dev `spikes/plant-677`](https://github.com/aornugent/plant-dev/tree/claude/pensive-johnson-ip4lx3/spikes/plant-677). They will come back as separate PRs, listed at the end.

## Cost per column

The issue times one metric and one column (`1.lma`) and finds finite differences cheaper below about 12 traits. The reverse pass returns every column for the same price, so its cost is shared across all of them. One-sided differences cost at least one run per column, and each run gives every metric. On the fixture above the pass now costs 0.15 runs per column for one metric and 0.22 runs per column for five. Before these changes the five-metric figure was 0.84. Finite differences are cheaper only when fewer than five to seven traits are wanted.

TF24 has 48 columns, and its pass already cost about three runs: 0.06 runs per column, measured on #679 at lifetime 2 with one metric. Most of a TF24 run is `solve_leaf`, and the reverse pass loads those solutions from the recording without solving them again. FF16's run has no step like that, so every operation in its rates is recorded. That is why the same overhead showed as 27x on FF16 and 3x on TF24.

## What reduced the cost

To separate the causes, each mechanism was switched off on its own in the final build and the instructions counted again. Numbers are callgrind instructions inside the gradient at lifetime 60. With everything on, the gradient is 1,803M instructions for one metric and 2,694M for five, against 375M for the run.

| switched off | 1 metric | 5 metrics |
| --- | --- | --- |
| the crown integral recorded as one statement | +19% | +31% |
| 12-byte tape operations | +11% | +10% |
| one active `Patch` for the whole reverse pass | +7% | +5% |
| one sweep per independent metric seed | 0 | +11% |
| the field reduction recorded as one statement per knot | +2% | +6% |
| the excluded field built only below the boundary node | +1% | +1% |

These six account for about a fifth of the reduction at one metric. The rest comes from no longer recording copies of active values. That change has no one-line switch, but measured in sequence it took the one-metric ratio from 14.5x to 8.7x at lifetime 8.

Most of the reduction came from copies. In XAD, constructing an active scalar from another records a statement. In #679 roughly half the crown quadrature's statements were copies: named intermediates, stage states copied into the System, and accessors returning a parameter by value. Taking references, moving stage states in, and folding the crown shape into per-point weights removed them. The tape analysis below also found duplicated work: the growth fraction recomputed the reproduction fraction, and heartwood area recomputed sapwood area.

The deep-crown integral evaluates the light spline at 21 points per node and is most of FF16's run. Each spline read is linear in the knot values and slopes of the span it falls in. odelia's `hermite_spline::read_linear` returns those four weights. So the integral's value and its partials can be computed in double and recorded once, through odelia's `record_with_derivatives`, with rows on the knots, on `a_p1`, `a_p2`, height and leaf area. The hand-written part is the derivative of the leaf rate `a_p1 E / (E + a_p2)`. Recording costs about the same either way, because XAD records efficiently. The saving is in the sweep, which reads each recorded operation once per metric. That is why the change is worth more at five metrics.

XAD stores each operation as a multiplier and a slot index. `XAD_REDUCED_MEMORY` keeps them in two arrays, 12 bytes per operation against a padded 16, and the sweep is limited by reading that array.

The reverse pass splits the recording into ranges of constant state width. With `node_density_in_birth_date` a node is introduced at almost every step, 118 times in 146 steps here, and each range rebuilt its active `Patch` from scratch twice, at about 540k instructions each. One active `Patch` now serves the whole pass, and `Patch::assign_from` writes the double patch's state and nodes into it at each width.

The adjoint is linear in its seed, so a metric whose seed is a combination of others' seeds has the same combination of their adjoints, in the state rows and the parameter rows. `offspring_production` weights the fitness integral by the birth rate at each introduction. At a constant birth rate its seed is a multiple of `net_reproduction_ratio`'s, so each species needs one sweep for its two fitness metrics. That saves 11% at five metrics and 20% at four species with eleven metrics.

## How we measured

The ratio was counted in instructions, with callgrind collecting only inside `census_trait_gradient_ff16`, divided by the instructions in `SCM::run`. Wall clock varied too much between runs to separate one change from the next, so it was used only to confirm, in interleaved runs. Every number is at lifetime 60. At lifetime 8 the seedling's height averages 82% of the canopy top over the run, and changes that depend on canopy structure barely register.

Before reading a number, each build was compared with the previous one: identical values, the count of finite and of bit-identical gradient entries, the largest relative change, and any entry that had dropped to zero. Both test suites ran on both builds and their failure sets were compared. One build that matched its baseline exactly turned out to be stale, and clearing `src/*.o` became part of every build.

The gradient costs about statements × (record + metrics × sweep). XAD's per-statement costs were measured on a small kernel: about 106 instructions to record a statement, about 10 to sweep it plus 8.5 per operation. The profile was then grouped into regions as calls × cost per call.

`tools/live*.cpp` records one rate evaluation and walks it backwards from the rates. It marks each statement as dead or read, marks those that depend on parameters alone, and lists each operand as a parameter, state, spline knot or intermediate. Most of the changes above came from reading that list.

## What did not help

| tried | result |
| --- | --- |
| Vector adjoints, `AReal<double, 5>`, one sweep for five metrics | 1.5x slower than five scalar sweeps |
| One backward walk carrying five adjoints per slot | Same time as five sweeps; each update is a scattered load and store either way |
| Preaccumulating the crown on a local tape | Exact, and costs about what it saves below three metrics |
| `XAD_TAPE_REUSE_SLOTS` | Recording 64% slower |
| Skipping zero multipliers in the sweep | Sweep 5.5% faster, recording 5.6% slower |
| Moving rates out of `Internals` on write-out | Not done: a later reader would get a value with no derivative, and nothing would report it |
| Registering only the requested traits | 3.5% at one metric, 5.6% at five, since parameters are a small part of the tape |

## What is left

Recording is now about 3.9 times the double evaluation and 80% of a one-metric gradient. About 30 points of that is XAD's per-statement bookkeeping, and each operation is stored twice, first in a stack buffer and then in the tape. The RK stage combinations are also recorded, although they are fixed linear algebra. Each of these is an estimated 5–8%.

A step's recording reads only the recorded forward state, never the adjoint, so steps can be recorded on other threads ahead of the sweep. Recording one step tape on 4 threads ran 2.8–3.1 times faster than serially, which would put one metric near 1.7 runs. It needs thread-local XAD tapes, which cost 7–10% more instructions on one thread. It also needs `thread_local` scratch, errors passed back to the main thread, and work handed out across ranges, since a range is about one step long.

On the question in the issue: supplying rows computed in double through `record_with_derivatives` gave the crown's saving. Preaccumulating on a local tape cost about what it saved. We did not try source transformation.

## How it will land

A review of the spikes (`REVIEW.md`) found two things to change before they become PRs.

The crown is implemented twice: the active scalar has its own function, which must match the forward one bit for bit. It will become one loop at both scalars, with the partials and the recording compiled in only for the active scalar. The spline also keeps its span coefficients active although nothing reads them. It will store them in double and record an active read as one statement over its span's knots. That removes 256 dead statements per field build, and two odelia patches that only made those statements cheaper.

Two spikes will not come back. The excluded-field cut threads a parameter through three environments for 1%. The boundary-interval rows were neutral at one metric. The seed basis will shrink to detecting rows that are multiples of another.

The PRs, in order:

1. plant: record no copies on the active rate path.
2. odelia: 12-byte operations, and no `memmove` per statement.
3. odelia: active spline reads over the knot data.
4. odelia: `record_with_derivatives` on parallel arrays, gathered in one pass.
5. plant: the crown integral as one statement.
6. odelia and plant: one active System per reverse pass.
7. odelia: one sweep per independent metric seed.
