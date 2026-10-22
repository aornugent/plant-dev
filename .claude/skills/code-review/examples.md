# Examples

These reviews show what the findings should look like and how they should read: complete sentences, each ending in a simpler alternative. Copy the reasoning, not the conclusions.

## 1. Four names for one bit of state

**Requirement:** CanopySystem's stage-dependent light forcing must be identical across the recording and replay passes.

**The diff adds:**
- a `ReplayMode` enum (`Idle, Recording, ReplayLive, ReplayFrozen`) with a `mode_` member, set at each call site
- a `ReplaySession` RAII class wrapping the existing `tape_guard`
- a `has_replay<T>` SFINAE detection struct
- a parallel `CanopySystemAD` class that duplicates `derivs` for the active type

**Bad review** (polishes the shape instead of judging it):

> 1. `ReplayMode` could be `enum class : uint8_t` 2. `ReplaySession` should be marked `[[nodiscard]]` 3. Consider `constexpr` on `has_replay` 4. Rename `mode_` to `replay_mode_` 5. Add a doc comment explaining the mode transitions… *(seven more)*

That is twelve comments that carefully polish four abstractions, none of which should survive, and silently endorse the shape.

**Good review:**

> **Verdict: rethink approach.**
>
> **Clean sheet.** A `bool recording` on the solver, the stage light stored as plain doubles at record time, and `if constexpr (Replayable<System>) load_recorded(step)` in the step loop. That is about 25 lines inside the existing types, with no new names. The diff adds four names (`ReplayMode`, `ReplaySession`, `has_replay`, `CanopySystemAD`), and no stated requirement demands any of them.
>
> **What must always be true.** The replay pass reads exactly the values the recording pass wrote. Today this is kept true by convention: `mode_` must be set correctly at every call site, and nothing stops `Recording` coexisting with a live recording it is about to overwrite.
>
> **Structural findings.**
> 1. `CanopySystemAD` is a near-copy of `CanopySystem`. Every future model change becomes a two-file edit whose copies will drift, because `derivs` is now maintained twice. Keep the single template over `T`, lift the double System via `rebind_from`, and delete the class.
> 2. `ReplayMode` stores what can be derived. That makes any record/replay mismatch harder to debug, because the mode field and the actual recording state are two sources that can disagree. Replace it with `bool recording` and `replaying() { return !recording && has_recording(); }`, and the disagreement can no longer be expressed.
>
> **Minor findings.**
> - `has_replay<T>` makes the replay condition harder to read than the existing `Replayable` concept with `if constexpr`, which it duplicates. Use the concept.
> - *[conditional]* `ReplaySession` wraps `tape_guard` without adding a guarantee. It is a second name for the same cleanup path, so every reader must check both to learn they are one thing. Use `tape_guard` directly.

The tell in the bad diff is its vocabulary: four new names to express one bit of state. Each of the good review's findings ends in a deletion.

## 2. Names that mislead

**The diff** adds a reverse sweep to odelia's solver:
- `solve_adjoint()`, which walks the recorded steps backward and returns how many segments it swept
- `rebind_from<U>()`, which returns this System on scalar `U`
- a `history` member holding the recorded rows, which the file already calls `recording` elsewhere

**Good review** (the vocabulary pass, Lens 1 step 5):

> 1. `solve_adjoint()` predicts a function that solves something and returns a solution. Its body sweeps recorded steps and returns a segment count. Every caller will guess wrong the same way, which already shows in the one call site that names the result `adjoint`. Rename it `sweep_adjoint()`, and name the result for what it counts.
> 2. `rebind_from<U>()` reads as "build this from a `U` System", but it builds a `U` System from this one. A caller writing the conversion in the other direction gets a compile error at best. Use `rebind<U>()`.
> 3. `history` is a second name for what the file calls `recording`. A reader now has to establish that the two are one thing, and the next author will add a third. Use `recording`.

These names come from odelia's reverse-mode API, where each one misled real users (traitecoevo/odelia#66). None of the findings is about taste: each is a prediction that failed, or a concept with two names.
