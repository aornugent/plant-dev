An explicit step on a System with a stiff part is held to that part's
stability limit, though the rest could take far longer steps. plant's
TF24 soil is the case: its layers are stiff under heavy rain, the
plants touch them only through each layer's uptake, and a daily
rainfall record changes from one cubic to the next every day.

A System can now name a subsystem (`HasSubsystem`): a range of its
state whose rates read the rest only through one input per component.
Under `method = "rkck"`, a step that spans a knot of the subsystem's
forcing integrates it in substeps of its own, landing on every stage
time and every knot, while the rest takes the step's six stages. So
does a step where the subsystem's stiffness, or its own error, holds
the step back (`OdeControl::substep_subsystem`, on by default). A step
records its substeps on its row, and replays and the reverse sweep
take them as recorded. A System without a subsystem steps as before,
bit for bit.

Closes #55
