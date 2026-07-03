# AD infrastructure: the R boundary for plant and odelia

Companion to [`ad-infrastructure-design.md`](./ad-infrastructure-design.md) and
[`ad-issues.md`](./ad-issues.md). This document covers how AD crosses the R/C++
boundary — the part Rcpp and RcppR6 make awkward — and the interface design that
keeps it clean.

---

## 1. The problem

Rcpp's `as<>`/`wrap<>` and RcppR6's generated bindings marshal **`double`** (and
containers of it). An XAD active type (`xad::adj<double>::active_type`) is a
different scalar with a tape identity; it has **no `as`/`wrap`** and must never
acquire one — serialising it would silently drop the derivative. Three concrete
frictions follow:

1. **Distinct pointer types, hand-dispatched.** `Solver<System<double>>` and
   `Solver<System<active>>` are unrelated C++ types, so they are two different
   `Rcpp::XPtr`s. odelia dispatches between them with a `bool active` flag
   threaded through *every* export (`if (active) get_solver<ActiveSystemType>` …;
   `Solver_reset_impl<SystemType, ActiveSystemType>`). The flag and the pointer's
   real type are kept in sync **only by convention** — `Solver_fit_impl` reads the
   handle as `<ActiveSystemType>` unconditionally, so a double handle reaches it as
   a type-confused reinterpret (UB / crash), not an error.
2. **Two objects leak into R.** To *fit*, the odelia user must construct a
   *second*, active solver (`LeafSolver_new(active = true)`) alongside the double
   one used to simulate. The active/double split becomes the R user's problem.
3. **The plant round-trip.** RcppR6 marshals a `FF16_Environment` to/from an R
   list. The spike's early replay rebuilt each per-stage environment in C++ with
   `Rcpp::as<plant::FF16_Environment>(st[k])` — a serialisation round-trip that is
   lossy for crown-sampled light and rebuilds the whole object per access
   (O(stand), ~1600× slower).

---

## 2. The invariant

> **Only `double` crosses the R boundary. Active types are created, used, and
> destroyed entirely within a single C++ call. R never holds an active handle.**

Everything below follows from this one rule. The AD lifecycle (build active
system → seed inputs → record → run → back-propagate → read adjoints) is an
internal detail of one C++ function; its inputs are doubles (and object handles)
and its outputs are doubles. The only place an active value is read is
`xad::value(x)` / `xad::derivative(x)` → `double`, at the very end.

This is not a limitation to work around — it is the design. It removes the pointer
duplication, the `active` flag, and the round-trip all at once, because none of
them need to exist if active types never travel.

---

## 3. odelia R interface

### 3.1 Retire the R-visible active solver and the `active` flag

R holds only the **double** `Solver`. Gradients are a driver call that builds the
active replay internally:

```cpp
// [[Rcpp::export]]  — R passes the DOUBLE solver handle; only doubles return.
Rcpp::List Solver_gradient(SEXP solver_xp,
                           Rcpp::Nullable<Rcpp::NumericVector> ic,
                           Rcpp::Nullable<Rcpp::NumericVector> params) {
  auto solver = get_solver<SystemType>(solver_xp);          // the DOUBLE solver
  auto [value, grad] = ode::compute_gradient(*solver, independents(ic, params),
                                             sum_of_squares_functional);
  return Rcpp::List::create(_["value"] = value, _["gradient"] = wrap(grad));
}
```

`compute_gradient`/`compute_jacobian` own the active system for the duration of
the call. The `bool active` parameter, the `ActiveSystemType` XPtr, and the dual
`_impl<SystemType, ActiveSystemType>` signatures disappear from the R surface. The
type-confusion hazard is gone because there is only one handle type.

### 3.2 A `rebind` contract so the driver can lift double → active

Today `LeafSolver_new` constructs the active system by hand
(`ActiveSystemType sys_active(pars, drv); sys_active.set_initial_state(…)`). Give
the System a single lift so the driver does this generically:

```cpp
struct System {
  using value_type = S;
  template <class S2> using rebind = System<…, S2>;   // double -> active mould
  template <class S2> System<…,S2> rebind_from() const; // copy config into S2
};
```

The driver calls `rebind_from<active>()`, seeds via the existing `set_params` /
`set_initial_state`, runs, and reads adjoints — all internal.

### 3.3 Tape reuse without exposing active types

The persistent tape matters *within* a call (a Jacobian records once and sweeps
per row) and across calls (an optimizer loop calling `Solver_gradient` repeatedly).
Keep it internal: cache the tape (and optionally the active scratch system) as an
**opaque handle owned by the double Solver**, keyed to nothing R can see. R reuses
the tape by reusing its double Solver; it never learns the tape exists.

### 3.4 No `wrap`/`as` for active types — by policy

