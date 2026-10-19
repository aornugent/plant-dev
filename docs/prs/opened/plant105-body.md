TF24's soil sets every step of a run. Under heavy rain its top layer is stiff (∂rate/∂θ down to −3.6e4 /yr), and on a variable rainfall record each one-day piece of the rain's cubic must not span a step's stages, so a run either stops at every knot (zero-depth rainfall pulses) or misses the rain that falls between stages (17% low in `J` on the dry record). Either way every node in the stand pays for the soil's steps.

The patch now names the soil as odelia's subsystem, whose rates read the plants only through each layer's uptake. A Cash–Karp step that spans a knot of the rain integrates the soil in substeps of its own, one landing on each knot, while the plants take the step's stages. So does a step that starts with the plants taking less than `Control$ode_soil_substep_max_uptake` of the water moving through the soil (inflow, drainage and uptake summed over the layers; default 0, off). Each step records its substeps, and replays, invasions and the reverse sweep take them as recorded, so the gradient is that of the run taken. A fixed step schedule carries the records (`ode_soil_input_slopes`, `ode_soil_substep_ends`); one that drops them is refused where a step spans a knot. Requires odelia 0.8.1.

Closes #105

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_016CzJXviWCsP18qwJ8cuPwz
