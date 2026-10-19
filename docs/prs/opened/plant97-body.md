A seedling's storage pool relaxes over `storage_max/(charge + drain)`, which is hours, while the stepper takes steps of days. An explicit step overshoots the pool and the stage check throws. A resident run shrinks the step and retries it. An invasion runs on the resident's recorded steps, cannot shrink one, and fails. TF24 gains `storage_relaxation_offset` (7 days, a gradient column), which is added to that time: the rate is divided by `1 + (charge + drain) * offset / storage_max`. The equilibrium and the sign at each bound are unchanged, and a negative offset is refused. Once a seedling's production turns negative, its relative reserve decays with e-folding time `offset`, so its reserves run down over `offset * ln(a_st3 * a_dG2)` = 19.4 d instead of hours.

The stage check and `storage_domain_tol` are removed. A stage below empty keeps finite rates, so the error estimate rejects the overshoot, and `non_negative_states()` still refuses a step that ends below empty. TF24 results change (model v12, TF24f v12.1). A zero offset gives v11's rates, but a run where the old check fired still steps differently.

Closes #97, closes #98

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_016CzJXviWCsP18qwJ8cuPwz
