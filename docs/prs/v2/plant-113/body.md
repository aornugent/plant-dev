TF24's storage pool relaxes toward its equilibrium at its own rate
(charge + drain) / storage_max, which reaches hundreds per year in a
seedling whose production has turned negative. An explicit step of days
then overshoots the empty pool, and the stage check threw. A resident
run shrinks and retries the step; an invasion takes the resident's
recorded steps, cannot shrink one, and failed: on a synthetic 41-year
daily record every invader tried was refused.

TF24 gains `storage_relaxation_offset`, 7 days by default and a gradient
column, added to the pool's own relaxation time: the rate is divided by
1 + (charge + drain) * offset / storage_max. The equilibrium and the
sign of the rate at each bound are unchanged, and a negative offset is
refused. The stage check and `storage_domain_tol` are removed; a stage
below empty keeps finite rates, the error estimate rejects the step, and
a step that ends below empty is still refused. TF24 results change
(v12, TF24f v12.1): offspring production on that record moves from
12.417 to 12.662 (+2.0%). An offset of zero gives v11's rates, but a
run where the old check fired steps differently.

Closes #97, closes #98
