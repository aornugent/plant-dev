---
name: code-review
description: Structured code review that prioritizes long-term comprehensibility over local polish. Use whenever reviewing a diff, PR, branch, or proposed change — including when the user says "review this", "look over my changes", "check this PR", "any feedback on this code", or asks whether an implementation is good. Also use to review design proposals, plans, RFCs, and plan-mode output before implementation, and when self-reviewing code or plans you just produced at the user's request.
---

# Code Review

The goal of review is to reduce the amount a future developer must hold in
their head to change this code correctly. It is not to improve this diff
locally. Every line is a maintenance liability; the best outcome of a review
is often less code, not better code.

For this workspace's C++/comment conventions, judge against the project code
style: [AGENTS.md → Code style](../../../AGENTS.md#code-style).

Be exhaustive over *real* findings: report everything that passes the finding
test below, and nothing that doesn't. Thoroughness means covering every real
problem, not producing volume.

## The finding test

Something is a finding only if you can fill in this sentence concretely:

> "This makes <specific future change or debugging task> harder/riskier
> because <mechanism>."

If you cannot name the future task and the mechanism, it is not a finding —
drop it. This test is what separates exhaustive from noisy.

The subject may be a design proposal or plan rather than code. The procedure
is unchanged; in Step 3 read "function" as "component", "side effect" as
"hidden coupling", and treat every claim the document makes (a number, a hit
rate, an assumption) as knowledge written down — it needs a source or it is
a finding. One addition for proposals: check each claimed property against
what is true in the problem domain, not just against the document's own
logic — the most expensive design flaws are internally consistent.

## Procedure

Work through all steps in order. Earlier steps produce higher-priority
findings; later findings that only matter if the current approach is kept are
marked **[conditional]**.

**Step 1 — Should this code exist?**
Check, in order: (a) can the requirement be met by deleting code? (b) does an
existing abstraction in the codebase already solve this? (c) is any of this
handling requirements that don't exist yet? A yes here is your lead finding
and the verdict is "rethink approach" — but still complete Steps 2–3 so the
author has the full picture if they keep the approach. Do not spend detail
effort on code you've recommended deleting; one line per conditional finding
is enough.

**Step 2 — Name what must always be true.**
State in one sentence the thing that must stay true for this code to be
correct — there is almost always one: "a job runs at most once", "these two
caches never disagree", "config never changes after startup". Then say how
the code keeps it true:
- **structure** — the code makes breaking it impossible
- **convention** — developers must remember to keep it true
- **nothing** — nothing keeps it true at all
If the answer is convention or nothing, and the code could be shaped so that
breaking the rule is impossible, that is a structural finding — it removes a
whole class of bugs, which outweighs any local issue.
For trivial diffs (typo fixes, doc edits, version bumps) there may be no such
property. Write "none — <reason>" rather than inventing one; a made-up
property teaches readers to skip this section.

**Step 3 — Comprehension cost.**
Now review the implementation exhaustively. Common sources of real findings:
- Understanding one function requires reading more than ~2 other functions
  (boundary is in the wrong place).
- The same fact is written down in more than one place (the copies will
  drift apart).
- A side effect a caller couldn't predict from the name and signature.
- Control flow nested deeper than 3 levels, or interacting mutable state that
  forces the reader to simulate execution.
- Error paths that quietly behave differently from the happy path.
This list is illustrative, not exhaustive — anything passing the finding test
belongs in the review.

## Hard rules

- Every finding must pass the finding test and state its cost sentence.
- Order findings by maintenance cost, highest first, and tier them:
  **Structural** (changes the design, or changes how a must-stay-true rule
  is protected) before **Minor** (real but local).
- Never suggest an abstraction that would have exactly one call site or one
  implementation. Deduplication that adds a concept is a net loss; name the
  second concrete use or don't suggest it.
- If you suggest adding code, first state why deleting or reusing doesn't
  work.
- Style, naming, and formatting comments are excluded unless they actively
  mislead a reader (e.g., a name that says something false) — in which case
  they pass the finding test and belong under Minor. Omitting them is
  approval, not oversight.
- Every finding shows a simpler alternative. A finding without an alternative
  is a complaint.

## Output format

Use exactly this structure. Sections marked (omit if empty) may be dropped;
all others are required and appear even when a lead finding recommends
rethinking the approach.

```
## Verdict: approve | approve with changes | rethink approach

## What must always be true
<one sentence, or "none — <reason>" for trivial diffs>
Kept true by: structure | convention | nothing

## Structural findings
1. <what> — makes <future task> harder because <mechanism> — <simpler
   alternative>. [conditional] if moot under an earlier finding.

## Minor findings (omit if empty)
- <same shape, one line each>
```

## Example

Diff adds an `OrderStatus` string field updated in three handlers, plus a
`RetryPolicy` class configurable via four constructor flags used once.

**Bad review** (violates this skill):
> 1. Rename `s` to `status` 2. Add docstring to `handle_cancel` 3. Extract the
> three update calls into `update_status()` helper 4. `RetryPolicy` could use
> a builder pattern 5. Consider adding type hints... *(eight more)*

Volume without findings: none of these can name the future task they protect.

**Good review** (follows this skill):
> Verdict: rethink approach.
> What must always be true: an order's status matches the last event applied.
> Kept true by: convention — three handlers each remember to write the field.
> Structural findings:
> 1. Status is stored separately from the events, so the two can disagree —
>    makes debugging any status mismatch harder because there are three write
>    sites to audit. Compute status from the events instead; then a mismatch
>    is impossible.
> 2. `RetryPolicy` has one call site and four flags nothing uses — makes
>    reading the retry path harder because the reader must rule out three
>    dead behaviors. Inline the two live lines; bring back a policy object
>    when a second caller exists.
> Minor findings:
> - [conditional] `handle_cancel` also changes `updated_at` — a side effect
>   callers can't predict from the signature. Move it to the caller or
>   rename.
