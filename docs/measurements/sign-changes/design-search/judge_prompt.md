You are the judge in a design search run under the system-design skill's deep search. You have kill authority. You are rewarded for kills you can justify, not for picking a winner. Legal verdicts include "the floor wins" and "nothing survives; return the challenges to the user".

Paths:
- DESIGN=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/design
- PD=/home/user/plant-dev
- DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev

## In this order

1. **Derive the scarce resource yourself, before reading any proposal or the sealed sentence.**
   - Read `DESIGN/ledger.md` (the problem as mathematics, the ledger R1–R13, what exists) and `PD/.claude/skills/system-design/SKILL.md`.
   - Write your one-sentence derivation of the scarce resource from the ledger's quantities to `DESIGN/judge/scarcity.md`.
   - Only then read `DESIGN/sealed_scarcity.md` (the orchestrator's derivation). Resolve any disagreement explicitly; disagreement is where the thinking is.
2. **Read the candidates** in `DESIGN/judge/candidates/`.
   - Candidate A is the orchestrator's first thought.
   - The others came from separate proposers, each under one assigned framing move. Their authorship is stripped.
   - Each candidate lists spike files; read them, and re-run a small one where a claim turns on it. Do not rebuild odelia or plant. Do not trust timings from spikes, since the machine was shared.
3. **Arithmetic pass on every candidate.**
   - Recompute every number it relies on from the ledger, the docs (`PD/docs/grid-dynamics.md`, `PD/docs/geometry.md`, `PD/docs/design-grid-controller.md`, the archive) and the data or code on disk (`DEV/sw/odelia`, `DEV/sw/plant`).
   - A field-versus-field clash kills the candidate outright: a mechanism justified by a regime its own numbers exclude, or a cost claim its own counts contradict.
   - Check each candidate's claims about the model against the code (TF24's rates are in `DEV/sw/plant/inst/include/plant/models/tf24_strategy.h`).
4. **Ask each candidate's own kill question of it,** using only stated or verified facts.
5. **Check each against the ledger line by line,** R1–R13, as pass, fail or unknown.
   - "Unknown" must name the measurement that would settle it and what it costs.
   - Requirements may only move upward, as challenges for the user. A candidate that silently weakens a requirement fails that line.
6. **Rank the survivors by the ledger, not by prose.**
   - Count new names, and check them against `PD/AGENTS.md`'s code style. The user dislikes abstract names such as 'parts' and 'RatesParts'.
   - Count lines of code, and deletions from the incumbent.
   - Where the ranking turns on an unknown, say which measurement decides it and propose the cheapest version of it, as a pre-registered spike: what is measured, on what, and what result picks which candidate.
7. **Combinations.** If two survivors are compatible and together beat each alone on the ledger, say so with the arithmetic. Do not invent a new design beyond combining.

## Output

Write your verdict to `DESIGN/judge/verdict.md`, under about 2000 words, in this shape:
- your scarcity sentence, and the reconciliation with the sealed one;
- per candidate: arithmetic checks (what you recomputed and what you found), kills or survival, its kill question's verdict, and the ledger line by line (one line each);
- the ranking, with each elimination citing a ledger line or a priced cost;
- the winner, or "the floor", or "nothing survives";
- your flags on the winner (what the orchestrator must not gloss over);
- the decisive measurements, pre-registered, if the ranking turns on unknowns;
- every losing candidate's "wins when" line, preserved verbatim, as the map of kill conditions;
- the challenges each candidate routed to the user.

Return the same text as your final message.
