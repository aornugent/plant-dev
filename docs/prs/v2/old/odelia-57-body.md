An explicit step on a System with a stiff part is held to that part's
stability limit, where the rest could take far longer steps. plant's
TF24 soil is the case: its layers are stiff under heavy rain, the
plants act on them only through their uptake from each layer, and a
daily rainfall record changes from one cubic to the next every day, so
a step must stop at each day or read the rain wrongly between stages.

A System can now name a subsystem (`HasSubsystem`): a range of its
state whose rates read the rest only through one input per component.
Under `method = "rkck"`, a step that spans a knot of the subsystem's
forcing, or that starts with the System reporting the subsystem weakly
coupled, integrates it in substeps of its own that land on every stage
time and every knot, while the rest takes the step's stages. Such a
step records its input slope and substep ends on its row
(`instruction::subsystem`), and replays and the reverse sweep take
them as recorded. A grid of times alone is refused across a step that
would substep. A System without a subsystem steps as before, bit for
bit.

Closes #55
