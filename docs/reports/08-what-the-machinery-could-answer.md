# What the machinery could answer: the adjoint as an operator, not a vector

Written 2026-08-04. Read after reports 05, 06 and 07.

Reports 05 to 07 take the trait gradient as the goal and ask how to compute it correctly
and cheaply. **This report asks a different question: given what the machinery already
computes, what else is it a short step from answering?**

Its motivation is that several of the plan's tasks are individually modest and jointly
change what kind of object the project produces. That only becomes visible when they are
read together, so this is the report that reads them together.

**Provenance discipline.** Every claim below is labelled:

- **[read]** — established from the code, with the symbol named.
- **[derived]** — follows from a labelled read by algebra stated here.
- **[inferred]** — consistent with what is read, not established. Needs a specific check,
  which is named.
- **[speculative]** — an idea whose value is clear and whose feasibility is not.

The project's failure record is that claims about code decay and mathematics does not, so
the labels matter more than the prose.

---

## 1. The shape the design is converging on

Four of the plan's tasks are, structurally, the same move: put a **small linear map** at a
boundary of the adjoint and keep the adjoint itself canonical.

| boundary | the map | what it replaces | plan item |
|---|---|---|---|
| parameters in | $J = \partial\Phi/\partial\phi$, 44 × (free) | differentiating the derivation | Task 28, report 07 §3 |
| field in | $W$, cohorts × 130, at most 78 non-zeros per row, measured **[read]** | treating 130 inputs as 130 channels | Task 22, report 07 §1 |
| censuses out | the seed matrix, metrics × states | one sweep per metric | Task 11, report 07 §4 |
| time out | a per-step source $\rho(t)$ instead of a terminal seed | one run per patch age | plan §9, unscoped |

**[derived]** If all four are thin and linear, the adjoint computes one object — the map
from *a seed at each time* to *input adjoints* — and everything a user asks is a choice of
adapters. A sensitivity matrix of (arbitrary censuses) × (arbitrary parameterisation),
integrated over patch age, then costs **one recording, one sweep per seed-basis element,
and two small matrix multiplies.**

That is the framing this report builds on. It is not a new mechanism; it is the
observation that the plan is already three-quarters of the way to it without saying so.

---

## 2. The adjoint state is being computed and discarded, and it answers a different question

**[read]** The reverse pass carries $\lambda$ over the state, backwards, segment by
segment: `Solver::solve_adjoint` sweeps it and `Step::step_adjoint` advances it. **[read]**
Only `Patch::trait_adjoint` is retained; $\lambda$ itself is a local and is dropped at each
segment boundary.

**[derived]** But $\lambda(t) = \partial \mathcal{C}/\partial y(t)$ — the sensitivity of the
final census to *the state of every cohort at every time on the trajectory*. The trait
gradient is one contraction of it, $\int (\partial f/\partial\varphi)^{\!\top}\lambda$.
Keeping $\lambda$ costs storage and no computation.

### What that object is, ecologically

Per cohort and per time it is:

- $\lambda_{\ell_k}(t)$ — how much the final census depends on **how many stems** that
  cohort carries at that moment;
- $\lambda_{h_k}(t)$ — on **how tall** they are;
- $\lambda_{r_k}(t)$ — on **how much carbon they have stored**.

That is a **demographic influence function**: which part of the size distribution, at which
point in the stand's history, drives the outcome. Report 06 argues that a trait gradient
mixes physiology with competition and cannot separate them. The influence function does not
have that problem — it is a statement about the stand, not about a parameter.

### And it answers questions about interventions, not only about traits

**[derived]** A perturbation $\delta y$ to the state at time $t$ changes the census by
$\lambda(t)^{\!\top}\delta y$ to first order, whatever the perturbation is. So:

- **Thinning.** Removing a fraction $f$ of stems from cohorts in a size class is
  $\delta \ell_k = \log(1-f)$ for those $k$. The census response is
  $\log(1-f)\sum_{k \in \text{class}} \lambda_{\ell_k}(t)$.
- **A disturbance at one age**, a planting, a defoliation, a drought year applied to
  reserves — each is a $\delta y$ at a time, and each is one dot product.

**One recording therefore answers "what happens if I intervene, in this way, at this time"
for every size class and every year at once**, to first order. A finite difference pays a
full re-run per intervention per timing.

**[inferred]** I believe this is the largest unclaimed capability in the project, and the
check is cheap: confirm from `solve_adjoint` that $\lambda$ at a segment boundary is the
full state adjoint and not a partial accumulation, and compare one dot product against a
re-run with the state perturbed. If those agree, the capability is real.

**Limits, stated plainly.** It is first order, so it is a marginal analysis and says nothing
about a large intervention. The model is one patch with a disturbance regime, so
"management" is a loose reading. And it inherits every gap in report 05 §11 — an influence
function built on an aliased seed is as wrong as the gradient is.

---

## 3. Competition is low-rank, and the rank does not grow with the stand

**[read]** Every cohort reads the shared environment and nothing else about its neighbours:
no plant-to-plant term exists anywhere in the model. The interface is 130 light numbers plus
$L$ soil numbers. **[read]** Each cohort reduces the light field to **one** scalar before its
physiology runs.

