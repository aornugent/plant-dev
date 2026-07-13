---
name: code-review
description: Structured code review that reopens the decisions a diff made and makes the diff justify them. Use whenever reviewing a diff, PR, branch, or proposed change — including "review this", "look over my changes", "check this PR", "any feedback", or asking whether an implementation is good — and before merging or when self-reviewing code just written.
---

# Code Review

A diff presents decisions as facts. The review's job is to reopen them as
choices. The ideals — code that fits in working memory, that is hard to
hold wrong, that is the least needed — are asserted by every reviewer and
checked by almost none; here each is checked by a mechanism, not a claim:
comprehensibility by prediction misses, durability by simulated changes,
sparingness by per-decision defaults. The diff is a proposal, not a fact;
every choice is open until a requirement closes it. A review that cannot
fail the diff is not a review.

For this workspace's C++/comment conventions — the "never" comment rules,
the exemplar, and the invariant that only `double` crosses the R boundary —
judge against the project code style:
[AGENTS.md → Code style](../../../AGENTS.md#code-style). It is admissible
evidence under Lens 1, not a source of opinions.

## Files in this skill

- `lenses.md` — the four lens procedures. Read before your first review
  under this skill and whenever running Tier 2+.

## The finding test (unchanged, load-bearing)

A finding must complete: "This makes <specific future change or debugging
task> harder/riskier because <mechanism>." Can't fill it in → not a
finding. Style, naming, and formatting are inadmissible as opinions and
admissible only as evidence: a name is a finding solely when it caused a
prediction miss in Lens 1.

## Step 0 — Triage

- **Tier 1** — typo fixes, doc edits, version bumps, mechanical renames:
  invariant slot ("none — <reason>" is expected), a one-pass scan,
  verdict. No lenses.
- **Tier 2** — ordinary feature/fix diffs: full sequence below.
- **Tier 3** — diffs touching persisted formats, wire protocols, public
  APIs, or module boundaries: full sequence, and produce the clean sheet
  in a fresh subagent that receives only the requirement, never the diff
  — uncontaminated is the one thing a single context cannot fake.

## Step 1 — Sources of truth

Assemble the ledger the diff will be judged against, in priority order:
1. **A design doc under the system-design skill, if one exists.** Then
   this review has two extra duties: verify the commitment's "kept true
   by" claim against the actual code (structure, or did it decay to
   convention?), and diff the diff's new nouns against the doc's "what
   survives deletion" — any noun not on that list must justify itself.
2. **The PR description / linked issue**, restated as outcomes with
   quantities where given.
3. **Reconstruction**: if neither exists, write the 2–4 line ledger the
   diff appears to serve, and say you reconstructed it. Decisions no
   ledger line pays for are challenged upward, not assumed correct.

## Step 2 — Clean sheet

From the ledger alone, sketch the least-code solution: parts, rough
size, new names (≤5 lines). Tier 3: subagent, blind to the diff. The
sketch is a yardstick, not the answer — where the diff knows something
the ledger didn't say, that is a finding against the ledger's wording,
and worth sending upward.

## Step 3 — Run the lenses, in this order

Order is load-bearing. See `lenses.md` for each procedure.

1. **Cold Reader** (predict-then-verify) — must be first contact with
   the bodies: predictions from the public surface, then verification.
   Misses become findings verbatim.
2. **Alternative Implementer** (decision reopening) — extract the ≤5
   largest decisions as "chose X over <simplest live alternative Y>".
   Per decision the null hypothesis is Y; a ledger line settles it for X,
   or it becomes a question with a default.
3. **Time Traveler** (change simulation) — walk 1–2 plausible next
   changes through the code; list every edit site; classify one-place /
   leaky / shotgun.
4. **Keeper** (what must always be true) — one sentence; kept true by
   structure | convention | nothing; convention-or-nothing with a
   structural option available is a structural finding. Trivial diffs:
   "none — <reason>".

Each lens must report either results or its explicit empty state
("no misses — checked N signatures"). An omitted lens is an unrun lens.

## Step 4 — Assemble

Shape verdict first (clean-sheet gap + time-over question: knowing what
this diff taught us, would we build differently? "It's already written"
is never a reason). Then findings, then questions. Detail findings under
a rethink verdict are one line each, marked [conditional].

## Hard rules

- Per reopened decision, the simpler alternative is the default winner;
  the diff's choice must cite the ledger line that pays for the
  difference. No citation → question with a default, not silence.
- Every question states its default and the conversion rule: unanswered,
  the default becomes a finding in the next review of this code.
- Predictions are written before bodies are read — reordering this is
  falsifying the experiment.
- Never suggest an abstraction with one call site; name the second
  witnessed use or don't suggest it. If you suggest adding code, first
  state why deleting or reusing fails.
- Every finding passes the finding test and shows a simpler alternative;
  every lens reports or declares empty; silence on style is approval.

## Output contract

```
## Verdict: approve | approve with changes | rethink approach
## Triage: 1 | 2 | 3 — <why>

## Ledger
<R-lines, with source: design doc | PR | reconstructed>
Design doc check (if doc exists): commitment kept true by <structure as
claimed | decayed to convention — finding>; nouns not on the doc's
survives-deletion list: <list | none>

## Clean sheet
<sketch> — Gap: <concepts the diff has that the sketch didn't — each
settled by a ledger line, or listed below>

## Prediction record
<misses only: "<surface element>: predicted <X>, actual <Y>">
| "no misses — checked <N>"

## Decisions reopened
D1: chose <X> over <Y> — settled by R<n> | UNSETTLED → Q1
...

## Change simulation
<next change> → edit sites: <list> → one-place | leaky | shotgun

## What must always be true
<one sentence, or "none — <reason>">   Kept true by: structure |
convention | nothing

## Structural findings
1. <what> — makes <future task> harder because <mechanism> — <simpler
   alternative> [conditional if moot]

## Minor findings (omit if empty)

## Questions with defaults (omit if empty)
Q1: why <X> over <Y>? Default if unanswered: <Y>.
```
