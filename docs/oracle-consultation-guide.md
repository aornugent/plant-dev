# Consulting the Oracle: guidance and best practice

Hard-won practice for framing external expert ("Oracle") consultations, written after a
long multi-round investigation in which *the framing of the question determined the
quality of the answer* more than anything else. Follow this whenever you prepare a
problem statement for an Oracle (or any powerful external reasoner) and when you act on
what comes back.

The single most important lesson, stated once: **the Oracle answers the question you
actually asked, not the one you meant.** A statement that advocates a candidate fix
gets that fix defended or refined; a statement that describes the problem completely and
neutrally gets a genuinely new reframe. We watched the *same underlying problem*, put
two ways, produce a narrow defence in one case and the decisive structural insight in
the other. Frame for discovery, not confirmation.

---

## 1. Describe the problem, never your candidate solution (avoid the XY trap)

- The failure mode: you have hypothesis Y for problem X, so you ask "how do I make Y
  work / is Y valid?" The Oracle then reasons about Y and never sees X. You get a better
  Y, not the insight that Y is the wrong object.
- The tell, in your own draft: the question is "is my fix valid", "how do I make X
  work", "which of my two options". Rewrite to "here is the complete system and exactly
  what we observe; what is going on, and what should we do?"
- Concretely, in this project: a statement built around "here is my conserved-weight
  reformulation, is it valid?" would have gotten that reformulation graded. The
  statement that instead laid out the whole system neutrally got the Oracle to identify
  — unprompted — that a quantity was being carried twice as a cancelling pair, which was
  the actual answer and which neither we nor the narrow framing had reached.
- **The mathematical representation is a candidate solution too.** Choosing to call the
  object a measure, a field, a point pattern, or an operator of a particular class
  silently selects the toolbox that fits it — the XY trap one layer down, and a lead even
  when you have named no method. Describe the object by the *operations available on it*
  (what is cheap to compute, what you can sample, what maps to the observable, what the
  couplings are) and let the reasoner name the right formalization. The tell: if the answer
  is the canonical method of the representation you chose, you led. In this project a
  statement that fixed the object as "a law on finite point sets with an intensity" drew,
  inevitably, the point-process calculus that fits that object — an excellent answer to a
  question we had silently narrowed, not to the open one.

## 2. Present every structural feature with equal weight; foreground nothing

- If you suspect feature F is important, that is exactly the reason **not** to headline
  it. List it among all the others, flat, and let the Oracle rank them. Foregrounding F
  both biases the Oracle toward F and starves the features you did not think to
  emphasise — which is where the answer usually hides.
- Include a "structural features, any of which may be load-bearing or incidental — we do
  not know which" section. This invites the Oracle to do the ranking that is the actual
  expert judgement you want.

## 3. Keep the mathematics complete; strip the domain to zero

Two opposing pressures, and you must satisfy both:

