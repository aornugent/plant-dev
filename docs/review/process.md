# The process, worked backwards from what we need

**Status.** A derivation: outcomes first, then the terms each one needs, then the primitives
that supply them, then the algorithmic steps, all in one notation. It collects results that
are scattered across `theory.md`, `assembly*.md`, `field-cut.md` and `../schedule/workflows.md`,
and says what each step costs. Numbers come from the spikes where cited. It is the base for
the next search over representations.

## 0. Notation

| Symbol | Meaning |
|---|---|
| θ ∈ ℝᵏ | a strategy's traits; species i = 1…m |
| b_i, β_i = ln b_i | seed rain |
| c | physiology parameters |
| ω | one climate record. A row Ω = {ω} with weights p_ω: independent records (regime) or slices of one record at disturbance dates (history) |
| E = 𝓔(θ, β, c; ω) | the field: light by height and patch age, soil water by layer and time, made by the residents' run |
| φ(θ′; E, c) = ln R′ | invader fitness in a held field; R′ = Σ_cohorts w_k R_k |
| F_i | resident fitness |
| g_i = ∂_θ′φ at θ′ = θ_i | selection gradient |
| S = δφ/δE | sensitivity: what fitness reads in the field |
| C_j = ∂𝓔/∂β_j | impact: what a species' density does to the field |
| E_θj = ∂𝓔/∂θ_j | what a species' traits do to the field |
| H = ∂²_θ′θ′φ | held-field curvature |
| G = ∂g/∂E = ∂S/∂θ′ | how selection reads the field |
| y | the field in d shared modes; K the field of the empty stand (supply) |

## 1. What we need as outcomes

**Site selection,** on history rows (the site's own record, the observed community at its
observed seed rain):
- **O1** the balance F_i^s of each observed resident, with its error;
- **O2** the selection gradient g_i^s on each observed resident;
- **O3** the landscape φ(θ′; E^s) for a library of strategies (entries);
- **O4** the decomposition of each resident's selection deficit into EEO inefficiency and
  niche mismatch;
- **O5** calibration: c\* = argmin_c L(c), with L built from O1–O3 and data, and dL/dc
  including the part through the field.

**The eco-evolutionary loop,** on regime rows:
- **O6** the ecological equilibrium β\* for given traits;
- **O7** the evolutionarily stable community: the active set, θ\*, β\*, E\*, and a certificate
  that nothing invades;
- **O8** its classification: ESS, convergence stability, branching;
- **O9** its sensitivity dL/dc to parameters and climate, for any scalar outcome L;
- **O10** prices: reproductive value, and the price of a millimetre of rain on each day.

**Projections:**
- **O11** the community along a climate path, with the points where species turn over.

## 2. The primitives

| Primitive | Returns | Cost | Parallel over |
|---|---|---|---|
| P1 resident run, recorded | the field E(z, a, t) on the run's steps, J_i, the tape | about 2m + 2 F (with sweeps) | records ω |
| P2 kept sweep of F_i | ∂F_i/∂(every input): θ_j, β_j, c, each day's rain | about 0.5 F | outputs |
| P3 cut sweep of Σ F_i | g_i for every species at once; S_i, the zeroed field adjoints | about one sweep | — |
| P4 mode-seeded sweep | ⟨e_r, ∂𝓔/∂(every input)⟩: rows of C and E_θ on mode r | one sweep per mode | modes |
| P5 two-stage sweep | ⟨σ, ∂𝓔/∂(every input)⟩ for any field cotangent σ | one sweep | cotangents |
| P6 invader run and sweep, held field | φ, g and S at any θ′ | about 2.5 F, 91% of it in the leaf | θ′, cohorts |
| P7 forward-over-reverse on P3 or P6 | Hu and the mixed ∂²φ/∂c∂θ′ · u for a direction u | about 2 sweeps | directions |
| P8 replay on the coarse half | e_q for each judged quantity | 0.5–0.66 of a run | — |

Identities that tie them together:
- **(I1)** F_i = φ(θ_i; E) = ln J_i − ln b_i. The resident is an invader at its own traits.
- **(I2)** The kept sweep gives the total derivative:

    dF_i/dp = ∂φ/∂p|_E + ⟨S_i, ∂𝓔/∂p⟩  for every input p.

  The cut sweep gives the first term; their difference is the second, the commons.
- **(I3)** ∂F_i/∂β_j = ⟨S_i, C_j⟩, and ∂φ/∂β|_E = 0. The second is an exact check that the cut
  is complete.
- **(I4)** On a row, F_Ω = ln Σ_ω p_ω R′_ω, and every gradient is Σ_ω π_ω ∇φ_ω, with
  π_ω = p_ω R′_ω / Σ_ω p_ω R′_ω.
- **(I5)** Linearity of the cotangent. P5 seeded with Σ_e u_e S_e gives Σ_e u_e ⟨S_e, ∂𝓔/∂p⟩
  for every input p in one pass, so any number of entries' field terms cost one sweep.

