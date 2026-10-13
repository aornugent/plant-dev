# D: silent blown-up TF24 adjoint on long drought

Scripts beside this file. Runs in `RUNS=.../schedtest/adjmap/runs/`.

## Observation 0 (look.R, look2.R)

The gradient error of the three bad runs against `val_a09s_c` (bug, n1, a10s) is one
direction: correlation of the difference vectors 0.988–0.9996, and their size ratio
bug : n1 : a10s ≈ 0.017 : 1 : 347, near-constant across all 50 traits. So the
defect is a single scalar λ multiplying a fixed trait-direction v: error = λ·v, λ spread
over three decades (heavy-tailed, like 1/δ with δ a small random number). Largest
components of v: omega, theta, a_bio, storage_relaxation_offset, a_r1, curv_fact_colim.

Inference: one place in the reverse sweep (or one forward quantity) divides by
something the schedule/tolerance makes arbitrarily small, and its adjoint flows into
the traits through one fixed path.
