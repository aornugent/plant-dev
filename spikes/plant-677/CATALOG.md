# traitecoevo/plant#677 spikes: catalogue

Every patch in `plant/` and `odelia/`, in the order it was measured. The plant
series applies on plant#679 (`git fetch upstream pull/679/head`), with plant's
pins relaxed to odelia >= 0.8.0 and phylloptim >= 0.10.3. The odelia series
applies on odelia `1e0f0f0`.

**Kind** says what a patch does to the numbers:

- **bit-identical**: gradients unchanged in every bit.
- **rounding**: values unchanged and gradients moved at rounding. The final
  arm against B is within 2.67e-13 relative at lifetime 30 and 2.29e-12 at
  lifetime 8; no entry dropped to zero or went non-finite.
- **plumbing**: no numerical effect by construction.

The effect column is callgrind instructions inside the gradient at lifetime 60
unless it says otherwise. Earlier rows were measured at lifetime 8; see the
README.

## plant

| # | change | kind | effect |
| --- | --- | --- | --- |
| 0001 | Fold the crown shape into per-node weights on the active path | rounding | 14.5x → 10.8x one metric (lifetime 8) |
| 0002 | Stop recording copies of active values on the rate path | rounding | → 9.6x (lifetime 8) |
| 0003 | Two statements per crown quadrature node | rounding | → 8.7x (lifetime 8) |
| 0004 | Take a moved stage state without recording a copy (with odelia 0004) | bit-identical | → 7.2x (lifetime 8) |
| 0005 | Move the light field's knot data into the spline (with odelia 0005) | rounding | → 7.0x (lifetime 8) |
| 0006 | One statement for each half of a node's competition read | rounding | → 6.7x (lifetime 8) |
| 0007 | Halve the captured reduction inside the knot sums (with odelia 0006) | rounding | → 6.6x (lifetime 8) |
| 0008 | Record nothing the rates do not read: a zero above a crown, the height scan's copies, the excluded field above the boundary node (from the liveness pass) | bit-identical | 14.5x → 6.3x at lifetime 60, with 0001–0007 |
| 0009 | Supply the deep-crown integral's rows: the value and partials in double, one statement per crown (with odelia 0007) | rounding | 6.3x → 5.8x one metric; 11.7x → 9.6x five metrics |
| 0010 | Gather the crown's rows per knot rather than per span (with odelia 0008) | rounding | → 5.75x / 9.45x |
| 0011 | Supply the field reduction's rows; write rows into presized scratch (with odelia 0009) | rounding | → 5.50x / 8.88x |
| 0012 | Gather the crown's rows over the knot range it reads; emit no zero rows (with odelia 0010) | bit-identical | → 5.24x / 8.62x; crown 8,458 → 6,967 instructions per call |
| 0013 | No recorded copies or repeats among a node's parameter reads | rounding | node rates 690.8M → 652.7M |
| 0014 | The field reduction's crossing interval as rows on the two nodes | rounding | sweep −6% per metric, recording +4%; pays only at several metrics |
| 0015 | `Patch::assign_from`: a rebind written in place (with odelia 0011) | bit-identical | 237 rebinds → 2; 5.13x / 8.32x → 4.80x / 7.98x |

## odelia

| # | change | kind | effect |
| --- | --- | --- | --- |
| 0001 | 12-byte operations (`XAD_REDUCED_MEMORY`); one clear per walk | bit-identical | 8.7x → 8.0x (lifetime 8) |
| 0002 | Copy a statement's operations without `memmove` | bit-identical | → 7.5x (lifetime 8) |
| 0003 | Read an active cubic's slope at its value, not as a second read | bit-identical | → 7.3x (lifetime 8); removed 90% of zero multipliers |
| 0004 | Move each stage's state into the System | bit-identical | with plant 0004 |
| 0005 | Take a spline's knot data by value | rounding | with plant 0005 |
| 0006 | One statement per cubic coefficient | bit-identical | with plant 0007 |
| 0007 | `read_linear`: a cubic read as the four coefficients it is linear in; supplied rows pushed as one run | bit-identical | with plant 0009 |
| 0008 | `read_linear` weighs a read on the knot values and slopes | bit-identical | with plant 0010 |
| 0009 | `record_with_derivatives` over parallel arrays, written into presized scratch | bit-identical | with plant 0011 |
| 0010 | Gather supplied rows in one pass; test finiteness through `d*0 + x*0` | bit-identical | with plant 0012 |
| 0011 | One `active_system` per descent, re-seated at each width | bit-identical | with plant 0015 |
| 0012 | Carry only a basis of the metric seeds; rebuild the rest at the end | rounding (worst 8.6e-14) | five metrics 2997M → 2694M; 4 species × 11 metrics −20% wall |

