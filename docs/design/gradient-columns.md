# Which parameters have a gradient, and what a zero means

The second of two tracks split out of the reverse-mode redesign. Unlike
`recording-and-sweep.md`, this one **changes the answer** on purpose: columns
appear that were absent, and R-visible status strings change. It has its own
referee — `test-gradient-ladder-declared-zero.R`, which checks the declarations in
both directions — and it lands after the recording track, because that track's
bit-for-bit claim is only clean against an unchanged column set.

## What the table is, and is not

`TF24_Pars`' 62-entry table reads as boilerplate and is not. C++ has no
reflection, so one line per member is the floor, each line carries a fact nothing
else knows, and the `sizeof` assert makes the list total — a member cannot be
added and silently miss the gradient. **The table is the declaration and it
stays.**

What was wrong is the vocabulary on it, and the shape of the argument that got us
here is worth keeping: **prefer a documented rule to a modelled one.** Three
rounds of this design tried to encode in `Kind` what a sentence explains better.

## The vocabulary, reduced

`Kind` carried six enumerators. Four of them were answering questions that are not
about the number a caller is holding:

| was | why it goes |
|---|---|
| `no_column` | the one value that switched the referee off — an omitted column is never computed, so nothing checks the claim that it is zero |
| `zero_slack` | named for a borrowed mechanism, and a static declaration of a state-dependent fact |
| `zero_structural` | claims more than it means: `a_f3`'s zero is relative to **this metric set**, not to the model |
| `zero_undeclared` | named for what the table failed to say, which is a fact about the table |

What survives is three: **`answered`**, **`refused`**, and one finding class for a
zero nobody can explain — `zero_unexplained`, named for the number rather than for
the table's silence about it.

## A limit is a kind of parameter, not a kind of zero

`psi_crit` and `root_psi_crit` **are limits**. That is static and always true.
Declare *that*, and "a limit's row is zero exactly while the operating point is
away from it, and live the moment the point sits on it" becomes one documented
consequence rather than an enum value that asserts a state-dependent claim
statically.

This is also T6's fix, and it picks the right side. phylloptim already has
`InputRole::Slack` on exactly those two inputs, and plant declares the same fact
independently. The leaf owns which of its inputs are limits, so plant derives it
from `leaf_par` and stops declaring it. One fact, one home, and the home is the
package that knows.

## Zeros that are answers, and zeros that are unavailable

`no_column` was hiding two different things behind one silence. The axis is
**is the derivative known to be zero, or is it unavailable?**

- **Known zero, and informative.** `a_f3` moves exactly two rates — `fecundity`
  and `offspring_produced_survival_weighted` — and the census reads neither; the
  ladder names those two rates so that *"a third rate would mean the census's
  silence about the column is wrong."* `S_D`, `nmass_*`, `dmass_dN`,
  `var_sapwood_volume_cost`, `a_p1`, `a_p2` and `p_50` are in the same position.
  "This trait does not move these metrics" is what a user optimising over it needs
  to learn, so these are **answers**: compute the column, return the zero, and let
  the ladder police it. Which metric set that is true of belongs in the
  documentation, not in an enumerator.
- **Unavailable.** `d` — *"no row in the leaf's supplied Jacobian"* — plus `eta`
  and `root_depth_shape_eta`, where a recorded row would be a wrong zero because
  `u^eta·log(u)` is `0·(−inf)` at `u = 0`. Nothing is known here, so these
  **refuse**, and the user's loop is the right one: ask, be refused, choose other
  targets. (T7 argues `lim(u→0+) u^η ln u = 0`, so the two `eta` cases may be
  answers after all. Testable on the ladder.)
- **Not a differentiable real.** `use_energy_balance` is a gate, compared rather
  than differentiated. It should not be an `S` in a table of differentiable reals
  at all, which is a struct question rather than a gradient one.

With `no_column` empty, the has-a-column partition goes: `column_count` and
`field_count` coincide, `has_column()` is unnecessary, and `ad_parameters()` and
`field_ptrs()` become one accessor.

## Detection beats declaration, where it is available

The fourteen leaf parameters do not need declaring: phylloptim fills unclaimed
rows with `util::na_value`, so an input nothing claims returns NA and the graft
refuses it. **That is detection, and it is why the leaf half of the table needs no
zero vocabulary at all.**

The forty-eight plant-only parameters have no equivalent default. They are seeded,
taped, and 0.0 for "no edge reached me" is indistinguishable from 0.0 for "the
derivative here is zero". **That indistinguishability is the only reason a
declaration exists.** So the question worth chasing before writing any of the
above: can plant's own parameters be given phylloptim's NA default? If they can,
eight declarations become detections and the residue is small enough to document
rather than model.

## The documented rule, in place of machinery

A parameter absent from the table is one whose gradient is not implemented. That
is a sentence in `stand_gradient`'s documentation and a refusal naming it, and
between them they replace an enumerator, its projection on two classes, and a
partition. Asking for such a trait refuses; the caller picks different targets.

Selection stays where the caller is. `stand_gradient()` already subsets columns in
R, a reverse sweep is indifferent to how many inputs it carries, and per-column
refusal means a degenerate `psi_crit` no longer costs a caller their `lma` column.
Nothing needs seeding a subset in C++.

## Increments

1. **Rename, mechanically.** `zero_undeclared` → `zero_unexplained`; the two
   R-visible strings and `stand_gradient`'s documentation with them.
2. **`limit` becomes a parameter kind**, derived in plant from `leaf_par` rather
   than declared — T6.
3. **Research, before 4.** Can plant's own parameters carry phylloptim's NA
   default? The answer sizes everything after it.
4. **Refile the eleven.** The eight known zeros become computed columns the ladder
   polices; `d`, `eta` and `root_depth_shape_eta` refuse; `use_energy_balance`
   leaves the differentiable struct. `no_column` empties, and the partition,
   `has_column()` and one of the two accessors go with it.
