A recording keeps, for every step, the values a System solved for
during that step's rate evaluations, such as the operating point of a
plant's leaf. `advance_recorded(rec)` replays the recorded steps and
hands each evaluation those values as read-only, so the System reuses
them and solves nothing. Some replays need to reuse part of what was
recorded and solve the rest. plant's invader is one: it should read
the resident stand's light environment from the recording but solve
its own leaf. With nowhere to store what it solved, its fitness was
computed at the resident's leaf.

`advance_recorded(rec, true)` copies each step's recorded values and
hands the copy to the evaluations. The System reads what it needs
from the copy and writes the values it solves over the rest. The
replay's own recording keeps the copy, so the reverse sweep of the
replay reads the values the replay computed. The copy lasts until the
next step, as a recorded entry does. `advance_recorded(rec)` is
unchanged.

Closes #56
