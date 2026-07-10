---
name: system-design
description: Design systems and features around one binding commitment instead of speculative flexibility. Use whenever planning or designing software — a new system, service, feature, data model, API, or a significant refactor — including when the user says "how should I structure", "design", "architect", "plan the approach", "what's the right data model", or asks for a technical proposal or design doc before writing code.
---

# System Design

Good design finds one fact about the problem that, once committed to, settles
most of the other decisions. The job is to find that fact and commit to it —
not to stay flexible. A design that keeps its options open forces every later
decision to be made from scratch; a design built on the right commitment
makes most later decisions for you.

When the design lands as code in this workspace, hold it to the project code
style: [AGENTS.md → Code style](../../../AGENTS.md#code-style).

## Procedure

**Step 1 — Find the hard fact.**
Before proposing any structure, answer: what actually dominates this problem?
Look for one of:
- a cost (latency, money, complexity, failure) that dwarfs everything else
- something impossible that must be accepted, not worked around
- a value that only ever moves one way (counts grow, time advances,
  events append)
- data that can be given one agreed-upon form, ending "which copy is right?"
- a failure that should be treated as normal rather than exceptional
- the shape of the real workload (read-heavy, small, bursty, single-writer)
State it as a fact about the problem, not about the solution.

**Step 2 — Choose the commitment.**
One sentence: the assumption you will enforce everywhere. It should follow
directly from the hard fact. Example shapes: "records are never changed after
they're written", "everything fits in memory", "there is exactly one writer",
"any node can die at any moment".

**Step 3 — Check it's real.**
The commitment passes only if all four hold:
1. It is true in the real operating environment, not just the demo.
2. Breaking it would make the system *worse*, not merely different — and you
   can say why.
3. It removes whole categories of decisions and bugs, not just relocates
   them.
4. You can name the change in requirements that would kill it (see kill
   condition below). "Nothing could kill it" means it's too vague to build
   on.
If any check fails, it is a slogan. Go back to Step 2.

If nothing survives the checks after a couple of attempts, this problem has
no dominant constraint — many ordinary features don't. Say so: write
"Commitment: none found — <why>", design with boring conventional defaults,
and skip the settles / makes-hard / kill-condition sections. A made-up
commitment costs more than none, because everything downstream is justified
against it.

**Step 4 — Spend the commitment.**
List concretely what the commitment settles: the components you no longer
need, the code you don't write, the states that can no longer occur, the
questions that stop being questions. Each item must name a component you
don't build, code you don't write, or a state that can't occur — "simpler",
"cleaner", and "more maintainable" don't count. If this list is short, the
commitment is weak — go back to Step 2, or take the "none found" exit.

**Step 5 — Price the commitment.**
Name what the design is now bad at: the workloads it handles poorly, the
features that become expensive. If you cannot name anything, you haven't
committed to anything. A design doc with no stated cost is advocacy, not
design.

## Hard rules

- One commitment per design. If you have three, you have none — keep the one
  that settles the most and demote the rest to consequences.
- The commitment must be enforced by the structure of the system (the API,
  the types, the storage, the permissions) — something that makes breaking it
  impossible, not a comment asking developers to remember. Name the
  mechanism.
- No flexibility for unnamed futures: every configuration option, plugin
  point, or layer of indirection must name the second concrete case it
  serves *today*. "We might need it" does not count.
- Prefer the design that makes wrong states impossible over the one that
  detects or documents them.

## Output format

Use exactly this structure:

```
## The hard fact
<what dominates this problem, or what is impossible — one short paragraph>

## The commitment
<one sentence, or "none found — <why>" (then skip the next three sections)>
Kept true by: <the concrete mechanism — API shape, schema, permissions, ...>

## What this settles
- <decision made, component removed, or bug class made impossible>
- ...

## What this makes hard
<the workloads or features this design is knowingly bad at, and how you'd
cope if forced>

## Kill condition
<the requirement change that would invalidate the commitment>

## The design
<components, data flow, interfaces — all justified against the commitment>
```

## Example

Task: build an audit log for admin actions.

**Bad design** (violates this skill):
> A generic event store with pluggable storage backends, a configurable
> retention engine, and update/delete endpoints "for admin corrections".
> Flexible — and committed to nothing. Every backend must now be tested,
> the update path reintroduces "can I trust this log?", and no decision
> downstream got easier.

**Good design** (follows this skill):
> Hard fact: the log's entire value is that it can be trusted after an
> incident. A log that can be edited is worth nothing.
> Commitment: a record, once written, is never changed or removed.
> Kept true by: the API has no update or delete; the DB role can only INSERT
> and SELECT; corrections are new records that reference the old one.
> Settles: no locking or write conflicts; replication and caching are
> trivial (records never change); "who edited the log" cannot happen;
> backups are plain copies; the reader never reasons about versions.
> Makes hard: legally required erasure. Cope by encrypting each user's
> records with a per-user key and deleting the key, not the rows.
> Kill condition: a regulator requires literal deletion of rows and rejects
> key-deletion as compliance.