## 3. Working backwards

### 3.1 O1 and O2: balance and selection at a site

On each record ω of the site's history row, at the observed (θ^s, b^s):
- **O1:** F_i^s = ln Σ_ω p_ω J_i(ω)/b_i, from P1 per record (I1, I4). Its error is
  λᵀe from P8 (`workflows.md` §6 item 1).
- **O2:** g_i^s = Σ_ω π_ω g_i(ω), from one P3 per record. No invader runs.

### 3.2 O3: the landscape at a site

φ(θ′; E^s) for a library {θ′_e}:
- **exact:** P6 per entry per record;
- **as an embedding:** φ ≈ a(θ′) + ⟨S(θ′), y_s⟩. Then a(θ′) and S(θ′) come from one P6 at an
  anchor field, and y_s is the site field on the modes (`assembly-geometry.md` §4b). The table
  costs sites + entries, not their product. Accuracy is about 0.45 ln R′ when interpolating
  inside the anchors' span; outside it, it fails.

### 3.3 O4: the decomposition of a resident's deficit

Write σ_i = S(θ_i). Then

  Δ_i = Ψ(y_s) − φ(θ_i; y_s) = [A(σ_i) − a(θ_i)] + [Ψ(y_s) − A(σ_i) − ⟨y_s, σ_i⟩].

- **Ψ(y_s) = max_θ′ φ(θ′; E^s)** is pricing at the site field: ascents with P6, or a dynamic
  program (`assembly-mfg.md`).
- **A(σ_i) = max { φ(θ; y_s) − ⟨y_s, σ_i⟩ : S(θ) = σ_i }** is a local ascent along
  null(∂S/∂θ), the traits that do not move the niche. ∂S/∂θ = Gᵀ comes from P7 or from probes
  of S with P6.
- **The first bracket is EEO inefficiency;** the second is the Fenchel–Young gap, the niche
  mismatch.

### 3.4 O5: the calibration gradient

L(c) = Σ_s ℓ_s(F^s, g^s, φ^s; data). By the chain rule,

  dL/dc = Σ_s [ ∂ℓ/∂F · dF/dc + ∂ℓ/∂g · dg/dc + Σ_e ∂ℓ/∂φ_e · dφ_e/dc ].

- **dF/dc:** P2 with c on the tape. At the observed, held b this already contains the field's
  response to c.
- **dφ_e/dc = ∂φ_e/∂c|_E + ⟨S_e, ∂𝓔/∂c⟩.** The first term is P6's sweep. For the second, one P5
  seeded with Σ_e (∂ℓ/∂φ_e) S_e gives every entry's field term at once (I5).
- **dg/dc is a second derivative.** Contract it first: with u = ∂ℓ/∂g,

    ∂ℓ/∂g · dg/dc = d/dc ⟨u, g⟩ = ∂²φ/∂c∂θ′ · u |_E + ⟨S_u, ∂𝓔/∂c⟩,

  where S_u = δ⟨u, g⟩/δE.
  - P7 on the cut tape with tangent u in θ′ gives the first term and S_u.
  - One P5 seeded with S_u gives the second.

So **a site's whole calibration gradient costs O(1) sweeps per record:** P1, P2, P3, P7, P5.
This is the term `site-selection.md` §7 found missing, now with a cost.

### 3.5 O6: the ecological equilibrium

Solve F(β) = 0 on the row by Newton:

  β ← β − F_β⁻¹ F,  F_β = [⟨S_i, C_j⟩] from P2's β columns.

It takes about 3–8 records of the row on TF24 (`field-cut.md`). The one-shot form moves β with
θ through F_θ.

### 3.6 O7: the evolutionarily stable community

The conditions, over every candidate p:

  N_p ≥ 0,  φ(θ_p; E\*) ≤ 0,  N_p φ(θ_p; E\*) = 0,  g_i = 0 on residents,  E\* = 𝓔(θ, N).

**The Newton step, in field coordinates** (`assembly-report.md` §4). Each tracked strategy steps
to its best response in the predicted field, and the field responds:

  δθ_p = −H_p⁻¹ (g_p + G_p δE),  δE = Σ_p c_p δN_p + Σ_res E_θj δθ_j.

Eliminating δθ leaves a d × d system:

  Q δE = C δN + r,  Q = I + Σ_j E_θj H_j⁻¹ G_j,  r = −Σ_j E_θj H_j⁻¹ g_j.

The densities then solve a complementarity problem of rank d:

  N⁺ ≥ 0,  q + M N⁺ ≤ 0,  N⁺ ⊥ (q + M N⁺),
  M = S̃ Q⁻¹ C,  q = φ̃ + S̃ Q⁻¹ (r − C N),
  φ̃_p = φ_p − ½ g_pᵀ H_p⁻¹ g_p,  s̃_p = S_p − G_pᵀ H_p⁻¹ g_p.

