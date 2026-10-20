An explicit Runge-Kutta step has to be short enough for the fastest
part of the System it integrates, so one fast component forces every
component to take short steps. In plant, the soil water in TF24 is
that component: after heavy rain the top layer drains within hours,
while the plants it supplies change over weeks. Daily rainfall is a
cubic that changes every day, and a step longer than a day reads it
at only six times, so plant also stops each run at every day.

A System can now name its fast part, provided that part depends on
the rest of the state only through one input per component (for the
soil, the plants' water uptake from each layer). When a Cash-Karp
step crosses a day boundary in the forcing, or when the fast part
would otherwise force the step to be short, the solver integrates the
fast part in many short substeps inside the step, while the rest of
the System is evaluated at the usual six points. Each step records
where its substeps fell, so a replay and the reverse sweep repeat the
same calculation. A System that does not name a fast part steps
exactly as before.

Closes #55
