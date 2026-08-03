# The cohort density transport term under a carried physiological state

`plant` carries a population as a density over size and transports it with a term that
needs the rate of change of growth with respect to size. That term stops computing the
required quantity as soon as growth depends on any state other than size — which is what
happened when a carbohydrate store was added to TF24.

| | |
|---|---|
| The analysis | [`reports/13-carried-state-invalidates-the-compression-term.md`](reports/13-carried-state-invalidates-the-compression-term.md) — self-contained; read this first |
| How to pick the work up | [`nsc-transport-handover.md`](nsc-transport-handover.md) — what is settled, what is open, how to rebuild the environment |
| Figures | [`reports/figures/`](reports/figures), regenerated from collected output by `probes/30-figures.R` |
| Reference | [`reference/`](reference) |

The measurements are in [`probes/`](../probes), indexed in
[`probes/README.md`](../probes/README.md). The implementation is the `plant` branch
`claude/nsc-density-measurements-efiolz`, which adds `Control$node_density_in_birth_date`
(default off, bit-identical when off).
