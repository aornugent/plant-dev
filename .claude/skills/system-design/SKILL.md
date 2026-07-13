---
name: system-design
description: Search for the design that does the least, then commit to it. Use whenever planning or designing software — a system, service, feature, data model, API, or significant refactor — including when the user says "how should I structure", "design", "architect", "plan the approach", "what's the right data model", asks for a technical proposal before code is written, or whenever you are tempted to introduce a new abstraction, layer, service, or framework.
---

# System Design

A design is good when a reader has to internalize one or two decisions and
everything else follows from them. Nearly all effort belongs in the search
for those decisions, before anything is built. Your first idea is an
anchor, not an answer — it competes below, labeled. Prose persuades;
only numbers and structure check. Every claim in a design doc is either a
quantity, a mechanism, or a decoration.

## Files in this skill

- `framing-moves.md` — read before Step 3, Tier 2 and above.
- `deep-search.md` — read only at Tier 3, and only if the stakes justify
  its cost.
- `examples.md` — one full search, one floor-win, one annotated failure.
  Read before writing your first design doc under this skill, and again
  whenever your winner matches an example's conclusion (that match is a
  flag to re-check the derivation, not a comfort). Copy derivations,
  never conclusions.

## Step 0 — Triage

Blast radius sets the search budget. Spending Tier-3 effort on a Tier-1
decision violates this skill as surely as overbuilding the design would.

- **Tier 1** — reversible and internal: helpers, private refactors,
  anything a later PR undoes cheaply. Do Steps 1–2 only. If the floor
  holds, build it. No candidates, no ceremony.
- **Tier 2** — visible seams: module boundaries, schemas you can still
  migrate, new dependencies. Full procedure, Steps 1–7.
- **Tier 3** — expensive to reverse: persisted formats, wire protocols,
  public APIs, anything with external consumers — or the requirements
  arrive as solution-verbs. Full procedure plus `framing-moves.md`;
  consider `deep-search.md`; where a twenty-line spike can settle a
  question, run it — an execution outranks any argument.

## Step 1 — Requirements ledger

Three duties, before any design exists:

1. **Strip solution-verbs.** "Get gradients", "make it flexible", "add
   caching" are mechanisms wearing requirement clothes. Rewrite each as
   an outcome. Never silently add, drop, or reinterpret a requirement —
   challenges go *upward*, as questions: "I believe you want
   X-the-outcome, not X-the-mechanism; if so, a cruder design suffices —
   confirm?" Log every challenge in the output.
2. **Attach a quantity to every requirement** — latency, count, size,
   frequency, error budget. Unknown → write "unknown — ask" and name the
   design choice hanging on it.
3. **Derive the scarce resource** from those quantities, in one sentence,
   before reading or writing any design. Scarcity inherited from an
   example, a past project, or a famous system is the classic deep
   failure: derive it or don't claim it.

## Step 2 — The floor

The dumbest design that meets the ledger: fewest parts, fewest new names,
most boring technology. The floor may question the frame itself — doing
less, a cruder model, buying instead of building, deleting a requirement
(name who screams).

The floor is the default winner. If it suffices, recommend it and stop —
at every tier. If it fails, cite the exact ledger line it fails, as
numbers; that line is what every candidate must pay for. Imagined
requirements ("we might need to scale") pay for nothing.

## Step 3 — Candidates (Tier 2+)

Read `framing-moves.md`. Produce three designs, each under a **different
assigned move** — assigned moves are how a single context avoids writing
three drafts of one idea. Candidate A is your first thought, labeled
`[first thought]`. One line per field, per candidate:

- move used
- commitment: the one assumption it enforces everywhere
- pays for: the ledger line it fixes, and how
- costs: new names, what it's bad at
- wins when: the concrete situation where this candidate is clearly right

No "wins when" you'd defend to a real stakeholder → strawman → replace it
before continuing. Three candidates where two exist to lose is a
one-candidate search.

## Step 4 — Pick by arithmetic

The winner does the least while meeting the ledger. Every elimination
sentence must cite a ledger line or a priced cost — "less elegant"
eliminates nothing. If no candidate beats the floor, the floor wins;
say so plainly.

## Step 5 — Try to kill the winner

Three passes, in writing:

1. **Kill question.** Name the single assumption whose falsity makes this
   entire design unnecessary. Then argue that it is false, using only
   facts already in the ledger. If the design dies here, it was
   decoration; return to Step 4 with the survivor.
2. **Consistency pass.** Reread your own fields as quantities and check
   them against each other. A method justified by large N beside a ledger
   line saying N ≤ 8 is a kill. The most common deep failure is a
   document that contains its own refutation and never notices.
3. **Deletion pass.** For every part and every new name: which ledger
   line breaks if it is removed? None → remove it. Repeat to fixpoint.

## Step 6 — Check the commitment

It passes only if all four hold: true in the real operating environment,
not the demo; breaking it makes the system worse, not merely different —
and you can say why; it removes categories of decisions and bugs rather
than relocating them; you can name the requirement change that kills it.
If nothing survives, the floor was the design all along — "none found" is
a legal, good outcome. A made-up commitment costs more than none, because
everything downstream gets justified against it.

## Step 7 — Price and expiry

Name what the design is now bad at, and how you'd cope if forced. Empty
means you haven't committed; a design doc with no stated cost is
advocacy, not design. Then the kill condition: the requirement change
that invalidates the commitment — usually a losing candidate's "wins
when"; point at it, so the next search starts from the map.

## Hard rules

- New names are the unit of cost. Every noun — service, class, table,
  queue, config key, term of art — must name the ledger line that demands
  it. If a reader must learn more than a couple of decisions before the
  rest is obvious, the design is overbuilt.
- Generalize only over witnesses. One mechanism may replace N existing
  cases when it is smaller than their sum — that is when the switch
  statement dies. Rumored futures are not witnesses; the consumer that
  "might come next year" buys nothing today. Under genuine uncertainty,
  take the reversible default and name the retrofit trigger — information
  only increases.
- One commitment per design. Three commitments are none; keep the one
  that settles the most, demote the rest to consequences.
- The commitment is kept true by structure — API shape, types, storage,
  permissions — something that makes breaking it impossible to express,
  not a comment asking developers to remember. Name the mechanism.
- Requirements move only upward (a logged challenge), never sideways
  (a silent edit).
- Every "faster", "simpler", "scales" appears as a number or dies.

## Output contract

```
## Triage: 1 | 2 | 3 — <why>

## Requirements ledger
R1: <outcome> — <quantity>    (challenged upward: <question>, if any)
...
Scarce resource: <one sentence, derived from the quantities above>

## The floor
<design> — "it suffices" (stop) | fails R<n>: <number> vs <number>

## Candidates                                    (Tier 2+)
A [first thought] <move>: <commitment — pays for R<n> — costs — wins when>
B <move>: ...
C <move>: ...
Winner: <letter | the floor>. Eliminations: <one sentence each, citing R<n>>

## The commitment
<one sentence, or "none — the floor is the design">
Kept true by: <the mechanism that makes breaking it inexpressible>

## Kill question
Assumption whose falsity makes this unnecessary: <one sentence>
Verdict: <survives | died — switched> — argued from ledger facts only

## What survives deletion
<each name → the ledger line holding it there>

## What this settles
- <component not built, code not written, or state that can't occur>

## What this makes hard
<knowingly bad at; how you'd cope if forced>

## Kill condition
<the requirement change that invalidates the commitment — name the losing
candidate it hands off to, if one exists>

## The design
<parts, data flow, interfaces — each justified against the commitment>
```
