`run_mutant()` placed every TF24 invader's leaf at the resident's
recorded operating point, so the fitness it reported for another trait
was the resident's leaf on the invader's body, and two invaders together
failed with `expected 2, received 1`. TF24 also declared no fitness, so
`stand_gradient()` offered its census only.

An invasion now steps through the resident's recording on a copy of
each row (odelia 0.8.2, `advance_recorded(rec, true)`): each rate
evaluation reads the resident's light and soil from the row, and each
invader solves its own leaf and stores it in the copy, which the
invasion's reverse sweep then reads. TF24 declares
`differentiable_fitness`, as FF16 does: `"<i>.net_reproduction_ratio"`
and `"<i>.offspring_production"` are stand metrics, `S_D` is a column,
and a species at a constant birth rate has a `"<i>.birth_rate"` column,
so Newton's method on ln J - ln b finds the resident's equilibrium
birth rate. `run_mutant()` refuses a resident run with a harvest or
climate extreme, and an invader introduced where the resident
introduced nothing. No resident number moves; TF24 invaders' do.

Closes #95
