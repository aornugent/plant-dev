# TF24 soil profile — ecological characterisation (why leaf shutdown is unreachable)

*Task #24, prompted by the Stage-1 classifier gate finding that leaf shutdown is
nearly unreachable. Data: `scripts/tf24-benchmarks/eco_soil_characterisation.R`
on the whole-profile drydown scenario (4 yr intermittent rain + 12 yr zero rain,
single LMA=0.0825 species). Raw: `results/eco_soil_drydown.rds`.*

## Question

The classifier found leaf shutdown (`set_shutdown_state`) fires on <0.5 % of
steps and its margin `psi_crit − |ψ_wettest|` never nears zero, because shutdown
keys on the **wettest accessible soil layer**. Is that ecologically defensible,
or a mechanistic artifact that suppresses a drought phenomenon that *should*
occur?

## What the drydown shows

**A strong vertical ψ gradient develops, but the deepest layer never dries.**
After 12 yr of zero rain (per-layer, end of run):

| depth | θ | ψ (MPa) |
|---|---|---|
| 0.3 m (top) | 0.127 | **5.34** |
| 0.6 m | 0.127 | 5.13 |
| 0.9 m | 0.136 | 3.28 |
| 1.2 m | 0.176 | 0.611 |
| 1.5 m (bottom) | 0.190 | **0.373** |

`psi_crit ≈ 5.6 MPa`. The **top two layers reach ~5.1–5.3 MPa — right at the
shutdown threshold** — but the bottom stays at 0.37 MPa. Shutdown keys on the
wettest accessible layer (`-wettest_soil_layer ≥ psi_crit` requires *every*
rooted layer drier than psi_crit), and every cohort roots to 1.5 m, so the wet
bottom layer keeps shutdown unreachable. Its max over the whole run: 0.37 MPa.

**The stand dies before it can draw the deep reservoir down.** Patch leaf area
peaks at 3.96 (t=3 yr) and collapses to ~0 by t=16 yr. Mortality is
**carbon-starvation-driven** (net production falls as the topsoil dries), not
hydraulic — the cohorts die from the drying top layers while still rooting into
accessible deep water they never fully exploit. Water budget over 16 yr: 4.00 m
rain in, **1.52 m (38 %) lost to deep drainage**, the rest to uptake/storage;
once the stand is dead the deep layer just sits (drainage `K(θ)∝θ^~16` has
collapsed at low θ, and there is no upward capillary flux between layers).

## Is it an artifact? Three modelling choices to weigh (for the Oracle / authors)

1. **Shutdown keys on the single wettest layer.** A cohort with *one* wet layer
   never shuts down, even with 4/5 layers at/above psi_crit (exactly this run).
   Root-weighted hydraulic function of the whole profile would shut down far
   sooner; single-wettest-layer is a generous criterion.
2. **No upward capillary flux between layers, uptake not strongly biased to the
   wet layer.** The top dries irreversibly toward psi_crit while the bottom
   holds ~0.19; in real soils capillary rise and preferential deep-water use
   partly equalise. Here the plant starves on top-layer stress while sitting on
   deep water — so mortality is carbon-starvation, and the hydraulic-failure
   pathway is bypassed.
3. **Deep-layer retention.** With drainage collapsing at low θ and no other sink
   once the stand dies, the 1.5 m layer asymptotes to θ≈0.19 (ψ≈0.37 MPa) and
   never approaches psi_crit under any rainfall forcing.

**Ecological reading:** carbon-starvation-dominated drought mortality (with
hydraulic failure a rare tail) is a defensible outcome and matches a real debate
in the drought-mortality literature. But the *combination* — single-wettest-layer
shutdown keying + no capillary redistribution + all-layer rooting — makes
hydraulic shutdown essentially **structurally unreachable**, which is worth
flagging: if TF24 is meant to represent hydraulic-failure mortality, the current
soil↔root coupling suppresses it.

## Consequence for the solver work

This *reinforces* the classifier's INTRINSIC verdict from the mechanism side: the
leaf-shutdown event the event-aware stepper was meant to locate is not merely
absent in these runs — it is close to unreachable by construction, so no
step-to-event machinery could pay for it. The step collapse is elsewhere
(continuous cohort-layer structure; the GSS/argmax interval is the one
predictor). Take both to the Oracle: (a) the gate verdict, (b) this
shutdown-reachability characterisation as a model-mechanism question.