**[derived]** So the per-step Jacobian of the whole stand has the form

$$\frac{\partial \dot y}{\partial y} = \underbrace{D}_{\text{block diagonal, per cohort}} + \underbrace{B\,C}_{\text{rank} \le 130 + L}$$

where $C$ maps cohort states to the environment (the reductions) and $B$ maps the
environment back into cohort rates. **The interaction is diagonal plus low rank, and the
rank is bounded by the environment's width — not by the number of cohorts.**

**A stand of ten thousand cohorts still interacts through 135 numbers.** That is an
ecological statement as much as a numerical one: the dimension of competition in this model
is a property of how finely the environment is discretised, not of how many plants there
are.

**[speculative]** What this buys is not in the adjoint, which already exploits the structure
implicitly. It is in everything that wants the Jacobian *itself*: the stability of a stand
against perturbation, an implicit solver for stiff configurations, and the invasion problem,
where a mutant's growth rate is an eigenvalue of exactly this operator. Diagonal-plus-low-rank
is a structure with standard solvers. **Nothing in the plan uses it and I cannot say what it
would cost.** Recorded because the structure is a read, even though the use is not.

---

## 4. The argmax channel may be dead in some configurations

**[read]** The expensive half of the leaf's derivative work is the argmax channel:
$\Pi_{pu}$, whose parameter part is 22 of 30 evaluations of `dprofit_droot_collar_psi`, plus
$\Pi_{pp}$ in its denominator. **[read]** `s_adjoint` accumulates the **uptake** rows only —
profit's channel through $p^\star$ is zero at an interior optimum by the envelope theorem, so
the code correctly omits it.

**[derived]** Therefore the argmax channel exists to carry sensitivity through **soil water
consumption**, and nothing else. Profit — and so growth, mortality and fecundity, which is
all of the demography — needs only direct partials at the operating point.

**[inferred]** So in a configuration where soil water consumption does not feed back — a
water-saturated run, or one where the soil state is held — **the entire argmax channel is
structurally dead, and with it the majority of the leaf's derivative cost.** The check is a
grep and one run: establish whether any census metric's dependence on $\varphi$ reaches soil
consumption when the soil is not limiting, and if not, guard the channel on it.

That would be a large saving available *without* Task 4's derivation, in exactly the
configuration an ecologist studying a mesic site would use. It does not remove the need for
Task 4, because the drought configurations are the interesting ones — but it means the
expensive derivation is not on the critical path for every question.

---

## 5. What the four adapters make possible that the project has not named

**[derived]** from §1, given the plan's own tasks and nothing more:

- **Calibration.** A misfit against observations is a functional of the trajectory, so it is
  a seed. Its gradient with respect to a fitted parameter vector is
  $J^{\!\top}\nabla_\varphi$. That is precisely what an optimiser consumes, and it is one
  recording per iteration rather than one per parameter per iteration.
- **Trait-spectrum sensitivity.** A leaf-economics axis is one column of $J$. So "how
  sensitive is this stand to position on the leaf-economics spectrum" is a question this
  machinery can answer directly, rather than by projecting 44 separate numbers afterwards.
- **Experimental design.** The influence function of §2 says which state, at which time, the
  outcome depends on most — which is where a measurement would be most informative.
- **Optimal intervention.** §2's dot products, ranked, order interventions by marginal
  effect for one recording.

**[speculative]** and the one I am least sure of: **invasion fitness may inherit the leaf's
economy one level up.** A resident stand at demographic equilibrium satisfies a stationarity
condition, and the envelope theorem's logic — at a stationary point, the shift in the
stationary state contributes nothing to first order — is not specific to a plant's water
potential. If the resident's equilibrium is a genuine stationarity in the right variable,
derivatives of resident quantities with respect to resident traits drop a term, exactly as
profit does. **Nothing has been read to support this.** What would settle it: whether the
model's resident equilibrium is characterised by a stationarity condition or only by a fixed
point, which are not the same thing and only the first gives an envelope theorem.

---

## 6. What to check, in order of value per unit of work

1. **§2's influence function.** One confirmation from `solve_adjoint` plus one dot product
   against a perturbed re-run. If it holds, it is a new capability for approximately no new
   code, and it is the thing most likely to matter to an ecologist.
2. **§4's dead argmax channel.** A grep and one run, and it may retire most of the leaf's
   cost in a common configuration.
3. **§1's composition** — that the seed matrix and the per-step source compose. This is
   already a question in the plan's task set and it decides whether the scaling claim in §5
   is real.
4. **§3's low-rank structure** is a read and needs no check; what needs establishing is
   whether anything wants it.
5. **§5's invasion claim** is speculative and should stay a note until the equilibrium
   condition is read.

**And one warning that applies to all of it.** Every capability here is built on the same
recording as the trait gradient, so every one inherits report 05 §11's gaps. An influence
function computed from an aliased seed is wrong in exactly the way the gradient is wrong,
and it is *more* dangerous, because it looks like a description of the stand rather than a
derivative and invites less scepticism. **None of this is worth exposing before the
correctness items are closed.**