Do **not** add an `Rcpp::wrap`/`Rcpp::as` specialization for XAD active types.
Forcing an explicit `xad::value()` / `xad::derivative()` at the one extraction
point keeps derivative loss visible and impossible to do by accident.

---

## 4. plant R interface

### 4.1 Pass the RcppR6 handle; unwrap the pointer, don't serialise

plant's SCM/Patch are RcppR6 objects over the **double** `<T,E>` types; keep them
that way. Gradient entries are hand-written `[[Rcpp::export]]` functions that take
the RcppR6 SCM and unwrap only its pointer — the pattern the spike's best entry
already uses:

```cpp
// [[Rcpp::export]]
Rcpp::NumericMatrix stand_gradient_cpp(SEXP scm_sexp, /* metric names, traits, … */) {
  // Rcpp::as<RcppR6<…>> unwraps .ptr only — NO serialisation of the SCM.
  auto scm = Rcpp::as<plant::RcppR6::RcppR6<plant::SCM<FF16, FF16_Environment>>>(scm_sexp);
  // build the active replay from the LIVE patch (native pointers into
  // environment_history / step_history) — no Rcpp::as<FF16_Environment>.
  // call odelia::compute_jacobian with an EmergentFunctional; return doubles.
}
```

### 4.2 Native harvest — delete the `Rcpp::as<Environment>` round-trip

The active replay reads the resident schedule and per-stage environments **by
pointer into the live Patch's own storage** (issue PLANT-4/5), so the round-trip of
§1.3 never happens. The environment is only ever read as a `double` value plus an
analytic/AD contribution; the active type never touches an RcppR6 object.

### 4.3 One thin R wrapper over one C++ entry

`stand_gradient()` keeps its signature (`scm, metrics, traits, species, feedback`)
but stops branching in R across `native` / `impl` / resident variants. It forwards
to a single C++ entry that dispatches strategy and feedback **in C++** (where the
active types live), returning the double Jacobian + values. RcppR6 never sees an
active type; the emergent translation unit is the only place they exist.

### 4.4 Functionals are constructed in C++, not passed from R

R cannot pass a C++ functional. R passes the **metric names** (strings); plant's
C++ entry maps them to an `EmergentFunctional` (a compile-time object reusing the
scalar-templated reductions) and hands that to odelia's driver. The "functional
shape" is a C++ concept that never crosses to R — only its *selection* does.

---

## 5. Resulting UX

- **odelia:** one solver object; `solver$gradient(params = …)` returns
  `list(value, gradient)`. No `active =` flag, no second solver, no way to hold a
  handle of the wrong type.
- **plant:** `stand_gradient(scm, metrics, traits, species, feedback)` on the
  ordinary (double) SCM the user already ran; returns a double Jacobian. No AD
  objects, no cache marshalling, no round-trip. `control(save_RK45_cache = TRUE)`
  on the resident run is the only AD-specific step the user sees, and it belongs to
  the model, not the boundary.

---

## 6. Work items (feed `ad-issues.md`)

| Item | Repo | Class | Note |
|---|---|---|---|
| RIF-1 | odelia | CP | `Solver_gradient`/`Solver_jacobian` on the double handle; retire the `active` flag + `ActiveSystemType` XPtr from the R surface |
| RIF-2 | odelia | CP | `rebind` lift contract (§3.2) so the driver constructs the active system |
| RIF-3 | odelia | CP-support | opaque tape/active-scratch cache on the double Solver (§3.3) |
| RIF-4 | odelia | NTH | policy check: ensure no `wrap`/`as` for active types compiles |
| RIF-5 | plant | CP | single `stand_gradient_cpp` entry taking the RcppR6 handle; C++ strategy/feedback dispatch (§4.1, §4.3) |
| RIF-6 | plant | CP | native-pointer harvest; delete `Rcpp::as<*_Environment>` (ties to PLANT-4/5) |
| RIF-7 | plant | CP-support | thin `stand_gradient()` R wrapper; remove R-side branching |

**Dependencies:** RIF-1..3 sit under ODELIA-1/2/3 (they are the R-facing side of the
driver). RIF-5..7 sit under PLANT-4/5 (native harvest) and UX-1 (stable surface).
None require exposing an active type to R; that is the point.

## Open questions

- **Keep any R-visible active solver at all?** An advanced user driving a bespoke
  optimizer loop in R might want to hold AD state across calls. The opaque-cache
  approach (§3.3) covers the common case; decide whether a power-user escape hatch
  is worth the re-introduced footgun. Recommendation: no — start with the invariant,
  add an escape hatch only on a demonstrated need.
- **RcppR6 template-type dispatch.** `stand_gradient_cpp` must resolve the SCM's
  `<T,E>` (FF16 / TF24 / TF24f) to instantiate the right replay. Confirm whether
  this dispatch is best done by the existing `extract_RcppR6_template_types` (R
  side, strings) feeding a C++ `switch`, or a C++-side type tag on the handle.
