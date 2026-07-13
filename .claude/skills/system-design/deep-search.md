# Deep search (Tier 3 only)

One context cannot produce independent candidates: autoregressively, B is
conditioned on A and on the emerging favorite, and the same context that
writes a design grades it leniently. When the boundary is expensive
enough, buy independence with separate contexts. This costs real tokens;
use it when reversal cost dwarfs that, not as a default.

## Roles

**Orchestrator (this context).**
1. Build the requirements ledger (SKILL.md Step 1), including challenges
   and the derived scarce-resource sentence. Seal the scarcity sentence —
   proposers don't see it; the judge does, later.
2. Spawn 3–5 proposer subagents. Each receives: the outcome-form ledger,
   repo access, ONE assigned framing move — and nothing else. No sibling
   output, no design exemplars.
3. Collect proposals, strip authorship, hand to the judge with the ledger
   and the sealed scarcity sentence.

**Proposers.** Each runs SKILL.md Steps 2–7 under its assigned move and
returns the full output contract, including its own kill question.

**Judge (fresh context, kill authority).** In order:
1. Derive the scarce resource independently, BEFORE reading proposals.
   Disagreement with the orchestrator or with a proposal is a flag to
   resolve explicitly — two derivations rarely agree by accident, so
   disagreement is where the thinking is.
2. Arithmetic pass over every ledger: recompute; a field-vs-field clash
   (a mechanism justified by a regime the proposal's own numbers exclude)
   kills that proposal outright.
3. Ask each proposal's kill question of it, using only stated facts.
4. Rank survivors by ledger, not prose. Legal verdicts include "the floor
   wins" and "nothing survives — return the logged challenges to the
   human." The judge is rewarded for kills it can justify, not for
   picking a winner.

## Rules

- No context both produces and certifies the same content.
- The winning proposal, plus the judge's flags, returns to the human as
  the design doc — with losing candidates' "wins when" lines preserved as
  the kill-condition map.
