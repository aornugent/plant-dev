# Brief: the residual — what is left after the three landings, against refreshed upstream

Landed (pushed as branches, PRs not yet opened): PLANT-93 (exact counts, 77e15141), PLANT-97
(storage pool, b23b2d67), ODELIA-55 + PLANT-105 (soil subsystem, b707d21 / 1e8e8fa4); cases in
docs/prs/*.md. Everything else built since develop is the residual, archived as
`archive/stack-2026-10-18/*` on each fork (plant PLANT-95…110, odelia ODELIA-53…55, phylloptim
PHYLLOPTIM-17…19), plus plant-dev's harness loop (harness/schedule/refine.R; design
docs/design-refine-schedule.md). Upstream since then (forks refreshed 2026-10-18):
- plant develop bd09645d: census gradient by trait (#648, #657), FF16 fitness gradient (#658),
  light field through odelia's Hermite (#649), fitness in long patches (#661), retried
  birth-date stage (#662), K93 body in its header (#659), odelia 0.6/0.7 and phylloptim 0.9.2/0.10.
- odelia master 1e0f0f0 (0.7.x/0.8.0): Dormand–Prince recorded and swept (#76), Hairer's rule the
  default (#77), active cubic query as one tape statement (#78), and the 0.5–0.7 work before it.
- phylloptim master d216a17 (0.10.x).
The user's questions: which of our pieces does upstream now provide (in some form), which remain
genuinely new, what does each buy (measured), and how do we make a compelling, easy-to-accept case
for maintainers. The user's view: "scalar runs, recording and walks don't sound like new features";
step control is important for performance (tolerance factors −31–34% of a gradient run), the field
pieces minor. Aggregate review: docs/stack-split.md and rootcause/review/stack/{A,B,C}-*.md.
Principles: Laziness Protocol, Subtract Before You Add, Minimize Reader Load. AGENTS.md style.

For each residual piece: (1) what it does in the model's terms; (2) upstream's equivalent, if any
(file/commit), and the delta that remains; (3) the measured gain of the delta (cite plant-dev docs;
note when the number was measured on a base that upstream has since changed); (4) its smallest
form on the refreshed bases and its dependencies; (5) verdict: DROP (upstream has it / no gain),
LAND (one PR, with the headline), or HOLD (needs a measurement first — name it). Then a short
narrative for maintainers per LAND item: the problem, the mechanism, three numbers, the cost.

Read and compare only (git, grep, docs); no builds and no SCM runs (the perf investigation is
using the machine). Do not commit, push or open PRs.