- **Strip all domain vocabulary.** Domain nouns bias a general reasoner toward
  domain-specific heuristics (sometimes the *wrong* domain's), and are a scope/leak
  concern. Replace them with neutral mathematical terms and scan every statement before
  sending (grep for your domain's nouns; get to CLEAN).
- **Do not strip the structure.** The leverage lives in the exact structure: the
  discretization, the operator, the kernel's support, the low rank, the record/replay,
  the boundary condition. Under-describe these and you get a generic answer. The key
  reframe in this project was only reachable because the *exact discretization* (a term
  appearing in two state variables via specific quadrature weights) was fully written
  out. A statement that said "we compute the transport term somehow" would have hidden
  it.
- The balance: a reader with no domain knowledge should be able to reconstruct the full
  mathematical model and its discretization from your statement, and could not guess the
  application. Both at once.

## 4. Bring the data — refutations are the most valuable payload

- Include measured results: what you tried, the numbers, what worked and what failed,
  and the **correctness reference** (what "truth" means and how you measure it — e.g.
  "converged finite difference of the model as run").
- A **measured refutation of a prior Oracle claim** is gold. In this project, reporting
  "you predicted these two terms cancel; measured, they add, same sign, +2.3× → +3.4×"
  is what forced the correct model. Do not soften refutations; state them with the
  numbers and invite the Oracle to update.
- A clean discriminating experiment (a null-channel probe, an A/B with one variable) is
  worth more than paragraphs of description.

## 5. Ask open questions, phrased to invite reframing

- Good: "Which feature is load-bearing? Is the difficulty intrinsic to <the structure>
  or an artifact of a representational choice we have not questioned? If intrinsic, state
  the precise obstruction; if representational, the minimal change and its cost."
- Bad: "Is my fix valid?" / "How do I make the slope read faithful?" (both assume the
  object to keep).
- Explicitly license the Oracle to reject your framing: "we suspect we are looking at
  this through the wrong variable." That sentence did real work here.

## 6. Consult more than once, and vary the framing deliberately

- Independent framings triangulate. **Convergence** of two independent framings on the
  same mechanism is strong evidence; **divergence** localises the real fork (and is
  itself information — which assumption they disagree on is the thing to test).
- Keep earlier statements and responses as dated docs; mark superseded ones. The running
  catalogue is what lets you diff responses and notice that a later, better-framed
  question unlocked something the earlier one suppressed.

## 7. Never act on an Oracle claim without a faithful falsifiable test first

- Oracles are confidently wrong sometimes. In this project a proposed cancellation
  mechanism and a curvature-based fix were both delivered with high confidence and both
  **falsified by a one-recompile experiment.** The correct diagnosis was *also* delivered
  confidently — the only way to tell them apart was to test.
- **The test's quality is fidelity to the real system, not cheapness.** The trap: an
  experiment made cheap by *simplifying the system representation* answers an easier
  question than the one you have, and its verdict need not transfer. In this project a
  multirate stepper looked beneficial on a simplified, decoupled sub-system and delivered
  **no benefit once coupled to the real system** — the cheapness came precisely from
  dropping the coupling that governed the outcome. Choose the **most decisive experiment
  that still exercises every interaction the conclusion depends on**, run in the deployed
  setting, not a proxy; smallness is a tiebreaker among faithful tests, never the criterion.
- Reduce every Oracle-proposed mechanism to the smallest *faithful* experiment that would
  confirm or kill it, and run that **before** any refactor. The prototype-and-measure loop
  is the arbiter; the Oracle is a source of hypotheses, not verdicts.
- Prefer the test the Oracle itself proposes if it offers one — a good Oracle response
  includes its own falsifiable prediction ("both classes go green simultaneously; if the
  mover is still off, the leak is in <named place>"). Run exactly that — **but first check
  its test keeps the real couplings; a prediction that only holds on a simplified
  representation is the trap above.**

## 8. State the constraints the answer must respect

- Give a "facts an answer can rely on" list: the invariants, what is settled, what is
  frozen, the cost model, what must stay bit-identical. This keeps the Oracle reasoning
  inside the real solution space instead of proposing things ruled out on line one.

## 9. Hygiene

- One problem per statement; narrow scope, complete description. Breadth dilutes.
- Self-contained: assume the reader has none of the prior thread. If it must stand alone
  in a fresh context, say so and remove every back-reference.
- Scan for domain leaks every time; treat CLEAN as a gate, not a nicety.

---

## The workflow in one paragraph

Write the complete, domain-clean, neutrally-weighted problem statement with the data and
an open question. Get responses from more than one framing. Where they converge, extract
the falsifiable prediction and **test it cheaply before building anything**. Where they
diverge, test the assumption they disagree on. Record everything. Treat the Oracle as a
generator of hypotheses to be verified by measurement — its value is in seeing structure
you cannot, not in being right on authority. The moment your statement starts arguing for
your preferred answer, stop and rewrite it as a description.
