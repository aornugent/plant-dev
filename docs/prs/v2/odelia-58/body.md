A pass over a recording, `advance_recorded(rec)`, hands each stage the
recorded row as `const`: the System reads every value the recorded run
solved for and stores none of its own. A System that reads some of a
row and solves the rest had nowhere to put what it solved. plant's
TF24 invader is one: it reads the resident stand's light environment
from the row and solves its own leaf, so its fitness was computed at
the resident's leaf and a sweep of its pass read the resident's values.

`advance_recorded(rec, true)` copies each step's row and hands the
stages the copy. The System reads what the recorded run left there and
writes its own values over it, and a pass that keeps its states records
the copy, so a sweep of that pass reads the values the pass solved.
The copy lasts until the next step, as a recorded row does.
`advance_recorded(rec)` is unchanged.

Closes #56