Where each term comes from:

| Term | Primitive |
|---|---|
| φ, g, S at residents | P1, P3 |
| φ, g, S at candidates | P6 |
| C, E_θ | P2's β columns and P4 on the modes |
| H, G | P6 probes or P7: full once a round, then d + 1 directions |

**Pricing.** Entry needs max_θ′ φ(θ′; E\*):
- ascents with P6;
- or one backward dynamic program over height × patch age (`assembly-mfg.md`), which bounds
  every strategy.

**The certificate:** the final round's pricing finds nothing above zero, with the sign of each
margin certified by P8.

**Three equivalent views of the same root:**
- **Projection.** If impacts align with sensitivities, c = −ΛS, then E\* is the projection of
  the supply K onto {Ψ ≤ 0}, residents are its active faces, and densities its multipliers.
- **Duality.** The frontier A(σ) and its conjugate Ψ(y); coexistence is a kink of Ψ.
- **Mean-field game.** A backward value sweep and a forward density sweep, coupled through E.

### 3.7 O8: classification

- **ESS:** H_i ≺ 0.
- **Convergence stability:** from J = H + G dE\*/dθ, with

    dE\*/dθ = E_θ − C F_β⁻¹ F_θ,

  all from the sweeps. Strong convergence stability needs J + Jᵀ ≺ 0.
- **Branching:** convergence-stable but not ESS.
- **Coexistence (convexity):** the symmetric part of A = −S·C, with λ_min > 0.

### 3.8 O9: sensitivity of the evolved outcome

At the root G(x; c) = 0 with x = (β, θ), for a scalar outcome L,

  dL/dc = ∂L/∂c − λᵀ G_c,  G_xᵀ λ = ∂L/∂x.

- **Solving for λ** reuses the step's structure: H_j⁻¹ block by block, and a (d + m) Schur
  system.
- **λᵀ G_c for every c at once:**
  - the F rows: P2 seeded with λ_F, c on the tape;
  - the g rows: P7 with tangent λ_g on the cut tape, then P5 with the S it returns.
- **Cost:** O(1) sweeps after the root, for every parameter and every day of rain.

### 3.9 O10: prices

- **The kept sweep's costates** are reproductive value including the externality; **the cut
  sweep's** are the invader's own.
- **A rain column** is P2's derivative with respect to the rain on day t. The invader's version
  is P5 seeded with S.
- **Their difference** is the commons in water, day by day.

### 3.10 O11: projections

- **Predict** dx\*/dc from O9, then **correct** with O7's step from that warm start.
- **Response conservation** (`assembly-geometry.md` §4c): with m = d, dE\* = dθ\* = 0 inside a
  supply cone, and dN = C⁻¹ dK. Inside a cell a step is one linear solve and one confirming
  run.
- Turnover happens where some N_p reaches 0, or where a candidate's φ̃ reaches 0. Pricing is
  needed only there.

## 4. The process

**Site selection (history rows), per site:**
1. **Sequential:** a P1 per record (records in parallel), then P2, P3 and P8 → O1, O2.
2. **Parallel over entries:** a P6 per entry, or the embedding → O3.
3. **Pricing at the site field,** then a local ascent along null(∂S/∂θ) → O4.
4. **Calibration terms:** P7 and P5 → O5. Then aggregate over sites and step c.

**The eco-evolutionary loop (regime rows):**
1. **Start:** pricing on K or a warm start; projection cuts for a globally convergent start.
2. **Passes:**
   - a P1 per record in parallel, then P2/P3/P4 (or a relinearised making map, then
     invader-only inner passes);
   - P6 probes for H and G in parallel;
   - the d × d system and the complementarity problem;
   - a trust-region step.
3. **Rounds:** price when the master converges; entrants join.
4. **At the root:** certify with P8 on the held schedule; classify (O8); run the adjoint (O9)
   and prices (O10).
5. **Along climate:** predict, correct, and price only at turnover (O11).

**What sets the cost:**
- the leaf solves, 91% of P1 and P6;
- pricing depth, the critical path on 16 cores;
- the number of sequential P1 runs.

Every outcome needs only first derivatives and P7's single directional second derivatives,
each contracted against one cotangent.

## 5. Open in the process

- **History rows have no equilibrium,** so O6–O8 are regime-only. O4 needs pricing at an
  unequilibrated site field, which is fine: Ψ needs no equilibrium.
- **Break-even sensitivity on closed canopies** (`spikes/break-even/`, running) may change
  what O1, O6 and O7 can resolve.
- **P7** (forward over reverse through odelia's stepwise sweeps) is assumed, not built. XAD
  supports it.
- **The field basis (modes) for P4 and the embedding** is chosen from the sensitivities.
  Exact residuals keep the answers independent of it; only rates depend on it.