## Where it ends up

Lifetime 60, one species, the gradient divided by its own forward run:

| arm | 1 metric, instructions | 5 metrics, instructions | 1 metric, seconds | 5 metrics, seconds |
| --- | --- | --- | --- | --- |
| B: plant#679 + odelia 0.8.0 | 14.5x | 29.5x | 0.56 s (14.5x) | 1.04 s (27x) |
| F2: everything above | 4.80x | 7.18x | 0.18–0.20 s (4.8–5.2x) | 0.25–0.27 s (6.4–7.2x) |

The seconds are medians of three interleaved rounds against a forward run of
about 0.038 s.

## What each mechanism is worth now

The history above credits each patch with whatever moved when it landed, in
sequence and partly at lifetime 8. Switching each mechanism off on its own in
the final build (F2) and counting again, at lifetime 60:

| switched off | 1 metric | 5 metrics |
| --- | --- | --- |
| crown integral as one statement (plant 0009, 0010, 0012) | +19% | +31% |
| 12-byte operations (odelia 0001) | +11% | +10% |
| one active System per descent (plant 0015, odelia 0011) | +7% | +5% |
| seed basis (odelia 0012) | 0 | +11% |
| field reduction rows (plant 0011, 0014) | +2% | +6% |
| excluded field built only below the boundary node (part of plant 0008) | +1% | +1% |

The remainder, about four-fifths of the one-metric reduction since B, is
copies no longer recorded. `REVIEW.md` turns this into a PR plan.

## Measured and not kept

| proposal | result |
| --- | --- |
| Vector adjoints (`AReal<double, 5>`), one sweep for five metrics | 1.5x slower to sweep than five scalar sweeps |
| One walk carrying five adjoint lanes per slot (lifetime 60, bit-identical) | 1.39 ms either way; the scattered update is the cost, not the walk |
| Preaccumulating the crown on a local tape | Exact; its local sweep costs what each metric saves; break-even near three metrics |
| `XAD_TAPE_REUSE_SLOTS` | Recording 64% slower, sweep 2% faster |
| Skipping zero multipliers inside XAD's sweep | Sweep −5.5%, recording +5.6%; fixed at the source instead (odelia 0003) |
| Moving rates out of `Internals` on write-out | Saves 637 copies per evaluation, but a later reader would get a value without its derivative and nothing would raise |
| Registering only the requested traits | Exact on the kept columns; −3.5% at one metric, −5.6% at five |
| Forward tangents per trait (`census_trait_tangent`, batched by four) | 1.8x for one trait, 2.5x for four, 30.8x for 32; fast per trait, but the multi-trait gradient is the point |
| Gathering rows with `push_back` onto a `static std::vector` | 199M instructions in non-inlined `emplace_back`; presized scratch instead |

## Left on the table

| lever | size | status |
| --- | --- | --- |
| Record step tapes on worker threads ahead of the sweep | 2.8–3.1x recording speed-up on 4 threads; about 1.7x the forward run at one metric | Measured (`tools/parallel/`); needs thread-local tapes (+7–10% single-threaded instructions), `thread_local` scratch, worker errors raised again on the main thread, and a pipeline across widths |
| XAD records every operation twice (stack buffer, then chunk) | 5–8% | Not built |
| RK stage combinations off the tape | ~9% of statements, ~12% of operations; 5–8% | Not built |
| Dead statements in the field build: unread span coefficients, knot positions | ~2.6% | Not built |
