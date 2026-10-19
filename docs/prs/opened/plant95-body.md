`run_mutant()` placed every TF24 invader's leaf at the resident's recorded root-collar water potential (`solve_leaf` → `replay_operating_point`), so the fitness it reported for another trait was the resident's leaf on the invader's body, and two invaders together failed with `expected 2, received 1`. An invasion now steps through the resident's recording with a copy of each row (odelia 0.8.2, `advance_recorded(rec, true)`): each rate evaluation reads the resident's light environment from the row, and each invader solves and records its own leaf operating point, which the invasion's reverse sweep then reads. `run_mutant()` also refuses two cases the invasion would otherwise skip without saying so: a resident run with a harvest or climate extreme, and an invader introduced where the resident introduced nothing.

TF24 sets `differentiable_fitness`, as FF16 does since #658: `"<i>.net_reproduction_ratio"` and `"<i>.offspring_production"` are stand metrics, `S_D` is a gradient column because the fitness reads it, and a species at a constant birth rate has a `"<i>.birth_rate"` column, as FF16's has. Newton's method on `ln J − ln b` therefore finds the resident's equilibrium birth rate, where an invader is then differentiated. No resident number moves.

Closes #95

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_016CzJXviWCsP18qwJ8cuPwz
