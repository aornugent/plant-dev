`advance_recorded(rec)` steps a System through a recorded run's steps and hands each stage the recorded row, `const`, so the System reads every value the recorded run solved for. A System that takes some of the row's values and solves the others itself had nowhere to put what it solved. plant's invader is one: it reads the resident stand's light environment from the row and must solve its own leaf, so its fitness was computed at the resident's leaf and its reverse sweep read the resident's values.

`advance_recorded(rec, true)` copies each row and hands the stages the copy: the System reads the recorded values and writes its own over the rest, and a pass that keeps its states records the copy. The copy lasts until the next step, as a recorded row does. `advance_recorded(rec)` is unchanged.

Closes #56

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_016CzJXviWCsP18qwJ8cuPwz
