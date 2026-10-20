TF24's storage pool relaxes toward its equilibrium at a rate set by
how fast reserves flow in and out relative to the pool's size. In a
seedling whose production has turned negative that rate reaches
hundreds per year, so the pool empties in hours, while the solver
takes steps of days. An explicit step then overshoots the empty pool,
and the check on each stage's storage threw. A resident run recovers
by retrying a shorter step. An invasion must take the resident's
recorded steps and cannot shorten one, so on a synthetic 41-year daily
rainfall record every invader tried failed.

TF24 gains `storage_relaxation_offset`, 7 days by default and a
gradient column, which is added to the pool's own relaxation time, so
the pool cannot relax faster than once per week. Its equilibrium is
unchanged. The stage check and `storage_domain_tol` are removed: a
stage below empty now has finite rates that refill the pool, so the
error estimate rejects the step, and a step that ends below empty is
still refused. TF24's results change (model v12, TF24f v12.1). On that
record, offspring production rises 2.0% and every invader runs.

Closes #97, closes #98
