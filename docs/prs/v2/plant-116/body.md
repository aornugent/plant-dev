An invader's fitness should come from its own leaf, optimised in the
resident stand's light and soil water. TF24's invasions reused the leaf
operating point the resident had recorded, so the fitness reported for
an invader with different traits was the resident's leaf on the
invader's body, and two invaders run together failed with `expected 2,
received 1`. TF24 also declared no fitness, so `stand_gradient()` could
not differentiate it.

An invasion now replays the resident's recorded steps with a copy of
each step's values (odelia 0.8.2): each invader reads the resident's
light and soil from the copy, solves its own leaf, and stores the result
there, where the invasion's reverse sweep reads it. TF24 declares its
fitness differentiable, and a species at a constant birth rate has a
birth-rate column, so Newton's method finds the resident's equilibrium
birth rate from one gradient per run. `run_mutant()` also refuses two
cases its replay cannot represent: a resident run with a harvest or a
climate extreme, and an invader introduced at a time the resident
introduced nothing. Residents' results are unchanged.

Closes #95
