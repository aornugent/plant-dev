# The requirement (for a clean-sheet sketch; no solution is given here)

## The problem

plant (an R package with a C++ core in `inst/include/plant/`) integrates a
size-structured forest stand with odelia (a header-only ODE library in
`inst/include/odelia/`): Cash–Karp 4(5) with error control, a recording of
every step (`step_record` rows with `solved_row` slots holding what each rate
evaluation's inner searches found), walks that replay a recording at a moved
parameter (invasion fitness of an invader in the resident's recorded field),
and a reverse sweep (adjoint) that tapes each recorded step with XAD at an
active scalar.

The state is y = (x_1 … x_N, s): N ≈ 108 node blocks of ≈ 20 components each
(one block per cohort node of the TF24 strategy), then the soil and
accumulators. Each node's rates read its net production P_i through a smooth
positive part σ(P) = (P + √(P² + η²))/2 with η = 1e-4: nearly a kink at the
step's scale. Every node reads a shared field E (the light field's knot data and
the soil's state), which a full evaluation builds from the whole state. One
node's rates in a given field cost ~15 µs (a leaf optimisation); a full
evaluation ~4.4 ms. On the 40-year long-drought stand 9247 node steps hold a
sign change of P_i, in 726 of 14844 steps; 14 hold a pair (two sign changes)
inside one step, most at a rain pulse's onset, where no stage reading need hold
the other sign.

A Cash–Karp step across such a kink has local error h²·a·ψ(u*) whose mean over
the crossing's place u* is zero, so J (offspring production) is unharmed, but
its derivative in a trait θ is a staircase: gradients jump as crossings pass
stages, and curvatures from chords are unstable.

## What must hold (with quantities)

- R1, reproducible gradients: nudging the tolerance ±5% moves each gradient
  entry by under ε/3 (ε per trait from a table; lma's 0.087 resident).
- R2, stable curvatures: the second difference of ln J in ln lma at r = 1e-2
  spreads under ε/3 across nudges.
- R3, continuous on a frozen mesh: no jump above 1e-8 in ln J as θ moves.
- R4, the reverse sweep returns the derivative of the run's own discrete map
  (the user's choice), checked against central differences of a pinned replay.
- R7, J′ = J to the last bit for an invader whose traits equal the resident's,
  walked on the resident's recording.
- R8, least runtime: forward at most +6%, sweep at most +7.3% over the unsplit
  run.
- R9, least code.
- R12, odelia (the general ODE library) may not say "node"; plant owns nodes.
- The user chose: plant owns the treatment of each node's crossing (which node,
  its field, its rates in that field, its pieces, its record); odelia owns the
  step's numerics (the dense output, integration of a block in pieces with the
  step's tableau, locating a sign change). The treatment is off by default and
  everything repeats bit for bit when off. Only TF24 uses it; TF24f (a variant
  whose newborn is found by an optimiser no recording holds) must not.
- Walks must not re-treat crossings in the resident's recorded field (the
  recording holds the field only at the run's own stage times).
- Splits are counted per node per run, for diagnostics.
- The sweep must tape exactly the map the forward computed, with each crossing
  moving with θ (a crossing held where the run put it leaves the gradient's
  error first order in h).
- Only `double` crosses the R boundary; active (AD) types live inside one call.
