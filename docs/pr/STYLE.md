# Writing a pull request for this family

Rules, worst-first. Each was earned by getting it wrong.

## Sources

- **`plant-meta/governance/commit-messages.md`** — binding. Every family repo
  squash-merges, so the title and body *are* the commit message.
- **Perkins, *Making Learning Whole***, via [fast.ai's teaching
  philosophy](https://www.fast.ai/posts/2016-10-08-teaching-philosophy.html) —
  teach the whole game first. The failure it names is *elementitis*: drilling
  disconnected fundamentals before anything reveals what they are for.
- **[Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing)**
  — a checklist of tells. The ones that bite here are negative parallelism,
  significance inflation and rule-of-three.
- **`docs/design/principles.md`** — the prime directive: *if a maintainer would
  find it exhausting, it is a bad solution.*

## Shape

Title: imperative, sentence case, no full stop, **≤50 characters**. GitHub
appends ` (#NNN)`. No issue number in the title.

Body: **≤20 lines, wrapped at 72**, two paragraphs — why it was needed, then what
changed in observable behaviour. This becomes permanent history.

Then **two comments**, posted in order:

1. *The whole thing, then its parts* — a runnable example with its result, the
   terms, the control flow, what changes for existing code, the file table and a
   reading order.
2. *How it works* — the two to four mechanisms that are not obvious from the
   diff.

Four comments was worse. A list of things to check and a list of things measured
are reference material, and reference material read as a wall. Fold each item
into the comment where it explains something.

## Rules

**Open with the whole game.** The smallest complete thing that works, end to end,
with its output. Then say the rest explains a part of it. Never open with a
glossary or a file table — those are elements, and elements are meaningless
before the reader knows what they are for.

**Write for maintainers.** They wrote the package. Do not define a cohort, a
census metric or an ODE solver. Define only what this branch invents and what
belongs to a field they have not worked in. If a term needs a sentence of setup,
it belongs in the glossary; if it needs a paragraph, it belongs in comment 2.

**No second person.** "Suppose you want to know how the solution responds" is a
tutorial. These are colleagues.

**Explain the implementation, not the comments about it.** Read the code. A
paraphrase of a good comment reads like explanation and contains nothing the
reader would not get from the diff.

**State the fact, not its importance.** If it matters, showing it is the
argument.

**Name symbols, not line numbers.** A line number rots silently and reads as
precise. `census_trait_gradient` is grep-able and fails visibly when wrong.

**Separate the measurement from the harness.** A number from one fixture is a
property of that fixture. Say which configuration produced it, and which
part generalises.

**Verify every number and every symbol before it ships.** Both at the time of
writing. A symbol that has moved makes the whole comment untrustworthy.

**Hazards go where they explain a design.** Do not lead with footguns. A reader
needs the ordinary path before the exceptions, and a hazard attached to the
decision it forced is worth more than the same hazard in a list.

**One diagram, ASCII, showing control flow.** It earns its place by showing what
prose fumbles — usually which way data moves and what runs twice. A numbered
list with aligned comments is not a diagram.

**Tables for inventories and migrations. Prose for mechanism.** A table of "how
it works" is a table of assertions.

## Failure modes

**Negative parallelism.** "Y rather than X", "not X but Y". The default move for
expressing a design choice, and the single most frequent tell. Budget: two per
document. State the positive.

**Significance inflation.** "the reason is load-bearing", "worth reviewing
hardest", "this is the sharpest thing in the diff".

**Transition sentences.** "What changed is what happens next." Zero information.

**Rule of three.** Three-item lists where two would do, on a rhythm.

**Catch-all sections.** "The rest", "Other notes", "Out of scope". If it has no
home, it has no place.

**Uniform paragraphs.** Every paragraph a topic sentence plus elaboration, all
the same length, is a rhythm a reader stops hearing.

**Em-dash density.** Fine in ones. Three to a paragraph is a tell.

## Examples

Announcing significance instead of delivering it:

> ✗ Five stages, not six, and the reason is load-bearing. The sixth rate
>   evaluation is at the state the step ends at…

> ✓ The array is five long and not six, and the reason is a property of the
>   stepper. Runge–Kutta–Cash–Karp is first-same-as-last: the sixth rate
>   evaluation happens at the state that step ends at, which is precisely the
>   state the next step begins from…

Paraphrasing a comment instead of reading the code:

> ✗ At each introduction the sweep narrows lambda, transposing the map that
>   widened it.

> ✓ The narrowing is not a projection and lambda's extra entries are not
>   dropped. The System's own widening map is recorded and swept like any other
>   function, with `parameter_adjoint` passed into it — so a newborn's initial
>   conditions contribute parameter derivatives, not only the steps.

A verdict standing in for a mechanism:

> ✗ That grain is forced rather than chosen.

> ✓ The grain is forced by where the failure occurs. What could not be supplied
>   is an intermediate of one recording that spans six stages and every cohort
>   in them, so no seed carries a component that could attribute it to a
>   particular cohort.

Elements before the game:

> ✗ ## Terms
>   **tape** — a linear log of arithmetic…

> ✓ ## The whole thing
>   ```cpp
>     solver.set_keep_states(true);
>     solver.advance_adaptive({0.0, 10.0});
>     solver.solve_adjoint(lambda, dp);
>     // dp[0][j] is now d(x_final)/d(parameter j), every j, from that one solve.
>   ```
>   Three lines are new. Everything below explains a part of them.

A fixture's property stated as the design's:

> ✗ A range is consecutive steps at constant state width. The century fixture
>   has 169.

> ✓ A range is consecutive steps at constant state width. A System of fixed
>   width has one; plant opens a new one at every cohort introduction.

A line number where a symbol would do:

> ✗ …and `scm.h:1080` gives the reason.

> ✓ …and `census_trait_gradient` gives the reason at the site.

## Before posting

- [ ] Title ≤50 characters, body ≤20 lines, nothing past column 72.
- [ ] Comment 1 opens with something that runs, and its output.
- [ ] Every symbol named still exists. Every number re-measured today.
- [ ] Measurements say which configuration produced them.
- [ ] In prose of one's own, not in quoted examples: "rather than" under three,
      no second person, no catch-all section.
- [ ] A maintainer new to the work can predict the call chain after comment 1.
